extends Node
## 程序化音效 + BGM 合成器（零外部音频文件，零版权风险）
## 自动加载为单例：Sfx
##
## 原理：所有声音都用 AudioStreamGenerator 实时合成 PCM 波形，
## 或预生成 AudioStreamWAV 缓存复用。

const SR := 22050  # 采样率，够用且省 CPU

var _players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _narrator_player: AudioStreamPlayer    # ★ 旁白专用：避免被单字读音打断
var _pool_i := 0
var _cache: Dictionary = {}
var _voice_cache: Dictionary = {}
var _story_cache: Dictionary = {}
var _ult_cache: Dictionary = {}            # ★ 大招喊话缓存（按台词文本索引）
var _shout_player: AudioStreamPlayer      # ★ 大招喊话专用声道
var voice_on := true
var _bgm_base_db := -12.0
var _duck_target := 0.0                    # ★ BGM 闪避目标（旁白时压低）

# BGM 状态
var _bgm_on := false
var _bgm_seq: Array = []
var _bgm_step := 0
var _bgm_timer := 0.0


func _ready() -> void:
	# 建 8 个音效播放器做池子
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -12.0
	add_child(_bgm_player)
	# 汉字读音专用播放器
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "Master"
	_voice_player.volume_db = 1.0
	add_child(_voice_player)
	# 旁白专用播放器（与单字读音分开，互不打断）
	_narrator_player = AudioStreamPlayer.new()
	_narrator_player.bus = "Master"
	_narrator_player.volume_db = 2.0
	add_child(_narrator_player)
	# 大招喊话专用声道（与上面三条都分开：结印那 1 秒里可能三件事同时发生）
	_shout_player = AudioStreamPlayer.new()
	_shout_player.bus = "Master"
	_shout_player.volume_db = 4.0
	add_child(_shout_player)
	_build_bgm_sequence()


func _process(delta: float) -> void:
	# BGM 闪避：旁白说话时把音乐压低，不抢人声
	if _bgm_player != null:
		var want: float = _bgm_base_db + _duck_target
		if abs(_bgm_player.volume_db - want) > 0.05:
			_bgm_player.volume_db = lerp(_bgm_player.volume_db, want, clamp(delta * 7.0, 0.0, 1.0))
	if not _bgm_on:
		return
	_bgm_timer -= delta
	if _bgm_timer <= 0.0:
		_play_bgm_step()
		_bgm_timer = 0.24  # 约 250 BPM 的十六分音，热血街机速度


## 旁白说话时压低 BGM（on=true 压低 -11dB）
func duck_bgm(on: bool) -> void:
	_duck_target = -11.0 if on else 0.0


# ============ 波形生成工具 ============
func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clamp(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	return w


func _tone(freq: float, dur: float, vol: float = 0.5,
		wave: String = "square", decay: bool = true) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SR
		phase += TAU * freq / SR
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if sin(phase) >= 0.0 else -1.0
			"tri":
				s = asin(sin(phase)) * 2.0 / PI
			"saw":
				s = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"noise":
				s = randf() * 2.0 - 1.0
			_:
				s = sin(phase)
		var env := 1.0
		if decay:
			env = pow(1.0 - float(i) / n, 2.0)
		out[i] = s * vol * env
	return out


## ★ 频率扫频（f0→f1 线性滑音）：破空音 / 上扬 zing 的核心
func _sweep(f0: float, f1: float, dur: float, vol: float = 0.5,
		wave: String = "saw", decay: bool = true) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		var freq: float = lerpf(f0, f1, k)
		phase += TAU * freq / SR
		var s := 0.0
		match wave:
			"saw":
				s = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"square":
				s = 1.0 if sin(phase) >= 0.0 else -1.0
			_:
				s = sin(phase)
		var env := 1.0
		if decay:
			env = pow(1.0 - k, 1.6)
		out[i] = s * vol * env
	return out


func _noise_burst(dur: float, vol: float = 0.6, lp: bool = true) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var s := randf() * 2.0 - 1.0
		if lp:
			prev = prev * 0.6 + s * 0.4
			s = prev
		var env := pow(1.0 - float(i) / n, 2.5)
		out[i] = s * vol * env
	return out


func _concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	out.append_array(b)
	return out


# ============ 音效库 ============
func _get_sfx(key: String) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var s: AudioStreamWAV
	match key:
		"swing":
			s = _make_wav(_tone(880, 0.08, 0.35, "saw"))
		"hit":
			var a := _noise_burst(0.12, 0.7, true)
			var b := _tone(180, 0.10, 0.5, "square")
			s = _make_wav(_concat(a, b))
		"crit":
			var c1 := _tone(1200, 0.06, 0.5, "square")
			var c2 := _tone(1600, 0.06, 0.5, "square")
			var c3 := _noise_burst(0.18, 0.8, true)
			s = _make_wav(_concat(_concat(c1, c2), c3))
		"hurt":
			s = _make_wav(_tone(220, 0.25, 0.5, "saw"))
		"correct":
			var d1 := _tone(784, 0.09, 0.4, "square")
			var d2 := _tone(1046, 0.09, 0.4, "square")
			var d3 := _tone(1318, 0.16, 0.45, "square")
			s = _make_wav(_concat(_concat(d1, d2), d3))
		"wrong":
			var w1 := _tone(196, 0.14, 0.45, "square")
			var w2 := _tone(147, 0.22, 0.45, "square")
			s = _make_wav(_concat(w1, w2))
		"select":
			s = _make_wav(_tone(1046, 0.06, 0.35, "square"))
		"levelup":
			var l1 := _tone(523, 0.07, 0.4, "tri")
			var l2 := _tone(659, 0.07, 0.4, "tri")
			var l3 := _tone(784, 0.07, 0.4, "tri")
			var l4 := _tone(1046, 0.20, 0.5, "tri")
			s = _make_wav(_concat(_concat(_concat(l1, l2), l3), l4))
		"boss":
			var b1 := _tone(110, 0.20, 0.6, "saw")
			var b2 := _tone(82, 0.35, 0.6, "saw")
			s = _make_wav(_concat(b1, b2))
		"jump":
			s = _make_wav(_tone(480, 0.11, 0.42, "tri"))
		"land":
			var ln1 := _tone(150, 0.10, 0.5, "square")
			var ln2 := _noise_burst(0.06, 0.4, true)
			s = _make_wav(_concat(ln1, ln2))
		"dash":
			s = _make_wav(_noise_burst(0.16, 0.5, true))
		"sonic":
			# ★ 穿梭特招专属：短促气爆 + 1400→120Hz 破空下扫 + 700→2300Hz 回锋上扬
			var so0 := _noise_burst(0.05, 0.55, true)
			var so1 := _sweep(1400.0, 120.0, 0.20, 0.50, "saw")
			var so2 := _sweep(700.0, 2300.0, 0.16, 0.38, "tri")
			s = _make_wav(_concat(_concat(so0, so1), so2))
		"stomp":
			var st1 := _tone(110, 0.13, 0.55, "square")
			var st2 := _noise_burst(0.09, 0.5, true)
			s = _make_wav(_concat(st1, st2))
		"special":
			var sp1 := _tone(880, 0.05, 0.4, "square")
			var sp2 := _tone(1318, 0.12, 0.4, "square")
			s = _make_wav(_concat(sp1, sp2))
		_:
			s = _make_wav(_tone(440, 0.1, 0.3))
	_cache[key] = s
	return s


func play(key: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	var p := _players[_pool_i]
	_pool_i = (_pool_i + 1) % _players.size()
	p.stream = _get_sfx(key)
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()


# ============ BGM（热血街机循环） ============
var _bgm_notes: Array = []
var _bgm_wave: PackedFloat32Array
var _bgm_stream: AudioStreamWAV

func _note_hz(n: int) -> float:
	# MIDI 音高转频率
	return 440.0 * pow(2.0, (n - 69) / 12.0)


func _build_bgm_sequence() -> void:
	# 一组小调 riff，做成有推进感的街机循环（MIDI 音高）
	# 主旋律（八分音）
	_bgm_seq = [69, 72, 76, 72, 74, 72, 69, 67,
				69, 72, 76, 79, 76, 74, 72, 69,
				67, 69, 72, 69, 67, 65, 64, 65,
				67, 69, 71, 72, 74, 72, 69, 67]
	# 预合成整段旋律，循环播放更省 CPU
	var step_dur := 0.12
	var buf := PackedFloat32Array()
	for i in _bgm_seq.size():
		var n: int = _bgm_seq[i]
		var lead := _tone(_note_hz(n), step_dur, 0.22, "square")
		# 加一个低八度贝斯
		var bass := _tone(_note_hz(n - 24), step_dur, 0.18, "tri")
		var mix := PackedFloat32Array()
		var cnt: int = max(lead.size(), bass.size())
		mix.resize(cnt)
		for k in cnt:
			var l := lead[k] if k < lead.size() else 0.0
			var b := bass[k] if k < bass.size() else 0.0
			mix[k] = l * 0.7 + b * 0.9
		buf.append_array(mix)
	_bgm_stream = _make_wav(buf)
	_bgm_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_bgm_stream.loop_begin = 0
	_bgm_stream.loop_end = buf.size()


func play_bgm() -> void:
	if _bgm_on:
		return
	_bgm_on = true
	# 用主旋律循环流直接播（比逐帧调度更稳）
	_bgm_player.stream = _bgm_stream
	_bgm_player.play()


func stop_bgm() -> void:
	_bgm_on = false
	_bgm_player.stop()


func _play_bgm_step() -> void:
	pass  # 已改为整段循环流播放


# ============ 汉字读音 ============
## 播放某个字的读音。优先用 Edge 情感语音（voice2/*.mp3），
## 没有则退回 SAPI 缓存（voice/*.wav），再没有就静默。
func speak(ch: String, vol_db: float = 1.0) -> void:
	if not voice_on or ch == "":
		return
	var st := _voice_stream(ch)
	if st == null:
		return
	_voice_player.stream = st
	_voice_player.volume_db = vol_db
	_voice_player.play()


func _voice_stream(ch: String) -> AudioStream:
	if _voice_cache.has(ch):
		return _voice_cache[ch]
	var code := ch.unicode_at(0)
	if code <= 0:
		return null
	# 只认 Edge 情感语音 mp3（音质好、体积小；SAPI wav 已移出资源目录）
	var mp3 := "res://assets/voice2/u%04X.mp3" % code
	var st: AudioStream = null
	if ResourceLoader.exists(mp3):
		st = load(mp3)
	_voice_cache[ch] = st
	return st


func has_voice(ch: String) -> bool:
	return _voice_stream(ch) != null


# ============ 剧情旁白（整句语音） ============
## 按文本 md5 载入整句语音；找不到返回 null（调用方回退到无语音模式）
func story_stream(md5: String) -> AudioStream:
	if md5 == "":
		return null
	if _story_cache.has(md5):
		return _story_cache[md5]
	var p := "res://assets/voice_story/%s.mp3" % md5
	var st: AudioStream = null
	if ResourceLoader.exists(p):
		var r = load(p)
		if r is AudioStream:
			st = r
	_story_cache[md5] = st
	return st


func has_story(md5: String) -> bool:
	return story_stream(md5) != null


## 播放旁白整句（用独立声道，不会打断单字读音，反之亦然）
func play_story(md5: String, vol_db: float = 2.0) -> bool:
	var st := story_stream(md5)
	if st == null:
		return false
	_narrator_player.stream = st
	_narrator_player.volume_db = vol_db
	_narrator_player.play()
	duck_bgm(true)
	return true


func stop_story() -> void:
	if _narrator_player != null:
		_narrator_player.stop()
	duck_bgm(false)


func story_playing() -> bool:
	return _narrator_player != null and _narrator_player.playing


func story_position() -> float:
	if _narrator_player == null or not _narrator_player.playing:
		return -1.0
	return _narrator_player.get_playback_position()


# ============ 大招喊话（角色"喊"招式名，带语音） ============
## 用**独立声道**：喊话时如果单字读音/旁白正在播，两者不应互相打断
## （结印 1 秒内玩家可能刚捡到一个字）。
## 文件按文本 md5 命名（assets/voice_ult/<md5>.mp3），与 Python 端 hashlib.md5 一致。
func _ult_cache_stream(text: String) -> AudioStream:
	if text == "":
		return null
	if _ult_cache.has(text):
		return _ult_cache[text]
	var p := "res://assets/voice_ult/%s.mp3" % text.md5_text()
	var st: AudioStream = null
	if ResourceLoader.exists(p):
		var r = load(p)
		if r is AudioStream:
			st = r
	_ult_cache[text] = st
	return st


func has_ult_shout(text: String) -> bool:
	return _ult_cache_stream(text) != null


## 让角色喊出大招台词。返回是否真的响了（false 时调用方可只显示文字）
func shout_ult(text: String, vol_db: float = 4.0) -> bool:
	if not voice_on:
		return false
	var st := _ult_cache_stream(text)
	if st == null:
		return false
	if _shout_player == null:
		return false
	_shout_player.stream = st
	_shout_player.volume_db = vol_db
	_shout_player.play()
	duck_bgm(true)
	# 喊完自动恢复 BGM 音量
	var t := get_tree().create_timer(st.get_length() + 0.15)
	t.timeout.connect(func(): duck_bgm(false))
	return true


func stop_ult_shout() -> void:
	if _shout_player != null:
		_shout_player.stop()
	duck_bgm(false)

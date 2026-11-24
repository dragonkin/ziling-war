extends Node2D
## 英雄玩家控制器 —— 三国战记式 8 向移动 + 2.5D 纵深 + 三段连招
##
## 2.5D 要点：
##   x ∈ [60, 1220]   左右
##   y ∈ [380, 600]   纵深（越小越远）
##   纵深决定 缩放 scale 与 明暗 modulate —— 靠后小且暗

signal hp_changed(hp: int, max_hp: int)
signal energy_changed(e: int, need: int)
signal char_picked(info: Dictionary)
signal died
signal rage_changed(v: int, max_v: int)
signal rage_burst                      # ★ 狂暴触发（Battle 接管全屏演出）
signal relay_landed(x: float)          # ★ 幻影接力「落地」→ Battle 在落点补一次横扫判定

const X_MIN := 60.0
var X_MAX := 1220.0      # 由 Battle 按世界宽度设置
const Y_NEAR := 520.0    # 最近（屏幕下方）—— 与 Battle.GROUND_BASE 一致
const Y_FAR := 392.0     # 最远（屏幕上方）—— 纵深带保持 128px
const SPEED := 300.0
const SCALE_NEAR := 1.0
const SCALE_FAR := 0.86

const ATTACK_DUR := 0.34
const COMBO_WINDOW := 0.45

# 立绘基准高度（英雄）—— 占画面高度约 23%（720 * 0.23 ≈ 166），
# 符合三国战记「小人在大场景」的比例
const BASE_H := 166.0
const FALLBACK_H := 166     # 兜底纹理高度（素材缺失时用于纵深换算，避免除零/空纹理）

# 状态
var max_hp := 100
var hp := 100
var shield := 0               # ★ 灵光盾（商店购得，先于 HP 承伤）
var energy := 0
var energy_need := 5          # 集齐 5 个字可放大招
var picked: Array = []        # 本关已拾取的字
var facing := 1               # 1=右 -1=左
var dead := false
var invuln := 0.0

# ★ 怒气狂暴（对标街机「怒」系统）：挨打/打人攒怒，满了 6 秒狂暴
var rage := 0
const RAGE_MAX := 100
var rage_t := 0.0             # 狂暴剩余时间（>0 = 狂暴中）
const RAGE_DUR := 6.0
const RAGE_DMG := 1.5         # 狂暴伤害倍率
const ATK_DUR_RAGE := 0.26    # 狂暴攻速（普通 0.34）

var _atk_t := 0.0
var _combo_step := 0
var _combo_reset := 0.0
var _bob := 0.0
var _hurt_flash := 0.0
var _sprite: Sprite2D
var _shadow: Sprite2D
var _shadow_core: Sprite2D        # ★ 紧贴脚下的深色接触影（2.5D 接地感）
var _shadow_base_scale := 0.0     # 影子纵深缩放基准（供走路伸缩重算，避免累乘）
var _slash_root: Node2D
var _can_move := true
var _art_idle: Texture2D
var _art_ready: Texture2D
var _art_hurt: Texture2D
var _art_walk: Array = []     # 4 帧走路循环
var _art_atk: Array = []      # 3 帧攻击
var _art_jump: Texture2D      # ★ 蜷腿腾空帧（素材一直有，以前从没加载过 → 立着跳）
var _idle_src := ""           # 站立立绘来源（自检用）
var _walk_i := 0              # 当前走路帧
var _walk_t := 0.0
var _moving := false          # 本帧是否在移动
var _force_dir := Vector2.ZERO  # 外部强制移动方向（测试/演出）
var _atk_frame := 0
var terrain: Node = null      # 由 Battle 注入的地形对象
var _step_lift := 0.0         # 踩台阶时的临时抬升
var _rot_lock := 0.0          # ★ 特招旋转锁：>0 时 _animate 不碰 _sprite.rotation
var _buffered_atk := false    # ★ 攻击后摇期间按下的 J（输入缓冲，连招更顺）

# ===== 主角（五行角色）=====
var hero_id := "huo"          # 当前主角 id（Game.current_hero 同步）
var hero_data: Dictionary = {}  # Heroes.by_id(hero_id)
var _elem_col := Color("#ff5a3c")   # 元素主色（攻击刀光/特效用）
var _elem_deep := Color("#8b1a00")

# ===== 跳跃 / 冲刺 / 特技 =====
const GRAVITY := 2000.0
const JUMP_V := 840.0         # 起跳初速度（约 0.42s 滞空，跳高 ~176px）
const DASH_SPEED := 1050.0
const DASH_DUR := 0.18        # 地面冲刺时长
const AIR_DASH_DUR := 0.32     # 空中冲刺（向前飞）时长
var _air := 0.0               # 离地高度（px，向上为正）
var _air_v := 0.0             # 垂直速度
var _on_ground := true
var _dashing := 0.0           # 冲刺剩余时间
var _dash_dir := 1
var _dash_cd := 0.0           # 冲刺冷却
var _trail_t := 0.0           # 冲刺残影计时
var _haste_t := 0.0           # 加速剩余时间
var _base_dmg := 12           # 基础攻击伤害（主角决定）
var _speed_k := 1.0           # 移速倍率（主角决定）
var atk_speed_k := 1.0        # ★ 词条加成：攻速倍率（迅捷）
var rage_gain_k := 1.0        # ★ 词条加成：攒怒倍率（战意）


func _ready() -> void:
	_apply_hero()          # 先按所选主角定属性/配色
	_load_art()
	_build()
	emit_signal("hp_changed", hp, max_hp)
	emit_signal("energy_changed", energy, energy_need)


## 从 Game.current_hero 读取主角数据，套用血量/攻击/配色
func _apply_hero() -> void:
	if Game != null:
		hero_id = Game.current_hero
	hero_data = Heroes.by_id(hero_id)
	_elem_col = Heroes.main_color(hero_id)
	_elem_deep = Heroes.deep_color(hero_id)
	max_hp = int(hero_data.get("hp", 100))
	hp = max_hp
	_base_dmg = int(hero_data.get("dmg", 12))
	_speed_k = float(hero_data.get("speed", 1.0))


## 立绘目录：按主角 id 取 res://assets/heroes/{id}/
func _hero_dir() -> String:
	return "res://assets/heroes/%s/" % hero_id


func _load_art() -> void:
	var base := _hero_dir()
	# 优先主角专属立绘；不存在时回退到老素材 char2（保证兼容）
	_art_idle = _try_tex(base + "idle.png")
	if _art_idle != null:
		_idle_src = base + "idle.png"
	_art_ready = _try_tex(base + "ready.png")
	_art_hurt = _try_tex(base + "hurt.png")
	_art_jump = _try_tex(base + "jump.png")   # ★ 蜷腿腾空帧
	_art_walk = []
	for i in range(1, 5):
		var t := _try_tex(base + "walk%d.png" % i)
		if t:
			_art_walk.append(t)
	_art_atk = []
	for i in range(1, 4):
		var t2 := _try_tex(base + "atk%d.png" % i)
		if t2:
			_art_atk.append(t2)
	# 回退链 0：老主角素材目录 char2/
	if _art_idle == null:
		var ob := "res://assets/char2/hero_"
		_art_idle = _try_tex(ob + "idle.png")
		if _art_idle != null:
			_idle_src = ob + "idle.png"
		if _art_ready == null:
			_art_ready = _try_tex(ob + "ready.png")
		if _art_hurt == null:
			_art_hurt = _try_tex(ob + "hurt.png")
		if _art_walk.is_empty():
			for i in range(1, 5):
				var t3 := _try_tex("res://assets/anim/hero_walk%d.png" % i)
				if t3:
					_art_walk.append(t3)
		if _art_atk.is_empty():
			for i in range(1, 4):
				var t4 := _try_tex("res://assets/anim/hero_atk%d.png" % i)
				if t4:
					_art_atk.append(t4)
	# 回退链 1：更老的素材目录
	if _art_idle == null:
		_art_idle = _try_tex("res://assets/char/hero_t.png")
		if _art_idle != null:
			_idle_src = "res://assets/char/hero_t.png"
	# ★ 回退链 2（终极兜底）：素材全部缺失时用程序化纹理（按元素配色），
	#   保证 texture 永不为 null —— 否则 _apply_depth() 的 .get_height() 会直接闪退
	if _art_idle == null:
		_art_idle = _make_fallback_tex()
		_idle_src = "FALLBACK(programmatic:%s)" % hero_id
	if _art_ready == null:
		_art_ready = _art_idle
	if _art_hurt == null:
		_art_hurt = _art_idle
	if _art_walk.is_empty():
		_art_walk = [_art_idle]
	if _art_atk.is_empty():
		_art_atk = [_art_ready, _art_ready, _art_ready]


func _try_tex(p: String) -> Texture2D:
	if not ResourceLoader.exists(p):
		return null
	var r = load(p)
	return r if r is Texture2D else null


## 自检用：报告当前立绘来源（导出后排查资源是否缺失）
func art_debug_info() -> String:
	if _art_idle == null:
		return "none"
	return "%s walk=%d atk=%d h=%d" % [
		_idle_src, _art_walk.size(), _art_atk.size(),
		_art_idle.get_height()]


## ★ 程序化兜底人形（素材丢失时使用，保证游戏永远能跑起来）
##   按主角元素配色 —— 六个角色即使没有立绘也能一眼区分
func _make_fallback_tex() -> ImageTexture:
	var w := 92
	var h := FALLBACK_H
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(w) * 0.5
	for y in h:
		for x in w:
			var c := Color(0, 0, 0, 0)
			var dx: float = (float(x) - cx) / 20.0
			var dy: float = (float(y) - 30.0) / 24.0
			if dx * dx + dy * dy <= 1.0:
				c = Color("#f2c99a")                       # 头
			elif y > 52 and y < 128 and absf(float(x) - cx) < 26.0:
				c = _elem_col                               # 身（元素主色）
			elif y >= 128 and absf(float(x) - cx) < 24.0:
				c = _elem_deep                              # 腿（元素深色）
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _set_art(t: Texture2D) -> void:
	if _sprite and t and _sprite.texture != t:
		_sprite.texture = t
		_sprite.position.y = -BASE_H * 0.5


func _build() -> void:
	# 影子（2.5D 关键：脚下的椭圆阴影，帮助判断纵深位置）
	_shadow = Sprite2D.new()
	var sh_tex := _ellipse_texture(110, 34)
	_shadow.texture = sh_tex
	_shadow.modulate = Color(0, 0, 0, 0.38)
	_shadow.position = Vector2(0, 4)
	add_child(_shadow)

	# ★ 接触影（contact shadow）：紧贴脚下的小而深的一圈
	#   大柔影负责"空间关系"，深接触影负责"真的踩在地上"——这一笔最能救 2D 平面感
	_shadow_core = Sprite2D.new()
	_shadow_core.texture = _ellipse_texture(64, 22)
	_shadow_core.modulate = Color(0, 0, 0, 0.48)
	_shadow_core.position = Vector2(0, 2)
	add_child(_shadow_core)

	# 立绘
	_sprite = Sprite2D.new()
	_sprite.texture = _art_idle
	_sprite.position = Vector2(0, -BASE_H * 0.5)
	# ★ 立体化着色器：底部环境遮蔽 + 顶缘光 + 侧缘暗部 + 对比增强 + 颗粒
	#   —— 不改素材，直接削弱「贴纸感」，这是 2D 立绘最有效的体积化手段
	if _hero3d_mat == null:
		var sh: Shader = null
		if ResourceLoader.exists("res://assets/shaders/hero3d.gdshader"):
			var r = load("res://assets/shaders/hero3d.gdshader")
			if r is Shader:
				sh = r
		if sh != null:
			_hero3d_mat = ShaderMaterial.new()
			_hero3d_mat.shader = sh
	if _hero3d_mat != null:
		_sprite.material = _hero3d_mat
	add_child(_sprite)

	_slash_root = Node2D.new()
	add_child(_slash_root)

	_apply_depth()


func _ellipse_texture(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w / 2.0
	var cy := h / 2.0
	for y in h:
		for x in w:
			var dx := (x - cx) / cx
			var dy := (y - cy) / cy
			var d := dx * dx + dy * dy
			if d <= 1.0:
				var a := 1.0 - d
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ============ 纵深 ============
func _apply_depth() -> void:
	if not _sprite:
		return
	var t: float = clamp((position.y - Y_FAR) / (Y_NEAR - Y_FAR), 0.0, 1.0)
	var s: float = lerp(SCALE_FAR, SCALE_NEAR, t)
	# ⚠️ 导出后若立绘缺失，texture 会是 null → 必须判空，否则 null.get_height() 直接闪退
	var th := float(FALLBACK_H)
	if _sprite.texture != null:
		th = max(1.0, float(_sprite.texture.get_height()))
	var k: float = BASE_H / max(1.0, th)
	# ★ 挤压拉伸（squash & stretch）：跳跃/落地/受击的动画十二法则，
	#   乘数形式——_apply_depth 每帧重算 scale，直接改 scale 会被吃掉
	# ★ 果冻乘数 + 龙卷风横向压扁（scale 每帧重算，必须走乘数）
	_sprite.scale = Vector2(k * s * _sq_x * _spin_x, k * s * _sq_y)
	_shadow_base_scale = s
	_shadow.scale = Vector2(s, s)
	# 靠后稍暗，增强层次
	var brightness: float = lerp(0.74, 1.0, t)
	# ★ 狂暴：全身红热脉动（乘进纵深亮度里，不会被每帧重算覆盖）
	if rage_t > 0.0:
		var pk: float = 0.5 + 0.5 * sin(_bob * 9.0)
		_sprite.modulate = Color(
			brightness * (1.0 + 0.10 * pk),
			brightness * (0.62 - 0.10 * pk),
			brightness * (0.55 - 0.10 * pk),
			_sprite.modulate.a)
	else:
		_sprite.modulate = Color(brightness, brightness, brightness, _sprite.modulate.a)
	# 纵深排序（越大越靠前）
	z_index = int(position.y)


# ============ 主循环 ============
func _process(delta: float) -> void:
	if invuln > 0.0:
		invuln -= delta
	# ★ 特招旋转锁倒计时（归零后 _animate 恢复接管 rotation）
	if _rot_lock > 0.0:
		_rot_lock -= delta
	if _combo_reset > 0.0:
		_combo_reset -= delta
		if _combo_reset <= 0.0:
			_combo_step = 0
	# ★ 狂暴计时（结束自然回常态，红光脉动在 _apply_depth 里跟着 rage_t 走）
	if rage_t > 0.0:
		rage_t -= delta
	# ★ 镜头冻结计时（穿梭特招期间 Battle 暂停摄像机跟随）
	if cam_hold_t > 0.0:
		cam_hold_t -= delta

	if _atk_t > 0.0:
		_atk_t -= delta
		if _atk_t <= 0.0:
			_can_move = true
			# ★ 后摇期间按过 J → 立刻接下一段连招（输入缓冲）
			if _buffered_atk:
				_buffered_atk = false
				attack()

	# ===== 冲刺 / 移动 / 跳跃 =====
	if _dash_cd > 0.0:
		_dash_cd -= delta
	if _haste_t > 0.0:
		_haste_t -= delta
	if _trail_t > 0.0:
		_trail_t -= delta

	_moving = false
	# 外部强制移动（脚本演出 / 测试用）：优先于输入
	if _force_dir != Vector2.ZERO and not dead:
		_moving = true
		if _force_dir.x != 0:
			facing = 1 if _force_dir.x > 0 else -1
		position += _force_dir.normalized() * SPEED * delta

	# 冲刺中：忽略普通移动，沿冲刺方向高速突进（带无敌帧）
	if _dashing > 0.0:
		_dashing -= delta
		_moving = true
		facing = _dash_dir
		position.x += _dash_dir * DASH_SPEED * delta
		if _trail_t <= 0.0:
			_trail_t = 0.03
			_spawn_dash_trail()
	else:
		if not dead and _can_move:
			var spd: float = SPEED * _speed_k * (1.5 if _haste_t > 0.0 else 1.0)
			var dir := Vector2.ZERO
			if _hold("ui_left", KEY_A):
				dir.x -= 1
			if _hold("ui_right", KEY_D):
				dir.x += 1
			# ★ 真实物理：↑/↓（W/S）不再改变高度 —— 角色贴地行走，
			#   高度变化只来自跳跃（_air，带重力）
			if dir != Vector2.ZERO:
				dir = dir.normalized()
				_moving = true
				var prev_x := position.x
				position += dir * spd * delta
				if dir.x != 0:
					facing = 1 if dir.x > 0 else -1
				# 踩台阶：地形落差大时给一个小抬升反馈
				if terrain and terrain.has_method("ground_y_at"):
					var gy0: float = terrain.ground_y_at(prev_x)
					var gy1: float = terrain.ground_y_at(position.x)
					if abs(gy1 - gy0) > 8.0:
						_step_lift = 14.0

	# 垂直（跳跃）物理 —— 离地高度作为独立视觉偏移，不影响纵深 position.y
	if not _on_ground:
		_air_v -= GRAVITY * delta
		_air += _air_v * delta
		if _air <= 0.0:
			_air = 0.0
			_air_v = 0.0
			_on_ground = true
			_squash(1.16, 0.82, 0.28)   # 落地：压扁回弹
			_dust(7, 24.0)              # 落地扬尘
			Sfx.play("land", 1.0, -8.0)

	position.x = clamp(position.x, X_MIN, X_MAX)
	# 地面高度：由地形决定脚下的 y
	var ground_y: float = Y_NEAR
	if terrain and terrain.has_method("ground_y_at"):
		ground_y = terrain.ground_y_at(position.x)
	# ★ 真实物理：玩家永远站在地面上（贴地行走，随地势起伏）；
	#   离地高度只由跳跃 _air 控制，落地自然回到地面
	position.y = ground_y
	if _step_lift > 0.0:
		_step_lift = max(0.0, _step_lift - delta * 90.0)
	# ★ 龙卷风自转：横向压扁周期变化（cos 走 1 → -1 → 1，像纸片绕竖轴翻转）
	if _spin_t > 0.0:
		_spin_t -= delta
		_spin_ph += delta * _spin_spd
		# |cos| 太扁会看不清人，夹在 0.18~1.0；负半周交给 flip_h 翻面（正反面感）
		_spin_x = clampf(absf(cos(_spin_ph)), 0.18, 1.0)
		_spin_flip = (cos(_spin_ph) < 0.0)
	else:
		_spin_x = 1.0
		_spin_flip = false
	_apply_depth()

	# ---- 动画状态机 ----
	_animate(delta)

	# 受击闪白
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		if _sprite:
			var on := fmod(_hurt_flash, 0.08) > 0.04
			_sprite.modulate = Color(2.4, 0.7, 0.7, _sprite.modulate.a) if on else Color(1, 1, 1, _sprite.modulate.a)
	elif invuln > 0.0:
		# 无敌帧闪烁
		if _sprite:
			_sprite.modulate.a = 0.45 if fmod(invuln, 0.16) > 0.08 else 1.0
	else:
		if _sprite:
			_sprite.modulate.a = 1.0


## 动画状态机：攻击 > 走路 > 站立
func _animate(delta: float) -> void:
	if _sprite == null:
		return
	var amp_base := BASE_H * 0.5
	var y_off := 0.0
	var tilt := 0.0

	# ★ 腾空优先：用蜷腿 jump.png（素材一直有，以前从没加载 → 只能立着跳）
	#   上升段后仰展开、下落段前倾蹬腿 —— 身体语言跟着抛物线走
	if not _on_ground:
		if _art_jump != null:
			if _sprite.texture != _art_jump:
				_sprite.texture = _art_jump
		# _air_v > 0 上升；< 0 下落
		var up_k: float = clamp(_air_v / JUMP_V, -1.0, 1.0)
		tilt = -0.12 * facing * up_k          # 上升后仰 / 下落前倾
		y_off = -4.0 * up_k
		_bob += delta * 6.0
	elif _atk_t > 0.0 and not _art_atk.is_empty():
		# 攻击：按进度推帧
		var prog: float = 1.0 - (_atk_t / atk_dur())
		var fi: int = int(prog * _art_atk.size())
		fi = clamp(fi, 0, _art_atk.size() - 1)
		if fi != _atk_frame or _sprite.texture != _art_atk[fi]:
			_atk_frame = fi
			_sprite.texture = _art_atk[fi]
		# 攻击前冲的轻微前倾
		tilt = 0.10 * facing * sin(prog * PI)
		y_off = -6.0 * sin(prog * PI)
		_bob += delta * 4.0
	elif _moving and not dead:
		# 走路循环：4 帧，按移动速度推进
		_walk_t += delta * 9.5
		var n: int = _art_walk.size()
		if n > 0:
			var wi: int = int(_walk_t) % n
			if _sprite.texture != _art_walk[wi]:
				_sprite.texture = _art_walk[wi]
			_walk_i = wi
		# 走路上下颠簸：passing 帧(1,3)最高
		var ph: float = fmod(_walk_t, 4.0)
		y_off = -4.5 * abs(sin(ph * PI / 2.0))
		# 身体前倾一点，像在赶路
		tilt = 0.05 * facing
		_bob += delta * 10.0
	else:
		# 站立：轻微呼吸
		if _sprite.texture != _art_idle:
			_sprite.texture = _art_idle
		_bob += delta * 2.6
		y_off = sin(_bob) * 2.4

	# 应用位姿（跳跃：整段精灵上移 _air，影子留在地面并随高度缩小）
	_sprite.position.y = -amp_base + y_off - _step_lift - _air
	_sprite.position.x = 0
	# ★ 特招旋转锁：旋转 tween 播放期间不让动画状态机覆盖 rotation
	#   （以前 tilt 每帧覆写 → 旋风斩/火旋冲的旋转完全看不见）
	if _rot_lock <= 0.0:
		_sprite.rotation = tilt
	_sprite.flip_h = (facing < 0) != _spin_flip
	# 影子随颠簸轻微伸缩；离地越高影子越小越淡（读作"浮空"）
	if _shadow and _shadow_base_scale > 0.0:
		var sq: float = 1.0
		if _moving and _on_ground:
			sq = 1.0 - abs(sin(_walk_t * PI / 2.0)) * 0.12
		var air_k: float = clamp(1.0 - _air / 520.0, 0.22, 1.0)
		_shadow.scale = Vector2(_shadow_base_scale * sq * air_k, _shadow_base_scale * air_k)
		_shadow.modulate.a = 0.38 * air_k
		# 接触影：更贴脚、离地时收得更快（离地就越发"悬空"）
		if _shadow_core:
			var ck: float = clamp(1.0 - _air / 240.0, 0.10, 1.0)
			_shadow_core.scale = Vector2(_shadow_base_scale * ck * sq,
					_shadow_base_scale * ck)
			_shadow_core.modulate.a = 0.48 * ck


# ============ 攻击 ============
func attack() -> void:
	if dead:
		return
	if not _can_move:
		# ★ 攻击后摇期间按下的 J 全部缓冲（以前直接丢弃）——
		#   猛按 J 时大部分按键都落在 0.34s 动作窗口内，全丢的话连击
		#   几乎永远推不到第三段 → 特招根本触发不出来（本次反馈的深层根因）
		_buffered_atk = true
		return
	_buffered_atk = false
	var step := (_combo_step % 3) + 1
	_combo_step = step
	_combo_reset = COMBO_WINDOW
	_atk_t = atk_dur()
	_atk_frame = -1
	_can_move = false
	_spawn_slash(step)
	# ★ 第三段 = 角色特招（旋风斩 / 水影穿梭 / 雷电穿梭……每人一个招牌动作）
	if step == 3:
		# 特招演出比普攻长得多（全屏穿梭 ~0.8s）——动作窗口同步拉长，
		# 否则 0.34s 后缓冲键接招，穿梭演到一半被打断（很难看）
		_spec_extra = 0.0
		_special_move()
		_atk_t = atk_dur() + _spec_extra
		return
	# 前冲
	var t := create_tween()
	var lunge := 34.0 * facing
	t.tween_property(self, "position:x", position.x + lunge, 0.08)
	t.tween_property(self, "position:x", position.x, atk_dur() - 0.08)
	# 挥砍旋转
	if _sprite:
		var base := _sprite.rotation
		var tw := create_tween()
		tw.tween_property(_sprite, "rotation", base + 0.22 * facing, 0.07)
		tw.tween_property(_sprite, "rotation", 0.0, 0.16)


# ============ ★ 第三段特招（连按 J 三下触发） ============
## 每个角色一个招牌动作，让"连按三下"有明显的节奏收尾：
##   金戈=旋风斩（原地自转 720°）/ 青藤=横扫藤鞭（大幅左右摆）
##   沧澜=水影穿梭（左残影→右残影）/ 赤炎=火旋冲（旋转+长突进）
##   磐岩=震地转砸（跳起半旋砸地）/ 紫电=雷电穿梭（最快的三段瞬步）
## ⚠️ 两类坑（都踩过）：
##   ① _animate 每帧覆写 _sprite.rotation → 旋转必须设 _rot_lock
##   ② _process 每帧 position.y = ground_y → 跳跃必须走 _air 跳跃物理
##   ③ 残影必须沿路径"边走边撒"（_ghost_trail），瞬间连发全叠在起点=看不见
func _special_move() -> void:
	# 特招的位移幅度大于普通段 → Battle 侧判定加宽（见 _player_attack）
	match hero_id:
		"jin":
			# ★ 旋风斩 = 龙卷风式自转（绕竖轴，横向压扁周期翻转）
			#   以前是 _sprite.rotation tween → 平面翻跟斗，很出戏
			_spin_t = 0.26
			_spin_spd = 19.0
			_spin_ph = 0.0
			Sfx.play("sonic", randf_range(0.90, 0.98), 2.0)
			var t := create_tween()
			t.tween_property(self, "position:x", position.x + 46.0 * facing, 0.10)
			t.tween_property(self, "position:x", position.x, atk_dur() - 0.10)
			_ghost_trail(6, 0.05)
		"huo":
			# ★ 火旋冲 = 龙卷风式高速自转 + 长突进（火系爆发感）
			_spin_t = 0.22
			_spin_spd = 24.0
			_spin_ph = 0.0
			Sfx.play("sonic", randf_range(1.05, 1.15), 1.0)
			var t := create_tween()
			t.tween_property(self, "position:x", position.x + 130.0 * facing, 0.13) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(self, "position:x", position.x, atk_dur() - 0.13)
			_ghost_trail(7, 0.045)
		"shui":
			# ★★ 水影穿梭 = 幻影接力（用户指定演出）
			#   分身先冲 → 真身原地不动 → 到位后真身瞬移过去，原地留一枚真人淡影
			#   观感：像一道水分身替你打出去，本体"唰"地跟上
			# ⚠️ 距离/速度三轮试玩反馈的收敛值（每次都在调窄调慢）：
			#   580px 太宽（一来一回 91% 屏宽，镜头被甩得乱抖）
			#   → 380px 仍嫌宽（相机冻结后 760px 横跨几乎整屏，像飞出画面）
			#   → 本轮 300px（单侧 23% 屏宽，一来一回 600px ≈ 47% 屏宽，正好"半屏"）
			#   速度：0.24s 看不清 → 0.40s 仍偏快 → 0.46s，三段全程约 1.55s
			Sfx.play("sonic", randf_range(0.90, 0.98), 1.0)
			_dust(8, 30.0)
			_spec_extra = 1.16
			_cam_hold(true, 1.58)
			var x0: float = clampf(position.x, X_MIN + 300.0, X_MAX - 300.0)
			# 先归位到安全带（否则左冲端点会越界）
			position.x = x0
			# 左：分身先冲，真身瞬移跟上；再右：同样接力；最后归位
			_clone_relay(-300.0, 0.46)
			var r1 := create_tween()
			r1.tween_interval(0.52)
			r1.tween_callback(_clone_relay.bind(600.0, 0.48))
			var r2 := create_tween()
			r2.tween_interval(1.06)
			r2.tween_callback(_clone_relay.bind(-300.0, 0.42))
		"lei":
			# ★ 雷电穿梭：同为幻影接力，节奏比水影快一档（电光的层次差）
			#   本轮同步收窄放慢：230px / 0.34s（比水影快约 25%，不再快到看不清）
			Sfx.play("sonic", randf_range(1.10, 1.20), 0.0)
			_dust(6, 26.0)
			_spec_extra = 0.90
			_cam_hold(true, 1.22)
			var x0: float = clampf(position.x, X_MIN + 230.0, X_MAX - 230.0)
			position.x = x0
			_clone_relay(-230.0, 0.34)
			var r1 := create_tween()
			r1.tween_interval(0.39)
			r1.tween_callback(_clone_relay.bind(460.0, 0.36))
			var r2 := create_tween()
			r2.tween_interval(0.80)
			r2.tween_callback(_clone_relay.bind(-230.0, 0.31))
		"mu":
			# 横扫藤鞭：大幅左右抡摆（藤鞭抽击）
			if _sprite:
				_rot_lock = 0.35
				var tw := create_tween()
				tw.tween_property(_sprite, "rotation", -0.75 * facing, 0.10)
				tw.tween_property(_sprite, "rotation", 0.65 * facing, 0.13)
				tw.tween_property(_sprite, "rotation", 0.0, 0.10)
			var t := create_tween()
			t.tween_property(self, "position:x", position.x - 70.0 * facing, 0.10)
			t.tween_property(self, "position:x", position.x + 70.0 * facing, 0.12)
			t.tween_property(self, "position:x", position.x, 0.09)
			_ghost_trail(4, 0.07)
		_:
			# 磐岩·震地转砸：跳起半旋砸地（土系厚重）
			# ★ 必须走真跳跃物理（_air / _air_v）—— 直接 tween position:y 会被
			#   _process 每帧的 position.y = ground_y 覆盖，跳不起来（踩过的坑）
			if _on_ground:
				_on_ground = false
				_air_v = 620.0          # 跳高 ≈ 96px，滞空 ≈ 0.62s
			if _sprite:
				_rot_lock = 0.17
				var t2 := create_tween()
				t2.tween_property(_sprite, "rotation", PI * facing, 0.14) \
						.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				t2.tween_property(_sprite, "rotation", 0.0, 0.01)


## ★ 冻结镜头跟随一段时间（穿梭特招专用，见 cam_hold_t 注释）
func _cam_hold(on: bool, dur: float) -> void:
	if on:
		cam_hold_t = maxf(cam_hold_t, dur)


## ★ 沿路径撒残影：每隔 interval 生成一个 _ghost，共 n 个
##   （在 tween 起跑的同时用独立 tween 按时间轴撒 —— 残影会落在移动路径上）
var _spec_extra := 0.0         # ★ 特招额外演出时长（attack() 把 _atk_t 拉长用）
## ★ 镜头冻结：穿梭特招期间真身会瞬移 380~760px，若相机照常跟随，
##   每段接力都甩一次镜头 → 整屏剧烈晃动（用户反馈「画面非常抖动」的元凶）。
##   >0 时 Battle 暂停「摄像机跟随」，让穿梭在稳定的构图里播完。
var cam_hold_t := 0.0
var _sq_x := 1.0               # ★ 挤压拉伸乘数（跳跃压扁/起跳拉长/受击压扁）
var _sq_y := 1.0
var _dust_tex: Texture2D       # 程序化径向渐变贴图（扬尘用，无需素材文件）
var _hero3d_mat: ShaderMaterial = null   # ★ 立体化材质（默认共享，见 _build）
# ★ 龙卷风旋转：绕「竖轴」自转 = 横向压扁周期变化（不是平面翻跟斗）
var _spin_t := 0.0             # 剩余时间
var _spin_ph := 0.0            # 相位
var _spin_spd := 17.0          # 转速（rad/s）
var _spin_x := 1.0             # 横向压扁倍率（_apply_depth 用）
var _spin_flip := false        # 负半周翻面（_animate 的 flip_h 用它）


## ★ 挤压拉伸：给精灵一个短暂的形变乘数然后弹回（动画十二法则·真实感的灵魂）
func _squash(sx: float, sy: float, rec: float = 0.24) -> void:
	_sq_x = sx
	_sq_y = sy
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "_sq_x", 1.0, rec) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_sq_y", 1.0, rec) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## ★ 扬尘：脚底冒出几团灰土（落地/冲刺/特招起手），程序化径向渐变，零素材依赖
func _dust(n: int = 6, spread: float = 26.0) -> void:
	var par := get_parent()
	if par == null:
		return
	if _dust_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		_dust_tex = gt
	for i in n:
		var p := Sprite2D.new()
		p.texture = _dust_tex
		p.position = position + Vector2(randf_range(-spread, spread), -8.0)
		p.z_index = 4
		p.scale = Vector2.ONE * randf_range(0.22, 0.45)
		p.modulate = Color(0.80, 0.74, 0.62, 0.50)
		par.add_child(p)
		var t := p.create_tween()
		t.set_parallel(true)
		t.tween_property(p, "position",
				p.position + Vector2(randf_range(-34, 34), -randf_range(16, 44)), 0.5)
		t.tween_property(p, "scale", p.scale * 1.9, 0.5)
		t.tween_property(p, "modulate:a", 0.0, 0.5)
		t.chain().tween_callback(p.queue_free)


func _ghost_trail(n: int, interval: float) -> void:
	var gt := create_tween()
	for i in n:
		gt.tween_interval(interval)
		gt.tween_callback(_ghost)


## ★ 残影：把当前精灵快照一份留在原地快速淡出（穿梭/旋转时的"影分身"）
func _ghost() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var g := Sprite2D.new()
	g.texture = _sprite.texture
	g.global_position = _sprite.global_position + Vector2(0, -30.0)
	g.rotation = _sprite.rotation
	g.flip_h = _sprite.flip_h
	g.scale = _sprite.scale
	g.modulate = Color(_elem_col.r, _elem_col.g, _elem_col.b, 0.55)
	# ★ z_index 必须用「全局 y」——以前用 _sprite.z_index（局部值恒为 0）→ 残影层级
	#   掉到 -1，被地形/前景盖住；用户反馈"看不到幻影，只有几根蓝线"就是这里
	g.z_index = int(g.global_position.y)
	var par := get_parent()
	if par == null:
		return
	par.add_child(g)
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.26)
	t.tween_callback(g.queue_free)


## ★★ 幻影接力（用户指定演出）：分身先冲出去 → 真身留在原地 →
##     分身到位后真身"瞬移"过去（瞬移感），原地留一枚淡影表示真人曾在此
func _clone_relay(dx: float, dur: float, tint_a: float = 0.92) -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var par := get_parent()
	if par == null:
		return
	var base_gx: float = _sprite.global_position.x       # 分身出发处（= 真身当前位）
	var base_gy: float = _sprite.global_position.y
	# ① 分身出场：完整实体（不透明，非淡影），微染元素色以便与真身区分
	var c := Sprite2D.new()
	c.texture = _sprite.texture
	c.flip_h = _sprite.flip_h
	c.scale = _sprite.scale
	c.z_index = int(position.y) + 2
	c.modulate = Color(
			lerpf(1.0, _elem_col.r, 0.34),
			lerpf(1.0, _elem_col.g, 0.34),
			lerpf(1.0, _elem_col.b, 0.34), tint_a)
	c.global_position = Vector2(base_gx, base_gy)
	par.add_child(c)
	# 分身冲刺（QUAD 出：起步快、末段收）
	var ct := c.create_tween()
	ct.tween_property(c, "global_position:x", base_gx + dx, dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# ② 冲刺途中拉出速度残影（沿分身路径撒淡影，读出"高速掠过"）
	var n: int = maxi(3, int(dur / 0.030))
	for i in n:
		var k: float = float(i + 1) / float(n + 1)
		var rel := create_tween()
		rel.tween_interval(dur * k)
		rel.tween_callback(_spawn_speed_ghost.bind(base_gx + dx * k, base_gy))
	# ③ 到位：真身"曾经在此"留一枚淡影，然后真身瞬移过去，分身淡出移交
	ct.tween_callback(func() -> void:
		_ghost()                                   # 真人在原位的淡影
		position.x += dx                           # ★ 真身瞬移（相对位移，稳）
		_dust(7, 24.0)
		Sfx.play("dash", randf_range(1.05, 1.18), -4.0)
		# ★ 通知 Battle：接力落点补一次横扫判定（沿途敌人挨打）
		relay_landed.emit(position.x)
		var ft := c.create_tween()
		ft.tween_property(c, "modulate:a", 0.0, 0.12)
		ft.tween_callback(c.queue_free))


## 分身路径上的速度虚影（比 _ghost 更淡更小，只为读速度）
func _spawn_speed_ghost(gx: float, gy: float) -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var par := get_parent()
	if par == null:
		return
	var s := Sprite2D.new()
	s.texture = _sprite.texture
	s.flip_h = _sprite.flip_h
	s.scale = _sprite.scale * Vector2(0.92, 1.0)
	s.modulate = Color(_elem_col.r, _elem_col.g, _elem_col.b, 0.42)
	s.z_index = int(position.y) + 1
	s.global_position = Vector2(gx, gy)
	par.add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.0, 0.22)
	t.tween_callback(s.queue_free)


func attack_box() -> Rect2:
	# 攻击判定框（前方一段扇形近似成矩形）
	var w: float = 74.0
	var x: float = position.x + (10.0 if facing > 0 else -w - 10.0)
	return Rect2(Vector2(x, position.y - 132.0), Vector2(w, 132.0))


func _spawn_slash(step: int) -> void:
	var arc := Node2D.new()
	arc.z_index = 50
	arc.position = Vector2(52 * facing, -140)
	_slash_root.add_child(arc)
	# 用一条弧形线段模拟刀光
	var pts := PackedVector2Array()
	var r := 120.0
	for i in range(13):
		var a: float = deg_to_rad(lerp(-70.0, 70.0, i / 12.0))
		pts.append(Vector2(cos(a) * r * facing, sin(a) * r * 0.6))
	var ln := Line2D.new()
	ln.points = pts
	ln.width = 18.0 if step < 3 else 26.0
	# ★ 刀光带主角元素色（三段连击末段最亮）
	if step < 3:
		ln.default_color = _elem_col.lerp(Color(1, 1, 1), 0.55)
	else:
		ln.default_color = _elem_col.lerp(Color(1, 1, 0.9), 0.25)
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	arc.add_child(ln)
	# 元素色光晕（让不同角色的攻击一眼可辨）
	var glow := Sprite2D.new()
	glow.texture = _ellipse_texture(64, 64)
	glow.modulate = Color(_elem_col.r, _elem_col.g, _elem_col.b, 0.35)
	glow.position = Vector2(52 * facing, -140)
	glow.z_index = 49
	arc.add_child(glow)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(arc, "scale", Vector2(1.35, 1.35), 0.18)
	t.tween_property(arc, "modulate:a", 0.0, 0.20)
	t.chain().tween_callback(arc.queue_free)


# ============ 受伤 ============
func take_damage(dmg: int) -> void:
	if dead or invuln > 0.0:
		return
	# ★ 灵光盾先扛（商店购得）：盾值扣完才伤血
	if shield > 0:
		var ab := mini(shield, dmg)
		shield -= ab
		dmg -= ab
		Sfx.play("crit", 1.4, -6.0)   # 盾挡：清脆一声
		invuln = 0.5
		if dmg <= 0:
			return
	hp = max(0, hp - dmg)
	invuln = 0.8
	_hurt_flash = 0.36
	_set_art(_art_hurt)
	add_rage(10)              # ★ 挨打攒怒（越挨打越容易爆发）
	emit_signal("hp_changed", hp, max_hp)
	Sfx.play("hurt")
	# 被击退
	var t := create_tween()
	t.tween_property(self, "position:x", position.x - 34 * facing, 0.09)
	t.chain().tween_property(self, "position:x", position.x, 0.14)
	# ★ 受击踉跄：身体后仰再站直 + 压扁一瞬（挨打不只是闪红，人要真的"晃"）
	_squash(1.10, 0.88, 0.18)
	if _sprite:
		_rot_lock = maxf(_rot_lock, 0.26)
		var rt := create_tween()
		rt.tween_property(_sprite, "rotation", -0.30 * facing, 0.08) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rt.tween_property(_sprite, "rotation", 0.0, 0.18)
	if hp <= 0:
		die()


func die() -> void:
	dead = true
	if _sprite:
		var t := create_tween()
		t.tween_property(_sprite, "rotation", PI * 0.5 * facing, 0.5)
		t.parallel().tween_property(_sprite, "modulate:a", 0.2, 0.6)
	emit_signal("died")


func heal(n: int) -> void:
	hp = min(max_hp, hp + n)
	emit_signal("hp_changed", hp, max_hp)


# ============ 拾字 ============
func add_char(info: Dictionary) -> void:
	picked.append(info)
	energy = min(energy_need, energy + 1)
	emit_signal("char_picked", info)
	emit_signal("energy_changed", energy, energy_need)


# ============ ★ 怒气狂暴 ============
## 攒怒：命中敌人 +6（Battle 调），挨打 +10。满了自动爆发。
func add_rage(n: int) -> void:
	if dead or rage_t > 0.0:
		return
	rage = clampi(rage + int(round(n * rage_gain_k)), 0, RAGE_MAX)
	emit_signal("rage_changed", rage, RAGE_MAX)
	if rage >= RAGE_MAX:
		_enter_rage()


func _enter_rage() -> void:
	rage = 0
	rage_t = RAGE_DUR
	emit_signal("rage_changed", 0, RAGE_MAX)
	emit_signal("rage_burst")
	Sfx.play("levelup", 0.75, 3.0)
	Sfx.play("crit", 0.7, -2.0)


## 狂暴中的伤害倍率（Battle 结算处乘）
func dmg_mult() -> float:
	return RAGE_DMG if rage_t > 0.0 else 1.0


## 当前攻击动作时长（狂暴攻速更快；词条「迅捷」再乘攻速倍率）
func atk_dur() -> float:
	var base: float = ATK_DUR_RAGE if rage_t > 0.0 else ATTACK_DUR
	return base / maxf(0.5, atk_speed_k)


func can_ult() -> bool:	return energy >= energy_need


func consume_ult() -> void:
	energy = 0
	emit_signal("energy_changed", energy, energy_need)


func energy_ratio() -> float:
	return float(energy) / float(max(1, energy_need))


## 主角基础攻击伤害（Battle 结算普攻时用）
func hero_dmg() -> int:
	return _base_dmg


## 主角元素主色（Battle 做大招/技能特效配色时用）
func elem_color() -> Color:
	return _elem_col


## 主角元素深色
func elem_deep() -> Color:
	return _elem_deep


# ============ 跳跃 / 冲刺 ============
## 是否处于"可躲判定"的腾空状态（机关 / 敌人近身攻击会据此放过）
func is_airborne() -> bool:
	return _air > 10.0


## 当前离地高度（Battle 踩踏判定用）
func air_h() -> float:
	return _air


## 是否在「下落」阶段（踩踏只在下落时触发）
func falling() -> bool:
	return (not _on_ground) and _air_v < 0.0


## 踩到敌人后的弹跳
func bounce() -> void:
	_air_v = max(_air_v, JUMP_V * 0.55)


## 跳跃：仅在地面上有效
func jump() -> void:
	if dead or not _on_ground:
		return
	_on_ground = false
	_air_v = JUMP_V
	_squash(0.84, 1.14, 0.26)     # 起跳：先蹲后弹（压扁→拉长）
	Sfx.play("jump", 1.25, -6.0)


## 双击方向 = 冲刺。
##   地面双击 → 跃冲（高速突进 + 顺势起跳，即"往前快冲一次，然后跳起来"）
##   空中双击 → 向前飞（滞空更久的空中冲刺）
func try_dash(dir: int) -> void:
	if dead or _dash_cd > 0.0:
		return
	_dash_dir = dir
	_dashing = AIR_DASH_DUR if not _on_ground else DASH_DUR
	_dash_cd = 0.42
	invuln = max(invuln, _dashing + 0.05)
	facing = dir
	_squash(0.88, 1.10, 0.18)     # 冲刺：拉长加速感
	_dust(6, 20.0)                # 蹬地扬尘
	Sfx.play("dash", 1.4, -10.0)
	if _on_ground:
		# 跃冲：起跳，变成"冲 + 跳"
		_on_ground = false
		_air_v = JUMP_V * 0.92


## 冲刺残影（淡蓝拖影，纯表现）
func _spawn_dash_trail() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.scale = _sprite.scale
	ghost.flip_h = _sprite.flip_h
	ghost.modulate = Color(0.6, 0.85, 1.0, 0.45)
	ghost.position = _sprite.position
	ghost.z_index = int(position.y) - 1
	add_child(ghost)
	var t := create_tween()
	t.tween_property(ghost, "modulate:a", 0.0, 0.22)
	t.chain().tween_callback(ghost.queue_free)


## 加速（数字键 6 特技）：限时提速
func haste(sec: float) -> void:
	_haste_t = max(_haste_t, sec)


## 数字键 1-9 特技的玩家侧表现（具体伤害 / 治疗在 Battle 里结算）
##   ⚠ 不用 sprite.modulate 变色 —— _process 每帧会重写 modulate（受击/无敌闪烁），
##     颜色闪光会被覆盖看不见。改用独立「光环 + 爆点粒子」节点，铁定可见。
##   配色以主角元素色为基准做微调，让每个角色的特效保持统一风格。
func play_special(n: int) -> void:
	if _sprite == null:
		return
	var col := _elem_col
	match n:
		1: col = _elem_col.lerp(Color(0.6, 0.9, 1.0), 0.6)   # 翻滚
		2: col = _elem_col.lerp(Color(1.0, 0.8, 0.4), 0.5)   # 上挑
		3: col = _elem_col                                    # 震地（纯元素色）
		4: col = _elem_col.lerp(Color(0.6, 1.0, 0.7), 0.5)   # 回旋斩
		5: col = _elem_col.lerp(Color(0.5, 0.8, 1.0), 0.5)   # 护盾
		6: col = _elem_col.lerp(Color(1.0, 0.8, 0.3), 0.5)   # 加速
		7: col = Color(0.5, 1.0, 0.5)                         # 回血（恒为绿）
		8: col = _elem_col.lerp(Color(0.7, 0.8, 1.0), 0.4)   # 引雷
		9: col = _elem_col.lerp(Color(1.0, 0.5, 0.8), 0.5)   # 烟花
	var cpos := _sprite.position
	# ① 彩色光环绕一圈（放大淡出）
	var glow := Sprite2D.new()
	glow.texture = _ellipse_texture(76, 76)
	glow.modulate = Color(col.r, col.g, col.b, 0.85)
	glow.position = cpos
	glow.z_index = int(position.y) + 10
	add_child(glow)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(glow, "scale", Vector2(2.4, 2.4), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(glow, "modulate:a", 0.0, 0.30)
	tw.chain().tween_callback(glow.queue_free)
	# ② 彩色爆点粒子
	var p := CPUParticles2D.new()
	p.amount = 16
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 170.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 230.0
	p.gravity = Vector2(0, 320)
	p.scale_amount_min = 5.0
	p.scale_amount_max = 10.0
	p.color = Color(col.r, col.g, col.b, 0.95)
	p.position = cpos
	p.z_index = int(position.y) + 9
	add_child(p)


# ============ 输入 ============
## 方向键 + WASD 双支持。
## 项目里没把 WASD 写进输入映射（改 project.godot 的 InputMap 风险大），
## 直接在代码里补一个物理键判断即可 —— 小朋友习惯方向键，家长习惯 WASD。
func _hold(action: String, key: int) -> bool:
	return Input.is_action_pressed(action) or Input.is_physical_key_pressed(key)

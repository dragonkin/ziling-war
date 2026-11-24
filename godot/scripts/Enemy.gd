extends Node2D
## 小兵 / Boss —— 会朝玩家靠近、间歇攻击；被击败后爆出汉字

signal enemy_died(enemy, char_info)
signal boss_summon_requested(origin)   # Boss 出召唤技时发给 Battle 生成小兵

const X_MIN := 40.0
const X_MAX := 6400.0    # 横向卷轴世界较宽，由 Battle 保证实际范围
const Y_NEAR := 520.0    # 与 Battle.GROUND_BASE 一致
const Y_FAR := 392.0

## 每场景主题配套的小兵 / Boss 池（assets/roster/）
## 没生成成功时回退到老的 char2 素材
const THEME_MOBS := {
	"water":  ["res://assets/roster/mob_water_a.png", "res://assets/roster/mob_water_b.png"],
	"bamboo": ["res://assets/roster/mob_bamboo_a.png", "res://assets/roster/mob_bamboo_b.png"],
	"palace": ["res://assets/roster/mob_palace_a.png", "res://assets/roster/mob_palace_b.png"],
	"lava":   ["res://assets/roster/mob_lava_a.png", "res://assets/roster/mob_lava_b.png"],
	"ruins":  ["res://assets/roster/mob_ruins_a.png", "res://assets/roster/mob_ruins_b.png"],
	"sky":    ["res://assets/roster/mob_sky_a.png", "res://assets/roster/mob_sky_b.png"],
}
const THEME_BOSSES := {
	"water":  ["res://assets/roster/boss_water_a.png", "res://assets/roster/boss_water_b.png"],
	"bamboo": ["res://assets/roster/boss_bamboo_a.png", "res://assets/roster/boss_bamboo_b.png"],
	"palace": ["res://assets/roster/boss_palace_a.png", "res://assets/roster/boss_palace_b.png"],
	"lava":   ["res://assets/roster/boss_lava_a.png", "res://assets/roster/boss_lava_b.png"],
	"ruins":  ["res://assets/roster/boss_ruins_a.png", "res://assets/roster/boss_ruins_b.png"],
	"sky":    ["res://assets/roster/boss_sky_a.png", "res://assets/roster/boss_sky_b.png"],
}
## 回退用：老的通用素材
const MOB_ARTS := [
	"res://assets/char2/mob_ink.png",
	"res://assets/char2/mob_scroll.png",
	"res://assets/char2/mob_brush.png",
]
const BOSS_ARTS := [
	"res://assets/char2/boss_inkgeneral.png",
	"res://assets/char2/boss_stonelion.png",
	"res://assets/char2/boss_scrolldragon.png",
]

var max_hp := 40
var hp := 40
var is_boss := false
var is_elite := false            # ★ 精英怪：紫色光环大怪，波次中后段出现，掉宝必给
var char_info: Dictionary = {}   # 该兵身上代表的字
var art_path := "res://assets/char/monster_t.png"
var boss_index := 0              # 哪个 Boss（决定名字与外型）
var theme := ""                  # 所属场景主题（决定素材池）

var dead := false
var enemy_type := "normal"      # normal(近身) / hopper(跳跳怪) / charger(冲撞兵)
var _target: Node2D = null
var _sprite: Sprite2D
var _shadow: Sprite2D
var _shadow_base_scale := 0.0     # 影子纵深缩放基准（走路伸缩重算用，避免累乘）
var _tag: Label
var _py: Label
var _hp_bar: ProgressBar
var _hp_wrap: Node2D
var _attack_cd := 1.2
var _atk_wind := 0.0
var _hurt_flash := 0.0
var _root_t := 0.0        # ★ 被缠藤定身剩余时间（>0 时禁止移动/攻击）
var _bob := 0.0
var _walk_ph := 0.0
var _speed := 95.0
var _base_h := 170.0
var terrain: Node = null      # 由 Battle 注入

# ===== ★ 形体个性（按主题差异化，让每系怪物"活"得不一样）=====
var _sq_x := 1.0              # 果冻抖动乘数（受击时弹一下）
var _sq_y := 1.0
var _bob_amp := 5.0           # 呼吸浮动幅度
var _bob_spd := 3.0           # 呼吸速度
var _sway_amp := 0.0          # 随风摇摆幅度（rad）

# ===== Boss 三招 + 二阶段 =====
var _boss_state := "idle"        # idle / dash / dashwind / stomp / stompwind / summon / recover
var _boss_skill_t := 0.0         # 距下次出招倒计时
var _boss_dash_dir := 1.0        # 冲刺方向
var _boss_dash_v := 560.0        # 冲刺速度
var _boss_stomp_x := 0.0         # 震地落点 x
var _boss_jump_y := 0.0          # 跳起当前高度
var _boss_jump_v := 0.0
var _boss_rage := false          # 血量 <50% 狂暴
var _boss_recover_t := 0.0
var _boss_summoned := 0


static func create(p_pos: Vector2, p_hp: int, p_boss: bool, p_char: Dictionary,
		p_boss_idx: int = 0, p_theme: String = "", p_type: String = "normal",
		p_elite: bool = false) -> Node2D:
	var n := Node2D.new()
	n.set_script(load("res://scripts/Enemy.gd"))
	n.position = p_pos
	n.max_hp = p_hp
	n.hp = p_hp
	n.is_boss = p_boss
	n.is_elite = p_elite
	n.char_info = p_char
	n.boss_index = p_boss_idx
	n.theme = p_theme
	n.enemy_type = p_type
	if p_boss:
		n._boss_skill_t = 1.4   # 开场略作停顿后出招
	var picked := ""
	if p_boss:
		# 优先：本主题的 Boss（用 boss_idx 决定 A/B 哪个）
		var tl: Array = THEME_BOSSES.get(p_theme, [])
		if not tl.is_empty():
			var cand: String = tl[p_boss_idx % tl.size()]
			if ResourceLoader.exists(cand):
				picked = cand
		if picked == "":
			var bp: String = BOSS_ARTS[p_boss_idx % BOSS_ARTS.size()]
			picked = bp if ResourceLoader.exists(bp) else "res://assets/char/boss_t.png"
	else:
		var ml: Array = THEME_MOBS.get(p_theme, [])
		if not ml.is_empty():
			var pick: String = ml[randi() % ml.size()]
			if ResourceLoader.exists(pick):
				picked = pick
		if picked == "":
			var mp: String = MOB_ARTS[randi() % MOB_ARTS.size()]
			picked = mp if ResourceLoader.exists(mp) else "res://assets/char/monster_t.png"
	n.art_path = picked
	return n


func _ready() -> void:
	_build()
	_bob = randf() * TAU
	_attack_cd = randf_range(0.8, 1.8)
	# ★ 出生演出：从透明淡入（像从战场里"冒出来"，而不是凭空出现）
	modulate.a = 0.0
	var st := create_tween()
	st.tween_property(self, "modulate:a", 1.0, 0.30)


func _build() -> void:
	_shadow = Sprite2D.new()
	_shadow.texture = _make_ellipse(96, 30)
	_shadow.modulate = Color(0, 0, 0, 0.34)
	_shadow.position = Vector2(0, 4)
	add_child(_shadow)

	# 占画面高：小兵约 21%，精英约 26%，Boss 约 32%（配合英雄 23% 的比例体系）
	_base_h = 232.0 if is_boss else (192.0 if is_elite else 152.0)
	if is_elite:
		_speed = 74.0   # 精英更沉稳（块头大走得慢，给玩家周旋空间）
	# ⚠️ 导出包里 art_path 可能不存在（被导出过滤排除）→ 必须判空，
	#    否则 _apply_depth() 的 .get_height() 会直接闪退
	var tex: Texture2D = null
	if ResourceLoader.exists(art_path):
		var _r = load(art_path)
		if _r is Texture2D:
			tex = _r
	if tex == null:
		tex = _make_fallback_tex()
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.position = Vector2(0, -_base_h * 0.5)
	# ★ 立体化着色器（与主角同一套，AO 稍重、顶缘光稍弱——怪物更"沉"）
	var sh: Shader = null
	if ResourceLoader.exists("res://assets/shaders/hero3d.gdshader"):
		var sr = load("res://assets/shaders/hero3d.gdshader")
		if sr is Shader:
			sh = sr
	if sh != null:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("ao_strength", 0.62)
		m.set_shader_parameter("rim_strength", 0.20)
		m.set_shader_parameter("side_dark", 0.20)
		m.set_shader_parameter("contrast", 1.10)
		_sprite.material = m
	add_child(_sprite)

	# ★ 精英标识：脚下紫色光环 + 头顶紫光晕（和普通怪一眼区分开）
	if is_elite and not is_boss:
		var aura := Sprite2D.new()
		aura.texture = _make_ellipse(150, 46)
		aura.modulate = Color(0.62, 0.30, 1.0, 0.38)
		aura.position = Vector2(0, 2)
		aura.z_index = -1
		add_child(aura)
		# 光环呼吸脉动（异步 tween 循环，死掉时随节点一起释放）
		var at := create_tween().set_loops()
		at.tween_property(aura, "modulate:a", 0.18, 0.7)
		at.tween_property(aura, "modulate:a", 0.38, 0.7)

	# 头顶汉字标牌 + 拼音
	_tag = Label.new()
	_tag.text = char_info.get("char", "")
	_tag.add_theme_font_size_override("font_size", 46 if not is_boss else 58)
	_tag.add_theme_color_override("font_color", Color("#fff3c4"))
	_tag.add_theme_color_override("font_outline_color", Color("#3a1000"))
	_tag.add_theme_constant_override("outline_size", 8)
	_tag.size = Vector2(120, 60)
	_tag.position = Vector2(-60, -_base_h - 46)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_tag)

	var py: String = char_info.get("pinyin", char_info.get("py", ""))
	if py != "":
		_py = Label.new()
		_py.text = py
		_py.add_theme_font_size_override("font_size", 22)
		_py.add_theme_color_override("font_color", Color("#ffe9a0"))
		_py.add_theme_color_override("font_outline_color", Color("#3a1000"))
		_py.add_theme_constant_override("outline_size", 5)
		_py.size = Vector2(120, 28)
		_py.position = Vector2(-60, -_base_h - 26)
		_py.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_py)

	# 小血条
	_hp_wrap = Node2D.new()
	_hp_wrap.position = Vector2(0, -_base_h - 8)
	add_child(_hp_wrap)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.size = Vector2(92, 11)
	bg.position = Vector2(-46, 0)
	_hp_wrap.add_child(bg)
	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_bar.show_percentage = false
	_hp_bar.size = Vector2(88, 7)
	_hp_bar.position = Vector2(-44, 2)
	var f := StyleBoxFlat.new()
	f.bg_color = Color("#7a3aff") if is_boss else (Color("#c04dff") if is_elite else Color("#ff5a5a"))
	f.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("fill", f)
	_hp_wrap.add_child(_hp_bar)

	# ★ 形体个性：主题 → 动作风格（水系像果冻、天系飘浮、草木随风、熔岩急颤）
	match theme:
		"water":
			_bob_amp = 9.0
			_bob_spd = 2.2      # 大而慢的呼吸 = 果冻感
		"sky":
			_bob_amp = 14.0
			_bob_spd = 1.8      # 高低浮沉 + 轻微摇摆 = 飘在天上
			_sway_amp = 0.05
		"lava":
			_bob_amp = 3.0
			_bob_spd = 6.0      # 快速小颤 = 灼热躁动
		"bamboo":
			_bob_amp = 5.0
			_bob_spd = 2.6
			_sway_amp = 0.09    # 大幅随风摆
		_:
			pass                # palace/ruins：石质硬朗，默认小幅沉稳

	_apply_depth()


## ★ 程序化兜底敌人（素材丢失时使用，保证游戏永远能跑起来）
func _make_fallback_tex() -> ImageTexture:
	var w := 84
	var h := int(_base_h) if _base_h > 1.0 else 152
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body: Color = Color("#8a3b3b") if is_boss else Color("#5b6b7d")
	var cx := float(w) * 0.5
	for y in h:
		for x in w:
			var c := Color(0, 0, 0, 0)
			var dx: float = (float(x) - cx) / (32.0 if is_boss else 26.0)
			var dy: float = (float(y) - float(h) * 0.42) / (float(h) * 0.44)
			if dx * dx + dy * dy <= 1.0:
				c = body
			elif y > int(float(h) * 0.78) and absf(float(x) - cx) < 22.0:
				c = body.darkened(0.32)
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_ellipse(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w / 2.0
	var cy := h / 2.0
	for y in h:
		for x in w:
			var dx := (x - cx) / cx
			var dy := (y - cy) / cy
			var d := dx * dx + dy * dy
			if d <= 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 - d))
	return ImageTexture.create_from_image(img)


func set_target(t: Node2D) -> void:
	_target = t


func _apply_depth() -> void:
	if not _sprite:
		return
	var t: float = clamp((position.y - Y_FAR) / (Y_NEAR - Y_FAR), 0.0, 1.0)
	var s: float = lerp(0.72, 1.0, t)
	var th := _base_h
	if _sprite.texture != null:
		th = max(1.0, float(_sprite.texture.get_height()))
	var k: float = (_base_h / max(1.0, th)) * s
	# ★ 果冻乘数：受击时的弹抖从这里进（scale 每帧重算，直接改会被吃掉）
	_sprite.scale = Vector2(-k * _sq_x, k * _sq_y)
	_shadow_base_scale = s
	_shadow.scale = Vector2(s, s)
	# 靠后稍暗
	var br: float = lerp(0.78, 1.0, t)
	_sprite.modulate = Color(br, br, br, _sprite.modulate.a)
	z_index = int(position.y)


func _process(delta: float) -> void:
	if dead:
		return
	_bob += delta * _bob_spd

	# ★ 被缠藤定身：完全不行动（只保留受击闪白）
	if _root_t > 0.0:
		_root_t -= delta
		if _hurt_flash > 0.0:
			_hurt_flash -= delta
			var ron := fmod(_hurt_flash, 0.08) > 0.04
			if _sprite:
				_sprite.modulate = Color(2.6, 2.0, 2.0, 1) if ron else Color(1, 1, 1, 1)
		return

	# 已受击闪白
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		var on := fmod(_hurt_flash, 0.08) > 0.04
		if _sprite:
			_sprite.modulate = Color(2.6, 2.0, 2.0, 1) if on else Color(1, 1, 1, 1)
	else:
		if _sprite:
			_sprite.modulate = Color(1, 1, 1, _sprite.modulate.a)

	# 呼吸浮动（站立时）—— 幅度/速度按主题个性走；摇摆类主题加缓摆
	if _sprite:
		_sprite.position.y = -_base_h * 0.5 + sin(_bob) * _bob_amp
		if _sway_amp > 0.0 and _atk_wind <= 0.0:
			_sprite.rotation = sin(_bob * 0.8) * _sway_amp

	# 攻击蓄力中
	if _atk_wind > 0.0:
		_atk_wind -= delta
		if _sprite:
			_sprite.position.x = -14.0
			# 蓄力时往后仰一点，像在蓄势
			_sprite.rotation = -0.10
		if _atk_wind <= 0.0:
			if _sprite:
				_sprite.rotation = 0.0
			_do_hit()
		return

	if _target == null or not is_instance_valid(_target):
		return

	# ★ Boss：走技能状态机（三招 + 二阶段）
	if is_boss:
		_boss_process(delta)
		return

	# ★ 小兵：按类型走行为
	match enemy_type:
		"hopper":
			_hopper_process(delta)
		"charger":
			_charger_process(delta)
		_:
			_normal_process(delta)


## 普通小兵：靠近 + 近身攻击（原逻辑）
func _normal_process(delta: float) -> void:
	var tp: Vector2 = _target.position
	var to := tp - position
	var dist := to.length()
	var desired := 76.0
	if dist > desired:
		var move := Vector2.ZERO
		if abs(to.y) > 14.0:
			move.y = sign(to.y)
		if abs(to.x) > 132.0:
			move.x = sign(to.x)
		if move != Vector2.ZERO:
			move = move.normalized()
		position += move * _speed * delta
		position.x = clamp(position.x, X_MIN, X_MAX)
		var gy: float = Y_NEAR
		if terrain and terrain.has_method("ground_y_at"):
			gy = terrain.ground_y_at(position.x)
		position.y = clamp(position.y, gy - 130.0, gy)
		_apply_depth()
		_walk_ph += delta * 11.0
		if _sprite:
			_sprite.position.y = -_base_h * 0.5 - abs(sin(_walk_ph)) * 7.0
			_sprite.position.x = -5.0 * sin(_walk_ph)
			_sprite.rotation = 0.045 * sin(_walk_ph)
		if _shadow and _shadow_base_scale > 0.0:
			var sq: float = 1.0 - abs(sin(_walk_ph)) * 0.10
			_shadow.scale = Vector2(_shadow_base_scale, _shadow_base_scale * sq)
	else:
		_walk_ph = 0.0
		if _sprite:
			_sprite.rotation = 0.0
		_attack_cd -= delta
		if _attack_cd <= 0.0:
			_atk_wind = 0.34
			_attack_cd = randf_range(1.4, 2.4)


## 跳跳怪：隔一段距离就窜起来砸向玩家（可跳跃躲避 / 空中踩扁）
var _hop_t := 0.0
var _hop_vy := 0.0
var _hop_vx := 0.0
var _hopping := false
func _hopper_process(delta: float) -> void:
	if not _hopping:
		# 靠近到射程内，起跳 CD 到了就扑
		_hop_t -= delta
		var dist := position.distance_to(_target.position)
		if dist < 340.0 and _hop_t <= 0.0:
			_hopping = true
			_hop_t = randf_range(1.6, 2.6)
			var to: Vector2 = _target.position - position
			var ttx: float = clamp(abs(to.x) / 520.0, 0.5, 1.0)   # 滞空 0.5~1s
			_hop_vy = 620.0
			_hop_vx = clamp(to.x, -320.0, 320.0) * 1.4
			if _sprite:
				_sprite.rotation = 0.0
		else:
			# 没到射程：缓慢靠近
			var to: Vector2 = _target.position - position
			position += Vector2(sign(to.x), 0) * _speed * 0.45 * delta
		return
	# 跳跃中：抛体运动（水平匀速 + 垂直重力），落地收招
	position.x = clamp(position.x + _hop_vx * delta, X_MIN, X_MAX)
	_hop_vy -= 1750.0 * delta
	position.y += _hop_vy * delta
	var gy: float = Y_NEAR
	if terrain and terrain.has_method("ground_y_at"):
		gy = terrain.ground_y_at(position.x)
	if position.y >= gy - 40.0:
		# 落地（接近地面）：砸地 + 判定命中
		position.y = gy - 40.0
		_hopping = false
		_hop_vy = 0.0
		_hop_vx = 0.0
		_stomp_aoe_hit(150.0, 8)


## 冲撞兵：看到玩家先举盾蓄力，然后朝玩家快速冲锋（前摇明显，可跳躲/绕后）
var _charge_t := 0.0
var _charge_dir := 1.0
var _charging := false
var _windup := 0.0
func _charger_process(delta: float) -> void:
	if _windup > 0.0:
		# 蓄力前摇：身体后仰，发出红光（警示）
		_windup -= delta
		if _sprite:
			_sprite.rotation = -0.22
			_sprite.position.x = -18.0
		# 出红光是 sdf 不好做，用 sprite modulate 闪红
		if _sprite:
			_sprite.modulate = Color(3.0, 1.3, 1.3, 1.0) if fmod(_bob * 9.0, 1.0) > 0.5 else Color(1, 1, 1, 1)
		if _windup <= 0.0:
			_charging = true
			_charge_dir = sign(_target.position.x - position.x)
			if _sprite:
				_sprite.rotation = 0.0
				_sprite.position.x = 0.0
		return
	if _charging:
		# 冲锋：高速位移 + 撞击判定
		position.x += _charge_dir * 520.0 * delta
		position.x = clamp(position.x, X_MIN, X_MAX)
		if abs(position.x - _target.position.x) < 60.0:
			_stomp_aoe_hit(90.0, 7)
		_walk_ph += delta * 20.0
		if _sprite:
			_sprite.rotation = 0.12 * _charge_dir
		# 撞到双方距离拉远或超时结束冲锋
		_charge_t -= delta
		if _charge_t <= 0.0 or abs(position.x - _target.position.x) > 420.0:
			_charging = false
			_charge_t = randf_range(1.6, 2.4)
			if _sprite:
				_sprite.rotation = 0.0
		return
	# 未冲锋：找机会进入蓄力
	_charge_t -= delta
	var dist := position.distance_to(_target.position)
	if dist < 400.0 and _charge_t <= 0.0:
		_windup = 0.42
		_charge_t = randf_range(1.8, 2.6)


## 范围命中玩家（踩踏/冲刺/震地共用）—— 单位伤害、腾空可躲
func _stomp_aoe_hit(radius: float, dmg: int) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if _target.has_method("is_airborne") and _target.is_airborne():
		return
	if position.distance_to(_target.position) < radius:
		_target.take_damage(dmg)


## ================= Boss 技能状态机 =================
func _boss_process(delta: float) -> void:
	match _boss_state:
		"idle":
			# 保持一定距离 + 不贴脸，倒计时出招
			var dist := position.distance_to(_target.position)
			var to := _target.position - position
			if dist > 110.0:
				position += to.normalized() * _speed * 0.55 * delta
				position.x = clamp(position.x, X_MIN, X_MAX)
				_apply_depth()
			_boss_skill_t -= delta
			if _boss_skill_t <= 0.0:
				_pick_boss_skill()
		"dashwind":
			# 蓄力前摇（红光示警）
			_boss_skill_t -= delta
			if _sprite:
				_sprite.rotation = -0.18
				_sprite.modulate = Color(2.6, 1.1, 1.1, 1.0) if fmod(_bob * 8.0, 1.0) > 0.5 else Color(1, 1, 1, 1)
			if _boss_skill_t <= 0.0:
				_boss_state = "dash"
				_boss_dash_dir = sign(_target.position.x - position.x)
				if _sprite:
					_sprite.rotation = 0.0
		"dash":
			# 冲刺撞击：高速突进一段，撞到人给伤害
			position.x += _boss_dash_dir * _boss_dash_v * delta
			position.x = clamp(position.x, X_MIN, X_MAX)
			if abs(position.x - _target.position.x) < 74.0:
				_stomp_aoe_hit(100.0, 12)
			_boss_skill_t -= delta
			if _boss_skill_t <= 0.0:
				_boss_state = "recover"
				_boss_recover_t = 0.5
		"stompwind":
			# 跃起前摇（预警圈由 Battle 画）；按脚下地面高度抬升
			var gy_stomp: float = Y_NEAR
			if terrain and terrain.has_method("ground_y_at"):
				gy_stomp = terrain.ground_y_at(position.x)
			_boss_jump_v += 1350.0 * delta   # 蓄力上浮
			_boss_jump_y += _boss_jump_v * delta
			position.y = gy_stomp - 90.0 - _boss_jump_y
			_boss_skill_t -= delta
			if _boss_skill_t <= 0.0:
				_boss_state = "stomp"
				_boss_jump_v = 0.0
		"stomp":
			# 落向目标 x，落地震地
			var gys2: float = Y_NEAR
			if terrain and terrain.has_method("ground_y_at"):
				gys2 = terrain.ground_y_at(position.x)
			_boss_jump_v -= 2600.0 * delta
			_boss_jump_y += _boss_jump_v * delta
			position.y = min(gys2 - 90.0 + _boss_jump_y, gys2 - 40.0)
			position.x = move_toward(position.x, _boss_stomp_x, 320.0 * delta)
			if position.y >= gys2 - 40.0:
				position.y = gys2 - 40.0
				# 震地冲击
				_stomp_aoe_hit(230.0, 10)
				_boss_state = "recover"
				_boss_recover_t = 0.55
		"summon":
			# 喊话召唤 2 只小兵（Battle 真实生成；用信号避免耦合 parent）
			if _boss_summoned < 2:
				boss_summon_requested.emit(position)
				_boss_summoned += 1
			_boss_state = "recover"
			_boss_recover_t = 0.5
		"recover":
			# 收招硬直：这段时间是玩家的输出窗口
			_boss_recover_t -= delta
			if _sprite:
				_sprite.modulate = Color(1, 1, 1, 1)
			if _boss_recover_t <= 0.0:
				_boss_state = "idle"
				_boss_skill_t = 0.85 if _boss_rage else (0.75 + randf_range(0.3, 0.7))


## 挑一个 Boss 招式（狂暴阶段全是高频招）
func _pick_boss_skill() -> void:
	var roll := randi() % 10
	if _boss_rage:
		# 狂暴：冲刺/震地频率暴增
		if roll < 4:
			_boss_begin_dash()
		elif roll < 8:
			_boss_begin_stomp()
		else:
			_boss_begin_summon()
	else:
		if roll < 3:
			_boss_begin_dash()
		elif roll < 6:
			_boss_begin_stomp()
		elif roll < 8:
			_boss_begin_summon()
		else:
			# 漫步
			_boss_state = "idle"
			_boss_skill_t = 1.0


func _boss_begin_dash() -> void:
	_boss_state = "dashwind"
	_boss_skill_t = 0.42   # 蓄力前摇 → 好让玩家起跳/后撤
	_boss_dash_v = 560.0 if not _boss_rage else 720.0


func _boss_begin_stomp() -> void:
	_boss_state = "stompwind"
	_boss_skill_t = 0.4
	_boss_stomp_x = clamp(_target.position.x, X_MIN, X_MAX)
	_boss_jump_v = 0.0
	_boss_jump_y = 0.0


func _boss_begin_summon() -> void:
	_boss_state = "summon"
	_boss_skill_t = 0.0


func _do_hit() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	# ★ 玩家腾空时近身攻击落空（跳跃可躲 Boss 横扫 / 小兵扑击）
	if _target.has_method("is_airborne") and _target.is_airborne():
		return
	if _target.has_method("take_damage"):
		# 距离判定，避免隔空打
		if position.distance_to(_target.position) < 155.0:
			# 普通 9 / 精英 13 / Boss 15 —— 精英介于其间，疼但不致命
			var touch: int = 15 if is_boss else (13 if is_elite else 9)
			_target.take_damage(touch)
	if _sprite:
		_sprite.position.x = 0.0


func take_damage(dmg: int, knock_dir: float = 1.0) -> void:
	if dead:
		return
	hp = max(0, hp - dmg)
	if _hp_bar:
		_hp_bar.value = hp
	# ★ 二阶段：血量 <50% 进入狂暴（出招更密、更快）
	if is_boss and not _boss_rage and hp <= max_hp * 0.5:
		_boss_rage = true
		_boss_state = "recover"
		_boss_recover_t = 0.8
		# 狂暴吼叫（视觉=闪红+略微放大，音效由 Battle 播 boss 段）
		if _sprite:
			var tw := create_tween()
			tw.tween_property(_sprite, "scale", _sprite.scale * 1.12, 0.08)
			tw.tween_property(_sprite, "scale", _sprite.scale * 1.0, 0.14)
	_hurt_flash = 0.18
	# ★ 受击果冻弹抖：横向鼓、纵向瘪，弹性回正（水系最弹，Boss 更稳重）
	var jk: float = (0.16 if is_boss else 0.24) * (1.0 + _bob_amp * 0.04)
	_sq_x = 1.0 + jk
	_sq_y = 1.0 - jk * 0.85
	var jt := create_tween()
	jt.set_parallel(true)
	jt.tween_property(self, "_sq_x", 1.0, 0.30) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	jt.tween_property(self, "_sq_y", 1.0, 0.30) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# 击退（精英半抗，Boss 后面单独再压）
	var kb: float = 32.0
	if is_elite:
		kb *= 0.45
	elif is_boss:
		kb *= 0.25
	var t := create_tween()
	t.tween_property(self, "position:x", position.x + kb * knock_dir, 0.08)
	t.chain().tween_property(self, "position:x", position.x, 0.10)
	if hp <= 0:
		_die()


## ★ 木系「缠藤缚」：定身一段时间（Boss 免疫减半）
func root_in_place(sec: float) -> void:
	if dead:
		return
	_root_t = max(_root_t, sec * (0.4 if is_boss else 1.0))
	if _sprite:
		# 缠绕视觉：整体染绿 + 轻微下压
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color(0.55, 1.35, 0.6, 1.0), 0.10)
		tw.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.40)


## ★ 水系「水龙吟」：强制击退
func knock_back(dir: float, power: float) -> void:
	if dead:
		return
	if is_boss:
		power *= 0.25   # Boss 几乎推不动
	elif is_elite:
		power *= 0.5    # 精英半抗
	var t := create_tween()
	t.tween_property(self, "position:x", position.x + power * dir, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _die() -> void:
	dead = true
	# ★ 死亡演出（真实倒地）：白闪一瞬 → 被击飞的小弧线 → 仰面倒地 →
	#   影子同步消散 → 尸身淡出（以前是原地漂起消失，很假）
	var y0: float = position.y
	var t := create_tween()
	t.set_parallel(true)
	if _sprite:
		_sprite.modulate = Color(2.6, 2.6, 2.6, 1)
		t.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.12)
	# 击飞弧线：先抛起 46px 再砸回（略沉入地面一点）
	t.tween_property(self, "position:y", y0 - 46.0, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", y0 + 8.0, 0.24) \
			.set_delay(0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _sprite:
		# 仰面倒下（1.5rad ≈ 躺平）
		t.tween_property(_sprite, "rotation", 1.5, 0.40) \
				.set_delay(0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(_sprite, "modulate:a", 0.0, 0.40).set_delay(0.26)
	if _shadow:
		t.tween_property(_shadow, "modulate:a", 0.0, 0.55)
	for w: Node in [_tag, _py, _hp_wrap]:
		if w != null:
			t.tween_property(w, "modulate:a", 0.0, 0.25)
	t.tween_interval(0.95)
	t.chain().tween_callback(queue_free)
	emit_signal("enemy_died", self, char_info)


func screen_rect() -> Rect2:
	return Rect2(position - Vector2(_base_h * 0.42, _base_h), Vector2(_base_h * 0.84, _base_h))

extends Node2D
## 大招演出 —— 三段式「结印 → 元素兽横扫 → 收场」（★ 真实素材版）
##
## ★ 用户需求（2026-09-24 口述）：
##   「放技能的时候得有人物的动作，或者说这个人物要变成一个具体的图像」
##   「释放出来一个实体，比如说火龙水龙之类的」
##   「把敌人冲飞，或者是在全屏布满雷电」
##   「持续个 5 秒钟左右」「不要问，直接做」
##
## ★ 素材方案（关键）：元素兽用 **Agnes 生成的「纯黑底特效图」**，
##   在 Godot 里用 **加色混合（BLEND_MODE_ADD）** 叠加 —— 黑色相加等于 0
##   → 黑底天然"透明"，地图与角色完全不受影响，全程看得见战场。
##   这比"程序化多边形"高级得多：是真实绘制的实体元素兽。
##
## ★ 让素材"活"起来（shader 行波形变）：逐像素把 UV.y 按「列位置 + 时间」偏移：
##     uv.y += sin(t·f − k·φ) · amp · (0.25+0.75·k)，k = UV.x
##   相位随列递减 → 沿身体向后传播的**行波**。
##   火龙会蛇形游动、海浪会翻滚、藤蔓会摇曳，而不是一张贴纸整体平移。
##   （各系频率/振幅/相位不同：剑=高频锐利、木=低频摇曳、水=大幅翻滚、
##     火=蛇形游动、土=近乎刚性抖动、雷=高频乱抖）
##   用 shader 而非"切成 N 条竖片 Sprite"：后者在片缝处会露出可见竖线。
##
## 三段式时间轴（总 5.2s）：
##   ① 结印 SEAL   0.00 → 1.05s  人物蓄力 + 大招插画定格 + 招式名/台词 + 符文收束
##   ② 兽暴 BEAST  1.05 → 4.55s  元素兽实体横扫战场，沿途敌人被击飞
##   ③ 收场 SETTLE 4.55 → 5.20s  光效退去

signal finished
## 兽扫到某处 → Battle 结算该处敌人（伤害 + 击飞）
signal beast_hit(world_pos: Vector2, radius: float, dmg: int, knock: float)

const FX_DIR := "res://assets/fx/ult/"
const SEAL_END := 1.05
const BEAST_START := 1.05
const BEAST_END := 4.55
const DURATION := 5.20
const CUTIN_W := 560.0            ## 结印插画目标宽度（1280 屏 ≈ 44% 宽，不糊屏）

var hero_id := "huo"
var hero_name := ""
var ult_name := ""
var ult_line := ""
var shout_line := ""                      ## ★ 角色喊出来的话（有语音）
var color_main := Color("#ff5a3c")
var color_deep := Color("#8b1a00")
var color_light := Color("#ffe9c0")

var _t := 0.0
var _phase := 0                          ## 0 结印 / 1 兽暴 / 2 收场
var _done := false
var _center := Vector2.ZERO
var _host: Node = null
var _juice: Node = null
var _cam: Camera2D = null

# ---- 共享资源（静态缓存，所有实例复用）----
static var _MAT_ADD: CanvasItemMaterial
static var _TEX: Dictionary = {}          ## {素材名: Texture2D}
static var _FB: Dictionary = {}           ## 程序化兜底贴图

# ---- 结印层 ----
var _seal_glow: Sprite2D
var _seal_ring: Sprite2D
var _seal_big_ring: Sprite2D
var _seal_runes: Node2D

# ---- 兽层 ----
var _beast_root: Node2D
var _beast_sprite: Sprite2D               ## ★ 单张兽（用 shader 做行波形变，无缝）
var _beast_shader: ShaderMaterial         ## 形变 shader 材质
var _bolt_root: Node2D
var _trail: CPUParticles2D                ## ★ v3 元素拖尾粒子
var _beast_progress := 0.0
var _hit_marks: Array = []


func setup(p_id: String, p_name: String, p_ult: String, p_line: String = "",
		p_shout: String = "") -> void:
	hero_id = p_id
	hero_name = p_name
	ult_name = p_ult
	ult_line = p_line
	shout_line = p_shout
	color_main = Heroes.main_color(p_id)
	color_deep = Heroes.deep_color(p_id)
	color_light = color_main.lerp(Color(1, 1, 1), 0.55)


func duration() -> float:
	return DURATION


func is_done() -> bool:
	return _done


## 启动。center = 角色世界坐标；host = 战场根
func play(center: Vector2, host: Node) -> void:
	_center = center
	_host = host
	_cam = host.get("cam")
	_juice = host.get("juice")
	_ensure_assets()

	# 世界层：Terrain(0) < 本层(1) < 角色 int(y)≈420~600 < Foreground(4000)
	z_index = 1

	_beast_root = Node2D.new()
	_beast_root.name = "Beast"
	# ★ 兽夹在「地形之上、角色之下」→ 角色永远完整可见，同时看得清敌人被冲飞
	_beast_root.z_index = 395
	_beast_root.visible = false
	add_child(_beast_root)

	_bolt_root = Node2D.new()
	_bolt_root.name = "Bolts"
	_bolt_root.z_index = 396
	_bolt_root.visible = false
	add_child(_bolt_root)

	_build_seal()
	_build_title(host)
	_build_line(host)
	_build_shout(host)
	set_process(true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


# ============================================================
#  时间轴
# ============================================================
func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _phase == 0:
		_update_seal()
		if _t >= SEAL_END:
			_enter_beast()
	elif _phase == 1:
		_update_beast()
		if _t >= BEAST_END:
			_enter_settle()
	elif _phase == 2:
		if _t >= DURATION:
			_finish()


# ============================================================
#  ① 结印
# ============================================================
func _build_seal() -> void:
	# ★ 尺寸一律按「贴图宽 2048px」基准（见 _glow 注释）：
	#   sx=0.25 → 512px 宽，sy=0.063 → 129px 高
	_seal_glow = _glow("glow", _center + Vector2(0, 10), 0.25, 0.063, 0)
	_seal_glow.modulate = color_main
	_seal_ring = _glow("ring", _center + Vector2(0, 10), 0.15, 0.034, 1)
	_seal_ring.modulate = color_light
	# 大环：从屏幕外收进来（"能量汇聚"）→ 1500×350
	_seal_big_ring = _glow("ring", _center + Vector2(0, 10), 0.73, 0.17, 1)
	_seal_big_ring.modulate = Color(color_main.r, color_main.g, color_main.b, 0.55)
	# 符文光点向角色收束
	_seal_runes = Node2D.new()
	_seal_runes.position = _center + Vector2(0, -110)
	_seal_runes.z_index = 4
	add_child(_seal_runes)
	for i in 10:
		var a: float = TAU * float(i) / 10.0
		var sp := _glow("spark", Vector2(cos(a) * 280.0, sin(a) * 120.0),
				0.028, 0.028, 4, _seal_runes)
		sp.modulate = color_light
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(sp, "position", Vector2.ZERO, SEAL_END) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(sp, "scale", sp.scale * 0.16, SEAL_END)
	_spawn_portrait()
	_build_seal_hands()
	Sfx.play("levelup", 1.25, -4.0)


func _update_seal() -> void:
	var k: float = clampf(_t / SEAL_END, 0.0, 1.0)
	var g: float = sin(k * PI) * 1.15 + 0.25
	if _seal_glow != null and is_instance_valid(_seal_glow):
		var b := Vector2(0.25, 0.063)
		_seal_glow.scale = Vector2(b.x * g, b.y * g)
		_seal_glow.modulate.a = 0.45 + 0.5 * k
	if _seal_ring != null and is_instance_valid(_seal_ring):
		var rs: float = lerp(1.0, 0.26, k)
		_seal_ring.scale = Vector2(0.15 * rs, 0.034 * rs)
		_seal_ring.modulate.a = 0.35 + 0.6 * k
	if _seal_big_ring != null and is_instance_valid(_seal_big_ring):
		var bs: float = lerp(1.0, 0.21, k)
		_seal_big_ring.scale = Vector2(0.73 * bs, 0.17 * bs)
		_seal_big_ring.modulate.a = (1.0 - k) * 0.7
	if _seal_runes != null and is_instance_valid(_seal_runes):
		_seal_runes.rotation += 0.024
		var ss: float = lerp(1.0, 0.5, k)
		_seal_runes.scale = Vector2(ss, ss)


## 大招插画定格：人物"变身"成具体图像，从角色身上炸开→回弹→停留→消散
func _spawn_portrait() -> void:
	# ★ 优先用「不规则镂空版」插画（assets/fx/ult/cutin_<id>.png）：
	#   原图 assets/heroes/<id>/ult.png 是 1024×576 满幅不透明插画，
	#   贴上去就是"一张方照片"，正是用户说的"图片感明显"。
	#   cutin_ 版已把四缘打散成絮状透明度，中央还保留人物造型。
	var tex: Texture2D = null
	for p in ["%scutin_%s.png" % [FX_DIR, hero_id],
			"res://assets/heroes/%s/ult.png" % hero_id]:
		if not ResourceLoader.exists(p):
			continue
		var tt = load(p)
		if tt is Texture2D:
			tex = tt
			break
	if tex == null:
		return
	var sp := Sprite2D.new()
	sp.texture = tex
	var k: float = CUTIN_W / maxf(1.0, float(tex.get_width()))
	sp.scale = Vector2(k * 0.30, k * 0.06)
	# ★★ 必须落在角色身上：曾漏加 _center → 插画跑到世界原点，
	#    在屏幕外，整个"结印定格"等于没做（真 bug，已修）。
	sp.position = _center + Vector2(0, -186)
	# z=900：盖住角色与敌人（int(y)≈420~600），但低于 Foreground(4000)
	sp.z_index = 900
	sp.modulate = Color(1, 1, 1, 0)
	add_child(sp)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(sp, "modulate:a", 1.0, 0.12)
	t.tween_property(sp, "scale", Vector2(k, k), 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.60)
	t.chain().tween_property(sp, "modulate:a", 0.0, 0.26)
	t.chain().tween_property(sp, "scale", Vector2(k * 1.14, k * 1.14), 0.26)
	t.chain().tween_callback(sp.queue_free)


## ★ 结印：角色身前依次闪出三道掌印光轮
##   （用户：「他发特效肯定需要有一个东西出来，就像火影忍者需要提前结印」）
func _build_seal_hands() -> void:
	for i in 3:
		var sp := _glow("ring", _center + Vector2(-40.0 + float(i) * 40.0, -104.0),
				0.055, 0.018, 60)
		sp.modulate = Color(color_light.r, color_light.g, color_light.b, 0.0)
		var t := create_tween()
		t.tween_interval(0.12 + float(i) * 0.19)
		t.set_parallel(true)
		t.tween_property(sp, "modulate:a", 1.0, 0.06)
		t.tween_property(sp, "scale", sp.scale * 1.7, 0.28)
		t.tween_property(sp, "rotation", 0.95, 0.28)
		t.chain().tween_property(sp, "modulate:a", 0.0, 0.18)
		t.chain().tween_callback(sp.queue_free)


# ============================================================
#  ② 兽暴
# ============================================================
func _enter_beast() -> void:
	_phase = 1
	if _seal_runes != null and is_instance_valid(_seal_runes):
		_seal_runes.queue_free()
	for n in [_seal_ring, _seal_big_ring]:
		if n != null and is_instance_valid(n):
			var tt := create_tween()
			tt.tween_property(n, "modulate:a", 0.0, 0.2)
			tt.tween_callback(n.queue_free)
	_beast_root.visible = true
	# ★ 压制亮度：ADD 混合会直接把素材亮度加到背景上，
	#   火焰/闪电这类高亮素材不压会整屏冲白（雷系尤甚）。0.78 保住细节与背景层次。
	_beast_root.modulate = Color(0.78, 0.78, 0.78, 1.0)
	_bolt_root.visible = true
	# 起爆演出：闪白 + 强震 + 推镜 + 速度线
	if _juice != null and _juice.has_method("flash"):
		_juice.flash(Color(1, 1, 1).lerp(color_main, 0.30), 0.34)
	if _host != null and _host.has_method("_shake"):
		_host._shake(1.7)
	if _juice != null and _juice.has_method("zoom_punch"):
		_juice.zoom_punch(0.10, 0.9)
	Sfx.play("crit", 0.9, 2.0)
	_build_speedlines()
	_build_beast()
	_build_trail()


## ★ v3 元素拖尾：兽身后掉落的元素粒子（火星/水珠/叶片/岩屑/电芒/金屑）
##    local_coords=false → 粒子留在世界坐标里，兽飞走后自然拖出尾迹；
##    重力按系不同（火星上飘、水珠下坠、岩屑砸落），像真的元素散落。
func _build_trail() -> void:
	_trail = CPUParticles2D.new()
	_trail.amount = 72
	_trail.lifetime = 0.70
	_trail.local_coords = false          # ★ 世界坐标：兽走了粒子留在原地
	_trail.texture = _TEX.get("glow")
	if _trail.texture == null:
		_trail.texture = _fallback_tex("glow")
	_trail.material = _MAT_ADD
	match hero_id:
		"huo":  _trail.gravity = Vector2(0, -190)   # 火星上飘
		"shui": _trail.gravity = Vector2(0, 260)    # 水珠下坠
		"mu":   _trail.gravity = Vector2(0, 120)    # 叶片缓落
		"tu":   _trail.gravity = Vector2(0, 320)    # 岩屑砸落
		"lei":  _trail.gravity = Vector2(0, 80)     # 电芒轻坠
		_:      _trail.gravity = Vector2(0, 40)
	_trail.direction = Vector2(-1, 0)    # 朝兽行进的反方向甩出
	_trail.spread = 28.0
	_trail.initial_velocity_min = 80.0
	_trail.initial_velocity_max = 230.0
	_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_trail.emission_rect_extents = Vector2(430, 120)   # 沿兽身随机冒出
	_trail.scale_amount_min = 0.03
	_trail.scale_amount_max = 0.09
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.85))
	ramp.set_color(1, Color(color_main.r, color_main.g, color_main.b, 0.0))
	_trail.color_ramp = ramp
	_trail.z_index = -1                  # 兽身之下、地形之上
	_beast_root.add_child(_trail)


func _update_beast() -> void:
	_beast_progress = clampf((_t - BEAST_START) / (BEAST_END - BEAST_START), 0.0, 1.0)
	var sp := _serpentine(_beast_progress)
	_beast_root.position = _beast_pos(_beast_progress)
	# ★ v3 生物感：随游动路径的斜率轻微"点头"（俯仰角跟蛇形波的导数走）
	_beast_root.rotation = sp.y
	_deform_slices()
	if hero_id == "lei":
		_update_bolts()
	# ★★ 进出场淡入淡出（消除"方方正正有边界"的关键）
	#    素材再怎么羽化，贴图的**外接矩形**在刚进场那一瞬仍是硬边。
	#    让 alpha 从 0 升到 1、再从 1 落到 0，直边就永远处在"看不见"的透明里。
	var a := 1.0
	if _beast_progress < 0.14:
		a = smoothstep(0.0, 0.14, _beast_progress)
	elif _beast_progress > 0.82:
		a = 1.0 - smoothstep(0.82, 1.0, _beast_progress)
	_beast_root.modulate.a = a
	_bolt_root.modulate.a = a
	_emit_hits()


## ★ v3 蛇形游动：路径本身是波浪线（不再是匀速直线平移）
##    返回 x = 纵向偏移(px)，y = 俯仰角(rad，取波形导数方向)
##    各系幅/频不同：火龙大幅蛇形、水浪起伏、岩山贴地微颠、雷电急颤
func _serpentine(th: float) -> Vector2:
	var amp := 20.0
	var freq := 1.6
	match hero_id:
		"huo":  amp = 52.0; freq = 2.1     # 火龙：大幅蛇形
		"shui": amp = 34.0; freq = 1.5     # 浪：起伏翻卷
		"jin":  amp = 15.0; freq = 2.8     # 剑气：小幅疾摆
		"mu":   amp = 26.0; freq = 1.1     # 藤蔓：缓缓摇曳
		"tu":   amp = 7.0;  freq = 1.9     # 岩山：贴地微颠
		"lei":  amp = 12.0; freq = 3.4     # 雷：急促颤动
	# 起终点收敛到 0，避免进出场时"跳"上波浪线
	var env := smoothstep(0.0, 0.10, th) * (1.0 - smoothstep(0.90, 1.0, th))
	var ph: float = th * TAU * freq
	return Vector2(sin(ph) * amp * env, cos(ph) * amp * 0.0022 * env)


## 兽首在各进度点的世界坐标：从屏幕左外 → 右外（横扫整屏）
## ★ 外扩 560（scale 0.52 → 半宽 533）：保证兽完全离开屏幕后才换场，
##   配合进出场淡入淡出，任何一帧都不会露出贴图的外接矩形。
## ★ v3 速度曲线：起手加速 → 中段近匀速 → 收尾减速（生物不是匀速平移），
##   与蛇形起伏叠加后就是"游过去"而不是"滑过去"。_emit_hits 走同一入口，
##   命中位置自动跟随新路径。
func _beast_pos(th: float) -> Vector2:
	var x0: float = _view_left() - 560.0
	var x1: float = _view_right() + 560.0
	var e: float = th * th * (3.0 - 2.0 * th)
	var x: float = lerpf(lerp(x0, x1, th), lerp(x0, x1, e), 0.55)
	return Vector2(x, _center.y + _beast_y_off() + _serpentine(th).x)


## 兽的纵向偏移（相对角色脚下）—— GDScript 无函数重载，按 hero_id 分派
func _beast_y_off() -> float:
	match hero_id:
		"tu":   return 40.0       # 土：贴着地面
		"huo":  return -170.0     # 火：半空游动
		"lei":  return -290.0     # 雷：天上
		"jin":  return -160.0     # 金：齐胸
		"mu":   return -80.0      # 木：从地里长出来
		_:      return -70.0      # 水：浪头居中偏下


## ★ 兽的显示尺寸（重要，改错就"糊屏"或"像一张图"）：
##   素材 2048×878，屏幕 1280×720。
##   ⚠️ 曾用 0.68（宽 1393px > 屏宽 1280px）→ **兽比屏幕还宽**，
##      平移时看到的就是"一整块贴图在滑"，正是用户说的"图片感明显"。
##   0.52 → 宽 1065px（占屏宽 83%，两端各留 ~107px 空白）
##          高 456px（占屏高 63%）
##      → 屏幕上就是"一条兽横空飞过"，而不是"一块矩形发光体"。
##   雷系靠 _update_bolts() 的程序化落雷铺满全屏，兽本身再小也没关系。
func _beast_scale() -> float:
	return _beast_scale_for(hero_id)


## 各系微调
func _beast_scale_for(hid: String) -> float:
	match hid:
		"lei":  return 0.46       # 雷素材是"均匀铺满型"，缩到最小，靠程序化落雷补全屏
		"jin":  return 0.54       # 剑气本身是细长条，稍长
		"tu":   return 0.56       # 岩山要厚实
		"shui": return 0.54       # 浪墙要够高
		_:      return 0.52


## ★ 素材主体朝向修正：兽统一从左往右飞，龙头朝左的素材需要翻转
func _beast_flip() -> bool:
	match hero_id:
		"huo":  return true      # 火龙素材龙头在左 → 翻转让它朝右飞
		_:      return false     # 其余素材无方向性或方向已正确（浪头朝右）


func _view_left() -> float:
	if _cam != null:
		return _cam.position.x - 640.0
	return _center.x - 640.0


func _view_right() -> float:
	if _cam != null:
		return _cam.position.x + 640.0
	return _center.x + 640.0


func _emit_hits() -> void:
	var steps := 12
	for i in range(_hit_marks.size(), steps):
		var th: float = float(i) / float(steps - 1)
		if _beast_progress < th:
			break
		_hit_marks.append(i)
		var pos := _beast_pos(th)
		var dmg: int = 34 + int(round(26.0 * th))
		var knock: float = 160.0 + 280.0 * th
		emit_signal("beast_hit", pos, 620.0, dmg, knock)


# ============================================================
#  ③ 收场
# ============================================================
func _enter_settle() -> void:
	_phase = 2
	if _host != null and _host.has_method("_shake"):
		_host._shake(0.9)
	if _juice != null and _juice.has_method("flash"):
		_juice.flash(color_main, 0.30)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.55)


# ============================================================
#  ★ 核心一：切片行波形变（让素材真的"游动"）
# ============================================================
func _beast_tex_name() -> String:
	return "beast_" + hero_id


func _build_beast() -> void:
	var tex: Texture2D = _TEX.get(_beast_tex_name())
	if tex == null:
		tex = _TEX.get("glow")
	if tex == null:
		tex = _fallback_tex("glow")
	_beast_sprite = Sprite2D.new()
	_beast_sprite.texture = tex
	_beast_sprite.centered = true
	# ★ 兽 0.52 倍缩小显示——不开 mipmap 在 nearest 全局过滤下会出摩尔纹
	_beast_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# ★ 用 shader 做行波形变（逐像素 → 无竖缝，比"切片 Sprite"顺滑得多）
	var sh: Shader = null
	var p := "res://assets/fx/ult/beast_wave.gdshader"
	if ResourceLoader.exists(p):
		sh = load(p)
	if sh != null:
		_beast_shader = ShaderMaterial.new()
		_beast_shader.shader = sh
		_beast_sprite.material = _beast_shader
	else:
		_beast_sprite.material = _MAT_ADD       # 兜底：至少是发光叠加
	_beast_root.add_child(_beast_sprite)


## ★ 行波形变驱动：只需更新 shader 的 uniform（逐像素计算在 GPU 里做）
func _deform_slices() -> void:
	if _beast_sprite == null or not is_instance_valid(_beast_sprite):
		return
	# 尺寸：按屏幕宽度铺开，保证横贯全屏
	# ★ v3 呼吸脉动：±1.2% 慢速缩放，破除"静态贴图平移"的最后残留
	var breathe: float = 1.0 + sin(_t * 6.0) * 0.012
	_beast_sprite.scale = Vector2(_beast_scale(), _beast_scale()) * breathe
	# ★ 朝向：兽一律「从左往右」横扫，凡素材自身主体朝左的必须水平翻转，
	#   否则会变成"龙头朝后倒着飞"（火龙的龙头在素材左侧，必须翻）。
	_beast_sprite.flip_h = _beast_flip()
	if _beast_shader == null:
		return
	var tt: float = _t - BEAST_START
	var f := 6.0
	var amp := 0.055
	var phi := 0.50
	var drift := 0.0
	var jitter := 0.0
	var twist := 0.06                 # ★ 身体扭转量（v3 新增，生物感）
	match hero_id:
		"jin":  f = 11.0; amp = 0.030; phi = 0.30; twist = 0.03   # 剑：高频小幅，锐利
		"mu":   f = 3.4;  amp = 0.045; phi = 0.40; drift = -0.02; twist = 0.10  # 木：低频摇曳
		"shui": f = 4.6;  amp = 0.080; phi = 0.54; twist = 0.12   # 水：大幅翻滚
		"huo":  f = 6.8;  amp = 0.070; phi = 0.50; drift = 0.10; twist = 0.14   # 火龙：蛇形扭身
		"tu":   f = 9.0;  amp = 0.014; phi = 0.22; jitter = 0.004; twist = 0.0 # 土：刚性
		"lei":  f = 16.0; amp = 0.022; phi = 0.70; jitter = 0.010; twist = 0.02 # 雷：乱抖
	_beast_shader.set_shader_parameter("u_t", tt)
	_beast_shader.set_shader_parameter("u_f", f)
	_beast_shader.set_shader_parameter("u_amp", amp)
	_beast_shader.set_shader_parameter("u_phi", phi * float(6))
	_beast_shader.set_shader_parameter("u_drift", drift)
	_beast_shader.set_shader_parameter("u_jitter", jitter)
	_beast_shader.set_shader_parameter("u_twist", twist)
	_beast_shader.set_shader_parameter("u_grow", clampf(tt / 0.24, 0.0, 1.0))


# ============================================================
#  雷系额外：全屏落雷 ★ 真素材版（Agnes 实拍质感闪电）
# ============================================================
## 每道雷 = 一张真实闪电竖条（3 形态随机 + 随机镜像），从天顶劈到地面。
## 不再逐帧重建：0.07s 换一批 → 自然频闪（60fps 全随机会太乱）。
var _bolt_last := -1.0

func _update_bolts() -> void:
	if _bolt_last >= 0.0 and _t - _bolt_last < 0.07:
		return
	_bolt_last = _t
	for c in _bolt_root.get_children():
		c.queue_free()
	var l: float = _view_left() - _beast_root.position.x
	var w: float = (_view_right() - _view_left())
	var ground_y: float = _center.y + 40.0 - _beast_root.position.y
	var n: int = 7
	for i in n:
		var x: float = l + w * (float(i) + randf_range(0.12, 0.88)) / float(n)
		_spawn_bolt(x, ground_y)
		# 落点爆光：sx 0.08 → 164px，0.16 → 328px
		var hit := _glow("glow", Vector2(x, ground_y), randf_range(0.08, 0.16),
				randf_range(0.032, 0.062), 0, _bolt_root)
		hit.modulate = Color(1, 1, 1).lerp(color_main, 0.35)


## 一道真闪电：竖条素材从 y=0（天顶）铺到 ground_y（地面）
func _spawn_bolt(x: float, ground_y: float) -> void:
	var tex: Texture2D = _TEX.get("bolt_%d" % (randi() % 3 + 1))
	if tex == null:
		return
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.material = _MAT_ADD
	sp.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.flip_h = randf() < 0.5
	var th: float = maxf(1.0, float(tex.get_height()))
	var k: float = ground_y / th                 # 高度精确铺到地面
	var kw: float = k * randf_range(0.8, 1.3)    # 宽度随机 → 粗细不一
	sp.scale = Vector2(kw, k)
	# centered=false：素材顶边贴天顶
	sp.centered = false
	sp.position = Vector2(x - float(tex.get_width()) * kw * 0.5, 0.0)
	sp.z_index = 1
	_bolt_root.add_child(sp)


# ============================================================
#  起手速度线（全屏放射收束）
# ============================================================
func _build_speedlines() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var cl := CanvasLayer.new()
	cl.layer = 38
	cl.name = "UltSpeed"
	_host.add_child(cl)
	# ★ 真素材版：一整张「漫画放射集中线」（Agnes 生成）铺满全屏，
	#   从外向内收束（scale 1.55 → 0.80）+ 先亮后隐 —— 电影冲击帧质感。
	#   替代旧版 26 条拉伸光条（streak 拉长 = "绿线紫线"感）。
	var tex: Texture2D = _TEX.get("speedlines")
	if tex == null:
		return
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.material = _MAT_ADD
	sp.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.position = Vector2(640.0, 360.0)
	var base: float = 1280.0 / maxf(1.0, float(tex.get_width()))   # 0.625 → 恰好 1280×720
	sp.scale = Vector2(base * 1.55, base * 1.55)
	sp.modulate = Color(color_light.r, color_light.g, color_light.b, 0.0)
	cl.add_child(sp)
	var t: Tween = cl.create_tween()
	t.set_parallel(true)
	t.tween_property(sp, "modulate:a", 0.85, 0.10)
	t.tween_property(sp, "scale", Vector2(base * 0.80, base * 0.80), 0.42) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_property(sp, "modulate:a", 0.0, 0.26)
	t.chain().tween_callback(cl.queue_free)


# ============================================================
#  屏幕层：招式名 + 台词
# ============================================================
func _build_title(host: Node) -> void:
	# ★ 位置：招式名横幅占 96~152，喊话字幕占 190~268（_build_shout），
	#   两者错开，不打架。
	var old := host.get_node_or_null("UltTitle")
	if old != null:
		old.queue_free()
	var cl := CanvasLayer.new()
	cl.layer = 40
	cl.name = "UltTitle"
	host.add_child(cl)
	for k in 2:
		var line := ColorRect.new()
		line.color = Color(color_main.r, color_main.g, color_main.b, 0.0)
		line.set_anchors_preset(Control.PRESET_TOP_WIDE)
		line.offset_top = 96.0 + k * 56.0
		line.offset_bottom = 99.0 + k * 56.0
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(line)
		var lt0: Tween = cl.create_tween()
		lt0.tween_property(line, "color:a", 0.9, 0.14)
		lt0.tween_interval(1.85)
		lt0.tween_property(line, "color:a", 0.0, 0.44)
		lt0.tween_callback(line.queue_free)
	var band := ColorRect.new()
	band.color = Color(color_deep.r, color_deep.g, color_deep.b, 0.0)
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.offset_top = 88.0
	band.offset_bottom = 164.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(band)
	var t := cl.create_tween()
	t.tween_property(band, "color:a", 0.16, 0.14)
	t.tween_interval(1.87)
	t.tween_property(band, "color:a", 0.0, 0.44)
	t.tween_callback(band.queue_free)
	var lab := Label.new()
	lab.text = "%s · %s" % [hero_name, ult_name]
	lab.add_theme_font_size_override("font_size", 54)
	lab.add_theme_color_override("font_color", Color(1, 1, 0.94))
	lab.add_theme_color_override("font_outline_color", color_deep * 0.42)
	lab.add_theme_constant_override("outline_size", 12)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lab.offset_top = 92.0
	lab.offset_bottom = 152.0
	lab.pivot_offset = Vector2(640, 30)
	lab.scale = Vector2(1.55, 0.58)
	lab.modulate.a = 0.0
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(lab)
	var lt: Tween = cl.create_tween()
	lt.set_parallel(true)
	lt.tween_property(lab, "modulate:a", 1.0, 0.10)
	lt.tween_property(lab, "scale", Vector2(1.0, 1.0), 0.26) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.chain().tween_interval(1.72)
	lt.chain().tween_property(lab, "modulate:a", 0.0, 0.40)
	lt.chain().tween_property(lab, "offset_top", 64.0, 0.40)
	lt.chain().tween_callback(lab.queue_free)


func _build_line(host: Node) -> void:
	if ult_line == "" or host == null or not is_instance_valid(host):
		return
	var cl := CanvasLayer.new()
	cl.layer = 39
	cl.name = "UltLine"
	host.add_child(cl)
	var lab := Label.new()
	lab.text = "「%s」" % ult_line
	lab.add_theme_font_size_override("font_size", 30)
	lab.add_theme_color_override("font_color", Color(1, 0.98, 0.90))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lab.add_theme_constant_override("outline_size", 9)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lab.offset_top = -186.0
	lab.offset_bottom = -140.0
	lab.pivot_offset = Vector2(640, 23)
	lab.scale = Vector2(1.0, 0.72)
	lab.modulate.a = 0.0
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(lab)
	# ★ 台词位置：曾直接把 position.y 写成 26，等于把 anchor 布局顶掉，
	#   结果台词跑到屏幕最顶端、被血条盖住。改用 pivot + scale 做"从下弹入"。
	var t := cl.create_tween()
	t.set_parallel(true)
	t.tween_property(lab, "modulate:a", 1.0, 0.30)
	t.tween_property(lab, "scale", Vector2(1.0, 1.0), 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(1.55)
	t.chain().tween_property(lab, "modulate:a", 0.0, 0.40)
	t.chain().tween_callback(cl.queue_free)


# ============================================================
#  屏幕层：角色「喊」出台词（★ 带语音 + 爆喝字放大）
# ============================================================
## 用户需求：「人物要动起来……可以摆一个造型，或者有一句台词」
## 台词语法：「焚！焚天烈焰！」= 爆喝字 + 招式名。
## 显示时把爆喝字**放大 + 换色 + 加粗描边**、单独弹一下，
## 再把招式名接着推出来 —— 就是漫画里"喊招"的节奏感。
func _build_shout(host: Node) -> void:
	if shout_line == "" or host == null or not is_instance_valid(host):
		return
	var cl := CanvasLayer.new()
	cl.layer = 41
	cl.name = "UltShout"
	host.add_child(cl)

	# 拆「爆喝字」与「招式名」
	var burst := shout_line
	var rest := ""
	var ix := shout_line.find("！")
	if ix >= 0:
		burst = shout_line.substr(0, ix)
		rest = shout_line.substr(ix + 1)

	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = 190.0
	box.offset_bottom = 268.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.pivot_offset = Vector2(640, 39)
	box.modulate.a = 0.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(box)

	# 爆喝字：大一号、亮色、厚描边
	var lb := Label.new()
	lb.text = burst
	lb.add_theme_font_size_override("font_size", 62)
	lb.add_theme_color_override("font_color", Color(1, 0.98, 0.80))
	lb.add_theme_color_override("font_outline_color", color_deep * 0.28)
	lb.add_theme_constant_override("outline_size", 18)
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lb)

	# 招式名：正文字号
	var lr := Label.new()
	lr.text = rest
	lr.add_theme_font_size_override("font_size", 44)
	lr.add_theme_color_override("font_color", Color(1, 1, 0.94))
	lr.add_theme_color_override("font_outline_color", color_deep * 0.35)
	lr.add_theme_constant_override("outline_size", 13)
	lr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lr)

	# 语音：先试角色专属喊话，缺文件就静默（只显示字幕，不影响演出）
	if Sfx.has_method("shout_ult"):
		Sfx.shout_ult(shout_line)

	# 节奏：整块弹入 → 爆喝字再震一下 → 停留 → 淡出放大
	var t := cl.create_tween()
	t.set_parallel(true)
	t.tween_property(box, "modulate:a", 1.0, 0.10)
	t.tween_property(box, "scale", Vector2(1.10, 1.10), 0.20) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(box, "scale", Vector2(1.0, 1.0), 0.13)
	# 爆喝字单独"炸"一下（时间与语音里的爆喝对齐）
	t.chain().tween_property(lb, "scale", Vector2(1.34, 1.34), 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(lb, "scale", Vector2(1.0, 1.0), 0.16)
	t.chain().tween_interval(1.10)
	t.chain().tween_property(box, "modulate:a", 0.0, 0.32)
	t.chain().tween_property(box, "scale", Vector2(1.22, 1.22), 0.32)
	t.chain().tween_callback(cl.queue_free)


# ============================================================
#  资源
# ============================================================
func _ensure_assets() -> void:
	if _MAT_ADD == null:
		_MAT_ADD = CanvasItemMaterial.new()
		_MAT_ADD.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for nm in ["beast_jin", "beast_mu", "beast_shui", "beast_huo", "beast_tu",
			"beast_lei", "ring", "glow", "spark", "streak",
			"bolt_1", "bolt_2", "bolt_3", "speedlines"]:
		if _TEX.has(nm):
			continue
		var p: String = "%s%s.png" % [FX_DIR, nm]
		if ResourceLoader.exists(p):
			var tx = load(p)
			if tx is Texture2D:
				_TEX[nm] = tx
	# ★ ring / glow 现在由 gen_glow_ring.py 程序化生成为 1024×1024 正方形。
	#   旧版是 Agnes 出的 2048×878 横长条，按 (sx,sy) 缩放时会拉成"巨大椭圆光团"
	#   （雷系落点爆光尤其难看）。若贴图仍是非正方形（旧资源），强制换成
	#   程序化圆形兜底，保证光斑永远是圆的。
	for nm in ["ring", "glow"]:
		var t2: Texture2D = _TEX.get(nm)
		if t2 == null or float(t2.get_width()) != float(t2.get_height()):
			_TEX.erase(nm)   # 删掉，走 _fallback_tex 的圆形兜底


## 造一个 ADD 光效 Sprite。素材缺失时走程序化兜底
##
## ★ 尺寸基准统一（重要）：sx/sy 一律按「贴图宽 = 2048px」为基准换算。
##   否则素材贴图（2048/1024px）与程序化兜底贴图（256px）尺寸差 8 倍，
##   同一个 sx 会得到完全不同的光斑大小 —— 素材一缺就炸。
func _glow(nm: String, pos: Vector2, sx: float, sy: float, z: int,
		parent: Node = null) -> Sprite2D:
	var sp := Sprite2D.new()
	var tex: Texture2D = _TEX.get(nm)
	if tex == null:
		tex = _fallback_tex(nm)
	sp.texture = tex
	sp.material = _MAT_ADD
	# ★ 光效贴图大幅缩放（ring 压到 0.22 倍）——全局 nearest 过滤下
	#   采样跳格 = 齿轮状锯齿（用户说的"像素化方块"）。局部覆盖为
	#   线性+mipmap：缩小平滑、不糊、不影响游戏其他部分的像素风设置。
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.position = pos
	var nw: float = 2048.0 / maxf(1.0, float(tex.get_width()))
	sp.scale = Vector2(sx * nw, sy * nw)
	sp.z_index = z
	if parent != null:
		parent.add_child(sp)
	else:
		add_child(sp)
	return sp


## 程序化兜底贴图（素材缺失时也不至于什么都看不见）
func _fallback_tex(kind: String) -> Texture2D:
	if _FB.has(kind):
		return _FB[kind]
	var g := Gradient.new()
	match kind:
		"ring":
			g.set_color(0, Color(1, 1, 1, 0))
			g.add_point(0.62, Color(1, 1, 1, 0.18))
			g.add_point(0.86, Color(1, 1, 1, 0.95))
			g.set_color(1, Color(1, 1, 1, 0))
		_:
			g.set_color(0, Color(1, 1, 1, 1))
			g.add_point(0.30, Color(1, 1, 1, 0.45))
			g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 512
	t.height = 512
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_FB[kind] = t
	return t


func _finish() -> void:
	if _done:
		return
	_done = true
	emit_signal("finished")
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_callback(queue_free)

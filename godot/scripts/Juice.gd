extends Node2D
## 打击感与特效库 —— 集中管理所有「手感」相关的视觉反馈
##
## 为什么单独成文件：Battle.gd 已经 900+ 行，特效再塞进去就维护不动了。
## 这里只做「视觉反馈」，不含任何游戏逻辑（伤害计算、胜负判定仍在 Battle）。
##
## 用法：Battle 里 juice.setup(cam, fx_root, self) 后按事件调用：
##   juice.shake(1.2, dir)              受击震屏（带方向感）
##   juice.damage_number(pos, 42, true) 伤害飘字
##   juice.pickup_beam(pos, col)        拾字冲天光柱
##   juice.ult_burst(pos, cols)         大招全屏爆发
##   juice.flash_red(0.5)               受伤红屏
##   juice.celebrate()                  过关烟花
##   juice.boss_entrance(name)          BOSS 登场演出
##   juice.debris(pos, col)             打碎木箱的木屑

var cam: Camera2D
var fx: Node2D
var host: Node                    # Battle 节点（用来 create_tween）

# ---- ★ 真实特效贴图（Agnes 生成，纯黑底/带 alpha）----
# 命中火花、暴击环、拾字光柱、飘落竹叶全部用真素材，告别方块粒子与线框
var _tex_glow: Texture2D
var _tex_ring: Texture2D
var _tex_leaf: Texture2D
var _tex_streak: Texture2D
var _mat_add: CanvasItemMaterial

func _fx_tex(nm: String) -> Texture2D:
	var p := "res://assets/fx/ult/%s.png" % nm
	if ResourceLoader.exists(p):
		var r = load(p)
		if r is Texture2D:
			return r
	return null

func _fx_add() -> CanvasItemMaterial:
	if _mat_add == null:
		_mat_add = CanvasItemMaterial.new()
		_mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _mat_add

# ---- 震屏状态（每帧驱动，比 tween 更有"连续撞击"的实感）----
var _shake_p := 0.0
var _shake_dir := Vector2.ZERO
var _shake_ph := 0.0
## ★ 演出平滑模式：穿梭特招（幻影接力）连打 3 段，每段都可能有爆炸/踩踏等
##   别处的震屏调用叠加进来 → 整屏剧烈抖动（用户反馈「画面非常抖动」）。
##   为 true 时把所有震屏幅度钳到 0.22 以内，让长演出在稳定构图里播完。
var calm := false

# ---- 镜头拉近 ----
var _zoom_base := Vector2.ONE
var _zoom_t := 0.0
var _zoom_amt := 0.0
var _zoom_dur := 0.0

# ---- 红屏 ----
var _red: ColorRect
var _red_t := 0.0
var _red_a := 0.0
var _red_hold := 0.0

var _rng := RandomNumberGenerator.new()


func setup(p_cam: Camera2D, p_fx: Node2D, p_host: Node) -> void:
	cam = p_cam
	fx = p_fx
	host = p_host
	if cam != null:
		_zoom_base = cam.zoom
	_rng.randomize()
	# 红屏遮罩延迟到第一次用到时再建（_ensure_red），避免开场就占用节点


# ============================================================
#  ① 战斗打击感
# ============================================================
## 受击震屏。dir = 冲击方向（攻击来自哪边就往反方向推）
func shake(power: float, dir: Vector2 = Vector2.ZERO) -> void:
	# ★ 长演出期间（穿梭接力）全局压平震屏，防止多来源震动叠加成"抖屏"
	if calm:
		power = minf(power, 0.22 / 3.8)     # 3.8 是 Battle._shake 的放大系数
	_shake_p = max(_shake_p, power)
	if dir.length_squared() > 0.01:
		_shake_dir = dir.normalized()


## 伤害飘字：弹出 → 上飘 → 淡出；暴击更大更金
func damage_number(pos: Vector2, dmg: int, crit: bool) -> void:
	var l := Label.new()
	l.text = ("%d!" % dmg) if crit else str(dmg)
	l.add_theme_font_size_override("font_size", 54 if crit else 34)
	l.add_theme_color_override("font_color", Color("#ffd23c") if crit else Color("#fff0b0"))
	l.add_theme_color_override("font_outline_color", Color("#5a2a00"))
	l.add_theme_constant_override("outline_size", 8 if crit else 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 980
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jitter := _rng.randf_range(-16.0, 16.0)
	l.position = pos + Vector2(jitter, 0)
	l.pivot_offset = Vector2(24, 22)
	l.scale = Vector2(0.45, 0.45)
	fx.add_child(l)

	var t1 := host.create_tween()
	t1.tween_property(l, "scale", Vector2(1.42, 1.42) if crit else Vector2(1.14, 1.14), 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t1.tween_property(l, "scale", Vector2.ONE, 0.11)

	var t2 := host.create_tween()
	t2.set_parallel(true)
	t2.tween_property(l, "position", pos + Vector2(jitter, -98.0 if crit else -76.0), 0.62) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t2.tween_property(l, "modulate:a", 0.0, 0.40).set_delay(0.24)
	t2.chain().tween_callback(l.queue_free)


## 命中火花（比原版更大、更有方向感）
func impact(pos: Vector2, col: Color, crit: bool, dir: Vector2) -> void:
	var n := 28 if crit else 16
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = 0.5
	p.spread = 62.0
	p.direction = dir.normalized() if dir.length_squared() > 0.01 else Vector2(1, 0)
	p.initial_velocity_min = 190.0 if crit else 130.0
	p.initial_velocity_max = 520.0 if crit else 330.0
	p.gravity = Vector2(0, 560)
	# ★ 真实光点贴图（glow 1024²）： Formerly 无贴图=白色方块粒子
	if _tex_glow == null:
		_tex_glow = _fx_tex("glow")
	p.texture = _tex_glow
	# scale 是贴图像素倍率：0.012~0.04 → 火花 12~40px
	p.scale_amount_min = 0.012
	p.scale_amount_max = 0.040 if crit else 0.028
	p.color = col
	p.material = _fx_add()          # 加色混合：光点叠加自然发亮
	p.z_index = 940
	fx.add_child(p)
	var t := host.create_tween()
	t.tween_interval(0.95)
	t.tween_callback(p.queue_free)
	if crit:
		_ring(pos, col, 26.0, 3.4, 0.34)


## 连击弹出：数字越大颜色越"烫"
func combo_color(n: int) -> Color:
	if n >= 20:
		return Color("#ff4d4d")
	if n >= 12:
		return Color("#ff8a3c")
	if n >= 6:
		return Color("#ffd23c")
	return Color("#fff0b0")


# ============================================================
#  ② 拾字 / 大招 华丽度
# ============================================================
## 拾字：一道冲天光柱 + 上升光点 ★ 真素材版（streak 拉竖 = 柔光光柱）
func pickup_beam(pos: Vector2, col: Color) -> void:
	if _tex_streak == null:
		_tex_streak = _fx_tex("streak")
	if _tex_streak != null:
		var sp := Sprite2D.new()
		sp.texture = _tex_streak
		sp.material = _fx_add()
		sp.position = pos + Vector2(0, -140)
		sp.rotation = -PI * 0.5            # 横向光线转竖
		# streak 512×64：竖起后高 512*k ≈ 420px、宽 64*k ≈ 34px
		var k: float = 0.82
		sp.scale = Vector2(k, k * 0.55)
		sp.modulate = Color(col.r, col.g, col.b, 0.0)
		sp.z_index = 900
		fx.add_child(sp)
		var t0 := host.create_tween()
		t0.set_parallel(true)
		t0.tween_property(sp, "modulate:a", 0.95, 0.09)
		t0.tween_property(sp, "scale", Vector2(k * 1.35, k * 0.16), 0.42) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t0.tween_property(sp, "modulate:a", 0.0, 0.40).set_delay(0.08)
		t0.chain().tween_callback(sp.queue_free)

	var p := CPUParticles2D.new()
	p.position = pos + Vector2(0, -20)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 18
	p.lifetime = 0.75
	p.spread = 18.0
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 340.0
	p.gravity = Vector2(0, -60)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 6.5
	p.color = col
	p.z_index = 901
	fx.add_child(p)
	var t2 := host.create_tween()
	t2.tween_interval(1.1)
	t2.tween_callback(p.queue_free)

	_ring(pos, col, 20.0, 2.6, 0.30)


## 大招：全屏白闪 + 三重冲击环 + 镜头拉近 + 猛震
func ult_burst(pos: Vector2, cols: Array) -> void:
	flash(Color(1.0, 1.0, 0.96, 0.62), 0.26)
	for i in 3:
		var c: Color = cols[i % cols.size()] if cols.size() > 0 else Color("#ffd23c")
		_ring(pos, c, 30.0, 5.2 + i * 1.4, 0.52 + i * 0.08)
	zoom_punch(0.13, 0.85)
	shake(2.1)


## ★ 特招起手爆点（三段连击的第三段）：元素色冲击环 + 火花
##   让「第三段」有明确的视觉收尾，孩子一眼看出"这招收招了"
func special_burst(pos: Vector2, col: Color) -> void:
	_ring(pos, col, 36.0, 3.8, 0.38)
	impact(pos, col, false, Vector2.ZERO)


## 字卡飞入字囊（拾字时的 UI 反馈）
func card_fly(from_global: Vector2, to_screen: Vector2, ch: String, py: String, col: Color) -> void:
	var lay := host.get_node_or_null("UI")
	if lay == null:
		return
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.92)
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -4)
	card.add_child(vb)
	var py_l := Label.new()
	py_l.text = py
	py_l.add_theme_font_size_override("font_size", 15)
	py_l.add_theme_color_override("font_color", Color("#3a2000"))
	py_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(py_l)
	var ch_l := Label.new()
	ch_l.text = ch
	ch_l.add_theme_font_size_override("font_size", 38)
	ch_l.add_theme_color_override("font_color", Color("#2a1400"))
	ch_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ch_l)
	card.position = from_global - Vector2(40, 40)
	card.scale = Vector2(0.5, 0.5)
	card.pivot_offset = Vector2(40, 40)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(card)

	var t := host.create_tween()
	t.set_parallel(true)
	t.tween_property(card, "position", to_screen, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(card, "scale", Vector2(0.42, 0.42), 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(card, "modulate:a", 0.0, 0.22).set_delay(0.34)
	t.chain().tween_callback(card.queue_free)


# ============================================================
#  ③ 场景互动
# ============================================================
## 木箱 / 竹筒被打破：木屑四溅 + 残片
func debris(pos: Vector2, col: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 26
	p.lifetime = 0.85
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 330.0
	p.gravity = Vector2(0, 760)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 11.0
	p.color = col
	p.z_index = 880
	fx.add_child(p)
	var t := host.create_tween()
	t.tween_interval(1.3)
	t.tween_callback(p.queue_free)


## 脚步扬尘
func dust(pos: Vector2, amount: int = 5) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = amount
	p.lifetime = 0.45
	p.spread = 55.0
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0, -30)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	p.color = Color(0.82, 0.78, 0.68, 0.42)
	p.z_index = 460
	fx.add_child(p)
	var t := host.create_tween()
	t.tween_interval(0.8)
	t.tween_callback(p.queue_free)


## 踩水涟漪：扁椭圆环扩散 ★ 真素材版（ring 压扁）
func ripple(pos: Vector2, col: Color = Color(0.72, 0.92, 1.0, 0.7)) -> void:
	if _tex_ring == null:
		_tex_ring = _fx_tex("ring")
	if _tex_ring == null:
		return
	var sp := Sprite2D.new()
	sp.texture = _tex_ring
	sp.material = _fx_add()
	sp.position = pos
	sp.modulate = col
	sp.scale = Vector2(0.05, 0.05 * 0.35)   # ring 1024 → 初始 51px 扁环
	sp.z_index = 452
	fx.add_child(sp)
	var t := host.create_tween()
	t.set_parallel(true)
	t.tween_property(sp, "scale", Vector2(0.13, 0.13 * 0.35), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(sp, "modulate:a", 0.0, 0.55)
	t.chain().tween_callback(sp.queue_free)


## 竹叶 / 花瓣被震落 ★ 真素材版（leaf.png 真竹叶）
func flakes(pos: Vector2, col: Color, n: int = 8) -> void:
	if _tex_leaf == null:
		_tex_leaf = _fx_tex("leaf")
	if _tex_leaf == null:
		return
	for i in n:
		var f := Sprite2D.new()
		f.texture = _tex_leaf
		var lk := _rng.randf_range(0.20, 0.32)   # leaf 256px → 飘叶 51~82px
		f.scale = Vector2(lk, lk)
		f.position = pos + Vector2(_rng.randf_range(-52.0, 52.0), _rng.randf_range(-26.0, 6.0))
		f.rotation = _rng.randf_range(0.0, TAU)
		f.modulate = col
		f.z_index = 470
		fx.add_child(f)
		var t := host.create_tween()
		t.set_parallel(true)
		t.tween_property(f, "position", f.position + Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(90.0, 170.0)), _rng.randf_range(0.9, 1.7)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(f, "rotation", f.rotation + _rng.randf_range(-5.0, 5.0), 1.6)
		t.tween_property(f, "modulate:a", 0.0, 1.4).set_delay(0.4)
		t.chain().tween_callback(f.queue_free)


# ============================================================
#  ④ UI / 过场
# ============================================================
## 全屏闪白 / 闪光
func flash(col: Color, dur: float = 0.24) -> void:
	_ensure_red()
	if _red == null:
		return
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red.get_parent().add_child(r)
	_red.get_parent().move_child(r, _red.get_index())
	var t := host.create_tween()
	t.tween_property(r, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(r.queue_free)


## 受伤 / 濒死：四周红色渐晕
func flash_red(strength: float, dur: float = 0.45) -> void:
	_ensure_red()
	if _red == null:
		return
	_red_a = max(_red_a, clamp(strength, 0.0, 1.0))
	_red_hold = max(_red_hold, dur)


## 濒死常驻警示（HP 低于阈值时开）
func set_danger(on: bool) -> void:
	_ensure_red()
	if _red == null:
		return
	_danger = on


## 过关：烟花 + 彩带
func celebrate() -> void:
	var lay := host.get_node_or_null("UI")
	if lay == null:
		return
	var cols := [Color("#ff5a7a"), Color("#ffd23c"), Color("#5ad8ff"), Color("#8affa8"), Color("#ff9ade")]
	for i in 7:
		var c: Color = cols[i % cols.size()]
		var x := _rng.randf_range(160.0, 1120.0)
		var y := _rng.randf_range(120.0, 340.0)
		_burst_at(lay, Vector2(x, y), c, 26)
	_burst_at(lay, Vector2(640.0, 300.0), Color("#ffffff"), 40)


func _burst_at(parent: Node, pos: Vector2, col: Color, n: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = 1.5
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 300.0
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	p.color = col
	parent.add_child(p)
	var t := host.create_tween()
	t.tween_interval(2.2)
	t.tween_callback(p.queue_free)


## ★ BOSS 震撼登场（三国战记式完整套餐）
##   时间轴：画面骤暗 → 名字大字从远推近砸下 → 光带横扫 → 元素色光环扩散
##           → 全屏白闪 → 震屏 + 低沉音效 → 幕布收
##   bname：Boss 名；ui：挂 UI 的 CanvasLayer；col：主题色（可选）
##   boss_tex：Boss 立绘（可选，有则同时推近放大）
func boss_entrance(bname: String, ui: CanvasLayer, col: Color = Color("#ff5a5a"),
		boss_tex: Texture2D = null) -> void:
	if ui == null:
		return

	# ① 骤暗（比原来更深、更快 —— 制造「时间停滞」感）
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dim)

	# ② Boss 立绘推近（可选）—— 作为半透明暗色背景，不抢名字的戏
	var portrait: TextureRect = null
	if boss_tex != null:
		portrait = TextureRect.new()
		portrait.texture = boss_tex
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait.pivot_offset = Vector2(640, 360)
		portrait.modulate = Color(0.30, 0.30, 0.36, 0.0)   # 压暗为剪影底衬
		portrait.scale = Vector2(1.35, 1.35)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(portrait)

	# ③ 光带（横扫的亮条）
	var sweep := ColorRect.new()
	sweep.color = Color(col.r, col.g, col.b, 0.0)
	sweep.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sweep.offset_top = 292.0
	sweep.offset_bottom = 320.0
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep.z_index = 10
	ui.add_child(sweep)

	# ④ 名字大字（从大缩到正常 = 从远推近）
	var lab := Label.new()
	lab.text = bname
	lab.add_theme_font_size_override("font_size", 92)
	lab.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86))
	lab.add_theme_color_override("font_outline_color", Color(0.10, 0.0, 0.0, 1))
	lab.add_theme_constant_override("outline_size", 16)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lab.offset_top = 250.0
	lab.offset_bottom = 372.0
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.scale = Vector2(3.4, 3.4)
	lab.pivot_offset = Vector2(640, 61)
	lab.modulate.a = 0.0
	lab.z_index = 20
	ui.add_child(lab)

	# ⑤ 副标题（血条下方的「守护者」字样）
	var sub := Label.new()
	sub.text = "守 关 者"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 1.0))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	sub.add_theme_constant_override("outline_size", 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 366.0
	sub.offset_bottom = 396.0
	sub.modulate.a = 0.0
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.z_index = 20
	ui.add_child(sub)

	# ⑥ 全屏元素色闪
	var fl := ColorRect.new()
	fl.color = Color(col.r, col.g, col.b, 0.0)
	fl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fl)

	# ---------------- 时间轴 ----------------
	var t := host.create_tween()
	t.set_parallel(true)
	# 骤暗
	t.tween_property(dim, "color:a", 0.78, 0.22)
	# 名字：淡入 + 从远推近（3.4 → 1.0）
	t.tween_property(lab, "modulate:a", 1.0, 0.12)
	t.tween_property(lab, "scale", Vector2(1.0, 1.0), 0.42).set_delay(0.06) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 光带横扫过名字后淡出
	t.tween_property(sweep, "color:a", 0.85, 0.10).set_delay(0.10)
	t.tween_property(sweep, "color:a", 0.0, 0.30).set_delay(0.38)
	# 副标题
	t.tween_property(sub, "modulate:a", 1.0, 0.20).set_delay(0.38)
	# 立绘推近
	if portrait != null:
		t.tween_property(portrait, "modulate:a", 0.92, 0.30).set_delay(0.06)
		t.tween_property(portrait, "scale", Vector2(1.0, 1.0), 0.70).set_delay(0.06) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 白闪（0.55s 处）
	var t2 := host.create_tween()
	t2.tween_interval(0.55)
	t2.tween_property(fl, "color:a", 0.62, 0.07)
	t2.tween_property(fl, "color:a", 0.0, 0.16)

	# 震屏 + 音效（在白闪瞬间，形成「咚」的感觉）
	var t3 := host.create_tween()
	t3.tween_interval(0.55)
	t3.tween_callback(func():
		shake(2.4, Vector2(0, 0.2))
		Sfx.play("boss", 0.82, 2.0))

	# 收场（1.85s 起）
	# ⚠️ 注意：不能在 tween_interval(1.85) 之后再 set_parallel(true) ——
	#    parallel 模式会让 interval 与后续 property 同时起跑，等于「淡出从第 0 秒开始」，
	#    直接把名字的淡入压成 0（Boss 名字整场看不见的真凶）。
	#    正确做法：interval 独占一段，到点后在回调里另起一个并行 tween。
	var t4 := host.create_tween()
	t4.tween_interval(1.85)
	t4.tween_callback(func():
		var t5 := host.create_tween()
		t5.set_parallel(true)
		t5.tween_property(dim, "color:a", 0.0, 0.34)
		t5.tween_property(lab, "modulate:a", 0.0, 0.30)
		t5.tween_property(sub, "modulate:a", 0.0, 0.30)
		t5.tween_property(sweep, "color:a", 0.0, 0.10)
		if portrait != null and is_instance_valid(portrait):
			t5.tween_property(portrait, "modulate:a", 0.0, 0.34)
		t5.chain().tween_callback(func():
			dim.queue_free()
			lab.queue_free()
			sub.queue_free()
			sweep.queue_free()
			fl.queue_free()
			if portrait != null and is_instance_valid(portrait):
				portrait.queue_free()))


# ============================================================
#  内部
# ============================================================
## 扩散圆环 ★ 真素材版：ring.png（Agnes 高斯环）替代 Line2D 折线圆
func _ring(pos: Vector2, col: Color, r0: float, k: float, dur: float) -> void:
	if _tex_ring == null:
		_tex_ring = _fx_tex("ring")
	var sp := Sprite2D.new()
	sp.texture = _tex_ring
	if sp.texture == null:
		return   # 素材缺失直接跳过（不回退到线框）
	sp.material = _fx_add()
	sp.position = pos
	sp.modulate = col
	# ring 1024px：初始直径 ≈ r0*2 → scale = r0*2/1024*0.5 ≈ r0/1024
	var s0: float = r0 * 1.6 / 1024.0
	sp.scale = Vector2(s0, s0 * 0.55)   # 扁环（贴合横版视角）
	sp.z_index = 960
	fx.add_child(sp)
	var t := host.create_tween()
	t.set_parallel(true)
	t.tween_property(sp, "scale", Vector2(s0 * k * 1.6, s0 * k * 0.9), dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(sp, "modulate:a", 0.0, dur)
	t.chain().tween_callback(sp.queue_free)


## 镜头拉近（punch zoom）
## ⚠️ 基准缩放只在 setup() 时记录一次！
##   以前在这里重取 cam.zoom 当基准 —— 连招连续命中时上一次的拉近还没回落，
##   就被当成新基准，越叠越近 → 「连按 J 画面逐渐放大」的元凶。
func zoom_punch(amount: float, dur: float) -> void:
	if cam == null:
		return
	if _zoom_t > 0.0:
		_zoom_amt = maxf(_zoom_amt, amount)   # 更猛的一拳覆盖弱的一拳，基准不变
		_zoom_dur = maxf(_zoom_dur, dur)
	else:
		_zoom_amt = amount
		_zoom_dur = dur
	_zoom_t = _zoom_dur


func _ensure_red() -> void:
	if _red != null and is_instance_valid(_red):
		return
	var ui := host.get_node_or_null("UI")
	if ui == null:
		return
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.12, 0.12, 0.0))
	g.set_color(1, Color(1.0, 0.12, 0.12, 0.9))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 144
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.62, 0.5)
	_red = ColorRect.new()
	_red.color = Color(1, 1, 1, 0)
	_red.set_anchors_preset(Control.PRESET_FULL_RECT)
	_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.modulate.a = 0.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_red)
	_red.add_child(tr)
	_red.set_meta("vignette", tr)


var _danger := false


func _process(delta: float) -> void:
	# ---- 震屏 ----
	if _shake_p > 0.03:
		_shake_ph += delta * 62.0
		var p := _shake_p
		var ox := sin(_shake_ph) * p * 3.2 + _shake_dir.x * p * 7.0
		var oy := cos(_shake_ph * 1.41) * p * 2.3 + _shake_dir.y * p * 3.4
		if cam != null:
			cam.offset = Vector2(ox, oy)
		_shake_p = lerp(_shake_p, 0.0, min(1.0, delta * 10.0))
	elif cam != null and cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO
		_shake_p = 0.0

	# ---- 镜头拉近 ----
	if _zoom_t > 0.0:
		_zoom_t -= delta
		var k: float = clamp(_zoom_t / max(0.0001, _zoom_dur), 0.0, 1.0)
		# 前 30% 快速推进，后 70% 回弹
		var e: float = sin(k * PI) if k < 0.35 else pow(k, 1.6)
		if cam != null:
			cam.zoom = _zoom_base * (1.0 + _zoom_amt * e)
	elif cam != null and _zoom_t <= 0.0 and cam.zoom != _zoom_base:
		cam.zoom = _zoom_base

	# ---- 红屏 ----
	if _red != null and is_instance_valid(_red):
		var tr: TextureRect = _red.get_meta("vignette")
		if tr != null:
			if _red_hold > 0.0:
				_red_hold -= delta
			elif _red_a > 0.0:
				_red_a = max(0.0, _red_a - delta * 2.2)
			var want: float = _red_a
			if _danger:
				var pulse: float = 0.34 + 0.16 * (0.5 + 0.5 * sin(_shake_ph * 0.06 + Time.get_ticks_msec() * 0.006))
				want = max(want, pulse)
			tr.modulate.a = lerp(tr.modulate.a, want, clamp(delta * 8.0, 0.0, 1.0))

	# ---- 危险警示（HP 低于阈值时呼吸）----
	if _danger and _red_hold <= 0.0 and _red_a <= 0.001:
		pass

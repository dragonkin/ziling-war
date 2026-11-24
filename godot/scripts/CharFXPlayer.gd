extends Node2D
## 字义特效播放器 —— 释放必杀时按字的意象播放专属动画
##
## 用法：CharFXPlayer.play(self, "快", "马", Vector2(640, 400))
## 会依 CharFX 的意象表绘制对应元素 + 大字 + 拼音

const CHARFX := preload("res://scripts/CharFX.gd")

static func play(parent: Node, ch: String, rad: String, pos: Vector2, py: String = "", emoji: String = "") -> Node2D:
	var n := Node2D.new()
	n.set_script(load("res://scripts/CharFXPlayer.gd"))
	n.position = pos
	parent.add_child(n)
	n.start(ch, rad, py, emoji)
	return n


var _ch := ""
var _rad := ""
var _py := ""
var _emoji := ""
var _t := 0.0
var _life := 1.5


func start(ch: String, rad: String, py: String = "", emoji: String = "") -> void:
	_ch = ch
	_rad = rad
	_py = py
	_emoji = emoji
	_build()


func _build() -> void:
	var fx := CHARFX.new()
	var kind: Dictionary = fx.kind_of(_ch, _rad, _emoji)
	var col: Color = Color(kind.get("color", "#ffd23c"))
	var elem: String = kind.get("elem", "glow")
	var motion: String = kind.get("motion", "burst")

	# ---- 1. 主体大字（放大弹出）----
	var big := Label.new()
	big.text = _ch
	big.add_theme_font_size_override("font_size", 150)
	big.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
	big.add_theme_color_override("font_outline_color", col.darkened(0.5))
	big.add_theme_constant_override("outline_size", 16)
	big.size = Vector2(240, 200)
	big.position = Vector2(-120, -180)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.scale = Vector2(0.2, 0.2)
	add_child(big)
	var bt := create_tween()
	bt.tween_property(big, "scale", Vector2(1.25, 1.25), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_property(big, "scale", Vector2(1.0, 1.0), 0.10)
	bt.parallel().tween_property(big, "modulate:a", 0.0, 0.85).set_delay(0.6)

	# ---- 2. 拼音 ----
	if _py != "":
		var pl := Label.new()
		pl.text = _py
		pl.add_theme_font_size_override("font_size", 46)
		pl.add_theme_color_override("font_color", Color("#fff0b0"))
		pl.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0, 1))
		pl.add_theme_constant_override("outline_size", 8)
		pl.size = Vector2(240, 60)
		pl.position = Vector2(-120, 24)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(pl)
		var pt := create_tween()
		pt.tween_property(pl, "modulate:a", 0.0, 0.5).set_delay(0.9)

	# ---- 3. 意象元素 ----
	_build_element(elem, motion, col)

	# ---- 4. 音效 & 读音 ----
	Sfx.speak(_ch, 0.0)
	Sfx.play("levelup", 1.0, -4.0)

	# 整体淡出
	var t := create_tween()
	t.tween_interval(_life)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)


# ================= 意象元素绘制 =================
func _build_element(elem: String, motion: String, col: Color) -> void:
	match elem:
		"wave":
			_wave(col, motion)
		"flame":
			_particles(col, 90, Vector2(0, -1), 30.0, 1.4)
			_glow(Vector2(0, -40), col, 200, 1.6)
		"rockfall":
			_rocks(col, 7)
		"bolt":
			_bolt(col)
		"crystal":
			_crystals(col)
		"ray":
			_rays(col)
		"horse":
			_horse(col)
		"bird":
			_birds(col)
		"fish":
			_fish(col)
		"blade":
			_slashes(col)
		"figure":
			_particles(col, 50, Vector2(0, -1), 20.0, 0.9)
			_glow(Vector2.ZERO, col, 170, 1.2)
		"streak":
			_slashes(col)
		"palm":
			_rings(col, 3)
		"grain":
			_particles(col, 70, Vector2(0, -1), 22.0, 1.0)
		"wheel":
			_rings(col, 2)
		"digit":
			_rings(col, 4)
		"heart":
			_hearts(col)
		"smoke":
			_particles(Color(0.45, 0.4, 0.55), 60, Vector2(0, -1), 16.0, 1.2)
		"peak":
			_rocks(col, 5)
		"cloud":
			_particles(Color(0.9, 0.94, 1.0), 45, Vector2(0, -0.4), 12.0, 0.8)
		"leaf", "sprout":
			_particles(col, 55, Vector2(0, -0.6), 24.0, 0.9)
		"ripple":
			_rings(col, 3)
		"shard":
			_crystals(col)
		"gust":
			_wave(col, "sweep")
		"glow", _:
			_glow(Vector2.ZERO, col, 230, 1.3)
			_rings(col, 2)


func _particles(col: Color, amount: int, dir: Vector2, speed: float, life: float) -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = 42.0
	p.initial_velocity_min = speed * 4.0
	p.initial_velocity_max = speed * 11.0
	p.gravity = Vector2(0, 180)
	p.scale_amount_min = 6.0
	p.scale_amount_max = 16.0
	p.color = col
	p.z_index = 600
	add_child(p)


func _glow(pos: Vector2, col: Color, size: int, sy: float) -> void:
	var s := Sprite2D.new()
	s.texture = _radial(size)
	s.modulate = Color(col.r, col.g, col.b, 0.75)
	s.position = pos
	s.scale = Vector2(1.0, sy)
	s.z_index = 580
	add_child(s)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale", Vector2(2.2, sy * 2.2), 0.5)
	t.tween_property(s, "modulate:a", 0.0, 0.5)


func _rings(col: Color, n: int) -> void:
	for i in n:
		var ln := Line2D.new()
		var pts := PackedVector2Array()
		for k in range(33):
			var a := TAU * k / 32.0
			pts.append(Vector2(cos(a), sin(a)) * 46.0)
		ln.points = pts
		ln.width = 10.0
		ln.default_color = Color(col.r, col.g, col.b, 0.9)
		ln.z_index = 590
		add_child(ln)
		var t := create_tween()
		t.tween_interval(i * 0.09)
		t.set_parallel(true)
		t.tween_property(ln, "scale", Vector2(4.2, 2.6), 0.5)
		t.tween_property(ln, "modulate:a", 0.0, 0.5)
		t.chain().tween_callback(ln.queue_free)


func _wave(col: Color, motion: String) -> void:
	# 几道横向水波
	for i in 5:
		var ln := Line2D.new()
		var pts := PackedVector2Array()
		for k in range(17):
			var x := -200.0 + k * 25.0
			pts.append(Vector2(x, sin(k * 0.8) * 22.0))
		ln.points = pts
		ln.width = 14.0
		ln.default_color = Color(col.r, col.g, col.b, 0.85)
		ln.z_index = 600
		ln.position = Vector2(0, -60 + i * 40)
		add_child(ln)
		var from: float = -420.0 if motion == "sweep" else -300.0
		ln.position.x = from
		var t := create_tween()
		t.tween_interval(i * 0.05)
		var tw := create_tween()
		tw.tween_property(ln, "position:x", 420.0, 0.55)
		tw.parallel().tween_property(ln, "modulate:a", 0.0, 0.55)
		tw.chain().tween_callback(ln.queue_free)


func _rocks(col: Color, n: int) -> void:
	for i in n:
		var s := Sprite2D.new()
		s.texture = _rock_tex()
		s.modulate = col
		s.position = Vector2(randf_range(-160, 160), -360)
		s.z_index = 600
		add_child(s)
		var t := create_tween()
		t.tween_interval(i * 0.06)
		var tw := create_tween()
		tw.tween_property(s, "position:y", randf_range(40, 140), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(s, "modulate:a", 0.0, 0.3)


func _bolt(col: Color) -> void:
	for i in 3:
		var ln := Line2D.new()
		var pts := PackedVector2Array()
		var x := randf_range(-60, 60)
		for k in range(9):
			pts.append(Vector2(x, -300 + k * 46))
			x += randf_range(-34, 34)
		ln.points = pts
		ln.width = 16.0
		ln.default_color = Color(1, 0.98, 0.6, 0.95)
		ln.z_index = 610
		add_child(ln)
		Sfx.play("crit", randf_range(0.9, 1.2), -6.0)
		var t := create_tween()
		t.tween_interval(i * 0.12)
		var tw := create_tween()
		tw.tween_property(ln, "modulate:a", 0.0, 0.22)
		tw.tween_callback(ln.queue_free)


func _crystals(col: Color) -> void:
	for i in 10:
		var ln := Line2D.new()
		var a := deg_to_rad(randf_range(0, 360))
		var r := randf_range(60, 150)
		var v := Vector2(cos(a), sin(a))
		ln.points = PackedVector2Array([v * r * 0.5, v * r])
		ln.width = randf_range(6, 14)
		ln.default_color = Color(col.r, col.g, col.b, 0.9)
		ln.z_index = 600
		add_child(ln)
		var t := create_tween()
		t.parallel().tween_property(ln, "scale", Vector2(1.8, 1.8), 0.5)
		t.parallel().tween_property(ln, "modulate:a", 0.0, 0.5)


func _rays(col: Color) -> void:
	var c := Node2D.new()
	c.z_index = 580
	add_child(c)
	for i in 12:
		var ln := Line2D.new()
		var a := TAU * i / 12.0
		var v := Vector2(cos(a), sin(a))
		ln.points = PackedVector2Array([v * 40, v * 220])
		ln.width = 12.0
		ln.default_color = Color(1, 0.9, 0.45, 0.8)
		c.add_child(ln)
	c.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(c, "scale", Vector2(1.5, 1.5), 0.5)
	t.tween_property(c, "modulate:a", 0.0, 0.5)


## 「快」→ 奔马：一匹马从左侧冲过
func _horse(col: Color) -> void:
	var horse := Node2D.new()
	horse.z_index = 620
	horse.position = Vector2(-460, 40)
	add_child(horse)
	# 马身（长条）+ 头 + 四条腿 + 飘鬃
	var body := Line2D.new()
	body.points = PackedVector2Array([Vector2(-90, 0), Vector2(-40, -14), Vector2(30, -12), Vector2(78, 0)])
	body.width = 34.0
	body.default_color = col
	horse.add_child(body)
	var head := Line2D.new()
	head.points = PackedVector2Array([Vector2(74, -8), Vector2(104, -34), Vector2(126, -22)])
	head.width = 22.0
	head.default_color = col
	horse.add_child(head)
	for k in 4:
		var leg := Line2D.new()
		var bx := -70.0 + k * 46.0
		leg.points = PackedVector2Array([Vector2(bx, 2), Vector2(bx + randf_range(-22, 22), 42)])
		leg.width = 11.0
		leg.default_color = col.darkened(0.15)
		horse.add_child(leg)
	var mane := Line2D.new()
	mane.points = PackedVector2Array([Vector2(60, -12), Vector2(34, -48), Vector2(10, -30)])
	mane.width = 14.0
	mane.default_color = col.lightened(0.2)
	horse.add_child(mane)
	# 奔腾 + 扬尘
	var t := create_tween()
	t.tween_property(horse, "position:x", 520.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(horse, "position:y", 20.0, 0.42)
	t.parallel().tween_property(horse, "modulate:a", 0.0, 0.42).set_delay(0.24)
	# 腿部跑动
	for k in 3:
		var lt := create_tween().set_loops(3)
		lt.tween_property(horse, "rotation", 0.06 * (1 if k % 2 == 0 else -1), 0.07)
		lt.tween_property(horse, "rotation", 0.0, 0.07)
	_particles(col.lightened(0.3), 40, Vector2(-1, -0.3), 30.0, 0.6)


func _birds(col: Color) -> void:
	for i in 7:
		var b := Node2D.new()
		b.z_index = 620
		b.position = Vector2(randf_range(-120, 120), 60)
		add_child(b)
		var w1 := Line2D.new()
		w1.points = PackedVector2Array([Vector2(-28, 0), Vector2(0, -14), Vector2(28, 0)])
		w1.width = 8.0
		w1.default_color = col
		b.add_child(w1)
		var t := create_tween()
		t.tween_interval(i * 0.05)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(b, "position:y", -300.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "position:x", b.position.x + randf_range(-160, 160), 0.7)
		tw.tween_property(b, "modulate:a", 0.0, 0.7).set_delay(0.3)


func _fish(col: Color) -> void:
	for i in 6:
		var f := Node2D.new()
		f.z_index = 620
		f.position = Vector2(randf_range(-180, -80), randf_range(-60, 60))
		add_child(f)
		var b := Line2D.new()
		b.points = PackedVector2Array([Vector2(-24, 0), Vector2(0, -16), Vector2(24, 0), Vector2(0, 16), Vector2(-24, 0)])
		b.width = 10.0
		b.default_color = col
		f.add_child(b)
		var tl := Line2D.new()
		tl.points = PackedVector2Array([Vector2(-24, 0), Vector2(-46, -16), Vector2(-46, 16), Vector2(-24, 0)])
		tl.width = 8.0
		tl.default_color = col.lightened(0.2)
		f.add_child(tl)
		var t := create_tween()
		t.tween_interval(i * 0.06)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(f, "position:x", randf_range(260, 400), 0.6)
		tw.tween_property(f, "position:y", f.position.y + sin(i) * 60.0, 0.6)
		tw.tween_property(f, "modulate:a", 0.0, 0.6).set_delay(0.3)


func _slashes(col: Color) -> void:
	for i in 4:
		var ln := Line2D.new()
		var y0 := -120.0 + i * 70.0
		ln.points = PackedVector2Array([Vector2(-230, y0 + 90), Vector2(230, y0 - 90)])
		ln.width = 18.0
		ln.default_color = Color(1, 0.95, 0.7, 0.95)
		ln.z_index = 610
		add_child(ln)
		var t := create_tween()
		t.tween_interval(i * 0.07)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(ln, "modulate:a", 0.0, 0.3)
		tw.tween_property(ln, "scale", Vector2(1.3, 1.3), 0.3)
		tw.chain().tween_callback(ln.queue_free)


func _hearts(col: Color) -> void:
	for i in 9:
		var l := Label.new()
		l.text = "♥"
		l.add_theme_font_size_override("font_size", randf_range(30, 54))
		l.add_theme_color_override("font_color", col)
		l.position = Vector2(randf_range(-150, 150), 60)
		l.z_index = 620
		add_child(l)
		var t := create_tween()
		t.tween_interval(i * 0.05)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(l, "position:y", l.position.y - randf_range(180, 300), 0.8)
		tw.tween_property(l, "modulate:a", 0.0, 0.8)


func _radial(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _rock_tex() -> Texture2D:
	var im := Image.create(48, 42, false, Image.FORMAT_RGBA8)
	var c := Vector2(24, 21)
	for y in 42:
		for x in 48:
			var d := Vector2(x - c.x, y - c.y).length()
			var r := 18.0 + sin(float(x) * 0.4) * 4.0 + cos(float(y) * 0.5) * 3.0
			if d <= r:
				im.set_pixel(x, y, Color(1, 1, 1, 1.0))
	return ImageTexture.create_from_image(im)

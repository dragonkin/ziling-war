extends Node2D
## 掉落的"字" —— 敌人死后爆出，英雄路过自动拾取
## 视觉：发光的大字 + 上下浮动 + 光环脉动

signal picked(info)

var info: Dictionary = {}
var _label: Label
var _py_label: Label
var _ring: Node2D
var _ring_line: Line2D
var _bob := 0.0
var _life := 14.0     # 14 秒后消失
var _taken := false


static func create(p_pos: Vector2, p_info: Dictionary, col: Color = Color("#ffd23c")) -> Node2D:
	var n := Node2D.new()
	n.set_script(load("res://scripts/CharDrop.gd"))
	n.position = p_pos
	n.info = p_info
	return n


func _ready() -> void:
	_build()
	# 弹出动画
	scale = Vector2(0.2, 0.2)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build() -> void:
	z_index = 900
	# 脉动光环（用 _process 的 sin 驱动，避免 set_loops 无限循环告警）
	_ring = Node2D.new()
	add_child(_ring)
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a), sin(a)) * 44.0)
	ring.points = pts
	ring.width = 5.0
	ring.default_color = Color("#ffe98a")
	_ring.add_child(ring)
	_ring_line = ring

	# 发光底色
	var glow := Sprite2D.new()
	glow.texture = _radial(130)
	glow.modulate = Color(1.0, 0.85, 0.35, 0.8)
	add_child(glow)

	# 大字
	_label = Label.new()
	_label.text = info.get("char", "？")
	_label.add_theme_font_size_override("font_size", 68)
	_label.add_theme_color_override("font_color", Color("#fffbe0"))
	_label.add_theme_color_override("font_outline_color", Color("#a05a00"))
	_label.add_theme_constant_override("outline_size", 9)
	_label.size = Vector2(104, 104)
	_label.position = Vector2(-52, -76)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)

	# 拼音（带声调）
	var py: String = info.get("pinyin", info.get("py", ""))
	if py != "":
		_py_label = Label.new()
		_py_label.text = py
		_py_label.add_theme_font_size_override("font_size", 26)
		_py_label.add_theme_color_override("font_color", Color("#ffe9a0"))
		_py_label.add_theme_color_override("font_outline_color", Color("#6a3200"))
		_py_label.add_theme_constant_override("outline_size", 6)
		_py_label.size = Vector2(120, 34)
		_py_label.position = Vector2(-60, 30)
		_py_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_py_label)

	# 爆字时读一遍
	Sfx.speak(info.get("char", ""), -1.0)


func _radial(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if _taken:
		return
	_bob += delta * 4.0
	position.y += 0.0
	if _label:
		_label.position.y = -76 + sin(_bob) * 7.0
	if _py_label:
		_py_label.position.y = 30 + sin(_bob) * 7.0
	# 光环脉动
	if _ring != null and is_instance_valid(_ring):
		var k: float = 1.0 + 0.26 * (0.5 + 0.5 * sin(_bob * 1.6))
		_ring.scale = Vector2(k, k)
		if _ring_line != null and is_instance_valid(_ring_line):
			_ring_line.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_bob * 1.6 + PI))
	_life -= delta
	if _life <= 0.0:
		_fade_out()


func _fade_out() -> void:
	if _taken:
		return
	_taken = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)


## 被玩家拾取
func collect() -> void:
	if _taken:
		return
	_taken = true
	Sfx.play("levelup", 1.2, -3.0)
	# 拾取时再读一遍（强化记忆）
	Sfx.speak(info.get("char", ""), 2.0)
	emit_signal("picked", info)
	# 飞向屏幕上方 + 缩小
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(0.3, 0.3), 0.35)
	t.tween_property(self, "position:y", position.y - 90, 0.35)
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(queue_free)

extends Node2D
## ★ 战利品掉落（对标三国战记：打敌人掉包子/铜钱，路过自动捡）
##   bun  = 包子，回血 15（低血时掉率翻倍 —— 雪中送炭）
##   coin = 铜钱，加分 200
## 视觉全部程序化：包子 = 白胖椭圆 + 顶部褶皱 + 腮红；铜钱 = 金圆 + 方孔
## 拾取判定由 Battle 的通用扫描完成（drop_root 里带 collect() 的都算）

signal picked(info: Dictionary)

const RISE := -46.0        # 弹起高度
var kind := "bun"
var _bob := 0.0
var _life := 12.0
var _taken := false
var _visual: Node2D


static func create(p_pos: Vector2, p_kind: String) -> Node2D:
	var n := Node2D.new()
	n.set_script(load("res://scripts/ItemDrop.gd"))
	n.kind = p_kind
	# 落点稍微散开，别都叠在敌人尸体上
	n.position = p_pos + Vector2(randf_range(-46.0, 46.0), randf_range(-10.0, 10.0))
	return n


func _ready() -> void:
	z_index = 880
	_build()
	# 抛起 → 弹跳落地（两段）
	var up := create_tween()
	up.set_parallel(true)
	up.tween_property(self, "position:y", position.y + RISE - 60.0, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.chain().tween_property(self, "position:y", position.y, 0.30) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _build() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	if kind == "bun":
		_build_bun()
	else:
		_build_coin()


## 包子：白胖椭圆 + 顶部收口褶 + 腮红（小朋友一眼认出"能吃的"）
func _build_bun() -> void:
	var body := _ell(46, 38, Color(1.0, 0.98, 0.93))
	_visual.add_child(body)
	# 顶部褶皱（三条弧）
	for i in 3:
		var fold := Line2D.new()
		var w := 18.0 - i * 5.0
		var pts := PackedVector2Array()
		for j in range(7):
			var t := float(j) / 6.0
			pts.append(Vector2(lerp(-w, w, t), -26.0 + abs(t - 0.5) * 2.0 * 8.0))
		fold.points = pts
		fold.width = 3.0
		fold.default_color = Color(0.86, 0.80, 0.72)
		_visual.add_child(fold)
	# 腮红
	for sx in [-1.0, 1.0]:
		var blush := _ell(10, 6, Color(1.0, 0.62, 0.62, 0.8))
		blush.position = Vector2(sx * 20.0, 6.0)
		_visual.add_child(blush)
	# 高光
	var hi := _ell(12, 8, Color(1, 1, 1, 0.9))
	hi.position = Vector2(-14, -12)
	_visual.add_child(hi)
	# 底部淡绿光环（= 治疗色，教小朋友"绿光=好事"）
	_ring(Color(0.55, 1.0, 0.6, 0.55))


## 铜钱：金色圆 + 方孔 + 外描边（"方孔圆钱"经典形制）
func _build_coin() -> void:
	var c := _ell(36, 36, Color(1.0, 0.80, 0.25))
	_visual.add_child(c)
	var rim := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * 36.0, sin(a) * 36.0))
	rim.points = pts
	rim.width = 4.0
	rim.default_color = Color(0.85, 0.58, 0.10)
	_visual.add_child(rim)
	var hole := ColorRect.new()
	hole.color = Color(0.72, 0.50, 0.10)
	hole.size = Vector2(16, 16)
	hole.position = Vector2(-8, -8)
	_visual.add_child(hole)
	# 金色闪光（旋转的十字星）
	var star := Line2D.new()
	star.points = PackedVector2Array([Vector2(0, -52), Vector2(0, 52)])
	star.width = 2.5
	star.default_color = Color(1, 1, 0.85, 0.7)
	star.position = Vector2.ZERO
	_visual.add_child(star)
	var star2 := star.duplicate() as Line2D
	star2.rotation = PI / 2.0
	_visual.add_child(star2)
	_ring(Color(1.0, 0.85, 0.4, 0.55))


func _ell(w: float, h: float, col: Color) -> Sprite2D:
	var sp := Sprite2D.new()
	var img := Image.create(int(w * 2), int(h * 2), false, Image.FORMAT_RGBA8)
	var cx := w
	var cy := h
	for y in int(h * 2):
		for x in int(w * 2):
			var d := Vector2((x - cx) / w, (y - cy) / h).length()
			if d <= 1.0:
				img.set_pixel(x, y, col)
	sp.texture = ImageTexture.create_from_image(img)
	return sp


func _ring(col: Color) -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * 52.0, sin(a) * 52.0))
	ring.points = pts
	ring.width = 4.0
	ring.default_color = col
	ring.name = "Ring"
	_visual.add_child(ring)


func _process(delta: float) -> void:
	if _taken:
		return
	_bob += delta * 4.2
	if _visual != null:
		_visual.position.y = sin(_bob) * 5.0
		var r := _visual.get_node_or_null("Ring")
		if r != null:
			var k: float = 1.0 + 0.22 * (0.5 + 0.5 * sin(_bob * 1.5))
			r.scale = Vector2(k, k)
			r.modulate.a = 0.35 + 0.6 * (0.5 + 0.5 * sin(_bob * 1.5 + PI))
	_life -= delta
	if _life <= 0.0:
		_fade_out()


func _fade_out() -> void:
	if _taken:
		return
	_taken = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(queue_free)


func collect() -> void:
	if _taken:
		return
	_taken = true
	Sfx.play("coin" if kind == "coin" else "levelup", randf_range(1.05, 1.2), -2.0)
	emit_signal("picked", {"kind": kind, "char": "", "pinyin": ""})
	# 飞向玩家头顶 + 缩小消失
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:y", position.y - 70.0, 0.30)
	t.tween_property(self, "scale", Vector2(0.25, 0.25), 0.30)
	t.tween_property(self, "modulate:a", 0.0, 0.30)
	t.chain().tween_callback(queue_free)

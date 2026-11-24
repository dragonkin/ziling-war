extends Node2D
## 环境机关 —— 落石 / 飞箭 / 喷火 / 水柱
##
## 四种机关都由 create(kind, x, ...) 生成，全部带「预警」阶段后再生效，
## 玩家在预警时间内可躲开，不会无故掉血。
##
## kind:
##   rock   落石：头顶出现尘土预警 → 巨石砸下，命中伤 30
##   arrow  飞箭：一侧出现红点预警 → 箭矢横飞，命中伤 15
##   fire   喷火：地面裂缝亮起 → 向上喷出火柱，持续伤害
##   water  水柱：地面冒泡 → 水柱冲天，命中击退 + 伤 10

signal hit_player(dmg: int, knock: float)

const WARN_ROCK := 0.85
const WARN_ARROW := 0.55
const WARN_FIRE := 0.75
const WARN_WATER := 0.7

var kind := "rock"
var dmg := 20
var _warn := 0.8
var _life := 3.0
var _state := "warn"      # warn -> active -> done
var _dir := 1.0
var _ground_y := 520.0    # 与 Battle.GROUND_BASE 一致
var _target: Node2D = null
var _hit_done := false
var _warn_node: Node2D = null
var _warn_pulse := false
var _pulse_t := 0.0


static func create(p_kind: String, p_x: float, p_ground_y: float,
		p_target: Node2D = null, p_dir: float = 1.0) -> Node2D:
	var n := Node2D.new()
	n.set_script(load("res://scripts/Hazard.gd"))
	n.kind = p_kind
	n.position = Vector2(p_x, p_ground_y)
	n._ground_y = p_ground_y
	n._target = p_target
	n._dir = p_dir
	match p_kind:
		"rock":
			n.dmg = 30
			n._warn = WARN_ROCK
			n._life = 1.5
		"arrow":
			n.dmg = 15
			n._warn = WARN_ARROW
			n._life = 1.6
		"fire":
			n.dmg = 22
			n._warn = WARN_FIRE
			n._life = 2.2
		"water":
			n.dmg = 10
			n._warn = WARN_WATER
			n._life = 1.6
	return n


func _ready() -> void:
	_build()
	Sfx.play("swing", 1.4, -14.0)


func _build() -> void:
	match kind:
		"rock":
			_make_warn_shadow(46, 16)
		"arrow":
			_make_arrow_warn()
		"fire":
			_make_fire_warn()
		"water":
			_make_water_warn()


func _make_warn_shadow(w: int, h: int) -> void:
	var s := Sprite2D.new()
	s.texture = _ellipse(w, h)
	s.modulate = Color(0, 0, 0, 0.45)
	s.name = "Warn"
	add_child(s)
	_warn_node = s
	_warn_pulse = true


func _make_arrow_warn() -> void:
	var l := Line2D.new()
	l.points = PackedVector2Array([Vector2(0, -120), Vector2(0, 40)])
	l.width = 3.0
	l.default_color = Color(1, 0.3, 0.2, 0.8)
	l.name = "Warn"
	add_child(l)
	_warn_node = l
	_warn_pulse = true


func _make_fire_warn() -> void:
	var r := Sprite2D.new()
	r.texture = _ellipse(90, 26)
	r.modulate = Color(1.0, 0.45, 0.1, 0.75)
	r.name = "Warn"
	add_child(r)
	_warn_node = r
	_warn_pulse = true


func _make_water_warn() -> void:
	var r := Sprite2D.new()
	r.texture = _ellipse(80, 22)
	r.modulate = Color(0.4, 0.8, 1.0, 0.7)
	r.name = "Warn"
	add_child(r)
	_warn_node = r
	_warn_pulse = true


func _ellipse(w: int, h: int) -> ImageTexture:
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


func _process(delta: float) -> void:
	# 预警脉动：用 sin 计算，避免 set_loops 无限循环告警
	if _warn_pulse and is_instance_valid(_warn_node):
		_pulse_t += delta
		var k: float = 1.0 + 0.30 * sin(_pulse_t * 9.0)
		if kind == "arrow":
			_warn_node.modulate.a = 0.35 + 0.5 * (0.5 + 0.5 * sin(_pulse_t * 14.0))
		else:
			_warn_node.scale = Vector2(k, k)
	if _state == "warn":
		_warn -= delta
		if _warn <= 0.0:
			_state = "active"
			_clear_warn()
			_activate()
	elif _state == "active":
		_life -= delta
		if _life <= 0.0:
			_state = "done"
			queue_free()


func _clear_warn() -> void:
	var w := get_node_or_null("Warn")
	if w:
		w.queue_free()


# ================= 生效 =================
func _activate() -> void:
	match kind:
		"rock":
			_do_rock()
		"arrow":
			_do_arrow()
		"fire":
			_do_fire()
		"water":
			_do_water()


func _do_rock() -> void:
	Sfx.play("hit", 0.7)
	# 巨石从天而降
	var rock := Sprite2D.new()
	rock.texture = _rock_texture()
	rock.position = Vector2(0, -420)
	rock.z_index = 400
	add_child(rock)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(rock, "position:y", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(func():
		_check_hit(dmg, 0.0)
		_shake_and_dust()
		var ft := create_tween()
		ft.tween_property(rock, "modulate:a", 0.0, 0.3)
		ft.tween_callback(rock.queue_free))


func _do_arrow() -> void:
	Sfx.play("swing", 1.6, -10.0)
	var arrow := Line2D.new()
	arrow.points = PackedVector2Array([Vector2(0, -8), Vector2(56 * _dir, 0), Vector2(0, 8)])
	arrow.width = 7.0
	arrow.default_color = Color("#ffe9a8")
	arrow.position = Vector2(-110 * _dir, -110)
	arrow.z_index = 400
	add_child(arrow)
	var t := create_tween()
	t.tween_property(arrow, "position:x", 260 * _dir, 0.34)
	t.parallel().tween_property(arrow, "modulate:a", 0.0, 0.34)
	t.chain().tween_callback(arrow.queue_free)
	# 飞行中判定
	var timer := get_tree().create_timer(0.2)
	timer.timeout.connect(func(): _check_hit(dmg, 30.0 * _dir))


func _do_fire() -> void:
	Sfx.play("crit", 1.3, -8.0)
	var col := CPUParticles2D.new()
	col.position = Vector2(0, -10)
	col.amount = 60
	col.lifetime = 0.75
	col.direction = Vector2(0, -1)
	col.spread = 16.0
	col.initial_velocity_min = 240.0
	col.initial_velocity_max = 420.0
	col.gravity = Vector2(0, -60)
	col.scale_amount_min = 10.0
	col.scale_amount_max = 24.0
	col.color = Color("#ff8a2a")
	col.z_index = 400
	add_child(col)
	var glow := Sprite2D.new()
	glow.texture = _radial(160)
	glow.modulate = Color(1.0, 0.5, 0.15, 0.85)
	glow.position = Vector2(0, -90)
	glow.scale = Vector2(1.0, 1.8)
	glow.z_index = 380
	add_child(glow)
	# 火柱持续 0.7 秒，期间持续判定
	var n := 0
	var rep := Timer.new()
	rep.wait_time = 0.16
	rep.one_shot = false
	rep.timeout.connect(func():
		n += 1
		_check_hit(8, 0.0)
		if n >= 5:
			rep.queue_free())
	add_child(rep)
	rep.start()
	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_callback(func():
		col.emitting = false
		var ft := create_tween()
		ft.tween_property(glow, "modulate:a", 0.0, 0.35)
		ft.tween_callback(glow.queue_free))


func _do_water() -> void:
	Sfx.play("levelup", 1.4, -8.0)
	var col := CPUParticles2D.new()
	col.position = Vector2(0, -10)
	col.amount = 70
	col.lifetime = 0.65
	col.direction = Vector2(0, -1)
	col.spread = 22.0
	col.initial_velocity_min = 320.0
	col.initial_velocity_max = 520.0
	col.gravity = Vector2(0, 420)
	col.scale_amount_min = 6.0
	col.scale_amount_max = 15.0
	col.color = Color("#9fe4ff")
	col.z_index = 400
	add_child(col)
	_check_hit(dmg, 210.0 * (1.0 if (_target and _target.position.x > position.x) else -1.0))
	var t := create_tween()
	t.tween_interval(0.9)
	t.tween_callback(func(): col.emitting = false)


func _rock_texture() -> Texture2D:
	var im := Image.create(76, 66, false, Image.FORMAT_RGBA8)
	var c := Vector2(38, 33)
	for y in 66:
		for x in 76:
			var d := Vector2(x - c.x, y - c.y).length()
			var r := 30.0 + sin(float(x) * 0.35) * 5.0 + cos(float(y) * 0.42) * 4.0
			if d <= r:
				var sh: float = 0.55 + 0.45 * (1.0 - d / r)
				im.set_pixel(x, y, Color(0.42 * sh, 0.36 * sh, 0.32 * sh, 1.0))
	return ImageTexture.create_from_image(im)


func _radial(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _shake_and_dust() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(0, -4)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 22
	p.lifetime = 0.5
	p.spread = 80.0
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2(0, 480)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	p.color = Color("#a89880")
	add_child(p)
	var t := create_tween()
	t.tween_interval(0.7)
	t.tween_callback(p.queue_free)


## 命中判定：玩家与机关水平距离足够近就算中
##   ★ 玩家腾空（跳起 / 跃冲 / 向前飞）时放过 —— 跳跃正是用来躲这些低矮机关的
func _check_hit(d: int, knock: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if _target.has_method("is_airborne") and _target.is_airborne():
		return
	var dx: float = abs(_target.position.x - position.x)
	if dx < 74.0:
		emit_signal("hit_player", d, knock)

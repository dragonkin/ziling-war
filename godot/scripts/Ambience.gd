extends Node2D
## 环境氛围系统 —— 让整个场景「活起来」
##
## 用户反馈：「环境也要动起来……不要看起来像死板的贴图」
## 每种场景主题配一套常驻动效，全部由 _process 驱动（不用 set_loops，避免空转报错）
##
## 六套主题：
##   water  水岸 —— 水面波纹流动 + 萤火 + 飘絮
##   bamboo 竹林 —— 竹叶横飞 + 光斑游移 + 竹竿摇曳
##   palace 宫阙 —— 金色尘埃上浮 + 光柱呼吸 + 灯笼晃
##   lava   熔岩 —— 火星上窜 + 热浪扭曲 + 岩浆脉动
##   ruins  废墟 —— 风沙横扫 + 碎石浮尘 + 残旗飘
##   sky    云端 —— 云层横移 + 光羽下落 + 星点闪烁

const VIEW_H := 720.0

# ---- 主题配色 ----
const THEME_CFG := {
	"water":  {"motes": 26, "mote_a": Color(1.0, 0.98, 0.72, 0.85), "mote_b": Color(0.72, 0.94, 1.0, 0.75),
	           "drift": Vector2(-14, -22), "wave": Color(0.68, 0.90, 1.0, 0.30), "n_wave": 5},
	"bamboo": {"motes": 30, "mote_a": Color(0.78, 1.0, 0.62, 0.85), "mote_b": Color(1.0, 0.99, 0.80, 0.70),
	           "drift": Vector2(-46, 16), "wave": Color(0.85, 1.0, 0.70, 0.10), "n_wave": 3},
	"palace": {"motes": 34, "mote_a": Color(1.0, 0.90, 0.55, 0.90), "mote_b": Color(1.0, 0.78, 0.42, 0.75),
	           "drift": Vector2(6, -34), "wave": Color(1.0, 0.88, 0.52, 0.11), "n_wave": 4},
	"lava":   {"motes": 40, "mote_a": Color(1.0, 0.62, 0.22, 0.95), "mote_b": Color(1.0, 0.86, 0.35, 0.85),
	           "drift": Vector2(-8, -58), "wave": Color(1.0, 0.50, 0.18, 0.16), "n_wave": 4},
	"ruins":  {"motes": 30, "mote_a": Color(0.92, 0.86, 0.72, 0.70), "mote_b": Color(0.78, 0.72, 0.62, 0.60),
	           "drift": Vector2(-62, 8), "wave": Color(0.86, 0.80, 0.66, 0.10), "n_wave": 3},
	"sky":    {"motes": 32, "mote_a": Color(0.94, 1.0, 1.0, 0.90), "mote_b": Color(0.80, 0.90, 1.0, 0.80),
	           "drift": Vector2(18, 26), "wave": Color(0.96, 1.0, 1.0, 0.13), "n_wave": 5},
}

var theme := "water"
var world_w := 2200.0

var _cfg: Dictionary = {}
var _motes: Array = []          # [{node, base, phase, sp, drift}]
var _waves: Array = []          # [{node, base_y, phase, amp, sp}]
var _t := 0.0
var _inited := false
var _rng := RandomNumberGenerator.new()

# ---- 前景层状态（近景飘动元素，制造纵深）----
var _fg_node: Node2D = null
var _fg_items: Array = []
var _fg_t := 0.0


func setup(p_theme: String, p_world_w: float, fg_parent: Node2D = null) -> void:
	theme = p_theme if THEME_CFG.has(p_theme) else "water"
	world_w = max(400.0, p_world_w)
	_cfg = THEME_CFG[theme]
	_rng.seed = hash(theme) + 7717
	_clear()
	_build()
	if fg_parent != null and is_instance_valid(fg_parent):
		_fg_node = fg_parent
		_build_foreground()
	_inited = true


func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_motes.clear()
	_waves.clear()
	# ⚠ _fg_node 是 Battle 的常驻 Foreground 节点，不能销毁它本身，
	#   只清掉它下面的前景元素（否则下次 setup 传入的引用已失效）
	_fg_items.clear()
	if _fg_node != null and is_instance_valid(_fg_node):
		for c in _fg_node.get_children():
			_fg_node.remove_child(c)     # 立即脱离，避免与新建节点同帧并存
			c.queue_free()


func _build() -> void:
	# 1) 横向流动的柔光带（贴地/贴背景的光扫）
	var n_wave: int = int(_cfg.get("n_wave", 4))
	var wave_col: Color = _cfg.get("wave", Color(1, 1, 1, 0.12))
	for i in n_wave:
		var ln := Line2D.new()
		ln.width = _rng.randf_range(26.0, 62.0)
		ln.default_color = wave_col
		ln.antialiased = true
		var y0: float = 150.0 + i * (420.0 / float(max(1, n_wave)))
		ln.points = PackedVector2Array([Vector2(-200, y0), Vector2(world_w + 200, y0 + _rng.randf_range(-30, 30))])
		ln.z_index = 0      # 相对父节点（Ambience 的 -10 决定层次：在地形之上、角色之下）
		add_child(ln)
		_waves.append({
			"node": ln,
			"base_y": y0,
			"phase": _rng.randf() * TAU,
			"amp": _rng.randf_range(12.0, 34.0),
			"sp": _rng.randf_range(0.35, 0.85),
			"w0": ln.width,
		})

	# 2) 空中飘浮的微粒（萤火 / 尘埃 / 火星 / 飞羽）
	var n: int = int(_cfg.get("motes", 28))
	var ca: Color = _cfg.get("mote_a", Color(1, 1, 1, 0.8))
	var cb: Color = _cfg.get("mote_b", Color(1, 1, 1, 0.7))
	var drift: Vector2 = _cfg.get("drift", Vector2(-20, -20))
	for i in n:
		var col: Color = ca if (i % 2 == 0) else cb
		var big: bool = (i % 7 == 0)
		var node: Node2D
		if big:
			# 大颗粒用「光点」——中心亮、边缘淡的菱形
			var poly := Polygon2D.new()
			var r: float = _rng.randf_range(9.0, 17.0)
			poly.polygon = PackedVector2Array([
				Vector2(0, -r * 1.6), Vector2(r, 0), Vector2(0, r * 1.6), Vector2(-r, 0)])
			poly.color = Color(col.r, col.g, col.b, col.a * 0.55)
			node = poly
		else:
			var dot := Polygon2D.new()
			var r2: float = _rng.randf_range(3.0, 6.5)
			var pts := PackedVector2Array()
			for k in 8:
				var a: float = TAU * float(k) / 8.0
				pts.append(Vector2(cos(a) * r2, sin(a) * r2))
			dot.polygon = pts
			dot.color = col
			node = dot
		var px: float = _rng.randf_range(0.0, world_w)
		var py: float = _rng.randf_range(60.0, 620.0)
		node.position = Vector2(px, py)
		node.z_index = 0    # 相对父节点，同上
		add_child(node)
		_motes.append({
			"node": node,
			"base": Vector2(px, py),
			"phase": _rng.randf() * TAU,
			"sp": _rng.randf_range(0.45, 1.35),
			"drift": drift * _rng.randf_range(0.55, 1.5),
			"sway": _rng.randf_range(8.0, 26.0),
			"flk": _rng.randf_range(0.7, 2.2),
		})


func _process(delta: float) -> void:
	if not _inited:
		return
	_t += delta

	# 柔光带：缓缓上下浮动 + 明暗呼吸
	for w in _waves:
		var node: Line2D = w.node
		if not is_instance_valid(node):
			continue
		var ph: float = w.phase + _t * w.sp
		var dy: float = sin(ph) * w.amp
		var ww: float = w.w0 * (0.82 + 0.30 * (0.5 + 0.5 * sin(ph * 0.6)))
		node.width = ww
		node.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(ph * 0.45))

	# 微粒：整体漂移 + 回卷 + 横向摆动 + 闪烁
	for m in _motes:
		var node: Node2D = m.node
		if not is_instance_valid(node):
			continue
		var d: Vector2 = m.drift
		var p: Vector2 = m.base + d * _t
		# 横向回卷（保持在世界范围内）
		var span: float = world_w + 120.0
		p.x = fposmod(p.x + 60.0, span) - 60.0
		# 纵向回卷
		if p.y < 30.0:
			p.y += 620.0
		elif p.y > 660.0:
			p.y -= 620.0
		# 摆动
		p.x += sin(_t * m.sp * 1.7 + m.phase) * m.sway
		node.position = p
		# 闪烁
		var k: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * m.flk + m.phase))
		node.modulate.a = k

	# ---- 前景层：贴近镜头，移动更快 → 纵深 ----
	if _fg_node != null and is_instance_valid(_fg_node):
		_fg_t += delta
		for it in _fg_items:
			var fnode: Node2D = it.node
			if not is_instance_valid(fnode):
				continue
			var sp2: Vector2 = it.sp
			var q: Vector2 = it.base + sp2 * _fg_t
			var span2: float = world_w + 320.0
			q.x = fposmod(q.x + 160.0, span2) - 160.0
			if q.y < 40.0:
				q.y += 700.0
			elif q.y > 740.0:
				q.y -= 700.0
			q.x += sin(_fg_t * 1.3 + it.phase) * it.sway
			fnode.position = q
			if it.rot_sp != 0.0:
				fnode.rotation += it.rot_sp * delta


## ★ 前景层：贴近镜头的飘动元素，横向移动比世界快 → 制造纵深感
## 每主题不同：水=飞溅水珠 / 竹=飞叶 / 宫=飘落金箔 / 熔=上窜火星 / 墟=横扫沙砾 / 云=斜落光羽
func _build_foreground() -> void:
	_fg_items.clear()
	var conf := {
		"water":  {"n": 16, "col": Color(0.86, 0.96, 1.0, 0.62), "sp": Vector2(-86, -40),
		           "r": Vector2(4, 9),  "rot": false},
		"bamboo": {"n": 18, "col": Color(0.66, 0.94, 0.48, 0.66), "sp": Vector2(-120, 52),
		           "r": Vector2(7, 15), "rot": true},
		"palace": {"n": 20, "col": Color(1.0, 0.86, 0.44, 0.60), "sp": Vector2(-34, 66),
		           "r": Vector2(3, 7),  "rot": true},
		"lava":   {"n": 24, "col": Color(1.0, 0.62, 0.24, 0.72), "sp": Vector2(-24, -104),
		           "r": Vector2(3, 7),  "rot": false},
		"ruins":  {"n": 20, "col": Color(0.88, 0.82, 0.68, 0.50), "sp": Vector2(-148, 20),
		           "r": Vector2(4, 11), "rot": true},
		"sky":    {"n": 18, "col": Color(0.98, 1.0, 1.0, 0.60), "sp": Vector2(44, 78),
		           "r": Vector2(3, 8),  "rot": false},
	}
	var c: Dictionary = conf.get(theme, conf["water"])
	var n: int = int(c["n"])
	var col: Color = c["col"]
	var sp: Vector2 = c["sp"]
	var rr: Vector2 = c["r"]
	var do_rot: bool = bool(c["rot"])
	for i in n:
		var fnode: Node2D
		if do_rot and i % 3 == 0:
			# 叶片：细长菱形
			var poly := Polygon2D.new()
			var w: float = _rng.randf_range(rr.x * 0.5, rr.x)
			var h: float = _rng.randf_range(rr.y * 1.5, rr.y * 3.0)
			poly.polygon = PackedVector2Array([
				Vector2(0, -h), Vector2(w, 0), Vector2(0, h), Vector2(-w, 0)])
			poly.color = col
			fnode = poly
		else:
			var dot := Polygon2D.new()
			var rd: float = _rng.randf_range(rr.x, rr.y)
			var pts := PackedVector2Array()
			for k in 6:
				var a: float = TAU * float(k) / 6.0 + 0.4
				pts.append(Vector2(cos(a) * rd, sin(a) * rd))
			dot.polygon = pts
			dot.color = col
			fnode = dot
		var px: float = _rng.randf_range(-120.0, world_w + 120.0)
		var py: float = _rng.randf_range(120.0, 700.0)
		fnode.position = Vector2(px, py)
		fnode.scale = Vector2.ONE * _rng.randf_range(0.9, 1.7)
		if do_rot:
			fnode.rotation = _rng.randf() * TAU
		_fg_node.add_child(fnode)
		_fg_items.append({
			"node": fnode,
			"base": Vector2(px, py),
			"sp": sp * _rng.randf_range(0.7, 1.45),
			"phase": _rng.randf() * TAU,
			"sway": _rng.randf_range(10.0, 34.0),
			"rot_sp": _rng.randf_range(-2.4, 2.4) if do_rot else 0.0,
		})

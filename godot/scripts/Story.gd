extends Node
## 剧情系统 —— 逐字注音字幕 + 整句情感语音 + 跟读高亮
##
## 给小学生学汉字用，所以字幕做了三件事：
##   1. 每个汉字正上方标拼音（HFlowContainer 逐字排版，自动换行不错位）
##   2. 朗读到哪个字，哪个字就变金黄并放大 —— 小朋友能跟着手指头读
##   3. 整句用 Edge TTS 情感语音朗读（按角色分音色），旁白时 BGM 自动压低
##
## 数据来源（由 tools/enum_story.gd + tools/gen_story_voice.py 生成）：
##   data/story_lines.json             { "<文本md5>": {w,s,d,t} }
##   assets/voice_story/<md5>.mp3      整句语音
##
## 容错：清单或语音缺失时自动退回「纯文字打字机」模式，不会报错。

signal finished
signal line_changed(text)

# ---------- 布局 ----------
const PANEL_TOP := -128.0      # 字幕条上沿（y≈592）—— 留出两行注音的高度
const PANEL_BOT := -4.0
const PANEL_SIDE := 44.0
const HAN_SIZE := 26
const PY_SIZE := 11
const CELL_SEP := 5            # 字块间距：太小会让长句挤成一行、拼音互相贴住
const ROW_SEP := 5

# ---------- 配色 ----------
const C_IDLE := Color("#fff6e2")      # 还没读到：米白
const C_CUR := Color("#ffd23c")       # 正在读：金黄
const C_DONE := Color("#6f97ab")      # 已读过：青灰
const C_PY := Color("#a89878")        # 拼音常态
const C_PY_CUR := Color("#ffe9a0")    # 拼音·正在读
const C_PY_DONE := Color("#4e6a7a")
const C_OUTLINE := Color(0.05, 0.03, 0.0, 1.0)
const C_NAME := Color("#ffd88a")
const SUB_BG := Color(0.04, 0.03, 0.08, 0.82)
const SUB_EDGE := Color(1.0, 0.86, 0.5, 0.30)

const MIN_HOLD := 0.85         # 语音读完后停留多久（给小朋友一点消化的时间）
const CHARS_PER_SEC := 24.0    # 无语音时的打字机速度
const WEIGHT_HAN := 1.0
const WEIGHT_PUNC := 1.9       # 标点处朗读会停顿，高亮也停久一点

var _root: Control
var _panel: PanelContainer
var _name_label: Label
var _flow: HFlowContainer
var _layer: CanvasLayer

var _queue: Array = []          # [{who, text, hold}]
var _idx := 0
var _state := "idle"            # idle / reading / wait
var _on_done: Callable = Callable()
var _gen := 0

# 当前句
var _cells: Array = []          # [{han:Label, py:Label, box:VBoxContainer}]
var _weights: Array = []
var _cum: Array = []            # 归一化累积权重
var _cur_i := -1
var _t := 0.0
var _dur := 2.5
var _has_voice := false
var _hold := 0.0
var _all_done := false

# 语音清单
var _lines: Dictionary = {}
var _lines_ok := false


# ================= 初始化 =================
func _ready() -> void:
	_load_lines()


func _load_lines() -> void:
	var p := "res://data/story_lines.json"
	var txt := ""
	if FileAccess.file_exists(p):
		txt = FileAccess.get_file_as_string(p)
	if txt == "":
		push_warning("[Story] 未找到旁白清单，退回纯文字模式")
		return
	var d = JSON.parse_string(txt)
	if d is Dictionary and not (d as Dictionary).is_empty():
		_lines = d
		_lines_ok = true
		print("[Story] 旁白清单载入成功：%d 条" % _lines.size())


func setup(layer: CanvasLayer) -> void:
	_layer = layer
	_build_ui()


func _build_ui() -> void:
	if _layer == null:
		return

	_root = Control.new()
	_root.name = "StoryRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	# ---- 说话人名字（浮在字幕条左上角外侧，不占内容高度）----
	_name_label = Label.new()
	_name_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_name_label.offset_left = PANEL_SIDE + 16.0
	_name_label.offset_right = PANEL_SIDE + 520.0
	_name_label.offset_top = PANEL_TOP - 27.0
	_name_label.offset_bottom = PANEL_TOP - 3.0
	_name_label.add_theme_font_size_override("font_size", 19)
	_name_label.add_theme_color_override("font_color", C_NAME)
	_name_label.add_theme_color_override("font_outline_color", C_OUTLINE)
	_name_label.add_theme_constant_override("outline_size", 5)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.visible = false
	_root.add_child(_name_label)

	# ---- 字幕条 ----
	_panel = PanelContainer.new()
	_panel.name = "SubtitlePanel"
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = PANEL_SIDE
	_panel.offset_right = -PANEL_SIDE
	_panel.offset_top = PANEL_TOP
	_panel.offset_bottom = PANEL_BOT
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = SUB_BG
	sb.border_color = SUB_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	_root.add_child(_panel)

	# ---- 逐字注音流式容器（自动换行，字块整体换行不会拆错）----
	_flow = HFlowContainer.new()
	_flow.name = "Cells"
	_flow.add_theme_constant_override("h_separation", CELL_SEP)
	_flow.add_theme_constant_override("v_separation", ROW_SEP)
	_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_flow)


# ================= 对外接口 =================
func play(lines: Array, on_done: Callable = Callable()) -> void:
	_gen += 1
	_queue = []
	for l in lines:
		if l is Dictionary and str(l.get("text", "")) != "":
			_queue.append(l)
	_idx = 0
	_on_done = on_done
	if _queue.is_empty():
		_finish()
		return
	_show_current()


func say(text: String, hold: float = 2.4, who: String = "") -> void:
	play([{"who": who, "text": text, "hold": hold}], Callable())


func is_busy() -> bool:
	return _state != "idle"


## 跳过：收尾当前句 → 立刻下一句
func skip() -> void:
	if _state == "reading":
		Sfx.stop_story()
		_highlight_all_done()
		_next()


func _current_text() -> String:
	if _idx < _queue.size():
		return str(_queue[_idx].get("text", ""))
	return ""


# ================= 显示一句 =================
func _show_current() -> void:
	if _idx >= _queue.size():
		return
	var line: Dictionary = _queue[_idx]
	var who: String = str(line.get("who", ""))
	var text: String = str(line.get("text", ""))

	var entry: Dictionary = {}
	if _lines_ok:
		var e = _lines.get(text.md5_text())
		if e is Dictionary:
			entry = e

	# 说话人
	_name_label.text = "" if who == "" else ("【%s】" % who)
	_name_label.visible = who != ""

	# 重建字块
	_clear_cells()
	if entry.has("s"):
		_build_cells_from_str(str(entry["s"]))
	else:
		_build_cells_plain(text)

	if _cells.is_empty():
		_next()
		return

	# 时长 / 语音
	_has_voice = false
	if entry.has("d"):
		_dur = max(0.9, float(entry["d"]))
		_has_voice = Sfx.play_story(text.md5_text())
	if not _has_voice:
		# ★ 没有整句语音时的兜底：按每格 0.52 秒逐字朗读（见 _set_current），
		#   保证「字幕上写的每一个字都会被读出来」，不会出现某个字哑掉。
		_dur = max(0.9, float(_cells.size()) * 0.52)

	_build_weights()
	_cur_i = -1
	_t = 0.0
	_hold = 0.0
	_all_done = false
	_state = "reading"

	_panel.visible = true
	_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 1.0, 0.16)
	emit_signal("line_changed", text)
	Sfx.play("select", 1.1, -20.0)
	_fit_panel()


func _clear_cells() -> void:
	for c in _flow.get_children():
		_flow.remove_child(c)
		c.queue_free()
	_cells.clear()
	_cum.clear()
	_weights.clear()


## 从 "字:pīn|字:pīn|，" 这样的紧凑串建字块
func _build_cells_from_str(s: String) -> void:
	for part in s.split("|"):
		if part == "":
			continue
		var ci := part.find(":")
		var c := part
		var p := ""
		if ci >= 0:
			c = part.substr(0, ci)
			p = part.substr(ci + 1)
		# ★ 标点并到上一格的汉字后面。
		#   不并的话，HFlowContainer 会把标点当成独立一格，换行时甩到下一行行首
		#   （出现「。走过去…」这种排版），中文排版里这是明显错误。
		if p == "" and _is_punct(c) and not _cells.is_empty():
			var prev: Dictionary = _cells[_cells.size() - 1]
			var hl: Label = prev["han"]
			hl.text = str(hl.text) + c
			continue
		_add_cell(c, p)


## 没有清单时的回退：逐字铺开、不注音
func _build_cells_plain(text: String) -> void:
	for i in text.length():
		_add_cell(text[i], "")


func _add_cell(c: String, p: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ★ 每个注音格至少 48px 宽 —— 汉字本身只有 26px，
	#   不撑开的话 40 个字会全挤进一行、拼音互相贴住，看着累。
	#   撑开后每行约 22 字，长句自动折成两行，接近儿童注音读物的排版。
	box.custom_minimum_size = Vector2(48, 0)

	# 拼音行（空也要占位，保证整句所有字块高度一致）
	var pl := Label.new()
	pl.text = p if p != "" else " "
	pl.add_theme_font_size_override("font_size", PY_SIZE)
	pl.add_theme_color_override("font_color", C_PY)
	pl.add_theme_color_override("font_outline_color", C_OUTLINE)
	pl.add_theme_constant_override("outline_size", 3)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pl)

	# 汉字行
	var hl := Label.new()
	hl.text = c
	hl.add_theme_font_size_override("font_size", HAN_SIZE)
	hl.add_theme_color_override("font_color", C_IDLE)
	hl.add_theme_color_override("font_outline_color", C_OUTLINE)
	hl.add_theme_constant_override("outline_size", 5)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hl)

	_flow.add_child(box)
	_cells.append({"han": hl, "py": pl, "box": box})


## 判断一段文字是否全是标点（用来决定能不能并到上一格里）
func _is_punct(s: String) -> bool:
	if s == "":
		return false
	for i in s.length():
		var u: int = s.unicode_at(i)
		if (u >= 0x3000 and u <= 0x303F) or (u >= 0xFF00 and u <= 0xFF65) \
				or u == 0x2026 or u == 0x2014 or u == 0x00B7 \
				or (u >= 0x21 and u <= 0x2F) or (u >= 0x3A and u <= 0x40) \
				or (u >= 0x5B and u <= 0x60) or (u >= 0x7B and u <= 0x7E) \
				or u == 0x20:
			continue
		return false
	return true


## 字幕条高度跟随内容自动伸缩：
##   短句（一行）矮一点，不白占屏幕；长句（两行）自动长高，不会被裁掉。
func _fit_panel() -> void:
	# 等两帧让 HFlowContainer 完成换行计算，才能拿到准确的所需高度
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_panel) or not _panel.visible:
		return
	var need: float = _flow.get_combined_minimum_size().y + 22.0
	_panel.offset_top = PANEL_BOT - need
	_panel.offset_bottom = PANEL_BOT
	# 说话人名字跟着字幕条上沿走
	if is_instance_valid(_name_label):
		_name_label.offset_top = PANEL_BOT - need - 27.0
		_name_label.offset_bottom = PANEL_BOT - need - 3.0


## 每格占多少「朗读时长权重」：多音节拼音（数字）和标点要占更多
func _build_weights() -> void:
	_weights.clear()
	var total := 0.0
	for c in _cells:
		var p: String = str(c["py"].text).strip_edges()
		var w: float
		if p == "":
			w = WEIGHT_PUNC
		else:
			w = float(max(1, p.split(" ").size()))
		_weights.append(w)
		total += w
	_cum.clear()
	var acc := 0.0
	for w in _weights:
		acc += w
		_cum.append(acc / max(0.0001, total))


# ================= 每帧推进 =================
func _process(delta: float) -> void:
	if _state != "reading":
		return
	if _idx >= _queue.size():
		return

	# ---- 进度来源：有语音就跟随语音，没语音按时间估算 ----
	var prog := 0.0
	if _has_voice:
		var pos: float = Sfx.story_position()
		if pos >= 0.0:
			prog = pos / _dur
			_t = pos
		else:
			prog = 1.0
			_t = _dur
	else:
		_t += delta
		prog = _t / _dur
	prog = clamp(prog, 0.0, 1.0)

	# ---- 跟读高亮 ----
	var gi := _grid_at(prog)
	if gi != _cur_i and not _all_done:
		_set_current(gi)

	# ---- 读完整句后停留，再下一句 ----
	var done: bool = (prog >= 1.0) and ((not _has_voice) or (not Sfx.story_playing()))
	if not done:
		return
	if not _all_done:
		_highlight_all_done()
	_hold += delta
	var line: Dictionary = _queue[_idx]
	# ★ 有语音时不再叠加脚本里给的 hold —— 那 2.8~4 秒的停顿是给「打字机」留的，
	#   语音本身已经是完整时长，再等就变成 10 秒一句了。只留一点余韵让小朋友消化。
	var need: float
	if _has_voice:
		need = MIN_HOLD
	else:
		need = max(MIN_HOLD, float(line.get("hold", 0.6)))
	if _hold >= need:
		_next()


## 进度 → 第几格
func _grid_at(prog: float) -> int:
	if _cum.is_empty():
		return -1
	for i in _cum.size():
		if prog <= float(_cum[i]):
			return i
	return _cum.size() - 1


func _set_current(i: int) -> void:
	if _cur_i >= 0 and _cur_i < _cells.size() and _cur_i != i:
		_paint(_cur_i, "done")
	_cur_i = i
	if i >= 0 and i < _cells.size():
		_paint(i, "cur")
		# ★ 兜底朗读：没有整句语音时，跟着高亮逐字读出来
		#   （有整句语音的情况下，这里什么都不做 —— 声音由那条 mp3 负责）
		if not _has_voice:
			_speak_cell(str(_cells[i]["han"].text))


## 逐字朗读一个「格」的内容。汉字直接读；数字串（如 "40"）逐字符读出来。
func _speak_cell(t: String) -> void:
	if t == "":
		return
	if t.length() == 1:
		Sfx.speak(t)
		return
	for k in t.length():
		if not is_inside_tree():
			return
		Sfx.speak(t[k])
		await get_tree().create_timer(0.24).timeout


func _paint(i: int, mode: String) -> void:
	if i < 0 or i >= _cells.size():
		return
	var c: Dictionary = _cells[i]
	var hl: Label = c["han"]
	var pl: Label = c["py"]
	match mode:
		"cur":
			hl.add_theme_color_override("font_color", C_CUR)
			pl.add_theme_color_override("font_color", C_PY_CUR)
			hl.add_theme_constant_override("outline_size", 8)
			var s: Vector2 = hl.size
			if s.x > 1.0 and s.y > 1.0:
				hl.pivot_offset = s * 0.5
				hl.scale = Vector2(1.22, 1.22)
		"done":
			hl.add_theme_color_override("font_color", C_DONE)
			pl.add_theme_color_override("font_color", C_PY_DONE)
			hl.add_theme_constant_override("outline_size", 4)
			hl.scale = Vector2.ONE
		_:
			hl.add_theme_color_override("font_color", C_IDLE)
			pl.add_theme_color_override("font_color", C_PY)
			hl.add_theme_constant_override("outline_size", 5)
			hl.scale = Vector2.ONE


func _highlight_all_done() -> void:
	for i in _cells.size():
		_paint(i, "done")
	_all_done = true


# ================= 收尾 =================
func _next() -> void:
	Sfx.stop_story()
	_idx += 1
	if _idx >= _queue.size():
		_hide_and_finish()
		return
	_show_current()


func _hide_and_finish() -> void:
	_state = "wait"
	var g := _gen
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 0.0, 0.22)
	t.tween_callback(func():
		if g != _gen:
			return                  # 已被新剧情顶替，作废
		if is_instance_valid(_panel):
			_panel.visible = false
		if is_instance_valid(_name_label):
			_name_label.visible = false
		_finish())


func _finish() -> void:
	_state = "idle"
	emit_signal("finished")
	if _on_done.is_valid():
		_on_done.call()

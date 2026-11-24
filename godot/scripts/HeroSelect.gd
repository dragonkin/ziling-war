extends Control
## 选人界面 —— 六大主角（金木水火土 + 隐藏雷）
##
## 布局：左侧大立绘预览 + 右侧信息卡（名字/称号/元素/技能/属性条）
## 底部一排 6 个角色头像卡片，左右键或鼠标切换，回车/点击确认
## 立绘缺失时用 Player 同款「程序化人形」按元素配色兜底

const SCREEN_W := 1280.0
const SCREEN_H := 720.0

var _idx := 0
var _cards: Array = []            # 底部头像卡片按钮
var _card_frames: Array = []      # 每张卡片的边框（选中高亮）
var _big_sprite: Texture2D        # 大立绘
var _t := 0.0
var _preview: TextureRect
var _locked_tip: Label

@onready var _root := self


func _ready() -> void:
	Sfx.stop_bgm()
	set_process(true)
	_build()
	# 默认选中上次用的角色
	var i := Heroes.index_of(Game.current_hero)
	_idx = max(0, i)
	_refresh()
	# 初次进入播一个提示音
	Sfx.play("select")
	# ★ 无人值守自检：--shot 时输出立绘来源并截图退出
	if "--shot" in OS.get_cmdline_args() or "--shot" in OS.get_cmdline_user_args():
		_selfcheck()


## 自检：报告 6 角色立绘加载情况 + 截图（导出后排查）
func _selfcheck() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var lines := []
	for k in Heroes.count():
		var h := Heroes.get_hero(k)
		var hid: String = str(h.get("id", ""))
		var p: String = Heroes.art_dir(hid) + "idle.png"
		var ok: bool = ResourceLoader.exists(p)
		lines.append("%s=%s" % [hid, "OK" if ok else "FALLBACK"])
	print("[Shot] heroselect tex: ", " ".join(lines))
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var out := OS.get_user_data_dir() + "/shots/heroselect_export.png"
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	var err := img.save_png(out)
	print("[Shot] err=%d %dx%d -> %s" % [err, img.get_width(), img.get_height(), out])
	get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	# 大立绘轻微呼吸浮动
	if _preview:
		var k: float = 1.0 + 0.02 * sin(_t * 2.4)
		_preview.scale = Vector2(k, k)
	# 选中卡片脉冲
	for i in _card_frames.size():
		var f: ColorRect = _card_frames[i]
		if i == _idx:
			f.color = Color(1.0, 0.85, 0.35, 0.55 + 0.35 * (0.5 + 0.5 * sin(_t * 6.0)))
		else:
			f.color = Color(0, 0, 0, 0)


# ============================================================
#  构建 UI
# ============================================================
func _build() -> void:
	# 背景：深色渐变
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.045, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 顶部标题
	var title := Label.new()
	title.text = "选　择　主　角"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#ffd23c"))
	title.add_theme_color_override("font_outline_color", Color("#5a2a00"))
	title.add_theme_constant_override("outline_size", 9)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 22.0
	title.offset_bottom = 84.0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# 左侧大立绘框
	var frame := Panel.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.10, 0.09, 0.14, 0.85)
	fsb.set_corner_radius_all(20)
	fsb.set_border_width_all(3)
	fsb.border_color = Color(1.0, 0.82, 0.30, 0.55)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.position = Vector2(56, 122)
	frame.size = Vector2(360, 430)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview.offset_left = 16.0
	_preview.offset_top = 16.0
	_preview.offset_right = -16.0
	_preview.offset_bottom = -16.0
	_preview.pivot_offset = Vector2(164, 199)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_preview)

	# 元素标记（立绘框角落）
	# —— 用 label 显示，颜色随角色变化
	var elem_tag := Label.new()
	elem_tag.name = "ElemTag"
	elem_tag.add_theme_font_size_override("font_size", 30)
	elem_tag.add_theme_color_override("font_color", Color(1, 1, 1))
	elem_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	elem_tag.add_theme_constant_override("outline_size", 7)
	elem_tag.position = Vector2(78, 138)
	elem_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(elem_tag)

	# 右侧信息区
	var info := VBoxContainer.new()
	info.name = "Info"
	info.position = Vector2(462, 132)
	info.custom_minimum_size = Vector2(760, 0)
	info.add_theme_constant_override("separation", 10)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)

	# 底部卡片行
	var row := HBoxContainer.new()
	row.name = "CardRow"
	row.add_theme_constant_override("separation", 16)
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 0.0
	row.offset_top = -172.0
	row.offset_bottom = -24.0
	# 居中：用 CenterContainer 包一层更稳
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	for i in Heroes.count():
		var h := Heroes.get_hero(i)
		row.add_child(_make_card(i, h))

	# 底部操作提示
	var tip := Label.new()
	tip.text = "方向键　切换主角　　　回车 / 点击卡片　确认选择　　　Esc　返回主菜单"
	tip.add_theme_font_size_override("font_size", 17)
	tip.add_theme_color_override("font_color", Color(0.86, 0.82, 0.70))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tip.offset_top = -196.0
	tip.offset_bottom = -170.0
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip)

	_locked_tip = Label.new()
	_locked_tip.add_theme_font_size_override("font_size", 18)
	_locked_tip.add_theme_color_override("font_color", Color("#ff9a9a"))
	_locked_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_locked_tip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_locked_tip.offset_top = 92.0
	_locked_tip.offset_bottom = 120.0
	_locked_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_locked_tip.visible = false
	add_child(_locked_tip)


## 底部头像卡片
func _make_card(i: int, h: Dictionary) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(152, 150)
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS

	var elem: String = str(h.get("elem", "fire"))
	var main: Color = Heroes.ELEM_COLORS[elem]["main"]
	var deep: Color = Heroes.ELEM_COLORS[elem]["deep"]
	var locked: bool = not Game.hero_unlocked(str(h.get("id", "")))

	# 卡底
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.16, 0.95) if not locked else Color(0.09, 0.09, 0.10, 0.95)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = deep
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(bg)

	# 选中高亮框（_process 里脉冲）
	var frame := ColorRect.new()
	frame.color = Color(0, 0, 0, 0)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = -5.0
	frame.offset_top = -5.0
	frame.offset_right = 5.0
	frame.offset_bottom = 5.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = -1
	wrap.add_child(frame)
	_card_frames.append(frame)

	# 小立绘
	var tr := TextureRect.new()
	tr.texture = _hero_tex(str(h.get("id", "")))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 8.0
	tr.offset_top = 4.0
	tr.offset_right = -8.0
	tr.offset_bottom = -34.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		tr.modulate = Color(0.25, 0.25, 0.28, 1.0)
	wrap.add_child(tr)

	# 名字
	var nm := Label.new()
	nm.text = "？？？" if locked else str(h.get("name", ""))
	nm.add_theme_font_size_override("font_size", 20)
	nm.add_theme_color_override("font_color", main if not locked else Color(0.5, 0.5, 0.55))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nm.offset_top = -34.0
	nm.offset_bottom = -4.0
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(nm)

	# 点击选择
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func():
		if not locked:
			_idx = i
			Sfx.play("select")
			_refresh()
		else:
			_flash_locked("『%s』需要通过多关后才能解锁哦！" % str(h.get("name", ""))))
	wrap.add_child(btn)

	return wrap


# ============================================================
#  刷新显示
# ============================================================
func _refresh() -> void:
	var h := Heroes.get_hero(_idx)
	var id := str(h.get("id", "huo"))
	var eid: String = str(h.get("elem", "fire"))
	var main: Color = Heroes.ELEM_COLORS[eid]["main"]
	var deep: Color = Heroes.ELEM_COLORS[eid]["deep"]
	var locked: bool = not Game.hero_unlocked(id)

	# 大立绘
	if _preview:
		_preview.texture = _hero_tex(id)
		_preview.modulate = Color(1, 1, 1, 1)

	# 元素标记
	var et := get_node_or_null("ElemTag") as Label
	if et:
		et.text = "《%s》" % str(Heroes.ELEM_COLORS[eid]["name"])
		et.add_theme_color_override("font_color", main)

	# 右侧信息重建
	var info := get_node_or_null("Info") as VBoxContainer
	if info == null:
		return
	for c in info.get_children():
		c.queue_free()

	info.add_child(_big_label(str(h.get("name", "")), 46, main))
	info.add_child(_big_label("—— " + str(h.get("title", "")), 24, Color(0.85, 0.85, 0.9)))
	info.add_child(_spacer(6))

	# 属性条
	info.add_child(_stat_row("血量", int(h.get("hp", 100)), 150.0, Color("#ff6b6b")))
	info.add_child(_stat_row("攻击", int(h.get("dmg", 12)), 20.0, Color("#ffb84a")))
	info.add_child(_stat_row("速度", float(h.get("speed", 1.0)) * 100.0, 130.0, Color("#6bc8ff")))
	info.add_child(_spacer(8))

	# 技能说明
	info.add_child(_big_label("主动技 · " + str(h.get("skill_name", "")), 24, main))
	info.add_child(_small_label(str(h.get("desc", ""))))
	info.add_child(_spacer(4))
	info.add_child(_big_label("必杀技 · " + str(h.get("ult_name", "")), 24, main))
	info.add_child(_small_label(str(h.get("ulta", ""))))

	if locked:
		info.add_child(_spacer(6))
		info.add_child(_small_label("★ 隐藏角色：通关任意 3 关后自动解锁", Color("#ff9a9a")))


func _big_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _small_label(txt: String, col: Color = Color(0.82, 0.80, 0.74)) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(740, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 属性条：label + 进度条
func _stat_row(label_txt: String, val: int, maxv: float, col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var l := Label.new()
	l.text = label_txt
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	l.custom_minimum_size = Vector2(72, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)

	var bar := ProgressBar.new()
	bar.max_value = maxv
	bar.value = clamp(val, 0, maxv)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(300, 20)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.18, 0.16, 0.22, 1)
	bg.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("fill", fg)
	row.add_child(bar)

	return row


# ============================================================
#  输入
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_move(-1)
			KEY_RIGHT, KEY_D:
				_move(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J:
				_confirm()
			KEY_ESCAPE:
				Sfx.play("select")
				get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move(1)


func _move(d: int) -> void:
	var n := Heroes.count()
	var start := _idx
	for _i in n:
		_idx = (_idx + d + n) % n
		if Game.hero_unlocked(str(Heroes.get_hero(_idx).get("id", ""))):
			break
	if _idx == start:
		return
	Sfx.play("select", 1.2, -8.0)
	_refresh()


func _confirm() -> void:
	var h := Heroes.get_hero(_idx)
	var id := str(h.get("id", ""))
	if not Game.hero_unlocked(id):
		_flash_locked("『%s』需要通过多关后才能解锁哦！" % str(h.get("name", "")))
		return
	Sfx.play("levelup", 1.1, -2.0)
	Game.current_hero = id
	Game.hero_hp_max = int(h.get("hp", 100))
	Game.hero_hp = Game.hero_hp_max
	Game.save()
	# 进选关
	get_tree().change_scene_to_file("res://scenes/StageSelect.tscn")


func _flash_locked(msg: String) -> void:
	if _locked_tip == null:
		return
	_locked_tip.text = msg
	_locked_tip.visible = true
	Sfx.play("wrong", 1.3, -8.0)
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_callback(func(): _locked_tip.visible = false)


# ============================================================
#  立绘加载（缺图时程序化兜底，与 Player.gd 同款思路）
# ============================================================
func _hero_tex(id: String) -> Texture2D:
	var base := Heroes.art_dir(id) + "idle.png"
	if ResourceLoader.exists(base):
		var r = load(base)
		if r is Texture2D:
			return r
	# 兜底：按元素配色的程序化人形
	return _fallback_tex(id)


func _fallback_tex(id: String) -> ImageTexture:
	var eid: String = str(Heroes.by_id(id).get("elem", "fire"))
	var main: Color = Heroes.ELEM_COLORS[eid]["main"]
	var deep: Color = Heroes.ELEM_COLORS[eid]["deep"]
	var w := 92
	var h := 166
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(w) * 0.5
	for y in h:
		for x in w:
			var c := Color(0, 0, 0, 0)
			var dx: float = (float(x) - cx) / 20.0
			var dy: float = (float(y) - 30.0) / 24.0
			if dx * dx + dy * dy <= 1.0:
				c = Color("#f2c99a")                     # 头
			elif y > 52 and y < 128 and absf(float(x) - cx) < 26.0:
				c = main                                  # 身（元素主色）
			elif y >= 128 and absf(float(x) - cx) < 24.0:
				c = deep                                  # 腿（元素深色）
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

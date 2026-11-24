extends Control
## 关卡选择：按教材册次分组，一关 = 一个单元

@onready var list: VBoxContainer = $Scroll/List
@onready var back_btn: Button = $TopBar/Back
@onready var info: Label = $TopBar/Info

var _last_book := ""


func _ready() -> void:
	Sfx.stop_bgm()
	info.text = "选择关卡　共 %d 关" % Game.stage_count()
	_style(back_btn, 22)
	back_btn.pressed.connect(func(): Sfx.play("select"); get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	_build()


func _build() -> void:
	for c in list.get_children():
		c.queue_free()
	for i in Game.stage_count():
		var st := Game.get_stage(i)
		var book: String = st.get("book", "")
		if book != _last_book:
			_last_book = book
			var hdr := Label.new()
			hdr.text = "　── %s ──" % (book if book != "" else "其他")
			hdr.add_theme_font_size_override("font_size", 26)
			hdr.add_theme_color_override("font_color", Color("#ffd23c"))
			hdr.custom_minimum_size = Vector2(0, 46)
			list.add_child(hdr)

		var found := Game.stage_found(i)
		var total: int = st.get("charCount", st.get("chars", []).size())
		var row := Button.new()
		row.text = "  第%d关　%s　　已学 %d/%d 字\n  %s" % [
			i + 1, st.get("name", ""), found, total,
			_preview(st)]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(860, 86)
		_style(row, 22)
		var idx := i
		row.pressed.connect(func():
			Sfx.play("select")
			Game.current_stage = idx
			Game.save()
			get_tree().change_scene_to_file("res://scenes/Battle.tscn"))
		list.add_child(row)


func _preview(st: Dictionary) -> String:
	var chars: Array = st.get("chars", [])
	var s := ""
	for i in range(min(14, chars.size())):
		s += chars[i].get("char", "")
	if chars.size() > 14:
		s += "…"
	return s


func _style(b: Button, fs: int) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#fff2d6") if state == "normal" else (Color("#ffe9b8") if state == "hover" else Color("#f5dcae"))
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(3)
		sb.border_color = Color("#c08a40")
		sb.content_margin_left = 20
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color("#3a2a12"))

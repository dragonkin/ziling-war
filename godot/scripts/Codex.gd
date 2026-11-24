extends Control
## 字灵图鉴：展示所有字的掌握度（等级用 ★ 到 👑 表示）

@onready var grid: GridContainer = $Scroll/Grid
@onready var back_btn: Button = $TopBar/Back
@onready var info: Label = $TopBar/Info

const LV_ICON := ["·", "★", "★★", "★★★", "★★★★", "👑"]

func _ready() -> void:
	Sfx.stop_bgm()
	info.text = "字灵图鉴　　精通 %d / %d" % [Game.total_mastered(), Game.total_chars()]
	_style(back_btn)
	back_btn.pressed.connect(func(): Sfx.play("select"); get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	_build()


func _build() -> void:
	for c in grid.get_children():
		c.queue_free()
	grid.columns = 8
	for si in Game.stage_count():
		var st := Game.get_stage(si)
		# 关名分隔条
		var hdr := Label.new()
		hdr.text = "　%s（%s）" % [st.get("name",""), st.get("radical","")]
		hdr.add_theme_font_size_override("font_size", 26)
		hdr.add_theme_color_override("font_color", Color("#ffe08a"))
		hdr.custom_minimum_size = Vector2(0, 44)
		grid.add_child(hdr)
		for k in range(7):
			var sp := Control.new()
			grid.add_child(sp)

		for cd in st.get("chars", []):
			grid.add_child(_make_card(cd))


func _make_card(cd: Dictionary) -> Control:
	var ch: String = cd.get("char", "")
	var lv := Game.level_of(ch)
	var found := lv > 0

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 170)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3a2a5a") if found else Color("#2a2338")
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = Color("#ffd23c") if lv >= 5 else (Color("#8a7ad0") if found else Color("#4a4258"))
	card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)

	var big := Label.new()
	big.text = ch if found else "？"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 54)
	big.add_theme_color_override("font_color", Color("#fff3c4") if found else Color("#6a6280"))
	vb.add_child(big)

	var py := Label.new()
	py.text = cd.get("pinyin", "") if found else "未遇见"
	py.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	py.add_theme_font_size_override("font_size", 16)
	py.add_theme_color_override("font_color", Color("#c8c0e0"))
	vb.add_child(py)

	var lvlab := Label.new()
	lvlab.text = LV_ICON[clamp(lv, 0, 5)]
	lvlab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvlab.add_theme_font_size_override("font_size", 20 if lv < 5 else 26)
	lvlab.add_theme_color_override("font_color", Color("#ffd23c") if lv > 0 else Color("#5a5468"))
	vb.add_child(lvlab)

	card.add_child(vb)
	return card


func _style(b: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#ffd98a") if state == "normal" else (Color("#ffe9b8") if state == "hover" else Color("#f0c060"))
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(3)
		sb.border_color = Color("#8a5a20")
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color("#4a2a08"))

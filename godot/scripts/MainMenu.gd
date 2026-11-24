extends Control
## 主菜单

@onready var btn_start: Button = $Center/Panel/VBox/BtnRow1/BtnStart
@onready var btn_dex: Button = $Center/Panel/VBox/BtnRow1/BtnDex
@onready var btn_reset: Button = $Center/Panel/VBox/BtnRow2/BtnReset
@onready var btn_quit: Button = $Center/Panel/VBox/BtnRow2/BtnQuit
@onready var stat: Label = $Center/Panel/VBox/Stat
@onready var title: Label = $Center/Panel/VBox/Title

## 自动截图模式：命令行加 --autoshot 触发
var _autoshot := false
var _shot_stage := 0
var _title_pulse := 0.0
var _ult_video_check := false

func _process(delta: float) -> void:
	# 标题呼吸
	_title_pulse += delta * 2.6
	if title:
		var k: float = 1.0 + 0.055 * (0.5 + 0.5 * sin(_title_pulse))
		title.scale = Vector2(k, k)

func _ready() -> void:
	Sfx.stop_bgm()
	_autoshot = "--autoshot" in OS.get_cmdline_user_args() or "--autoshot" in OS.get_cmdline_args()	# ★ 调试：--stage=N 直接进入第 N 关（1 基），用于无人值守排查崩溃
	# ⚠️ 参数必须分两遍扫：先收齐所有值（--hero / --stage），再决定跳哪个场景。
	#   老写法在 --stage= 分支里直接 return → `--stage=2 --hero=shui` 时
	#   --hero 永远轮不到解析，实测三个角色全跑成了默认角色（真 bug）。
	var dbg_stage := 0
	var dbg_hero := ""
	for _a in OS.get_cmdline_args():
		if _a.begins_with("--stage="):
			dbg_stage = int(_a.split("=")[1])
		elif _a.begins_with("--hero="):
			dbg_hero = _a.split("=")[1]
		elif _a == "--heroselect":
			print("[Debug] jump to hero select")
			get_tree().change_scene_to_file.call_deferred("res://scenes/HeroSelect.tscn")
			return
		elif _a == "--ultvideo":
			# ★ 调试：--ultvideo 直进战斗并自动放大招（验证 .ogv 是否打进包且能解码）
			print("[Debug] ult video self-check")
			Game.current_stage = 1
			Game.current_hero = "huo"
			_ult_video_check = true
			get_tree().change_scene_to_file.call_deferred("res://scenes/Battle.tscn")
			return
	# 先应用主角（无论是否跳关都要生效）
	if dbg_hero != "" and Heroes.index_of(dbg_hero) >= 0:
		Game.current_hero = dbg_hero
		print("[Debug] hero = %s" % dbg_hero)
	# 再决定是否直进关卡
	if dbg_stage > 0:
		Game.current_stage = dbg_stage - 1
		print("[Debug] jump to stage %d" % dbg_stage)
		get_tree().change_scene_to_file.call_deferred("res://scenes/Battle.tscn")
		return
	if _ult_video_check:
		_ult_check_deferred()
	# 标题呼吸 + 描边
	title.add_theme_color_override("font_color", Color("#ffd23c"))
	title.add_theme_color_override("font_outline_color", Color("#7a3a00"))
	title.add_theme_constant_override("outline_size", 10)
	# 标题呼吸（3 段，避免首尾同值被判为空转）
	_title_pulse = 0.0
	set_process(true)

	for b in [btn_start, btn_dex, btn_reset, btn_quit]:
		_style(b)
	btn_start.pressed.connect(func(): Sfx.play("select"); get_tree().change_scene_to_file("res://scenes/HeroSelect.tscn"))
	btn_dex.pressed.connect(func(): Sfx.play("select"); get_tree().change_scene_to_file("res://scenes/Codex.tscn"))
	btn_reset.pressed.connect(_on_reset)
	if btn_quit:
		btn_quit.pressed.connect(func(): Sfx.play("select"); get_tree().quit())
	_refresh()

	if _autoshot:
		_run_autoshot()


func _refresh() -> void:
	stat.text = "已发现 %d / %d　　精通 %d" % [Game.total_found(), Game.total_chars(), Game.total_mastered()]


## 自动巡场截图（开发用，命令行 --autoshot 触发）
func _run_autoshot() -> void:
	get_tree().create_timer(1.4).timeout.connect(_do_shot.bind("01_menu"))
	get_tree().create_timer(2.6).timeout.connect(_go_stageselect)
	get_tree().create_timer(4.0).timeout.connect(_do_shot.bind("02_stageselect"))
	get_tree().create_timer(4.6).timeout.connect(_go_battle)
	get_tree().create_timer(6.8).timeout.connect(_do_shot.bind("03_battle"))
	get_tree().create_timer(7.4).timeout.connect(_sim_answer)
	get_tree().create_timer(8.0).timeout.connect(_do_shot.bind("04_battle_hit"))
	get_tree().create_timer(9.0).timeout.connect(_go_codex)
	get_tree().create_timer(10.4).timeout.connect(_do_shot.bind("05_codex"))
	get_tree().create_timer(11.0).timeout.connect(_auto_quit)


func _go_stageselect() -> void:
	get_tree().change_scene_to_file("res://scenes/StageSelect.tscn")


func _go_battle() -> void:
	Game.current_stage = 0
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")


func _go_codex() -> void:
	get_tree().change_scene_to_file("res://scenes/Codex.tscn")


func _sim_answer() -> void:
	var b = get_tree().current_scene
	if b and b.has_method("_on_answer"):
		b._on_answer(true, "", "")


func _auto_quit() -> void:
	print("[AutoShot] done")
	get_tree().quit()


func _do_shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	# ⚠️ 导出后 res:// 是只读的 pck，写目录会失败；此功能仅供编辑器内调试
	if not OS.has_feature("editor"):
		return
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://shots")
	var gp := "res://shots/%s.png" % tag
	var err := img.save_png(gp)
	print("[AutoShot] %s err=%d %dx%d" % [tag, err, img.get_width(), img.get_height()])


func _style(b: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#ffd98a") if state == "normal" else (Color("#ffe9b8") if state == "hover" else Color("#f0c060"))
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(4)
		sb.border_color = Color("#8a5a20")
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color("#4a2a08"))
	b.custom_minimum_size = Vector2(0, 56)


func _on_reset() -> void:
	Game.reset_progress()
	_refresh()
	stat.text += "　（进度已重置）"


# ================= 大招视频自检（--ultvideo，导出版专用） =================
## 目的：验证 assets/heroes/{id}/ult_video.ogv 是否真的打进导出版并能正常解码。
## 做法：进关 → 跳过剧情 → 填满字囊 → 放大招 → 采样视频播放状态 + 截画面
func _ult_check_deferred() -> void:
	await get_tree().process_frame
	var b = null
	var guard := 0
	while guard < 300:
		await get_tree().process_frame
		b = get_tree().current_scene
		if b != null and is_instance_valid(b) and b.player != null:
			break
		guard += 1
	if b == null or b.player == null:
		print("[UltCheck] 未拿到 Battle 场景")
		get_tree().quit()
		return
	var st = get_tree().root.get_node_or_null("Story")
	for i in 8:
		if st != null and st.is_busy():
			st.skip()
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.5).timeout
	# 视频素材是否在包里
	var vpath := "res://assets/heroes/%s/ult_video.ogv" % b.player.hero_id
	var exists := ResourceLoader.exists(vpath)
	var is_vid := false
	if exists:
		var r = load(vpath)
		is_vid = r is VideoStream
	print("[UltCheck] ogv_exists=%s is_VideoStream=%s path=%s" % [exists, is_vid, vpath])
	# 放大招
	b.player.energy = b.player.energy_need
	b._do_ult()
	# 采样 10 次（覆盖 8 秒）
	for i in 10:
		await get_tree().create_timer(0.9).timeout
		var cut = b.get_node_or_null("UltCutin")
		if cut == null:
			print("[UltCheck] t=%.1f UltCutin=已收场" % ((i + 1) * 0.9))
			continue
		var vp = null
		for c in cut.get_children():
			if c is VideoStreamPlayer:
				vp = c
				break
		if vp == null:
			print("[UltCheck] t=%.1f 无 VideoStreamPlayer" % ((i + 1) * 0.9))
		else:
			print("[UltCheck] t=%.1f playing=%s pos=%.2f 树暂停=%s" % [
				(i + 1) * 0.9, vp.is_playing(), vp.stream_position, get_tree().paused])
		var img: Image = get_tree().root.get_texture().get_image()
		if img != null:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
			img.save_png("user://shots/ultcheck_%d.png" % i)
	print("[UltCheck] DONE")
	get_tree().quit()

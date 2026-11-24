extends Node2D
## 《字灵战记》街机 ACT —— 三国战记式「横向卷轴推进」
##
## 关卡 = 教材一个单元（该单元全部生字）
## 流程：向右走 → 遇空气墙 → 清完小兵 → 开门继续走 → … → 尽头打 Boss
## 学段决定长度：低年级 1 段 / 中年级 2 段 / 高年级 3 段（洞→竹→宫）

const PLAYER := preload("res://scripts/Player.gd")
const ENEMY := preload("res://scripts/Enemy.gd")
const DROP := preload("res://scripts/CharDrop.gd")
const ITEM_DROP := preload("res://scripts/ItemDrop.gd")   # ★ 战利品（包子/铜钱）
const HAZARD := preload("res://scripts/Hazard.gd")
const TERRAIN := preload("res://scripts/Terrain.gd")
const CHARFX := preload("res://scripts/CharFXPlayer.gd")
const JUICE := preload("res://scripts/Juice.gd")      # ★ 打击感 / 特效库
const ACH := preload("res://scripts/Achievements.gd") # ★ 成就系统（跨局持久）

# ---- 世界几何 ----
const SCREEN_W := 1280.0
const VIEW_H := 720.0
const SEG_W := 2200.0        # 每个场景段落的宽度（约 1.7 屏）
const SEG_GAP := 140.0       # 段落过渡带

# ---- 关卡数据 ----
var stage: Dictionary = {}
var char_pool: Array = []
var _pool_i := 0
var score := 0
var combo := 0
var max_combo := 0
var _combo_timer := 0.0
var finished := false

# ---- 卷轴推进状态 ----
var world_w := SCREEN_W      # 整关世界宽度
var seg_themes: Array = []   # 各段场景名 ["water","bamboo",...]
var seg_bounds: Array = []   # 各段 x 范围 [Vector2(x0,x1), ...]
var ground_segs: Array = []  # 地面高度图 [{x0,x1,gy}, ...]
var cur_seg := 0             # 当前所在段
var gate_x := 0.0            # 当前空气墙位置
var gate_open := true        # 是否已放行
var encounter_waves := 0     # 本卡点剩余波数
var wave_no := 0
var alives: Array = []
var picked_chars: Array = []
var boss_spawned := false
var _boss_down := false          # ★ Boss 已被击败（结算兜底用）
var _spawned_marks: Array = []   # 已触发过的卡点 x
var _mark_done: Array = []       # 各卡点是否已处理（与 _spawned_marks 等长）
var _gate_cols: Array = []       # 封印立柱节点（闪烁由 _process 驱动）
var _gate_pulse := 0.0

# ---- 双击冲刺判定 ----
var _dt_dir := 0              # 上一次点击的方向（1 右 / -1 左 / 0 无）
var _dt_t := 99.0             # 距上一次方向键按下的时间

# ---- 视差立体（多层山脊 + 前景草丛 + 浮尘）----
var _parallax: Array = []     # [{node, factor}]
var _parallax_built := false
var _boss_circle_t := 0.0

# ---- 节点 ----
@onready var bg_rect: TextureRect = $BG/Far
@onready var sky_base: ColorRect = $BG/SkyBase
@onready var world: Node2D = $World
@onready var terrain_node: Node2D = $World/Terrain
@onready var hazard_root: Node2D = $World/Hazards
@onready var enemy_root: Node2D = $World/Enemies
@onready var drop_root: Node2D = $World/Drops
@onready var fx_root: Node2D = $World/FX
@onready var foreground: Node2D = $World/Foreground
var ambience: Node2D            # ★ 环境氛围（常驻动效）
@onready var gate_root: Node2D = $World/Gate
@onready var ui: CanvasLayer = $UI
@onready var stage_label: Label = $UI/HUD/StageLabel
@onready var hp_bar: ProgressBar = $UI/HUD/HPWrap/HP
@onready var hp_label: Label = $UI/HUD/HPWrap/HPLabel
@onready var combo_label: Label = $UI/HUD/ComboLabel
@onready var energy_bar: ProgressBar = $UI/HUD/EnergyWrap/Energy
@onready var energy_label: Label = $UI/HUD/EnergyWrap/ELabel
@onready var picked_label: Label = $UI/HUD/PickedLabel
@onready var wave_label: Label = $UI/HUD/WaveLabel
@onready var ult_hint: Label = $UI/HUD/UltHint
@onready var pickup_banner: Control = $UI/PickupBanner
@onready var pb_char: Label = $UI/PickupBanner/Char
@onready var pb_py: Label = $UI/PickupBanner/Pinyin
@onready var pb_scene: Label = $UI/PickupBanner/Scene
@onready var result_panel: Control = $UI/ResultPanel
@onready var result_title: Label = $UI/ResultPanel/Box/Title
@onready var result_info: Label = $UI/ResultPanel/Box/Info
@onready var result_btn: Button = $UI/ResultPanel/Box/Btn
@onready var cam: Camera2D = $Cam
@onready var toast: Label = $UI/Toast
@onready var boss_bar_wrap: Control = $UI/HUD/BossWrap
@onready var boss_bar: ProgressBar = $UI/HUD/BossWrap/BossHP
@onready var boss_name: Label = $UI/HUD/BossWrap/BossName
@onready var progress_bar: ProgressBar = $UI/HUD/ProgressWrap/Progress
@onready var progress_label: Label = $UI/HUD/ProgressWrap/PLabel

const BOSS_NAMES := ["墨魔元帅", "石狮守将", "卷龙妖君"]
## 按场景主题的 Boss 名（每个主题 2 个，与 roster 素材一一对应）
const BOSS_NAMES_BY_THEME := {
	"water":  ["瀑魔·涛将", "沧江龙君"],
	"bamboo": ["竹煞·虎威", "古木妖王"],
	"palace": ["青铜镇将", "金猊天子"],
	"lava":   ["熔岩巨灵", "炎鳞赤龙"],
	"ruins":  ["残甲亡将", "城垣石魔"],
	"sky":    ["玉阙天将", "雷羽神鹰"],
}
const THEME_NAMES := {
	"water": "水帘洞", "bamboo": "青竹林", "palace": "金銮殿",
	"lava": "熔岩窟", "ruins": "古城墙", "sky": "云端天梯",
}
const THEME_SKY := {
	"water": Color("#7fa7c9"),
	"bamboo": Color("#9fc08c"),
	"palace": Color("#e6c98f"),
	"lava": Color("#5c2a22"),
	"ruins": Color("#8d92a0"),
	"sky": Color("#bcd3e8"),
}
## ★ 各主题的主色（Boss 登场演出 / 光束 / 高亮用）
const THEME_EDGE_COLORS := {
	"water":  Color("#5fb8e8"),
	"bamboo": Color("#7fce5f"),
	"palace": Color("#f0c44a"),
	"lava":   Color("#ff6a3c"),
	"ruins":  Color("#b8a88c"),
	"sky":    Color("#9ad8ff"),
}
## 每个场景绑定的环境机关
const THEME_HAZARDS := {
	"water": ["water", "water", "arrow"],
	"bamboo": ["arrow", "rock"],
	"palace": ["arrow", "fire"],
	"lava": ["rock", "fire", "fire"],
	"ruins": ["arrow", "arrow", "rock"],
	"sky": ["water", "rock"],
}
## ★ 可破坏木箱 / 竹筒的配色（按场景，让箱子融进环境又不至于看不见）
const CRATE_COLORS := {
	"water":   Color("#8a6a42"),
	"bamboo":  Color("#9db85a"),
	"palace":  Color("#b08a3c"),
	"lava":    Color("#7a4a34"),
	"ruins":   Color("#8c8478"),
	"sky":     Color("#a8b8cc"),
}

var player: Node2D
var _hitstop_t := 0.0
var _rage_bg: ColorRect        # ★ 怒气条（动态创建）
var _rage_fill: ColorRect
var juice: Node2D                 # ★ 打击感 / 特效库
var _foot_t := 0.0                # 脚步扬尘计时
var _crates: Array = []           # ★ 可破坏的木箱 [{node, x, hp, col, th}]
var _ult_ready_notified := false  # 字囊集满时只提醒一次
var _ult_ready := false           # 字囊是否已满（驱动必杀提示呼吸）
var _hint_pulse := 0.0
var _hint_pulse_t := 0.0
var _ult_busy := false            # ★ 大招演出中（防止连按 U 叠出两套特效）

# ★ 暂停菜单（Esc 弹出：继续 / 回主菜单 / 缩小窗口）—— 动态创建，不动 tscn
var _pause_panel: CanvasLayer = null
var _paused := false
## ★ 摄像机「解冻缓入」进度 0→1 —— 穿梭冻结结束后用 0.45s 爬坡恢复跟随，
##   避免解冻瞬间以原速猛追玩家造成第二次甩镜（用户反馈的「画面非常抖动」）
##   初始 1.0 = 满速跟随；只有穿梭冻结开始时才清零，逼出一次缓入。
var _cam_resume_ease := 1.0


## 大字提示闪一下（玩家按了 U 但字囊没满时用来强调）
func _ult_hint_pulse() -> void:
	_hint_pulse_t = 0.55


## ★ 暂停期间的 Esc 捕获器（用户反馈「连按退出键会卡住」的修复件）
##   为什么需要它：Battle 根节点必须保持默认 process_mode（INHERIT）——
##   它的子节点（World/玩家/敌人）全靠 INHERIT，一旦把根改成 WHEN_PAUSED，
##   恢复游戏后整棵树就"仅暂停时处理"= 全场停摆（画面冻住、按键全失效）。
##   所以另起一个 ALWAYS 的小节点专门收暂停期间的 Esc。
class PauseEscCatcher extends Node:
	var host: Node = null

	func _input(e: InputEvent) -> void:
		if not (e is InputEventKey) or not e.pressed or e.echo:
			return
		if e.keycode != KEY_ESCAPE:
			return
		if host == null or not is_instance_valid(host):
			return
		if host.get("_paused"):
			host._resume_game()
			get_viewport().set_input_as_handled()


func _ready() -> void:
	Sfx.play_bgm()
	stage = _load_stage(Game.current_stage)
	_build_world()
	_apply_theme(seg_themes[0])
	_spawn_player()
	_setup_juice()
	_spawn_crates()
	_build_shop_ui()
	_roll_stage_buff()
	_refresh_hud()
	Story.setup(ui)
	# 开场剧情结束后才允许操作
	_paused_for_story = true
	Story.finished.connect(_on_story_finished)
	Story.play(StoryScript.build_intro(stage, seg_themes[0]), Callable(self, "_on_intro_done"))


## 建特效库（震动 / 飘字 / 光柱 / 烟花…）
func _setup_juice() -> void:
	juice = JUICE.new()
	juice.name = "Juice"
	world.add_child(juice)
	juice.setup(cam, fx_root, self)
	if "--shot" in OS.get_cmdline_args():
		_auto_shot()


## ★ 自检截图：命令行加 --shot 时，进入关卡后自动截图存到 user:// 并退出。
##   用于验证「导出版资源是否完整」（导出包 res:// 只读，无法存桌面）
func _auto_shot() -> void:
	await get_tree().create_timer(1.4).timeout
	# --shotlong：连跳两句，拍到最长的那句（验证注音换行排版）
	if "--shotlong" in OS.get_cmdline_args():
		Story.skip()
		await get_tree().create_timer(0.35).timeout
		Story.skip()
		await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	var f := dir + "/shot_stage%d.png" % (Game.current_stage + 1)
	var err := img.save_png(f)
	print("[Shot] err=%d %dx%d -> %s" % [err, img.get_width(), img.get_height(), ProjectSettings.globalize_path(f)])
	print("[Shot] hero_tex=%s enemy_count=%d" % [
		str(player.art_debug_info()) if player and player.has_method("art_debug_info") else "n/a",
		enemy_root.get_child_count() if enemy_root else -1])
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


var _paused_for_story := false
var _stage_started := false


func _on_intro_done() -> void:
	_paused_for_story = false
	_stage_started = true


func _on_story_finished() -> void:
	_paused_for_story = false


## 顿帧
func _hitstop(dur: float) -> void:
	_hitstop_t = max(_hitstop_t, dur)


func _apply_hitstop(delta: float) -> void:
	if _hitstop_t > 0.0:
		_hitstop_t -= delta
		Engine.time_scale = 0.12 if _hitstop_t > 0.0 else 1.0
	else:
		Engine.time_scale = 1.0


func _load_stage(idx: int) -> Dictionary:
	var path := "res://data/units.json"
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d and d.has("stages") and idx < d["stages"].size():
			return d["stages"][idx]
	var p2 := "res://data/stages.json"
	if FileAccess.file_exists(p2):
		var d2 = JSON.parse_string(FileAccess.get_file_as_string(p2))
		if d2 and d2.has("stages") and idx < d2["stages"].size():
			return d2["stages"][idx]
	return {}


# ================= 世界构建 =================
## 各场景的地面高度模板（相对基准 y=620）
## 数值 = 该段地面 y（越小越高）；用「段列表」拼出楼梯 / 平台 / 高低起伏
const GROUND_TEMPLATES := {
	"water":  [0, -52, -52, -104, -104, -104, -44, 0],
	"bamboo": [0, -40, -40, -88, -88, -40, 16, 0],
	"palace": [0, 0, -70, -70, -70, 22, 22, -38],
	"lava":   [0, -74, -74, -22, -22, -96, -96, 0],
	"ruins":  [0, -56, -56, -56, -16, -16, -82, 0],
	"sky":    [0, -62, -126, -126, -62, -62, -142, 0],
}
## ★ 2026-09 地面基准从 600 抬到 520：
##   原来 600 让地面只剩 600~720 的窄带，且被字幕条(620~720)完全遮住 → 玩家看不到脚下的地。
##   抬到 520 后地面有 520~640 的可见带，角色走路/台阶一目了然。
const GROUND_BASE := 520.0


func _build_world() -> void:
	var sid: int = abs(int(stage.get("id", 1)))
	# ★ 2026-09 关卡大幅加长：学段决定段落数（三倍）
	#   1-20 单段 → 三段 / 21-45 双段 → 三段 / 46+ 三段 → 四段
	#   保证任何一关都至少有 3 段 × 3 卡点 × 多波小兵，节奏充足
	var seg_count := 1
	if sid > 45:
		seg_count = 4
	elif sid > 20:
		seg_count = 3
	else:
		seg_count = 3
	var pool := ["water", "bamboo", "palace", "lava", "ruins", "sky"]
	# 场景起点：用质数步进轮转，让 61 关的场景序列尽量不重复
	# （原来 sid % 6 会让每 6 关完全重演一遍）
	var n := pool.size()
	var step := 5   # 与 6 互质 → 轮转遍历所有起点
	var start_i: int = (sid * step) % n
	# 段数 > 1 时，段间跳跃也用质数，避免出现相同的段组合
	var seg_step := 2 if seg_count == 2 else 3
	if seg_count == 4 and sid % 2 == 0:
		seg_step = 5
	if seg_count == 3 and sid % 2 == 0:
		seg_step = 4
	seg_themes = []
	for i in seg_count:
		seg_themes.append(pool[(start_i + i * seg_step) % n])
	# 计算各段 x 范围
	seg_bounds = []
	var x := 0.0
	for i in seg_count:
		seg_bounds.append(Vector2(x, x + SEG_W))
		x += SEG_W + SEG_GAP
	world_w = x - SEG_GAP
	# 布置卡点：每段 3 个（0.25 / 0.58 / 0.90）—— 波次更密，关卡更饱满
	_spawned_marks = []
	for i in seg_count:
		var b: Vector2 = seg_bounds[i]
		_spawned_marks.append(b.x + SEG_W * 0.25)
		_spawned_marks.append(b.x + SEG_W * 0.58)
		_spawned_marks.append(b.x + SEG_W * 0.90)
	boss_x = world_w - 260.0
	cur_seg = 0
	gate_x = 0.0
	gate_open = true
	encounter_waves = 0
	wave_no = 0
	char_pool = stage.get("chars", []).duplicate()
	char_pool.shuffle()
	result_panel.visible = false
	pickup_banner.visible = false
	boss_bar_wrap.visible = false
	cam.limit_left = 0
	cam.limit_right = int(world_w)
	cam.limit_top = 0
	cam.limit_bottom = int(VIEW_H)
	cam.limit_smoothed = true
	_stage_total_waves = max(1, _spawned_marks.size() - 1)
	_build_terrain()
	_mark_done = []
	_waves_cleared = 0


## 按段落生成地面高度图：每段切成 8 小格，套模板
func _build_terrain() -> void:
	for c in terrain_node.get_children():
		c.queue_free()
	ground_segs = []
	var per := 8
	for i in seg_bounds.size():
		var b: Vector2 = seg_bounds[i]
		var theme: String = seg_themes[i]
		var tpl: Array = GROUND_TEMPLATES.get(theme, GROUND_TEMPLATES["water"])
		var slot := (b.y - b.x) / float(per)
		for k in per:
			var x0: float = b.x + k * slot
			var x1: float = x0 + slot
			var gy: float = GROUND_BASE + float(tpl[k % tpl.size()])
			ground_segs.append({"x0": x0, "x1": x1, "gy": gy, "theme": theme})
		# 段落之间的过渡带：铺平
		if i < seg_bounds.size() - 1:
			var nx: float = b.y
			ground_segs.append({"x0": nx, "x1": nx + SEG_GAP, "gy": GROUND_BASE, "theme": theme})
	# 用一个 Terrain 节点统一渲染（它内部按段换色需要拆分，这里改为整体一个 + 分区上色）
	_terrain = TERRAIN.new()
	terrain_node.add_child(_terrain)
	_terrain.setup(ground_segs, seg_themes[0])
	# ★ 层次：BG(-1000) < Terrain(-20) < Ambience(-10) < 角色(int(y)≥392)
	_terrain.z_index = -20


var _terrain: Node = null


## 当前 x 处的地面 y（供机关等使用）
func ground_at(x: float) -> float:
	if _terrain and _terrain.has_method("ground_y_at"):
		return _terrain.ground_y_at(x)
	return GROUND_BASE


var boss_x := 0.0
var _stage_total_waves := 1
var _waves_cleared := 0


func _apply_theme(theme_name: String) -> void:
	var p := "res://assets/bg3/%s_bg.png" % theme_name
	if not ResourceLoader.exists(p):
		p = "res://assets/bg2/%s_far.png" % theme_name
	if not ResourceLoader.exists(p):
		p = "res://assets/bg/stage1_water.png"
	if ResourceLoader.exists(p):
		var t: Texture2D = load(p)
		bg_rect.texture = t
		# 背景横向平铺：贴图按世界宽度铺满
		bg_rect.size = Vector2(world_w, VIEW_H)
		bg_rect.position = Vector2(0, 0)
		sky_base.color = THEME_SKY.get(theme_name, Color("#7fa7c9"))
	_wire_ambience(theme_name)
	# 视差立体层（只建一次）：多层山脊 + 前景草丛 + 浮尘
	_build_parallax()


## ★ 让场景「活」起来：换主题时重建该场景的常驻环境动效
## 用 load() 而非 class_name 直接引用（--script 模式下 class_name 不可见）
const AMBIENCE_SCRIPT := "res://scripts/Ambience.gd"

func _wire_ambience(theme_name: String) -> void:
	if ambience == null or not is_instance_valid(ambience):
		var scr = load(AMBIENCE_SCRIPT)
		if scr == null:
			return
		ambience = Node2D.new()
		ambience.set_script(scr)
		ambience.name = "Ambience"
		ambience.z_index = -10
		world.add_child(ambience)
	if ambience.has_method("setup"):
		ambience.call("setup", theme_name, world_w, foreground)


func _spawn_player() -> void:
	player = PLAYER.new()
	player.set_script(load("res://scripts/Player.gd"))
	player.position = Vector2(260, ground_at(260.0))
	world.add_child(player)
	player.X_MAX = world_w - 60.0
	player.terrain = _terrain
	player.hp_changed.connect(_on_hp_changed)
	player.energy_changed.connect(_on_energy_changed)
	player.char_picked.connect(_on_char_picked)
	player.died.connect(_on_player_died)
	# ★ 怒气狂暴
	player.rage_changed.connect(_on_rage_changed)
	player.rage_burst.connect(_on_rage_burst)
	# ★ 幻影接力落点：在分身/真身落点补一次横扫判定
	player.relay_landed.connect(_on_relay_landed)
	_build_rage_bar()
	player.z_index = int(player.position.y)


## ★ 怒气条：贴在血条正下方（代码动态建，不动场景文件）
func _build_rage_bar() -> void:
	var wrap := hp_bar.get_parent() as Control
	if wrap == null:
		return
	_rage_bg = ColorRect.new()
	_rage_bg.color = Color(0.16, 0.10, 0.10, 0.85)
	_rage_bg.position = hp_bar.position + Vector2(0, hp_bar.size.y + 5.0)
	_rage_bg.size = Vector2(hp_bar.size.x, 9.0)
	_rage_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_rage_bg)
	_rage_fill = ColorRect.new()
	_rage_fill.color = Color(1.0, 0.45, 0.20, 0.0)      # 空怒时隐形
	_rage_fill.position = Vector2(2, 2)
	_rage_fill.size = Vector2(0, 5.0)
	_rage_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rage_bg.add_child(_rage_fill)


func _on_rage_changed(v: int, max_v: int) -> void:
	if _rage_fill == null:
		return
	var k: float = float(v) / maxf(1.0, float(max_v))
	_rage_fill.size.x = (_rage_bg.size.x - 4.0) * k
	_rage_fill.color.a = 0.25 + 0.75 * k
	# 接近满怒闪一下提示"要爆了"
	if k >= 0.85:
		_rage_fill.color = Color(1.0, 0.75, 0.25)       # 金→临爆
	else:
		_rage_fill.color = Color(1.0, 0.45, 0.20)


## ★ 狂暴爆发全屏演出：红闪 + 大字 + 强震
## ★ 幻影接力落点横扫：穿梭每次「到位」都在落点补一次判定
##   否则穿梭只是视觉演出，路上敌人一点血都不掉（白穿一趟）
func _on_relay_landed(x: float) -> void:
	if player == null or not is_instance_valid(player) or player.dead:
		return
	if finished:
		return
	var base_y: float = player.position.y
	var col: Color = player.elem_color() if player.has_method("elem_color") else Color(0.6, 0.85, 1.0)
	var hit_any := false
	for e in enemy_root.get_children():
		if not is_instance_valid(e) or e.dead:
			continue
		# 接力是横向高速掠过 → 判定按「横向窄带 + 纵向放宽」
		if absf(e.position.x - x) > 120.0:
			continue
		if absf(e.position.y - base_y) > 240.0:
			continue
		var hdmg: int = player.hero_dmg() if player.has_method("hero_dmg") else 12
		var dmg: int = int(float(hdmg + randi_range(2, 7)) * player.dmg_mult())
		var dir: int = sign(e.position.x - x)
		if dir == 0:
			dir = player.facing
		e.take_damage(dmg, dir)
		if e.has_method("knock_back"):
			e.knock_back(dir, 130.0)
		if juice != null:
			juice.impact(e.position + Vector2(0, -110), col, false,
					Vector2(dir, -0.4))
			juice.damage_number(e.position + Vector2(0, -170), dmg, false)
		hit_any = true
	if hit_any:
		combo += 1
		max_combo = max(max_combo, combo)
		_combo_timer = 1.8
		_update_combo()
		if player.has_method("add_rage"):
			player.add_rage(6)
		# ★ 轻反馈：穿梭是连续演出，不能每段都来一次全屏强震（否则画面抖）
		_shake(0.20, Vector2(sign(player.facing), -0.3))
		_hit_fx_light(x, base_y, col)


## 穿梭落点的轻量命中特效（不叠震屏，只出火花）
func _hit_fx_light(x: float, y: float, col: Color) -> void:
	if juice == null:
		return
	juice.impact(Vector2(x, y - 120.0), col, false, Vector2(0, -0.6))


func _on_rage_burst() -> void:
	if juice != null:
		juice.flash(Color(1.0, 0.25, 0.15, 0.5), 0.42)
		juice.zoom_punch(0.08, 0.5)
	_shake(1.5, Vector2(0, -0.4))
	_unlock_ach("rage")
	Sfx.play("levelup", 0.9, 1.5)
	# 大字横幅「狂暴！」
	var cl := CanvasLayer.new()
	cl.layer = 42
	add_child(cl)
	var lab := Label.new()
	lab.text = "怒 气 爆 发 ！"
	lab.add_theme_font_size_override("font_size", 72)
	lab.add_theme_color_override("font_color", Color(1.0, 0.42, 0.30))
	lab.add_theme_color_override("font_outline_color", Color(0.35, 0.03, 0.02))
	lab.add_theme_constant_override("outline_size", 16)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_CENTER)
	lab.position = Vector2(640 - 300, 300)
	lab.size = Vector2(600, 90)
	lab.pivot_offset = Vector2(300, 45)
	lab.scale = Vector2(2.2, 2.2)
	lab.modulate.a = 0.0
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(lab)
	var t := cl.create_tween()
	t.set_parallel(true)
	t.tween_property(lab, "modulate:a", 1.0, 0.12)
	t.tween_property(lab, "scale", Vector2.ONE, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.85)
	t.chain().tween_property(lab, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(cl.queue_free)


func _refresh_hud() -> void:
	stage_label.text = "%s" % stage.get("name", "关卡")
	wave_label.text = "第 %d 段 · %s" % [cur_seg + 1, THEME_NAMES.get(seg_themes[cur_seg] if cur_seg < seg_themes.size() else "water", "")]
	hp_bar.max_value = player.max_hp if player else 100
	hp_bar.value = player.hp if player else 100
	hp_label.text = "字灵战士　%d/%d" % [int(hp_bar.value), int(hp_bar.max_value)]
	energy_bar.max_value = player.energy_need if player else 5
	energy_bar.value = player.energy if player else 0
	energy_label.text = "字囊 %d/%d" % [int(energy_bar.value), int(energy_bar.max_value)]
	picked_label.text = "已拾字：%s" % ("".join(picked_chars) if picked_chars else "—")
	var can: bool = player.can_ult() if player else false
	_ult_ready = can
	# ★ 必杀提示「常驻」显示，不再只在集满时才冒出来。
	#   玩家反馈「怎么释放大招，释放不来」—— 根因是提示不够：没集满时界面上
	#   没有任何地方告诉他「按 U」。现在没集满写清还差几个，集满则高亮闪烁。
	ult_hint.visible = true
	if can:
		ult_hint.text = "★ 字囊集满！按 U 放必杀技 ★"
		ult_hint.add_theme_color_override("font_color", Color("#ffd23c"))
	else:
		var need: int = 5
		var have: int = 0
		if player != null:
			need = player.energy_need
			have = player.energy
		ult_hint.text = "集满 %d 个字按 U 放必杀（还差 %d 个）" % [need, need - have]
		ult_hint.add_theme_color_override("font_color", Color("#a9c0d2"))
	# ★ 字囊没满时，把「还差几个」直接写在标签上，别让小朋友自己数
	if player != null and not can:
		energy_label.text = "字囊 %d/%d（还差 %d 个）" % [
			player.energy, player.energy_need, player.energy_need - player.energy]
	if can and not _ult_ready_notified:
		_ult_ready_notified = true
		_show_toast("字囊集满！按 U 放必杀技", Color("#ffd23c"))
		Sfx.play("correct", 1.0, -4.0)
	elif not can:
		_ult_ready_notified = false
	if progress_bar:
		progress_bar.max_value = 100.0
		progress_bar.value = clamp(progress_ratio() * 100.0, 0.0, 100.0)
	if progress_label:
		progress_label.text = "推进 %d%%" % int(clamp(progress_ratio() * 100.0, 0.0, 100.0))


func progress_ratio() -> float:
	if player == null:
		return 0.0
	return clamp(player.position.x / max(1.0, world_w), 0.0, 1.0)


# ================= 卡点 / 空气墙 =================
func _check_marks() -> void:
	if player == null or finished:
		return
	# ★ 无墙版兜底：玩家可以一路冲到终点而不打怪 ——
	#   走到 Boss 战场附近就必须出 Boss，否则关卡永远结束不了。
	if not boss_spawned and player.position.x >= boss_x - 220.0:
		_apply_theme(seg_themes[seg_themes.size() - 1])
		_spawn_boss()
		return
	# ★ Boss 已登场后不再触发新卡点 ——
	#   否则「最后一关段的第 3 个卡点(x=seg末-0.1*SEG_W)」会落在 boss_x 之后，
	#   玩家刚打完 8 波、Boss 都出来了，往前走又被门拦住再刷一波怪（真 bug）。
	if boss_spawned:
		return
	if _mark_done.size() < _spawned_marks.size():
		_mark_done.resize(_spawned_marks.size())
	var px: float = player.position.x
	for i in _spawned_marks.size():
		var mx: float = _spawned_marks[i]
		if not _mark_done[i] and px >= mx - 24.0:
			_mark_done[i] = true
			_show_toast("字灵来了！", Color("#ff9a5a"))
			_start_encounter(i)


## ★ 2026-09-24 用户要求：**去掉封印墙（空气墙）**
##   原设计「关门 → 必须清完怪才放行」在横版清关里很别扭 ——
##   玩家走到某处突然被一堵墙拦住、想走走不了，体验上是"莫名其妙被挡住"。
##   改为「到点刷怪，但不封路」：敌人从前方涌来，玩家想打就打、想冲就冲。
##   保留的约束只有世界右边界（尽头是 Boss）。
func _gate_close(_x: float) -> void:
	# 空实现：保留函数名以免其它调用点报错（旧存档 / 演出回调可能还引用）
	pass


## ★ 2026-09-24 已废弃：封印墙视觉整体移除（用户要求去掉空气墙）。
##   保留空实现，避免遗留调用点报错。
func _build_gate_visual(_x: float) -> void:
	_gate_cols = []
	_gate_pulse = 0.0


func _gate_open() -> void:
	gate_open = true
	_gate_cols = []
	# ★ 无墙版：不再有「封印解除」的开门提示（本来就没关门）


func _start_encounter(mark_i: int) -> void:
	# ★ 2026-09 每卡点 2~3 波（原来 1~2 波），关卡更持久
	encounter_waves = 2 + (mark_i % 2)      # 2~3 波
	wave_no = 0
	alives.clear()
	_start_wave(1)


func _start_wave(_n: int) -> void:
	wave_no += 1
	# ★ 每波 4~7 个兵（原来 2~4 个），靠后关卡更多
	var count := 4 + wave_no + cur_seg + int(cur_seg * 0.5)
	alives.clear()
	var th: String = seg_themes[clamp(cur_seg, 0, seg_themes.size() - 1)]
	# ★ 无墙版：敌人一律刷在玩家【前方】一片带状区域（左右各留余量），
	#   玩家想打就停下打、想冲就直接冲过去 —— 不再有任何封路。
	var px: float = player.position.x if player != null else 0.0
	var x_lo: float = px + 260.0          # 离玩家稍远，避免"脸上突然冒怪"
	var x_hi: float = min(x_lo + 760.0, world_w - 120.0)
	if x_hi < x_lo + 80.0:
		x_lo = max(80.0, px - 320.0)      # 已接近终点（Boss 区）→ 改为在玩家两侧铺开
		x_hi = min(world_w - 80.0, px + 320.0)
	var span: float = max(1.0, x_hi - x_lo)
	for i in count:
		var ci := _next_char()
		var hp := 32 + cur_seg * 10 + wave_no * 8
		# 分散站位：纵深分 3 层 + 横向错开，避免叠在一起
		var lane_i: int = i % 3
		var fx: float = (float(i) + 0.5) / float(count)
		var spawn_x: float = x_lo + span * (fx * 0.86) + randf_range(-30, 30)
		spawn_x = clamp(spawn_x, 60.0, world_w - 60.0)
		var lane: float = 420.0 + lane_i * 78.0 + randf_range(-14, 14)
		# ★ 精英怪：每波的第二波起，压轴刷 1 只（第 2 关起才出现，别开头就劝退）
		var elite := (i == count - 1) and wave_no >= 2 and cur_seg >= 1
		if elite:
			hp = int(hp * 2.4)
		var e = ENEMY.create(Vector2(spawn_x, lane), hp, false, ci, 0, th,
			_pick_mob_type(i), elite)
		enemy_root.add_child(e)
		e.set_target(player)
		e.terrain = _terrain
		e.enemy_died.connect(_on_enemy_died)
		alives.append(e)


## 随机挑选小兵类型：普通 / 跳跳怪 / 冲撞兵 混合（新玩法，前期多普通，后期多特殊）
func _pick_mob_type(i: int) -> String:
	# 前 3 个纯普通；第 4 个起混入特殊兵种
	if i < 3:
		return "normal"
	var r := randi() % 10
	if cur_seg >= 2 and r < 2:
		return "charger"
	if r < 4:
		return "hopper"
	return "normal"


## Boss 召唤的 2 只助阵小兵（由 Enemy.boss_state=summon 调用）
func boss_spawn_minions(origin: Vector2) -> void:
	if finished:
		return
	var th: String = seg_themes[seg_themes.size() - 1]
	for i in 2:
		var ci := _next_char()
		var hp := 28 + cur_seg * 8
		var sx: float = origin.x + (i * 150.0 - 75.0) + randf_range(-20, 20)
		var e = ENEMY.create(Vector2(sx, ground_at(sx) - 8.0), hp, false, ci, 0, th,
			"hopper" if i == 0 else "charger")
		enemy_root.add_child(e)
		e.set_target(player)
		e.terrain = _terrain
		e.enemy_died.connect(_on_enemy_died)
		alives.append(e)


func _spawn_boss() -> void:
	boss_spawned = true
	boss_bar_wrap.visible = true
	alives.clear()
	var ci := _next_char()
	# Boss 按「最后一关段」的场景主题选，用关卡 id 决定 A/B 型
	var last_th: String = seg_themes[seg_themes.size() - 1]
	var sid2: int = abs(int(stage.get("id", 1)))
	# 用 (id/6) 决定 A/B，保证同场景在不同关也能换 Boss
	var bidx: int = (sid2 / 6 + sid2) % 2
	var e = ENEMY.create(Vector2(boss_x, ground_at(boss_x) - 60.0),
		220 + seg_themes.size() * 60, true, ci, bidx, last_th)
	enemy_root.add_child(e)
	e.set_target(player)
	e.terrain = _terrain
	e.enemy_died.connect(_on_enemy_died)
	e.boss_summon_requested.connect(boss_spawn_minions)
	alives.append(e)
	boss_bar.max_value = e.max_hp
	boss_bar.value = e.hp
	var bname: String = boss_name_for(last_th, bidx)
	boss_name.text = bname
	Sfx.play("boss")
	# ★ BOSS 震撼登场演出：骤暗 + 立绘推近 + 光带 + 名字砸下 + 白闪 + 震屏
	if juice != null:
		var bcol: Color = THEME_EDGE_COLORS.get(last_th, Color("#ff5a5a"))
		juice.boss_entrance(bname, ui, bcol, _boss_texture(last_th, bidx))
	# Boss 对峙剧情
	_paused_for_story = true
	Story.play(StoryScript.build_boss_intro(bname, stage.get("name", "")),
		Callable(self, "_on_mid_done"))


## 按场景主题 + A/B 型取 Boss 名
func boss_name_for(theme: String, bidx: int) -> String:
	var pair: Array = BOSS_NAMES_BY_THEME.get(theme, BOSS_NAMES)
	return pair[bidx % pair.size()]


## ★ 取 Boss 立绘（用于登场演出推近）；缺失则返回 null（演出自动跳过立绘）
func _boss_texture(theme: String, bidx: int) -> Texture2D:
	var suf: String = "a" if bidx % 2 == 0 else "b"
	# 优先新版：res://assets/bosses/{theme}_{a|b}.png
	for p in [
		"res://assets/bosses/%s_%s.png" % [theme, suf],
		"res://assets/roster/boss_%s_%s.png" % [theme, suf],
	]:
		if ResourceLoader.exists(p):
			var r = load(p)
			if r is Texture2D:
				return r
	return null


func _next_char() -> Dictionary:
	if char_pool.is_empty():
		char_pool = stage.get("chars", []).duplicate()
		char_pool.shuffle()
	if char_pool.is_empty():
		return {"char": "字", "pinyin": ""}
	var c = char_pool[_pool_i % char_pool.size()]
	_pool_i += 1
	return c


# ================= 事件 =================
func _on_enemy_died(_e: Node, ci: Dictionary) -> void:
	var alive := []
	for e in alives:
		if is_instance_valid(e) and not e.dead:
			alive.append(e)
	alives = alive
	combo += 1
	max_combo = max(max_combo, combo)
	_combo_timer = 2.2
	score += 100 * combo
	_update_combo()
	# 爆字
	var pos: Vector2 = _e.position + Vector2(0, -90)
	var d = DROP.create(pos, ci)
	drop_root.add_child(d)
	d.picked.connect(_on_drop_picked)
	_spawn_burst(pos, Color("#ffd23c"), 20)
	# ★ 三国战记式掉宝：概率掉包子（回血）/ 铜钱（加分）
	#   低血（<40%）时包子概率翻倍 —— 雪中送炭，救急的设计惯例
	#   ★ 精英怪必掉一件战利品（打精英有回报，激励优先集火）
	var e_elite: bool = bool(_e.get("is_elite"))
	if not _e.is_boss:
		if e_elite:
			_spawn_item(pos, "bun" if randf() < 0.55 else "coin")
			if randf() < 0.35:
				_spawn_item(pos + Vector2(46, 0), "coin")   # 富得流油：35% 双掉
		else:
			var hp_ratio: float = float(player.hp) / maxf(1.0, float(player.max_hp)) if player else 1.0
			var bun_rate: float = 0.22 if hp_ratio < 0.4 else 0.12
			# ★ 词条「财气」：铜钱掉率翻倍（0.30 → 0.60）
			var coin_rate: float = 0.30 * (2.0 if str(stage_buff.get("id", "")) == "coin" else 1.0)
			var r := randf()
			if r < bun_rate:
				_spawn_item(pos, "bun")
			elif r < bun_rate + coin_rate:
				_spawn_item(pos, "coin")
	if e_elite:
		score += 300
		if player != null and player.has_method("add_rage"):
			player.add_rage(15)   # 打掉精英怒气大补
	# Boss 被击败 → 收尾剧情
	if _e.is_boss:
		_boss_down = true
		Sfx.play("levelup")
		_paused_for_story = true
		Story.play(StoryScript.build_boss_defeat(boss_name.text), Callable(self, "_on_boss_done"))
		_boss_clear_watchdog()
		return
	# 本波清完？
	if alives.is_empty():
		# ★ 清波定格演出：时间缓一下 + 镜头微推（"这波清干净了"的仪式感）
		_hitstop(0.22)
		if juice != null:
			juice.zoom_punch(0.09, 0.55)
			juice.flash(Color(1, 1, 0.95, 0.14), 0.20)
		if wave_no < encounter_waves:
			await get_tree().create_timer(0.7).timeout
			if not finished:
				_start_wave(wave_no + 1)
		else:
			# 这个卡点结束
			_waves_cleared += 1
			await get_tree().create_timer(0.6).timeout
			if not finished:
				_after_encounter()


func _on_boss_done() -> void:
	_paused_for_story = false
	await get_tree().create_timer(0.7).timeout
	_finish(true)


## ★ 兜底：Boss 已死但剧情迟迟没结束（回调丢失 / 玩家卡在异常态）→ 强制结算
## 12 秒足够播完正常剧情（Boss 击败台词通常 3~6 秒），只在真正卡死时兜底。
func _boss_clear_watchdog() -> void:
	await get_tree().create_timer(12.0).timeout
	if not finished and _boss_down:
		if Story.has_method("is_busy") and Story.is_busy():
			pass          # 剧情还在正常播放，再等一轮
			await get_tree().create_timer(8.0).timeout
		if not finished and _boss_down:
			_finish(true)


func _after_encounter() -> void:
	_gate_open()
	_refresh_hud()
	# ★ 卡点打完 → 行商小驼开摊（攒的铜钱终于能花了）
	if gold > 0:
		_open_shop()
	# 更新当前段号
	var px: float = player.position.x
	for i in seg_bounds.size():
		var b: Vector2 = seg_bounds[i]
		if px >= b.x - 40 and px <= b.y + 40:
			if i != cur_seg:
				cur_seg = i
				_apply_theme(seg_themes[i])
				_refresh_hud()
			break
	# 推进到 Boss？
	if _waves_cleared >= _stage_total_waves:
		await get_tree().create_timer(0.5).timeout
		if not finished:
			_apply_theme(seg_themes[seg_themes.size() - 1])
			_spawn_boss()
	else:
		# 关中对白（不阻塞，让玩家继续走）
		var lines := StoryScript.build_mid(_waves_cleared, _stage_total_waves, stage.get("chars", []))
		if not lines.is_empty():
			_paused_for_story = true
			Story.play(lines, Callable(self, "_on_mid_done"))


func _on_mid_done() -> void:
	_paused_for_story = false


func _on_drop_picked(info: Dictionary) -> void:
	if player == null:
		return
	# ★ 战利品（包子/铜钱）与掉字共用拾取扫描，按 kind 分流
	if info.has("kind") and str(info.get("kind", "")) != "":
		_on_item_picked(str(info.get("kind", "")))
		return
	player.add_char(info)
	picked_chars.append(info.get("char", ""))
	_show_pickup_banner(info)
	_refresh_hud()
	# ★ 拾字反馈：冲天光柱 + 字卡飞进右上角「字囊」
	if juice != null:
		var ch: String = str(info.get("char", ""))
		var py: String = str(info.get("pinyin", info.get("py", "")))
		var col := Color("#ffd23c")
		juice.pickup_beam(player.position + Vector2(0, -30), col)
		if cam != null and player != null:
			var sc: Vector2 = cam.get_screen_center_position()
			var sp: Vector2 = player.position - sc + Vector2(SCREEN_W * 0.5, VIEW_H * 0.5)
			juice.card_fly(sp + Vector2(0, -60), Vector2(SCREEN_W - 118.0, 150.0), ch, py, col)


func _on_char_picked(_info: Dictionary) -> void:
	pass


## ★ 生成战利品（包子/铜钱）
func _spawn_item(pos: Vector2, kind: String) -> void:
	var it = ITEM_DROP.create(pos + Vector2(0, 40.0), kind)
	drop_root.add_child(it)
	it.picked.connect(_on_drop_picked)


## ★ 战利品拾取效果
func _on_item_picked(kind: String) -> void:
	if player == null:
		return
	if kind == "bun":
		player.heal(15)
		_refresh_hud()
		_spawn_damage_number(player.position + Vector2(0, -190), -15, false, Color(0.5, 1.0, 0.55))
		if juice != null:
			juice.pickup_beam(player.position + Vector2(0, -30), Color(0.55, 1.0, 0.6))
	else:
		score += 200
		# ★ 铜钱攒进钱包（商店货币），不只是分数
		gold += 1
		if gold >= 50:
			_unlock_ach("rich50")
		_refresh_hud()
		_spawn_damage_number(player.position + Vector2(0, -190), 200, false, Color(1.0, 0.85, 0.4))


# ================= ★ 金币商店（波次间隙补给站） =================
## 铜钱以前只能换分，现在攒进钱包；每个卡点打完后弹出商店，
## 按 1/2/3 购买（7 秒不买自动收摊），给孩子"攒钱买什么"的小决策
var gold := 0
var _shop_panel: PanelContainer = null
var _shop_gold: Label = null
var _shop_t := 0.0
const SHOP_OFFERS := [
	{"name": "包子宴 · 回血 30", "cost": 30},
	{"name": "灵光盾 · 吸伤 30", "cost": 40},
	{"name": "怒气全满 · 立刻狂暴", "cost": 50},
]


func _build_shop_ui() -> void:
	# 钱包常显（右上角，字囊提示下方）
	_shop_gold = Label.new()
	_shop_gold.add_theme_font_size_override("font_size", 22)
	_shop_gold.add_theme_color_override("font_color", Color("#ffd23c"))
	_shop_gold.add_theme_color_override("font_outline_color", Color("#4a2600"))
	_shop_gold.add_theme_constant_override("outline_size", 6)
	_shop_gold.position = Vector2(SCREEN_W - 260.0, 206.0)
	_shop_gold.z_index = 30
	ui.add_child(_shop_gold)
	_update_gold_label()
	# 商店面板（平时隐藏）
	_shop_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.06, 0.02, 0.92)
	sb.border_color = Color("#ffd23c")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 16.0
	_shop_panel.add_theme_stylebox_override("panel", sb)
	_shop_panel.position = Vector2(SCREEN_W * 0.5 - 250.0, 240.0)
	_shop_panel.custom_minimum_size = Vector2(500, 0)
	_shop_panel.visible = false
	_shop_panel.z_index = 40
	_shop_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_shop_panel.add_child(vb)
	var title := Label.new()
	title.text = "—— 行 商 小 驼 · 补 给 站 ——"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#ffe9a8"))
	vb.add_child(title)
	for i in SHOP_OFFERS.size():
		var off: Dictionary = SHOP_OFFERS[i]
		var row := Label.new()
		row.text = "[%d] %s　%d 文钱" % [i + 1, off["name"], off["cost"]]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", Color("#fff6dd"))
		vb.add_child(row)
	var tip := Label.new()
	tip.text = "按 1 / 2 / 3 购买 · 走开自动收摊"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	vb.add_child(tip)
	ui.add_child(_shop_panel)


func _update_gold_label() -> void:
	if _shop_gold == null or player == null:
		return
	var txt := "💰 %d 文钱" % gold
	if player.shield > 0:
		txt += "　🛡 %d" % player.shield
	_shop_gold.text = txt


func _open_shop() -> void:
	if _shop_panel == null:
		return
	_shop_panel.visible = true
	_shop_panel.modulate.a = 1.0
	_shop_t = 7.0
	Sfx.play("levelup", 0.5, 4.0)   # 开摊音（短促上扬）


func _close_shop() -> void:
	if _shop_panel != null and _shop_panel.visible:
		_shop_panel.visible = false


func _buy_shop(n: int) -> void:
	if n < 1 or n > SHOP_OFFERS.size() or player == null:
		return
	var off: Dictionary = SHOP_OFFERS[n - 1]
	var cost: int = int(off["cost"])
	if gold < cost:
		Sfx.play("hurt", 0.8, -2.0)     # 钱不够：低沉提示
		return
	gold -= cost
	_unlock_ach("shop_first")
	match n:
		1: player.heal(30)
		2: player.shield = mini(player.shield + 30, 60)
		3: player.add_rage(player.RAGE_MAX)   # 满 100 自动爆发
	Sfx.play("crit", 1.25, -2.0)
	_update_gold_label()
	_refresh_hud()
	_close_shop()


# ================= ★ Roguelite 随机词条（每关开场掷一签） =================
## 每关随机一条增益，全关生效。轻量 roguelite：每关开局都有"今天抽到什么"
## 的小期待，多周目手感不重样
var stage_buff := {}      # {id, name, desc}
var _buff_label: Label = null
const BUFF_POOL := [
	{"id": "atk", "name": "锋锐", "desc": "攻击 +15%"},
	{"id": "haste", "name": "迅捷", "desc": "攻速 +18%"},
	{"id": "swift", "name": "疾风", "desc": "移速 +25%"},
	{"id": "coin", "name": "财气", "desc": "铜钱掉率翻倍"},
	{"id": "rage", "name": "战意", "desc": "攒怒 +60%"},
	{"id": "shield", "name": "灵盾", "desc": "开局自带灵光盾 30"},
]


func _roll_stage_buff() -> void:
	stage_buff = BUFF_POOL[randi() % BUFF_POOL.size()]
	if player == null:
		return
	match str(stage_buff["id"]):
		"swift":
			player._speed_k *= 1.25
		"haste":
			player.atk_speed_k = 1.18
		"rage":
			player.rage_gain_k = 1.6
		"shield":
			player.shield = 30
	# HUD 常显（金色小签，挂在顶栏中间下方）
	_buff_label = Label.new()
	_buff_label.text = "✦ 本关词条「%s」%s" % [stage_buff["name"], stage_buff["desc"]]
	_buff_label.add_theme_font_size_override("font_size", 20)
	_buff_label.add_theme_color_override("font_color", Color("#ffe9a8"))
	_buff_label.add_theme_color_override("font_outline_color", Color("#4a2600"))
	_buff_label.add_theme_constant_override("outline_size", 6)
	_buff_label.position = Vector2(SCREEN_W * 0.5 - 160.0, 42.0)
	_buff_label.z_index = 25
	ui.add_child(_buff_label)


func _show_pickup_banner(info: Dictionary) -> void:
	pickup_banner.visible = true
	pickup_banner.modulate.a = 1.0
	pb_char.text = info.get("char", "")
	pb_py.text = info.get("pinyin", "")
	var scene_txt: String = info.get("scene", "")
	if scene_txt == "":
		var fam: String = info.get("familyHint", "")
		scene_txt = fam if fam != "" else ""
	pb_scene.text = scene_txt
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(pickup_banner, "modulate:a", 0.0, 0.45)
	t.tween_callback(func(): pickup_banner.visible = false)


func _on_hp_changed(hp: int, mx: int) -> void:
	hp_bar.max_value = mx
	hp_bar.value = hp
	hp_label.text = "字灵战士　%d/%d" % [hp, mx]
	_shake(0.18)
	# ★ 受伤红屏 + 濒死常驻警示（呼吸式）
	if juice != null:
		var ratio: float = float(hp) / float(max(1, mx))
		juice.flash_red(0.5, 0.32)
		juice.set_danger(ratio <= 0.28 and hp > 0)


func _on_energy_changed(_e: int, _n: int) -> void:
	_refresh_hud()
	if player and player.can_ult():
		_show_toast("字囊已满！按 U 放大招", Color("#ffd23c"))


func _on_player_died() -> void:
	_finish(false)


func _update_combo() -> void:
	if combo >= 2:
		combo_label.text = "COMBO x%d" % combo
		# ★ 连击特效阶梯：颜色随连击升档，弹跳幅度随连击变大
		#   2+ 白 → 5+ 金 → 10+ 橙红 → 20+ 烈焰红
		var c := Color(1, 1, 1)
		if combo >= 20:
			c = Color("#ff3860")
		elif combo >= 10:
			c = Color("#ff7a2e")
		elif combo >= 5:
			c = Color("#ffd23c")
		combo_label.add_theme_color_override("font_color", c)
		combo_label.add_theme_color_override("font_outline_color", c * 0.30)
		combo_label.pivot_offset = combo_label.size / 2.0
		var k: float = 1.28 + minf(0.55, combo * 0.025)
		var t := create_tween()
		combo_label.scale = Vector2.ONE
		t.tween_property(combo_label, "scale", Vector2(k, k), 0.07)
		t.tween_property(combo_label, "scale", Vector2.ONE, 0.11)
		# ≥10 连且逢 5 的整倍：全屏元素色氛围闪（"打红了"的爽感）
		if combo >= 10 and combo % 5 == 0 and juice != null and player != null:
			juice.flash(Color(1, 1, 1).lerp(player.elem_color(), 0.35), 0.16)
	else:
		combo_label.text = ""


# ================= 输入 =================
func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	# ★ 剧情播放中：回车 / 鼠标左键 = 跳过当前句。
	#   （战斗键【空格跳 / J攻击 / 方向双击 / 数字特技】在对白期间照常可用，
	#     不再被「跳过剧情」分支吞掉 —— 修复「有时候跳不起来 / 特技没反应」）
	if Story.is_busy():
		var skip_it := false
		if event is InputEventKey and event.pressed and not event.echo:
			var sk: int = event.keycode
			if sk == KEY_ENTER or sk == KEY_KP_ENTER:
				skip_it = true
		elif event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			skip_it = true
		if skip_it:
			Story.skip()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_J, KEY_K:
				_player_attack()
			KEY_SPACE:
				if player != null and is_instance_valid(player):
					player.jump()
			KEY_U, KEY_I, KEY_O, KEY_P:
				_do_ult()
			KEY_RIGHT, KEY_D:
				_tap_dir(1)
			KEY_LEFT, KEY_A:
				_tap_dir(-1)
			KEY_1, KEY_2, KEY_3:
				# ★ 商店开摊期间 1/2/3 = 购买（平时仍是特技）
				if _shop_panel != null and _shop_panel.visible:
					_buy_shop(event.keycode - KEY_1 + 1)
				else:
					_do_special(event.keycode - KEY_1 + 1)
			KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				_do_special(event.keycode - KEY_1 + 1)
			KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9:
				_do_special(event.keycode - KEY_KP_1 + 1)
			KEY_ESCAPE:
				_toggle_pause()
	elif event is InputEventMouseButton and event.pressed:
		# 鼠标右键 = 攻击（方便只用鼠标的小朋友）
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_player_attack()


# ================= 双击冲刺 =================
func _tap_dir(dir: int) -> void:
	if _dt_dir == dir and _dt_t > 0.0 and _dt_t < 0.45 and player != null and is_instance_valid(player):
		player.try_dash(dir)
		_dt_dir = 0
		_dt_t = 99.0
	else:
		_dt_dir = dir
		_dt_t = 0.0


# ================= 数字键 1-9 特技 =================
## ★ 其中「2」是当前主角的专属主动技（名称与效果按角色变化）
func _do_special(n: int) -> void:
	if player == null or player.dead or finished:
		return
	Sfx.play("special", 1.0, -4.0)
	player.play_special(n)
	var hcol: Color = player.elem_color() if player.has_method("elem_color") else Color(1.0, 0.85, 0.45)
	# 飘字点名特技 —— 让小朋友明确看到「按了数字键有效果」
	var names := ["翻滚", "上挑", "震地", "回旋斩", "护盾", "加速", "回血", "引雷", "烟花"]
	if n == 2 and player != null:
		var hd: Dictionary = Game.hero_data() if Game != null else {}
		var sn: String = str(hd.get("skill_name", "上挑"))
		_show_toast("%s · %s！" % [str(hd.get("name", "")), sn], hcol)
	else:
		if n >= 1 and n <= 9:
			_show_toast("特技·%s！" % names[n - 1], hcol)
	match n:
		1:  # 翻滚：短暂无敌闪避
			player.invuln = max(player.invuln, 0.55)
			juice.flash(Color(0.6, 0.9, 1.0), 0.25)
		2:  # ★ 主角专属主动技（按角色走不同效果与元素色）
			_hero_skill()
		3:  # 震地：落地冲击波，范围伤害
			var ep := player.position
			juice.ult_burst(ep, [hcol, hcol.lerp(Color(1, 1, 1), 0.45)])
			_aoe(ep, 165.0, 15)
		4:  # 回旋斩：周身一圈范围伤害
			juice.impact(player.position, hcol, true, Vector2.ZERO)
			_aoe(player.position, 175.0, 16)
		5:  # 护盾：2 秒无敌
			player.invuln = max(player.invuln, 2.0)
			juice.flash(Color(0.5, 0.8, 1.0), 0.35)
		6:  # 加速：4 秒提速
			player.haste(4.0)
			juice.flash(hcol, 0.25)
		7:  # 回血
			player.heal(18)
			juice.flash(Color(0.5, 1.0, 0.5), 0.30)
		8:  # 引雷：劈最近的敌人
			var e8 = _nearest_enemy(900.0)
			if e8 != null:
				juice.impact(e8.position, hcol, true)
				e8.take_damage(22, -player.facing)
		9:  # 烟花：纯表演，哄娃开心
			juice.celebrate()


## ★ 六大主角的专属主动技（数字键 2）
##   金=穿透剑气 / 木=缠藤+回血 / 水=水龙卷击退 / 火=爆炎AoE / 土=岩崩震地 / 雷=连锁闪电
func _hero_skill() -> void:
	if player == null:
		return
	var id: String = player.hero_id
	var col: Color = player.elem_color()
	var ppos: Vector2 = player.position
	match id:
		"jin":
			# 穿透剑气：向面朝方向发射一道长距离剑气，命中路径上所有敌人
			juice.flash(col, 0.22)
			for e in alives:
				if e == null or not is_instance_valid(e) or e.dead:
					continue
				var dx: float = (e.position.x - ppos.x) * player.facing
				if dx > 0.0 and dx < 520.0 and abs(e.position.y - ppos.y) < 150.0:
					e.take_damage(26, player.facing)
					juice.impact(e.position + Vector2(0, -110), col, true, Vector2(player.facing, -0.2))
			_spawn_beam(ppos + Vector2(0, -120), player.facing, col)
		"mu":
			# 缠藤缚：范围缠绕（定身 + 伤害），并给自己回血
			juice.ult_burst(ppos, [col, col.lerp(Color(1, 1, 1), 0.4)])
			_aoe(ppos, 200.0, 14)
			for e in alives:
				if e != null and is_instance_valid(e) and not e.dead:
					if ppos.distance_to(e.position) <= 200.0 and e.has_method("root_in_place"):
						e.root_in_place(1.8)
			player.heal(10)
		"shui":
			# 水龙吟：环形巨浪，强力击退并伤敌
			juice.ult_burst(ppos, [col, col.lerp(Color(1, 1, 1), 0.5)])
			for e in alives:
				if e == null or not is_instance_valid(e) or e.dead:
					continue
				if ppos.distance_to(e.position) <= 230.0:
					e.take_damage(18, sign(e.position.x - ppos.x))
					if e.has_method("knock_back"):
						e.knock_back(sign(e.position.x - ppos.x), 210.0)
		"huo":
			# 烈焰爆：前方强力爆炸
			var c2 := ppos + Vector2(120.0 * player.facing, -90.0)
			juice.ult_burst(c2, [col, Color(1.0, 0.85, 0.4)])
			_aoe(c2, 190.0, 30)
			juice.shake(0.6, Vector2(player.facing, -0.2))
		"tu":
			# 裂地击：脚下大地龟裂，稳定大范围伤害
			juice.ult_burst(ppos, [col, col.lerp(Color(1, 1, 1), 0.35)])
			_aoe(ppos, 210.0, 20)
			juice.shake(0.75, Vector2(0, 0.4))
		"lei":
			# 落雷闪：连锁闪电，依次劈向最近的多名敌人
			var targets: Array = []
			for e in alives:
				if e != null and is_instance_valid(e) and not e.dead:
					targets.append(e)
			targets.sort_custom(func(a, b):
				return ppos.distance_to(a.position) < ppos.distance_to(b.position))
			var cnt := 0
			for e in targets:
				if cnt >= 4:
					break
				juice.impact(e.position + Vector2(0, -100), col, true, Vector2(0, -1))
				e.take_damage(20, sign(e.position.x - ppos.x))
				_spawn_beam(e.position + Vector2(0, -60), 1, col, 0.22)
				cnt += 1
			juice.flash(col, 0.28)
		_:
			# 兜底：普通上挑
			var e2 = _nearest_enemy(220.0)
			if e2 != null:
				e2.take_damage(12, -player.facing)
			juice.impact(ppos + Vector2(0, -120), col, false, Vector2(0, -1))


## 剑气光带（金/雷系用）
func _spawn_beam(from: Vector2, dir: int, col: Color, w: float = 34.0) -> void:
	var ln := Line2D.new()
	ln.points = PackedVector2Array([Vector2.ZERO, Vector2(420.0 * dir, 0)])
	ln.width = w
	ln.default_color = col.lerp(Color(1, 1, 1), 0.45)
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	ln.position = from
	ln.z_index = 960
	fx_root.add_child(ln)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ln, "modulate:a", 0.0, 0.26)
	t.tween_property(ln, "scale", Vector2(1.0, 2.6), 0.26)
	t.chain().tween_callback(ln.queue_free)


## 范围内敌人造成伤害（特技用）
func _aoe(center: Vector2, radius: float, dmg: int) -> void:
	var hit := 0
	for e in alives:
		if e == null or not is_instance_valid(e) or e.dead:
			continue
		if center.distance_to(e.position) <= radius:
			e.take_damage(dmg, -player.facing)
			hit += 1
	if hit == 0:
		# 没打到也来点反馈，别让小朋友按了没反应
		juice.impact(center, Color(1.0, 0.9, 0.5), false, Vector2.ZERO)


func _nearest_enemy(max_dist: float) -> Node2D:
	var best: Node2D = null
	var bd := max_dist
	for e in alives:
		if e == null or not is_instance_valid(e) or e.dead:
			continue
		var d: float = player.position.distance_to(e.position)
		if d < bd:
			bd = d
			best = e
	return best


## 踩踏：跳跃下落时踩到敌人 → 踩扁 + 弹跳（让跳跃真正有用）
## ★ 连携版：空中连续踩不落地，伤害逐次滚大（20/34/48/...），落地清零。
##   这是街机"跳踩连锁"惯例——奖励玩家用跳跃打出手感连段。
var _stomp_chain := 0

func _stomp_check() -> void:
	if player == null or not is_instance_valid(player) or player.dead:
		return
	# 落地 → 连携清零
	if player.has_method("is_airborne") and not player.is_airborne():
		_stomp_chain = 0
		return
	if not (player.has_method("falling") and player.falling()):
		return
	if player.air_h() < 40.0:
		return
	for e in alives:
		if e == null or not is_instance_valid(e) or e.dead:
			continue
		if abs(e.position.x - player.position.x) < 76.0:
			_stomp_chain += 1
			var dmg := 20 + 14 * (_stomp_chain - 1)
			# Boss 很难被踩（一半伤害），精英 0.8 倍
			if e.is_boss:
				dmg = int(dmg * 0.5)
			elif e.get("is_elite"):
				dmg = int(dmg * 0.8)
			e.take_damage(dmg, 0.0)
			player.bounce()
			if player.has_method("add_rage"):
				player.add_rage(5 + 2 * _stomp_chain)
			score += 50 * _stomp_chain
			juice.impact(e.position, Color(1.0, 0.9, 0.4), true, Vector2(0, -1))
			_spawn_damage_number(e.position + Vector2(0, -190), dmg, _stomp_chain >= 2)
			Sfx.play("stomp", 1.2 - 0.04 * minf(4, _stomp_chain), -6.0)
			if _stomp_chain >= 2:
				_show_stomp_banner(_stomp_chain)
			if _stomp_chain >= 3:
				_unlock_ach("stomp3")
			return

## 「踩踏连携 xN」横幅：N 越大字越大越金
func _show_stomp_banner(n: int) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 42
	add_child(cl)
	var lab := Label.new()
	lab.text = "踩踏连携 x%d" % n
	lab.add_theme_font_size_override("font_size", 34 + minf(18, n * 3))
	lab.add_theme_color_override("font_color", Color(1.0, 0.82 + 0.02 * n, 0.35))
	lab.add_theme_color_override("font_outline_color", Color(0.28, 0.08, 0.0))
	lab.add_theme_constant_override("outline_size", 10)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lab.offset_top = 236.0
	lab.offset_bottom = 286.0
	lab.offset_left = -220.0
	lab.offset_right = 220.0
	lab.pivot_offset = Vector2(220, 25)
	lab.scale = Vector2(1.45, 1.45)
	lab.modulate.a = 0.0
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(lab)
	var t := cl.create_tween()
	t.set_parallel(true)
	t.tween_property(lab, "modulate:a", 1.0, 0.08)
	t.tween_property(lab, "scale", Vector2.ONE, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.62)
	t.chain().tween_property(lab, "modulate:a", 0.0, 0.26)
	t.chain().tween_callback(cl.queue_free)


# ================= 视差立体（多层山脊 + 前景 + 浮尘） =================
func _build_parallax() -> void:
	if _parallax_built:
		return
	_parallax_built = true
	# ★ 远/中景山脊加到 world（world 在 BG 场景图之前绘制），
	#   这样山脊能压在场景图上、又位于地面(Terrain z-20)与角色之后，形成纵深。
	#   （若加到 BG 下，相对 z 会让它们跑到天空层后面，看不见）
	# 远景山脊（淡蓝灰、慢）
	var far := Node2D.new()
	far.z_index = -999
	world.add_child(far)
	_add_hills(far, Color(0.42, 0.52, 0.64, 1.0), 150.0, 466.0, 1)
	_parallax.append({"node": far, "factor": 0.14})
	# 中景山脊（更深、更高、中速，压出「远山近山」剪影层次）
	var mid := Node2D.new()
	mid.z_index = -998
	world.add_child(mid)
	_add_hills(mid, Color(0.24, 0.31, 0.40, 1.0), 260.0, 486.0, 97)
	_parallax.append({"node": mid, "factor": 0.72})
	# 前景草丛（更深更高、快，框住画面）
	var fg := Node2D.new()
	fg.z_index = 4000
	foreground.add_child(fg)
	_add_tufts(fg, Color(0.03, 0.045, 0.09, 0.55), 560.0, 7)
	_parallax.append({"node": fg, "factor": 1.35})
	# 浮尘（压在场景图上、角色之后）
	_add_dust()


func _add_hills(group: Node2D, color: Color, amp: float, base_y: float, seed0: int) -> void:
	var span := world_w + 4000.0
	var bw := 1280.0
	var n := int(span / bw) + 1
	for i in n:
		var local_x := -2000.0 + float(i) * bw
		var seed := seed0 + i
		var hill := _make_hill(bw, amp * (0.78 + 0.44 * fmod(float(i) * 0.37, 1.0)), color, seed)
		if hill == null:
			continue
		hill.position = Vector2(local_x, base_y)
		group.add_child(hill)


func _make_hill(base_w: float, amp: float, color: Color, seed: int) -> Polygon2D:
	if amp <= 1.0:
		return null
	var pts := PackedVector2Array()
	var steps := int(base_w / 16.0)
	for i in steps + 1:
		var x: float = float(i) / float(steps) * base_w
		var y: float = -amp * (0.5 + 0.5 * sin(float(i) * 0.5 + float(seed))) \
			- amp * 0.32 * sin(float(i) * 0.17 + float(seed) * 1.7)
		pts.append(Vector2(x, y))
	pts.append(Vector2(base_w, 600.0))
	pts.append(Vector2(0.0, 600.0))
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	return p


func _add_tufts(group: Node2D, color: Color, base_y: float, seed0: int) -> void:
	var span := world_w + 4000.0
	var spacing := 340.0
	var n := int(span / spacing) + 1
	for i in n:
		var local_x := -2000.0 + float(i) * spacing + fmod(float(i) * 53.0, 130.0)
		var t := _make_tuft(color, seed0 + i)
		t.position = Vector2(local_x, base_y)
		group.add_child(t)


func _make_tuft(color: Color, seed: int) -> Polygon2D:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed
	var w := 56.0 + rnd.randf() * 54.0
	var h := 46.0 + rnd.randf() * 56.0
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, 0.0))
	var steps := 9
	for i in steps + 1:
		var x := float(i) / float(steps) * w
		var y := -h * (0.35 + 0.65 * sin(float(i) / float(steps) * PI)) * (0.7 + 0.5 * rnd.randf())
		pts.append(Vector2(x, y))
	pts.append(Vector2(w, 0.0))
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	return p


func _add_dust() -> void:
	var col := CPUParticles2D.new()
	col.z_index = -997
	col.amount = 46
	col.lifetime = 6.5
	col.emitting = true
	col.one_shot = false
	col.explosiveness = 0.0
	col.direction = Vector2(1.0, -0.12)
	col.spread = 26.0
	col.initial_velocity_min = 10.0
	col.initial_velocity_max = 38.0
	col.gravity = Vector2(-5.0, -9.0)
	col.scale_amount_min = 1.5
	col.scale_amount_max = 4.5
	col.color = Color(1.0, 1.0, 1.0, 0.10)
	col.position = Vector2(world_w * 0.5, 360.0)
	col.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	col.emission_rect_extents = Vector2(world_w * 0.5 + 240.0, 280.0)
	world.add_child(col)


func _update_parallax() -> void:
	if cam == null:
		return
	for p in _parallax:
		if is_instance_valid(p.node):
			p.node.position.x = cam.position.x * (1.0 - p.factor)


func _process(delta: float) -> void:
	# 双击冲刺计时衰减（0.45s 窗口，小朋友也能按出来）
	if _dt_t < 99.0:
		_dt_t += delta
		if _dt_t > 0.45:
			_dt_dir = 0
			_dt_t = 99.0
	_stomp_check()
	_update_parallax()
	_apply_hitstop(delta)
	# ★ 必杀提示呼吸：集满时缓慢呼吸；玩家按了 U 却放不出来时狂闪一下（强调原因）
	if ult_hint != null and ult_hint.visible:
		_hint_pulse += delta * 4.2
		if _hint_pulse_t > 0.0:
			_hint_pulse_t -= delta
			ult_hint.modulate.a = clamp(1.0 + 0.6 * (0.5 + 0.5 * sin(_hint_pulse * 3.6)), 0.35, 1.7)
		elif _ult_ready:
			ult_hint.modulate.a = 0.68 + 0.32 * (0.5 + 0.5 * sin(_hint_pulse))
		else:
			ult_hint.modulate.a = 0.72
	# （封印墙已移除，原「立柱闪烁」代码一并删除）
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 0
			_update_combo()
	# 卡点触发
	_check_marks()
	# ★ 商店倒计时收摊 + 钱包/护盾刷新（便宜起见只在文本变化时写）
	if _shop_panel != null and _shop_panel.visible:
		_shop_t -= delta
		if _shop_t <= 0.0:
			_close_shop()
	_update_gold_label()
	# 拾取检测
	# ★ 玩家贴地（y=地上）后，掉字在敌人头部（y 可低于玩家 190px），
	#   2D 距离判定会让「从字下面路过」永远够不着 → 改为主看 x 轴（横版惯例：路过即拾取）
	for d in drop_root.get_children():
		if d.has_method("collect") and player and is_instance_valid(player):
			var dy: float = abs(d.position.y - player.position.y)
			if dy < 230.0 and abs(d.position.x - player.position.x) < 82.0:
				d.collect()
	# Boss 震地预警圈：起跳时在落点画红圈，落地瞬间触发
	if boss_spawned and not alives.is_empty() and is_instance_valid(alives[0]) \
			and alives[0].has_method("_boss_state"):
		var b = alives[0]
		if b._boss_state == "stompwind" or b._boss_state == "stomp":
			_boss_circle_t += delta
			# 用冲击环每帧补一个淡圈 = 落点预警（视觉上在地面绕圈闪红）
			if _boss_circle_t > 0.15 and juice != null:
				juice.ripple(Vector2(b._boss_stomp_x, ground_at(b._boss_stomp_x) - 6.0),
					Color(1.0, 0.2, 0.2, 0.65))
				_boss_circle_t = 0.0
		else:
			_boss_circle_t = 0.0
	# 摄像机跟随
	if player and is_instance_valid(player):
		# ★ 穿梭特招期间 player.cam_hold_t > 0 → 冻结跟随
		#   原因：接力是「瞬移」式的（每段几百 px），相机照着追会把整屏甩得乱晃
		var hold: float = float(player.get("cam_hold_t"))
		if hold > 0.0:
			_cam_resume_ease = 0.0    # 冻结中：清缓入，解冻后从 0 重新爬
			if juice != null:
				juice.calm = true     # 长演出期间全局压平震屏（多来源震动不叠加）
		else:
			if juice != null and juice.calm:
				juice.calm = false
			# ★ 解冻缓入：冻结结束瞬间相机离玩家很近，若用原速 3.4 猛追回来，
			#   又是一次"甩镜"。改为 0→1 的 0.45s 爬坡，且爬坡期内用更柔的速率。
			_cam_resume_ease = minf(1.0, _cam_resume_ease + delta / 0.45)
			var tx: float = clamp(player.position.x + 90.0, 640.0, max(640.0, world_w - 640.0))
			var k: float = clamp(delta * 3.4 * _cam_resume_ease, 0.0, 1.0)
			cam.position.x = lerp(cam.position.x, tx, k)
	# 机关投放
	if not finished and _stage_started and player and is_instance_valid(player) and not player.dead:
		_hazard_t -= delta
		if _hazard_t <= 0.0:
			_hazard_t = randf_range(1.5, 3.2)
			_spawn_hazard()
	# Boss 血条
	if boss_spawned and alives.size() > 0 and is_instance_valid(alives[0]):
		boss_bar.value = alives[0].hp
	# ★ 2026-09-24 已移除封印墙（空气墙）—— 玩家不再被任何东西拦住，
	#   只保留世界右边界（尽头是 Boss 战场）。
	# 世界右边界
	if player:
		player.position.x = min(player.position.x, world_w - 40.0)
	# 推进进度
	if progress_bar:
		progress_bar.value = clamp(progress_ratio() * 100.0, 0.0, 100.0)
		progress_label.text = "推进 %d%%" % int(progress_bar.value)
	# ★ 脚步反馈：奔跑扬尘；水岸场景踩水起涟漪
	if juice != null and player != null and is_instance_valid(player) and not player.dead:
		if player._moving:
			_foot_t -= delta
			if _foot_t <= 0.0:
				_foot_t = 0.24
				var foot: Vector2 = player.position + Vector2(0, 4)
				var th: String = "water"
				if not seg_themes.is_empty():
					th = str(seg_themes[clamp(cur_seg, 0, seg_themes.size() - 1)])
				match th:
					"water":
						juice.ripple(foot)
					"bamboo", "sky":
						juice.dust(foot, 3)
					_:
						juice.dust(foot, 4)


var _hazard_t := 2.0


## 按当前场景主题 + 临近的敌人投放一个环境机关
func _spawn_hazard() -> void:
	# 找当前段主题
	var theme: String = seg_themes[clamp(cur_seg, 0, seg_themes.size() - 1)]
	var kinds: Array = THEME_HAZARDS.get(theme, ["rock"])
	var kind: String = kinds[randi() % kinds.size()]
	# 位置：玩家前方 260~520，且在世界内
	var hx: float = player.position.x + randf_range(260.0, 520.0)
	hx = clamp(hx, 120.0, world_w - 120.0)
	var hy: float = ground_at(hx)
	var dir: float = -1.0 if hx < player.position.x else 1.0
	var h = HAZARD.create(kind, hx, hy, player, dir)
	hazard_root.add_child(h)
	h.hit_player.connect(_on_hazard_hit)


func _on_hazard_hit(dmg: int, knock: float) -> void:
	if player == null or player.dead or finished:
		return
	player.take_damage(dmg)
	if abs(knock) > 1.0:
		var t := create_tween()
		t.tween_property(player, "position:x", clamp(player.position.x + knock, 60.0, world_w - 60.0), 0.18)
	_shake(0.72, Vector2(sign(knock), -0.3))
	if juice != null:
		juice.flash_red(0.55, 0.34)


func _player_attack() -> void:
	if player == null or player.dead:
		return
	player.attack()
	# ★ 第三段 = 角色特招（旋风斩/水影穿梭…）：判定加宽、打击感加倍
	var special: bool = (player._combo_step == 3)
	if special:
		Sfx.play("dash", randf_range(1.0, 1.15), -2.0)
		# ★ 特招起手爆点：元素色冲击环 + 火花（第三段有明确的视觉收尾）
		if juice != null:
			juice.special_burst(player.global_position + Vector2(0, -90),
					player.elem_color())
		_unlock_ach("first_special")
	Sfx.play("swing", randf_range(0.95, 1.1), -6.0)
	await get_tree().create_timer(0.06).timeout
	var box: Rect2 = player.attack_box()
	if special:
		box = box.grow_individual(96.0, 34.0, 96.0, 34.0)
	var struck := false
	for e in enemy_root.get_children():
		if not is_instance_valid(e) or e.dead:
			continue
		if box.intersects(e.screen_rect()):
			var crit := (combo >= 4)
			# ★ 普攻伤害按主角基础值走（金/火攻高、木/水偏中庸、土稳）
			var hdmg: int = player.hero_dmg() if player.has_method("hero_dmg") else 12
			var dmg := hdmg + randi_range(0, 6) + (combo / 2)
			# ★ 词条「锋锐」：攻击 +15%
			if str(stage_buff.get("id", "")) == "atk":
				dmg = int(float(dmg) * 1.15)
			if crit:
				dmg = int(dmg * 1.8)
			dmg = int(dmg * player.dmg_mult())   # ★ 狂暴 ×1.5
			var kdir := Vector2(sign(e.position.x - player.position.x), -0.35)
			e.take_damage(dmg, sign(e.position.x - player.position.x))
			_on_melee_hit(e.position, crit, kdir, dmg, special)
			struck = true
			# 特招只打最近的一个，剩下的交给第二次扫描
			break
	if special:
		# ★ 特招第二扫：穿梭/旋转的后半段（0.24s 后），沿途敌人也能吃到
		await get_tree().create_timer(0.18).timeout
		if player == null or not is_instance_valid(player) or player.dead:
			return
		var box2: Rect2 = player.attack_box().grow_individual(120.0, 40.0, 120.0, 40.0)
		for e in enemy_root.get_children():
			if not is_instance_valid(e) or e.dead:
				continue
			if box2.intersects(e.screen_rect()):
				var dmg2: int = int((player.hero_dmg() + randi_range(2, 8)) * player.dmg_mult())
				e.take_damage(dmg2, sign(e.position.x - player.position.x))
				_on_melee_hit(e.position, true, Vector2(sign(e.position.x - player.position.x), -0.4), dmg2, true)
	if struck:
		return
	# 没打到敌人 → 看有没有砸到木箱
	_hit_crates(box)


## ★ 近战命中统一反馈：连击计数（每次命中+1）+ 打击特效 + 屏幕反馈
func _on_melee_hit(epos: Vector2, crit: bool, kdir: Vector2, dmg: int, special := false) -> void:
	# 连击：每次命中都 +1（原来只有击杀才+1，"连按 J"没有连击感）
	combo += 1
	max_combo = max(max_combo, combo)
	_combo_timer = 1.8
	_update_combo()
	# ★ 打人攒怒
	player.add_rage(6)
	# ★ 连击音调递增（街机经典）：连得越高音越尖，爽感随连击攀升
	var pitch_k: float = 1.0 + minf(float(combo) * 0.028, 0.50)
	Sfx.play("crit" if crit else "hit", randf_range(0.95, 1.12) * pitch_k)
	if combo >= 10:
		_unlock_ach("combo10")
	_spawn_hit_fx(epos + Vector2(0, -120), crit, kdir)
	_spawn_damage_number(epos + Vector2(0, -175), dmg, crit)
	# ★ 穿梭接力演出期间（cam_hold_t > 0）：震屏/顿帧大幅收敛
	#   原因：接力会连打 3 段，每段都来一次「全屏强震 + 顿帧」叠在一起 →
	#   画面剧烈抖动（用户反馈）。改为轻震 + 短顿，演出平稳收束。
	var hold: float = 0.0
	if player != null and is_instance_valid(player):
		hold = float(player.get("cam_hold_t"))
	if hold > 0.0:
		_hitstop(0.04)
		_shake(0.22 if special else 0.16, kdir * 0.5)
	else:
		_hitstop(0.11 if special else (0.09 if crit else 0.05))
		_shake(0.85 if special else (0.62 if crit else 0.30), kdir)
	if crit and juice != null and hold <= 0.0:
		juice.zoom_punch(0.045, 0.30)


func _do_ult() -> void:
	if player == null or player.dead:
		return
	if _ult_busy:
		return
	# ★ 字囊没满时按 U：必须给出明确反馈。
	#   原来这里是直接 return —— 玩家按了毫无反应，只会以为「大招坏了 / 按键失灵」。
	if not player.can_ult():
		var need: int = player.energy_need - player.energy
		_show_toast("字囊还差 %d 个字，打倒小兵就会掉字哦！" % need, Color("#ffd8a0"))
		Sfx.play("wrong", 1.35, -10.0)
		_ult_hint_pulse()
		return
	var used: Array = player.picked.duplicate()
	player.consume_ult()
	var hname: String = ""
	var uname: String = "必杀"
	var uline: String = ""
	var ushout: String = ""
	var hd: Dictionary = Game.hero_data() if Game != null else {}
	hname = str(hd.get("name", ""))
	uname = str(hd.get("ult_name", "必杀"))
	uline = str(hd.get("ulta", ""))
	ushout = str(hd.get("shout", ""))

	# ★★ 大招 = 三段式「结印 → 元素兽横扫 → 收场」（2026-09-24 用户定稿）
	#   ① 结印 1.05s：人物蓄力姿态 + 大招插画定格 + 招式名 + **角色喊台词（带语音）**
	#   ② 兽暴 3.50s：元素兽实体横穿全屏，沿途敌人逐个被撞飞（beast_hit 信号回调）
	#   ③ 收场 0.65s
	#   全程留在战场上（相机不切走），玩家看得见自己和敌人。
	var fx = _play_ult_cutin(hname, uname, uline, ushout)
	if fx == null:
		_ult_fallout()
		return

	_ult_busy = true
	player.invuln = max(player.invuln, float(fx.duration()) + 0.6)
	# 兽每次扫过 → 结算该位置的敌人（击飞 + 伤害）
	fx.beast_hit.connect(_on_beast_hit)
	# 字囊里的字：结印阶段在大招起点依次亮出
	for i in mini(used.size(), 3):
		var c: Dictionary = used[i]
		var ch: String = str(c.get("char", ""))
		if ch == "":
			continue
		CHARFX.play(fx_root, ch, str(c.get("radical", "")),
				player.position + Vector2(-150.0 + i * 150.0, -200.0),
				str(c.get("pinyin", c.get("py", ""))), str(c.get("emoji", "")))
		await get_tree().create_timer(0.14).timeout
	await fx.finished
	_ult_busy = false
	_ult_fallout()


## 元素兽扫过某处 → 把该范围敌人全部撞飞
func _on_beast_hit(pos: Vector2, radius: float, dmg: int, knock: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var ucol: Color = player.elem_color() if player.has_method("elem_color") else Color("#ffd23c")
	var dir: float = signf(pos.x - player.position.x)
	if dir == 0.0:
		dir = 1.0
	for e in enemy_root.get_children():
		if not is_instance_valid(e) or e.dead:
			continue
		# 兽的身体是一个宽扁的横扫面：横向判定宽、纵向判定高
		if absf(e.position.x - pos.x) > radius:
			continue
		if absf(e.position.y - pos.y) > 320.0:
			continue
		var kd := Vector2(dir, -0.55)
		e.take_damage(dmg, dir)
		# ★ 冲飞：敌人被兽撞得横向抛出（Boss 会被 knock_back 自动减半）
		if e.has_method("knock_back"):
			e.knock_back(dir, knock)
		if juice != null:
			juice.impact(e.position + Vector2(0, -110), ucol, true, kd)
			juice.damage_number(e.position + Vector2(0, -170), dmg, true)
		else:
			_spawn_burst(e.position + Vector2(0, -110), ucol, 26)
		Sfx.play("crit", randf_range(1.02, 1.16), -2.0)
	_hitstop(0.045)
	if juice != null:
		juice.shake(0.85, Vector2(dir, -0.3))


## 大招收尾：贴地冲击波 + 音效
func _ult_fallout() -> void:
	if player == null or not is_instance_valid(player):
		return
	_spawn_shockwave(player.position)
	_hitstop(0.10)
	Sfx.play("levelup", 1.0, -2.0)


## ★ 播放「战场原地大招演出」（世界坐标层，不遮地图）
##   返回 UltCutin 节点（调用方可 await fx.finished 等演出结束），
##   失败返回 null（调用方应立即执行结算，不能卡住）。
func _play_ult_cutin(hname: String, uname: String, uline: String = "",
		ushout: String = "") -> Node:
	if player == null:
		return null
	var fx = load("res://scripts/UltCutin.gd").new()
	fx.name = "UltFx"
	fx.setup(player.hero_id, hname, uname, uline, ushout)
	fx_root.add_child(fx)
	fx.play(player.position, self)
	return fx


# ================= 特效 =================
func _spawn_shockwave(pos: Vector2) -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(41):
		var a := TAU * i / 40.0
		pts.append(Vector2(cos(a), sin(a)) * 40.0)
	ring.points = pts
	ring.width = 26.0
	ring.default_color = Color("#fff0a0")
	ring.z_index = 800
	ring.position = pos
	fx_root.add_child(ring)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(14, 8), 0.5)
	t.tween_property(ring, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(ring.queue_free)


func _spawn_hit_fx(pos: Vector2, crit: bool, dir: Vector2 = Vector2.ZERO) -> void:
	if juice != null:
		juice.impact(pos, Color("#ffd23c") if crit else Color("#fff0c0"), crit, dir)
		return
	_spawn_burst(pos, Color("#ffd23c") if crit else Color("#fff0c0"), 24 if crit else 14)


func _spawn_burst(pos: Vector2, col: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.5
	p.spread = 180.0
	p.initial_velocity_min = 130.0
	p.initial_velocity_max = 380.0
	p.gravity = Vector2(0, 520)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 9.0
	p.color = col
	fx_root.add_child(p)
	var t := create_tween()
	t.tween_interval(0.9)
	t.tween_callback(p.queue_free)


func _spawn_damage_number(pos: Vector2, dmg: int, crit: bool, col: Color = Color(1, 1, 1)) -> void:
	if juice != null:
		juice.damage_number(pos, dmg, crit)
		return
	var l := Label.new()
	l.text = ("%d!" % dmg) if crit else str(dmg)
	l.add_theme_font_size_override("font_size", 46 if crit else 34)
	l.add_theme_color_override("font_color", Color("#ffd23c") if crit else Color("#fff0b0"))
	l.add_theme_color_override("font_outline_color", Color("#5a2a00"))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	l.z_index = 950
	fx_root.add_child(l)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", pos.y - 80, 0.7)
	t.tween_property(l, "modulate:a", 0.0, 0.7)
	t.chain().tween_callback(l.queue_free)


## 震屏：交给 Juice 每帧驱动（比 tween 更有连续撞击感）；dir 为冲击方向
func _shake(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	if juice != null:
		juice.shake(amount * 3.8, dir)
		return
	var t := create_tween()
	t.tween_property(cam, "offset", Vector2(randf_range(-9, 9), randf_range(-9, 9)) * amount * 4, 0.04)
	t.tween_property(cam, "offset", Vector2.ZERO, 0.09)


func _show_toast(text: String, col: Color) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", col)
	toast.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_property(toast, "modulate:a", 0.0, 0.4)


## ★ 成就解锁统一入口：新解锁弹 toast + 音效；旧成就静默
func _unlock_ach(id: String) -> void:
	if ACH.unlock(id):
		_show_toast("🏆 成就解锁「%s」" % ACH.name_of(id), Color("#ffd23c"))
		Sfx.play("levelup", 0.9, 2.4)


# ================= 结算 =================
func _finish(win: bool) -> void:
	if finished:
		return
	finished = true
	result_panel.visible = true
	var unlocked_now := false
	if win:
		_unlock_ach("win")
		Sfx.play("levelup")
		result_title.text = "关卡通关！"
		result_title.add_theme_color_override("font_color", Color("#ffd23c"))
		# ★ 过关烟花
		if juice != null:
			juice.celebrate()
		# ★ 隐藏角色解锁：累计通关 3 关后开放「雷」
		if Game != null:
			unlocked_now = Game.record_win()
	else:
		Sfx.play("wrong", 0.7)
		result_title.text = "被击败…"
		result_title.add_theme_color_override("font_color", Color("#ff8080"))
	var uniq := {}
	for c in picked_chars:
		uniq[c] = true
	var info_line := "得分 %d　　最大连击 x%d\n本关拾取 %d 个字：%s" % [
		score, max_combo, uniq.size(), "".join(uniq.keys())]
	# ★ 成就汇总：总数 + 本局新解锁
	info_line += "\n🏆 成就 %d/%d" % [ACH.count(), ACH.DEFS.size()]
	var new_line := ACH.session_new_line()
	if new_line != "":
		info_line += "　本局新解锁：%s" % new_line
	if unlocked_now:
		info_line = "★ 隐藏角色『紫电』已解锁！回主菜单选人即可使用 ★\n" + info_line
	result_info.text = info_line
	result_btn.text = "返回选关"
	if not result_btn.pressed.is_connected(_back_to_select):
		result_btn.pressed.connect(_back_to_select)
	Game.save()


func _back_to_select() -> void:
	Sfx.play("select")
	if _pause_panel != null and is_instance_valid(_pause_panel):
		_pause_panel.queue_free()
	_pause_panel = null
	_paused = false
	_hitstop_t = 0.0
	# ★ 切场景前必须解除全局暂停 + 复位时间缩放
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/StageSelect.tscn")


# ================= 暂停菜单（Esc） =================
## 按 Esc：弹出 暂停面板（继续 / 回主菜单 / 缩小窗口）—— 动态创建，避免改 tscn
## ⚠️ 本函数是「连按 Esc 卡住」的修复核心，三条防御：
##   ① finished（结算中）不再直接 return —— 改为「再按一次即返回选关」，
##      否则结算时按 Esc 毫无反应，玩家以为卡死；
##   ② 状态自愈：只要面板可见就视为「已暂停」，无论 _paused 是否同步
##      （防中途异常导致 _paused=false 但面板还挂着 → 按 Esc 只会重建面板、退不出去）；
##   ③ 恢复时强制复位 time_scale，防 hitstop 残留把时间冻在 0.12 倍。
func _toggle_pause() -> void:
	# ① 结算期间：Esc = 返回选关（给玩家一条明确的出路，而不是死等按钮）
	if finished:
		_back_to_select()
		return
	# ② 状态自愈：面板挂着就是暂停中（即便 _paused 标志不同步）
	var panel_up: bool = _pause_panel != null and is_instance_valid(_pause_panel) \
			and _pause_panel.visible
	if _paused or panel_up:
		_resume_game()
		return
	_paused = true
	get_tree().paused = true        # ★ 全局暂停：所有敌人/机关/玩家停住
	if juice:
		juice.set_danger(false)
	if _pause_panel == null or not is_instance_valid(_pause_panel):
		_build_pause_panel()
	if _pause_panel != null:
		_pause_panel.visible = true
	Sfx.play("select")


func _resume_game() -> void:
	_paused = false
	get_tree().paused = false       # ★ 恢复
	# ③ 防 hitstop 残留：暂停期间 _apply_hitstop 不跑（树停着），
	#   若暂停前刚好开了顿帧，time_scale 会一直停在 0.12 → 恢复后全场慢放=「卡住」
	_hitstop_t = 0.0
	Engine.time_scale = 1.0
	if _pause_panel != null and is_instance_valid(_pause_panel):
		_pause_panel.visible = false
	Sfx.play("select")


func _go_main_menu() -> void:
	Sfx.play("select")
	if _pause_panel != null and is_instance_valid(_pause_panel):
		_pause_panel.queue_free()
	_pause_panel = null
	_paused = false
	_hitstop_t = 0.0
	# ★ 必须解除全局暂停！否则切到主菜单后 MainMenu 整棵树处于 paused 状态，
	#   按钮点不动、视频不动 —— 看起来就是「卡住」。切场景不会自动清 paused。
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _build_pause_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS   # 树暂停时仍能响应按钮
	# ★ 【不要】在这里改 Battle 根节点的 process_mode！
	#   以前写成 `process_mode = PROCESS_MODE_WHEN_PAUSED`，导致恢复游戏后
	#   整棵 Battle 子树（World/玩家/敌人，全 INHERIT）只在暂停时处理 →
	#   全场停摆、按键全失效，就是用户说的「连按退出键会卡住」。
	#   暂停期间收 Esc 改用下方 ALWAYS 的 PauseEscCatcher。
	# 半透明遮罩
	var mask := ColorRect.new()
	mask.color = Color(0, 0, 0, 0.55)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(mask)
	# 居中卡片
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.06, 0.96)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color("#ffd23c")
	card.add_theme_stylebox_override("panel", sb)
	layer.add_child(card)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(360, 0)
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)
	# 标题
	var ttl := Label.new()
	ttl.text = "暂停"
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_font_size_override("font_size", 34)
	ttl.add_theme_color_override("font_color", Color("#ffd23c"))
	vbox.add_child(ttl)
	# 三个按钮
	var btn_resume := _pause_btn("继续游戏（Esc）", func(): _resume_game())
	var btn_menu := _pause_btn("返回主菜单", func(): _go_main_menu())
	var btn_win := _pause_btn("缩小窗口（F11）", func():
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			get_tree().root.size = Vector2i(1600, 900)
		vbox.visible = false
		_resume_game())
	vbox.add_child(btn_resume)
	vbox.add_child(btn_menu)
	vbox.add_child(btn_win)
	# 提示
	var tip := Label.new()
	tip.text = "提示：按 F11 也可随时切换 全屏 / 窗口"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 15)
	tip.add_theme_color_override("font_color", Color(0.9, 0.85, 0.72))
	vbox.add_child(tip)
	# 挂在 UI CanvasLayer 外面层
	var ui_layer: CanvasLayer = $UI
	if ui_layer:
		ui_layer.add_child(layer)
	else:
		add_child(layer)
	_pause_panel = layer
	# ★ 暂停期间收 Esc 的捕获器（ALWAYS：树暂停时也照常收到输入）
	var catcher := PauseEscCatcher.new()
	catcher.name = "PauseEscCatcher"
	catcher.process_mode = Node.PROCESS_MODE_ALWAYS
	catcher.host = self
	add_child(catcher)


func _pause_btn(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(320, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color("#4a2a08"))
	for state in ["normal", "hover", "pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#ffd98a") if state == "normal" else (Color("#ffe9b8") if state == "hover" else Color("#f0c060"))
		st.set_corner_radius_all(12)
		st.set_border_width_all(3)
		st.border_color = Color("#8a5a20")
		b.add_theme_stylebox_override(state, st)
	b.pressed.connect(cb)
	return b


# ================= 可破坏木箱（场景互动） =================
## 沿每段地面随机撒 2~4 个木箱/竹筒，打两下碎掉，有五成几率爆出一个字
func _spawn_crates() -> void:
	_crates.clear()
	for si in seg_bounds.size():
		var b: Vector2 = seg_bounds[si]
		var th := "water"
		if not seg_themes.is_empty():
			th = str(seg_themes[clamp(si, 0, seg_themes.size() - 1)])
		var col: Color = CRATE_COLORS.get(th, CRATE_COLORS["water"])
		var tex := _make_crate_tex(56, 62, col)
		var n := randi_range(2, 4)
		for i in n:
			var hi: float = max(b.x + 260.0, b.y - 220.0)
			if hi <= b.x + 240.0:
				continue
			var x: float = randf_range(b.x + 240.0, hi)
			var y: float = ground_at(x)
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.position = Vector2(x, y - 31.0)
			sp.z_index = int(y)
			world.add_child(sp)
			_crates.append({"node": sp, "x": x, "y": y, "hp": 2, "col": col, "th": th})


## 程序化生成木箱贴图（省素材、零版权）
func _make_crate_tex(w: int, h: int, base: Color) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(base)
	var dk: Color = base.darkened(0.44)
	var lt: Color = base.lightened(0.20)
	for x in w:
		img.set_pixel(x, 0, dk)
		img.set_pixel(x, 1, dk)
		img.set_pixel(x, h - 2, dk)
		img.set_pixel(x, h - 1, dk)
	for y in h:
		img.set_pixel(0, y, dk)
		img.set_pixel(1, y, dk)
		img.set_pixel(w - 2, y, dk)
		img.set_pixel(w - 1, y, dk)
	# 两道横木条
	for row in 2:
		var yy: int = int(h * (0.32 + 0.36 * float(row)))
		for x in range(3, w - 3):
			img.set_pixel(x, yy, lt)
			if yy + 1 < h:
				img.set_pixel(x, yy + 1, lt.darkened(0.25))
	# 交叉斜条纹
	var diag: int = 0
	for i in range(4, w - 4):
		diag += 1
		var yv: int = int(6.0 + float(diag) / float(max(1, w - 8)) * float(h - 14))
		if yv >= 0 and yv < h:
			img.set_pixel(i, yv, dk)
	return ImageTexture.create_from_image(img)


## 攻击框是否打到木箱
func _hit_crates(box: Rect2) -> bool:
	var idx := _crates.size() - 1
	while idx >= 0:
		var c: Dictionary = _crates[idx]
		var sp = c["node"]
		if not is_instance_valid(sp):
			_crates.remove_at(idx)
			idx -= 1
			continue
		var r := Rect2(sp.position - Vector2(30.0, 33.0), Vector2(60.0, 66.0))
		if box.intersects(r):
			c["hp"] = int(c["hp"]) - 1
			if int(c["hp"]) > 0:
				var t := create_tween()
				t.tween_property(sp, "scale", Vector2(1.16, 0.84), 0.06)
				t.tween_property(sp, "scale", Vector2.ONE, 0.11)
				if juice != null:
					juice.debris(sp.position + Vector2(0, 8), c["col"])
				Sfx.play("hit", 1.2, -6.0)
			else:
				_break_crate(idx)
			return true
		idx -= 1
	return false


func _break_crate(idx: int) -> void:
	if idx < 0 or idx >= _crates.size():
		return
	var c: Dictionary = _crates[idx]
	var sp = c["node"]
	var pos := Vector2(c["x"], c["y"])
	_crates.remove_at(idx)
	if is_instance_valid(sp):
		pos = sp.position
		sp.queue_free()
	# 木屑四溅
	if juice != null:
		juice.debris(pos + Vector2(0, 18), c["col"])
		juice.shake(0.32, Vector2(0, -0.5))
	Sfx.play("crit", 0.85, -4.0)
	# 五成几率爆出一个字（让小朋友有动力去砸箱子）
	if randf() < 0.55 and not char_pool.is_empty():
		var ci := _next_char()
		var d = DROP.create(pos + Vector2(0, -20), ci)
		drop_root.add_child(d)
		d.picked.connect(_on_drop_picked)

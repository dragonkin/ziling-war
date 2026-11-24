extends Node
## 全局游戏状态 / 数据加载 / 存档
## 自动加载为单例：Game

signal progress_changed

const SAVE_PATH := "user://ziling_save.json"

# 关卡数据
var stages: Array = []
# 每个字的掌握度：{ "江": {"level":0..5, "due_day":int, "right":int, "wrong":int} }
var mastery: Dictionary = {}
# 当前关卡索引
var current_stage: int = 0
# 玩家（英雄）血量，跨小关保留一点成长感
var hero_hp_max: int = 100
var hero_hp: int = 100
# ★ 所选主角 id（金木水火土雷，见 Heroes.gd）
var current_hero: String = "huo"
# 已解锁的隐藏角色（通关后解锁）
var unlocked_heroes: Array = ["jin", "mu", "shui", "huo", "tu"]
# 累计通关次数（用于解锁隐藏角色）
var total_wins: int = 0


func _ready() -> void:
	load_stages()
	load_save()
	# 全屏开关（F11 / Alt+Enter）
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		# F11 = 4194342, Enter = 4194309
		if k == 4194342 or (k == 4194309 and (event as InputEventKey).alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


## 全屏 / 窗口 切换
func toggle_fullscreen() -> void:
	var w := DisplayServer.window_get_mode()
	if w == DisplayServer.WINDOW_MODE_FULLSCREEN or w == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))
		_center_window()
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _center_window() -> void:
	var screen: int = DisplayServer.window_get_current_screen()
	var ss: Vector2i = DisplayServer.screen_get_size(screen)
	var sp: Vector2i = DisplayServer.screen_get_position(screen)
	var ws: Vector2i = DisplayServer.window_get_size()
	DisplayServer.window_set_position(sp + (ss - ws) / 2)


func load_stages() -> void:
	# 优先 units.json（关卡 = 教材单元，61 关 / 3162 字）
	var path := "res://data/units.json"
	if not FileAccess.file_exists(path):
		path = "res://data/stages.json"
	if not FileAccess.file_exists(path):
		push_error("找不到关卡数据")
		return
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_error("关卡数据解析失败")
		return
	stages = parsed.get("stages", [])
	print("[Game] 载入关卡数: ", stages.size(), " (", path, ")")


func get_stage(i: int) -> Dictionary:
	if i < 0 or i >= stages.size():
		return {}
	return stages[i]


func stage_count() -> int:
	return stages.size()


# ---------------- 掌握度 / SRS ----------------
func _mkey(char: String) -> String:
	return char


func get_mastery(char: String) -> Dictionary:
	var k := _mkey(char)
	if not mastery.has(k):
		mastery[k] = {"level": 0, "right": 0, "wrong": 0}
	return mastery[k]


func level_of(char: String) -> int:
	return int(get_mastery(char).get("level", 0))


## 答对：掌握度 +1，最高 5 级（👑）
func record_right(char: String) -> void:
	var m := get_mastery(char)
	m["level"] = min(5, int(m.get("level", 0)) + 1)
	m["right"] = int(m.get("right", 0)) + 1
	mastery[_mkey(char)] = m
	progress_changed.emit()
	save()


## 答错：掌握度 -1（不低于 0）
func record_wrong(char: String) -> void:
	var m := get_mastery(char)
	m["level"] = max(0, int(m.get("level", 0)) - 1)
	m["wrong"] = int(m.get("wrong", 0)) + 1
	mastery[_mkey(char)] = m
	progress_changed.emit()
	save()


## 某关已发现的字数
func stage_found(fam_index: int) -> int:
	var st := get_stage(fam_index)
	var n := 0
	for c in st.get("chars", []):
		if level_of(c.get("char", "")) > 0:
			n += 1
	return n


## 全局统计
func total_found() -> int:
	var n := 0
	for k in mastery.keys():
		if int(mastery[k].get("level", 0)) > 0:
			n += 1
	return n


func total_mastered() -> int:
	var n := 0
	for k in mastery.keys():
		if int(mastery[k].get("level", 0)) >= 5:
			n += 1
	return n


func total_chars() -> int:
	var n := 0
	for s in stages:
		n += s.get("chars", []).size()
	return n


# ---------------- 存档 ----------------
func save() -> void:
	var d := {
		"mastery": mastery,
		"hero_hp": hero_hp,
		"current_stage": current_stage,
		"current_hero": current_hero,
		"unlocked_heroes": unlocked_heroes,
		"total_wins": total_wins,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "  "))
		f.close()


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var d = JSON.parse_string(txt)
	if d == null or typeof(d) != TYPE_DICTIONARY:
		return
	mastery = d.get("mastery", {})
	hero_hp = int(d.get("hero_hp", hero_hp_max))
	current_stage = int(d.get("current_stage", 0))
	current_hero = str(d.get("current_hero", current_hero))
	total_wins = int(d.get("total_wins", 0))
	var uh = d.get("unlocked_heroes", null)
	if uh is Array and not (uh as Array).is_empty():
		unlocked_heroes = uh


## ★ 记一次通关；累计 3 关自动解锁隐藏角色「雷」
## 返回 true 表示本次刚好解锁（用于界面提示）
func record_win() -> bool:
	total_wins += 1
	var just := false
	if total_wins >= 3 and not hero_unlocked("lei"):
		unlock_hero("lei")
		just = true
	save()
	return just


## 某角色是否已解锁（隐藏角色需通关）
func hero_unlocked(id: String) -> bool:
	return id in unlocked_heroes


## 解锁隐藏角色（通关后调用）
func unlock_hero(id: String) -> void:
	if not hero_unlocked(id):
		unlocked_heroes.append(id)
		save()


## 当前所选角色的数据字典
## 注意：Heroes 是 autoload 单例，其 static 方法通过实例调用
func hero_data() -> Dictionary:
	return Heroes.by_id(current_hero)


func reset_progress() -> void:
	mastery.clear()
	hero_hp = hero_hp_max
	current_stage = 0
	save()
	progress_changed.emit()
extends RefCounted
## ★ 成就系统（轻量跨局持久版）—— 进化第 4 轮
## 用法（Battle 里）：const ACH := preload("res://scripts/Achievements.gd")
##   ACH.unlock("combo10") 返回 true = 本次新解锁（调用方弹 toast）
## 存档：user://achievements.json（跨局持久，重开游戏不丢）
## 注意：故意不用 class_name / autoload —— --script 探针模式下两者都不可见，
##       preload 常量是探针和运行时都稳的引用方式。

const SAVE_PATH := "user://achievements.json"

const DEFS := [
	{"id": "first_special", "name": "初试锋芒", "desc": "第一次使出第三段特招"},
	{"id": "combo10", "name": "十连击！", "desc": "单次连击达到 10"},
	{"id": "stomp3", "name": "凌空三连踩", "desc": "空中连踩 3 只敌人"},
	{"id": "shop_first", "name": "第一桶金", "desc": "第一次在行商小驼买东西"},
	{"id": "rich50", "name": "小富翁", "desc": "钱包攒到 50 文"},
	{"id": "rage", "name": "怒火燃烧", "desc": "第一次进入狂暴状态"},
	{"id": "win", "name": "过关斩将", "desc": "通关任意一关"},
]

static var unlocked := {}
static var _loaded := false
static var session_new: Array = []   # 本局新解锁的 id（结算面板展示）


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if d is Dictionary:
			unlocked = d


static func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(unlocked))


static func is_unlocked(id: String) -> bool:
	_load()
	return bool(unlocked.get(id, false))


## 解锁成就。返回 true = 这次是新解锁（该弹 toast）；false = 早就有过/非法 id
static func unlock(id: String) -> bool:
	_load()
	if bool(unlocked.get(id, false)):
		return false
	var valid := false
	for d in DEFS:
		if str(d["id"]) == id:
			valid = true
			break
	if not valid:
		return false
	unlocked[id] = true
	session_new.append(id)
	_save()
	return true


static func name_of(id: String) -> String:
	for d in DEFS:
		if str(d["id"]) == id:
			return str(d["name"])
	return id


## 结算面板用：本局新解锁的「名x，名y」串（没有则空串）
static func session_new_line() -> String:
	if session_new.is_empty():
		return ""
	var names: Array[String] = []
	for id in session_new:
		names.append(name_of(str(id)))
	return "、".join(names)


static func count() -> int:
	_load()
	return unlocked.size()


## 测试钩子：清空存档与本次会话记录
static func _reset() -> void:
	unlocked = {}
	session_new = []
	_loaded = true
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

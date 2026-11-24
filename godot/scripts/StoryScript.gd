extends Node
## 剧情文案生成 —— 把教材单元的生字串成关卡故事
##
## 设计原则：不写死剧情，而是按「年级 + 单元生字」组合出有代入感的旁白。
## 低年级用简单句 + 拟声词（小朋友爱听），高年级用完整叙事。

# 地点氛围（按场景主题）
const PLACE_INTRO := {
	"water": {"name": "水帘洞", "desc": "瀑布像白布一样挂在山前，水花溅起老高"},
	"bamboo": {"name": "青竹林", "desc": "竹叶层层叠叠，风一吹就沙沙作响"},
	"palace": {"name": "金銮殿", "desc": "金瓦红柱排成两行，灯笼在檐下轻轻晃"},
	"lava": {"name": "熔岩窟", "desc": "黑色的石头裂着缝，火红的岩浆咕嘟咕嘟冒泡"},
	"ruins": {"name": "古城墙", "desc": "灰色的城墙塌了半边，风从破洞里呜呜地吹"},
	"sky": {"name": "云端天梯", "desc": "白玉台阶一级级往上长，云朵在脚下慢慢地飘"},
}

const BOSS_TAUNT := [
	"哈哈！想拿回这些字？先过我这关！",
	"这些小字都是我的！谁也别想带走！",
	"又来一个不知天高地厚的娃娃！",
]

const BOSS_DEFEAT := [
	"不……不可能……字都飞走了……",
	"呜……我认输……那些字还给你……",
	"好厉害……原来字是记得住的……",
]

const CLEAR_WORDS := [
	"干得漂亮！这些字已经记在心里啦。",
	"太棒了！这一关的字全部收齐。",
	"厉害！字灵们都在为你欢呼呢。",
]

const CHEER := [
	"记住它们，它们就不会再跑掉。",
	"读一读，写一写，字就跟你做朋友了。",
	"再来一关吧，字灵界还等着你。",
]


## 生成开场剧情
func build_intro(stage: Dictionary, theme: String) -> Array:
	var name: String = stage.get("name", "神秘之地")
	var chars: Array = stage.get("chars", [])
	var pool := _pick_chars(chars, 5)
	var p: Dictionary = PLACE_INTRO.get(theme, PLACE_INTRO["water"])
	var char_list := _join(chars, "、")
	var lines := [
		{"who": "旁白", "text": "字灵界的封印松动了，《%s》里的字散落人间……" % name, "hold": 3.2},
		{"who": "旁白", "text": "它们飘啊飘，飘进了%s。这里%s。" % [p["name"], p["desc"]], "hold": 3.2},
	]
	if pool.size() > 0:
		lines.append({
			"who": "字灵向导",
			"text": "先找这几只捣蛋的小字灵：%s。走过去碰一碰，它们就跟你走啦！" % _join(pool, "、"),
			"hold": 4.0,
		})
	lines.append({
		"who": "任务",
		"text": "本关共 %d 个字，收齐它们就能打开前方的封印。" % chars.size(),
		"hold": 3.0,
	})
	# ★ 操作教学：只在第 1 关讲一次。
	#   玩家反馈「不知道怎么放大招」—— 光靠 HUD 上一行小字不够，
	#   开场让「任务」用一句完整的话把三个操作讲清楚，之后靠 HUD 常驻提示。
	if abs(int(stage.get("id", 1))) == 1:
		lines.append({
			"who": "任务",
			"text": "记住操作：方向键左右走，按 J 打小兵；集满 5 个字，按 U 放必杀技！",
			"hold": 4.2,
		})
	return lines


## 清除一个卡点后的对白
func build_mid(there: int, total: int, chars: Array) -> Array:
	if there >= total:
		return []
	var tips := [
		"不错不错！继续往右边走。",
		"干得好！前面还有字灵在等你。",
		"越来越熟练啦，别停下。",
	]
	var pool := _pick_chars(chars, 2)
	var t: String = tips[there % tips.size()]
	if pool.size() > 0:
		t += "刚才记住的「%s」别忘了。"
		return [{"who": "字灵向导", "text": t % _join(pool, ""), "hold": 2.8}]
	return [{"who": "字灵向导", "text": t, "hold": 2.8}]


## Boss 前的对峙
func build_boss_intro(boss_name: String, stage_name: String) -> Array:
	var taunt: String = BOSS_TAUNT[randi() % BOSS_TAUNT.size()]
	return [
		{"who": "旁白", "text": "地面突然震动，%s从阴影里走了出来！" % boss_name, "hold": 3.0},
		{"who": boss_name, "text": taunt, "hold": 3.0},
		{"who": "字灵向导", "text": "别怕！用你收集的字，放出必杀技！", "hold": 2.8},
	]


## 击败 Boss
func build_boss_defeat(boss_name: String) -> Array:
	var d: String = BOSS_DEFEAT[randi() % BOSS_DEFEAT.size()]
	return [{"who": boss_name, "text": d, "hold": 3.0}]


## 通关收尾
func build_clear(stage: Dictionary, picked: int) -> Array:
	var c: String = CLEAR_WORDS[randi() % CLEAR_WORDS.size()]
	var cheer: String = CHEER[randi() % CHEER.size()]
	return [
		{"who": "旁白", "text": "%s 的封印解除了！" % stage.get("name", "这里"), "hold": 2.8},
		{"who": "字灵向导", "text": c, "hold": 2.8},
		{"who": "字灵向导", "text": cheer, "hold": 2.8},
	]


# ---------- 工具 ----------
func _pick_chars(chars: Array, n: int) -> Array:
	var out := []
	for i in min(n, chars.size()):
		var c = chars[i]
		var ch: String = c.get("char", c) if c is Dictionary else str(c)
		if ch != "":
			out.append(ch)
	return out


func _join(arr: Array, sep: String) -> String:
	var parts := []
	for x in arr:
		parts.append(str(x))
	return sep.join(parts)

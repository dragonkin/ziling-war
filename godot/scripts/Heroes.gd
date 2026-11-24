extends Node
## 六大主角数据表 —— 五行（金木水火土）+ 隐藏角色（雷）
##
## 每个角色拥有一套完全不同的技能与配色：
##   主动技（数字键 2）与大招（U）的伤害/范围/特效色/演出插画都按 hero 走
##
## 立绘目录约定：res://assets/heroes/{id}/
##   idle.png / walk1..4.png / atk1..3.png / jump.png / ult.png（大招插画）
## 素材缺失时 Player.gd 会自动程序化兜底（五行配色人形），保证永远能跑。

## ---------- 元素配色调色板 ----------
const ELEM_COLORS := {
	"metal":  {"main": Color("#f5d76e"), "deep": Color("#b8860b"), "name": "金"},
	"wood":   {"main": Color("#5fd35f"), "deep": Color("#1b6b1b"), "name": "木"},
	"water":  {"main": Color("#4aa8ff"), "deep": Color("#0b3d7a"), "name": "水"},
	"fire":   {"main": Color("#ff5a3c"), "deep": Color("#8b1a00"), "name": "火"},
	"earth":  {"main": Color("#d9a441"), "deep": Color("#6b4a12"), "name": "土"},
	"thunder":{"main": Color("#b07aff"), "deep": Color("#4a1a8a"), "name": "雷"},
}

## ---------- 六大主角 ----------
## skill = 数字键 2 主动技；ult = U 大招
## dmg/base：普攻基础伤害；speed：移速倍率；hp：血量上限
## ulta  = 大招描述（选人界面的文学描述，不进战斗）
## shout = 大招「喊话」（结印时角色喊出来，带语音）
##         ★ 格式统一为「单字爆喝 + 四字招式名」——像火影结印后那一声短喝，
##           斩钉截铁、不拖泥带水。小朋友也能跟着喊出招式名。
##         语音见 assets/voice_ult/<md5>.mp3（tools/gen_ult_shout.py 生成）
##         GDScript 侧显示时会把爆喝字放大加色（见 UltCutin._build_shout）
const HEROES := [
	{
		"id": "jin", "name": "金戈", "elem": "metal", "title": "锐金之刃",
		"desc": "刀锋锐利无坚不摧，攻击范围最广",
		"hp": 110, "speed": 1.0, "dmg": 14,
		"skill_name": "破甲斩", "ult_name": "万剑归宗",
		"ulta": "天罡剑气自四面八方汇聚，化作万道金刃横扫全场",
		"shout": "斩！万剑归宗！",
	},
	{
		"id": "mu", "name": "青藤", "elem": "wood", "title": "长生之木",
		"desc": "藤蔓缠身、生生不息，回血能力最强",
		"hp": 130, "speed": 1.05, "dmg": 11,
		"skill_name": "缠藤缚", "ult_name": "万木回春",
		"ulta": "大地裂开涌出参天古木，缠住所有敌人并治愈自身",
		"shout": "缚！万木回春！",
	},
	{
		"id": "shui", "name": "沧澜", "elem": "water", "title": "沧浪之水",
		"desc": "行云流水、进退自如，冲刺距离最远",
		"hp": 100, "speed": 1.18, "dmg": 12,
		"skill_name": "水龙吟", "ult_name": "沧海怒涛",
		"ulta": "滔天巨浪自九天垂落，将战场化为怒海汪洋",
		"shout": "啸！沧海怒涛！",
	},
	{
		"id": "huo", "name": "赤炎", "elem": "fire", "title": "燎原之火",
		"desc": "爆发最强、伤害最高，但血量偏薄",
		"hp": 92, "speed": 1.02, "dmg": 16,
		"skill_name": "烈焰爆", "ult_name": "焚天烈焰",
		"ulta": "九条火龙自地底冲天而起，将一切焚为灰烬",
		"shout": "焚！焚天烈焰！",
	},
	{
		"id": "tu", "name": "磐岩", "elem": "earth", "title": "厚土之盾",
		"desc": "血厚防高、震地最稳，新手最不易死",
		"hp": 150, "speed": 0.92, "dmg": 13,
		"skill_name": "裂地击", "ult_name": "山崩地裂",
		"ulta": "群山崩塌、大地龟裂，亿万吨岩石砸向敌人",
		"shout": "镇！山崩地裂！",
	},
	{
		"id": "lei", "name": "紫电", "elem": "thunder", "title": "迅雷之势",
		"desc": "★隐藏角色：攻速最快，雷电连锁全场",
		"hp": 95, "speed": 1.25, "dmg": 15,
		"skill_name": "落雷闪", "ult_name": "九霄神雷",
		"ulta": "九天神雷贯顶而下，连锁劈向每一个敌人",
		"shout": "劈！九霄神雷！",
	},
]

## 默认角色（未选人时的兜底）
const DEFAULT_ID := "huo"


static func count() -> int:
	return HEROES.size()


static func get_hero(i: int) -> Dictionary:
	if i < 0 or i >= HEROES.size():
		return HEROES[0]
	return HEROES[i]


static func index_of(id: String) -> int:
	for i in HEROES.size():
		if str(HEROES[i].get("id", "")) == id:
			return i
	return -1


static func by_id(id: String) -> Dictionary:
	var i := index_of(id)
	return HEROES[i] if i >= 0 else HEROES[0]


## 该角色的元素主色
static func main_color(id: String) -> Color:
	var h := by_id(id)
	var e: String = str(h.get("elem", "fire"))
	return ELEM_COLORS.get(e, ELEM_COLORS["fire"])["main"]


## 该角色的元素深色（描边 / 阴影）
static func deep_color(id: String) -> Color:
	var h := by_id(id)
	var e: String = str(h.get("elem", "fire"))
	return ELEM_COLORS.get(e, ELEM_COLORS["fire"])["deep"]


## 该角色的元素中文名（金木水火土雷）
static func elem_name(id: String) -> String:
	var h := by_id(id)
	var e: String = str(h.get("elem", "fire"))
	return str(ELEM_COLORS.get(e, ELEM_COLORS["fire"])["name"])


## 立绘目录
static func art_dir(id: String) -> String:
	return "res://assets/heroes/%s/" % id


## 大招演出用色（三重渐变：主色 → 亮色 → 白）
static func ult_palette(id: String) -> Array:
	var main := main_color(id)
	return [
		main,
		Color(min(1.0, main.r * 1.35 + 0.2), min(1.0, main.g * 1.35 + 0.2), min(1.0, main.b * 1.35 + 0.2)),
		Color(1, 1, 0.96),
	]

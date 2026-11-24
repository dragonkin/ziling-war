extends Node
## 字义特效库 —— 每个字对应一种视觉意象
##
## 三层优先级：
##   1. 专属意象（SPECIAL）：约 400 个高频字手工配置，如 快→奔马、火→烈焰
##   2. 部首/语义归类（RADICAL）：按部首映射到大类（动物/自然/动作/器物…）
##   3. 兜底（DEFAULT）：通用光效
##
## 每个意象用「元素类型 + 颜色 + 运动方式」描述，由 FX 层程序化绘制。

## ===== 大类定义 =====
## elem: 绘制元素；color: 主色；motion: 运动方式；aux: 辅助元素
const KINDS := {
	# —— 自然 ——
	"water":   {"elem": "wave",     "color": "#5fc8ff", "motion": "surge",  "aux": "droplet"},
	"fire":    {"elem": "flame",    "color": "#ff7a2a", "motion": "rise",   "aux": "spark"},
	"wood":    {"elem": "leaf",     "color": "#79d95a", "motion": "swirl",  "aux": "leaf"},
	"metal":   {"elem": "shard",    "color": "#d8e2ee", "motion": "slash",  "aux": "spark"},
	"earth":   {"elem": "rockfall", "color": "#c49a6a", "motion": "drop",   "aux": "dust"},
	"wind":    {"elem": "gust",     "color": "#b6f0d8", "motion": "sweep",  "aux": "line"},
	"thunder": {"elem": "bolt",     "color": "#fff37a", "motion": "strike", "aux": "flash"},
	"ice":     {"elem": "crystal",  "color": "#a8e8ff", "motion": "burst",  "aux": "shard"},
	"sun":     {"elem": "ray",      "color": "#ffd23c", "motion": "radiate","aux": "glow"},
	"moon":    {"elem": "crescent", "color": "#dfe6ff", "motion": "arc",    "aux": "star"},
	# —— 动物 ——
	"beast":   {"elem": "horse",    "color": "#c98a52", "motion": "gallop", "aux": "dust"},
	"bird":    {"elem": "bird",     "color": "#8fd8ff", "motion": "fly",    "aux": "feather"},
	"fish":    {"elem": "fish",     "color": "#4fd8d8", "motion": "swim",   "aux": "ripple"},
	"insect":  {"elem": "bug",      "color": "#a8d84f", "motion": "crawl",  "aux": "spark"},
	# —— 人 / 动作 ——
	"person":  {"elem": "figure",   "color": "#ffd8b0", "motion": "dash",   "aux": "aura"},
	"action":  {"elem": "streak",   "color": "#ffb04f", "motion": "charge", "aux": "line"},
	"hand":    {"elem": "palm",     "color": "#ffc88a", "motion": "push",   "aux": "ring"},
	"speech":  {"elem": "bubble",   "color": "#ffe9a8", "motion": "float",  "aux": "note"},
	# —— 器物 ——
	"weapon":  {"elem": "blade",    "color": "#ffd23c", "motion": "slash",  "aux": "spark"},
	"tool":    {"elem": "hammer",   "color": "#b0a898", "motion": "strike", "aux": "dust"},
	"cloth":   {"elem": "ribbon",   "color": "#ff9ac8", "motion": "wave",   "aux": "petal"},
	"food":    {"elem": "grain",    "color": "#ffcf6a", "motion": "scatter","aux": "crumb"},
	"vehicle": {"elem": "wheel",    "color": "#9fb0c8", "motion": "roll",   "aux": "dust"},
	# —— 抽象 ——
	"number":  {"elem": "digit",    "color": "#ffd23c", "motion": "orbit",  "aux": "ring"},
	"color":   {"elem": "palette",  "color": "#ff8ad8", "motion": "swirl",  "aux": "drop"},
	"emotion": {"elem": "heart",    "color": "#ff7a9a", "motion": "float",  "aux": "spark"},
	"light":   {"elem": "glow",     "color": "#fff0a0", "motion": "radiate","aux": "star"},
	"dark":    {"elem": "smoke",    "color": "#6a5a8a", "motion": "rise",   "aux": "wisp"},
	"time":    {"elem": "clock",    "color": "#d8c8a0", "motion": "orbit",  "aux": "ring"},
	"space":   {"elem": "grid",     "color": "#8ac8ff", "motion": "expand", "aux": "line"},
	"sound":   {"elem": "ripple",   "color": "#ffe9a8", "motion": "radiate","aux": "note"},
	"body":    {"elem": "figure",   "color": "#ffd0b0", "motion": "pulse",  "aux": "aura"},
	"plant":   {"elem": "sprout",   "color": "#7ad85a", "motion": "grow",   "aux": "leaf"},
	"mountain":{"elem": "peak",     "color": "#b0a08a", "motion": "rise",   "aux": "dust"},
	"sky":     {"elem": "cloud",    "color": "#d8ecff", "motion": "drift",  "aux": "star"},
	"default": {"elem": "glow",     "color": "#ffd23c", "motion": "burst",  "aux": "spark"},
}

## ===== 专属意象（高频核心字）=====
## key = 汉字, value = 大类 key（用专属 kind 表达更精确的意象）
const SPECIAL := {
	# 动物 / 奔腾
	"快": "beast", "马": "beast", "骑": "beast", "奔": "beast", "跑": "beast",
	"虎": "beast", "狮": "beast", "熊": "beast", "猫": "beast", "狗": "beast",
	"牛": "beast", "羊": "beast", "猪": "beast", "兔": "beast", "狼": "beast",
	"鸟": "bird", "鸡": "bird", "鸭": "bird", "鹅": "bird", "鹤": "bird",
	"鹰": "bird", "鸽": "bird", "雀": "bird", "燕": "bird", "鹏": "bird",
	"鱼": "fish", "虾": "fish", "龟": "fish", "鲸": "fish", "龙": "fish",
	"虫": "insect", "蝶": "insect", "蜂": "insect", "蚁": "insect", "蝉": "insect",
	# 自然
	"水": "water", "河": "water", "海": "water", "江": "water", "湖": "water",
	"雨": "water", "雪": "ice", "冰": "ice", "霜": "ice", "泉": "water",
	"火": "fire", "炎": "fire", "烧": "fire", "焰": "fire", "炉": "fire",
	"木": "wood", "树": "wood", "林": "wood", "竹": "wood", "草": "plant",
	"花": "plant", "叶": "plant", "根": "plant", "芽": "plant", "苗": "plant",
	"金": "metal", "铁": "metal", "银": "metal", "铜": "metal", "钢": "metal",
	"土": "earth", "地": "earth", "山": "mountain", "石": "earth", "岩": "earth",
	"风": "wind", "雷": "thunder", "电": "thunder", "云": "sky", "天": "sky",
	"阳": "sun", "星": "moon", "光": "light",
	# 人 / 身体
	"人": "person", "你": "person", "我": "person", "他": "person", "她": "person",
	"手": "hand", "足": "person", "脚": "person", "眼": "body", "耳": "body",
	"口": "speech", "心": "emotion", "头": "body",
	# 动作
	"打": "action", "击": "action", "战": "weapon", "斗": "weapon", "攻": "action",
	"飞": "bird", "跳": "action", "走": "action", "看": "body", "听": "sound",
	"说": "speech", "唱": "sound", "笑": "emotion", "哭": "emotion",
	# 器物
	"刀": "weapon", "剑": "weapon", "枪": "weapon", "弓": "weapon", "箭": "weapon",
	"车": "vehicle", "船": "vehicle", "门": "tool", "窗": "tool", "灯": "light",
	"衣": "cloth", "布": "cloth", "丝": "cloth", "线": "cloth",
	"饭": "food", "米": "food", "菜": "food", "果": "food", "茶": "food",
	# 抽象
	"一": "number", "二": "number", "三": "number", "十": "number", "百": "number",
	"千": "number", "万": "number", "数": "number", "算": "number",
	"红": "color", "黄": "color", "蓝": "color", "绿": "color", "白": "color",
	"黑": "dark", "彩": "color", "色": "color",
	"爱": "emotion", "喜": "emotion", "怒": "fire", "哀": "emotion", "乐": "sound",
	"年": "time", "时": "time", "春": "time", "秋": "time", "今": "time",
	"声": "sound", "音": "sound", "歌": "sound", "琴": "sound", "鼓": "sound",
}

## emoji → 大类（数据里 100% 覆盖，作为最强的一层映射）
const EMOJI_MAP := {
	"💧": "water", "🌊": "water", "☔": "water", "🏞": "water",
	"🔥": "fire", "🕯": "fire", "☄": "fire",
	"🌳": "wood", "🌲": "wood", "🌿": "plant", "🍀": "plant", "🌱": "plant",
	"🌸": "plant", "🌷": "plant", "🌻": "plant", "🍂": "plant", "🌾": "food",
	"⛰": "mountain", "🏔": "mountain", "🗻": "mountain", "🪨": "earth", "🟫": "earth",
	"☀": "sun", "🌞": "sun", "🌤": "sun", "🌙": "moon", "⭐": "moon", "🌟": "moon",
	"☁": "sky", "🌫": "sky", "🌈": "light", "⚡": "thunder", "🌩": "thunder",
	"❄": "ice", "🧊": "ice", "💨": "wind", "🌪": "wind",
	"🐴": "beast", "🐎": "beast", "🐯": "beast", "🦁": "beast", "🐻": "beast",
	"🐱": "beast", "🐶": "beast", "🐮": "beast", "🐑": "beast", "🐷": "beast",
	"🐰": "beast", "🐺": "beast", "🐘": "beast", "🐒": "beast", "🦊": "beast",
	"🐦": "bird", "🐔": "bird", "🦆": "bird", "🦢": "bird", "🕊": "bird",
	"🦅": "bird", "🐧": "bird", "🦉": "bird",
	"🐟": "fish", "🐠": "fish", "🐢": "fish", "🐳": "fish", "🦐": "fish", "🦀": "fish",
	"🐛": "insect", "🦋": "insect", "🐝": "insect", "🐜": "insect", "🦗": "insect",
	"🧍": "person", "👤": "person", "👦": "person", "👧": "person", "👨": "person",
	"👩": "person", "👶": "person", "🧑": "person", "🚶": "action", "🏃": "action",
	"✋": "hand", "🤚": "hand", "👋": "hand", "🤝": "hand", "👏": "hand",
	"👄": "speech", "💬": "speech", "🗣": "speech", "👂": "sound", "🔊": "sound",
	"🎵": "sound", "🎶": "sound", "🎤": "sound", "🥁": "sound", "🎸": "sound",
	"🔪": "weapon", "⚔": "weapon", "🗡": "weapon", "🏹": "weapon", "🛡": "weapon",
	"🔧": "tool", "🔨": "tool", "🪚": "tool", "⚙": "tool", "🔩": "tool",
	"🚗": "vehicle", "🚌": "vehicle", "🚲": "vehicle", "✈": "vehicle", "🚢": "vehicle",
	"🏠": "tool", "🏢": "tool", "🚪": "tool", "🪟": "tool", "🪑": "tool", "🛏": "tool",
	"🧵": "cloth", "🧶": "cloth", "👕": "cloth", "👗": "cloth", "🎀": "cloth",
	"🍚": "food", "🍎": "food", "🥬": "food", "🍇": "food", "🍞": "food", "🍵": "food",
	"🔢": "number", "1️⃣": "number", "2️⃣": "number", "3️⃣": "number",
	"🔟": "number", "💯": "number", "🧮": "number",
	"🎨": "color", "🖌": "color", "🔴": "color", "🟡": "color", "🔵": "color",
	"🟢": "color", "⚫": "dark", "⬛": "dark", "🌑": "dark", "👻": "dark",
	"💗": "emotion", "❤": "emotion", "😊": "emotion", "😢": "emotion", "😠": "emotion",
	"😄": "emotion", "🥰": "emotion", "😍": "emotion",
	"⏰": "time", "🕐": "time", "📅": "time", "🌅": "time", "🌇": "time",
	"🧭": "space", "🗺": "space", "📐": "space", "📏": "space",
	"🦵": "body", "🦶": "body", "👀": "body", "👁": "body", "🦷": "body", "💪": "body",
	"🫁": "body", "🫀": "body", "🧠": "body", "🦴": "body",
	"🔍": "action", "🔎": "action", "📖": "tool", "📕": "tool", "✏": "tool",
	"📝": "tool", "🗒": "tool", "📄": "tool", "💡": "light", "🔦": "light",
	"🔷": "default", "🔶": "default", "🔸": "default", "🔹": "default",
	"⬜": "default", "🟥": "color", "🟦": "color", "🟨": "color", "🟩": "color",
}
## 部首 → 大类（覆盖大部字）
const RADICAL := {
	"氵": "water", "水": "water", "冫": "ice", "川": "water",
	"火": "fire", "灬": "fire", "日": "sun", "月": "moon",
	"木": "wood", "艹": "plant", "竹": "wood", "禾": "plant", "米": "food",
	"钅": "metal", "金": "metal", "石": "earth", "土": "earth", "山": "mountain",
	"风": "wind", "气": "sky", "云": "sky",
	"马": "beast", "牛": "beast", "羊": "beast", "犬": "beast", "犭": "beast",
	"鸟": "bird", "虫": "insect", "鱼": "fish",
	"口": "speech", "言": "speech", "讠": "speech", "心": "emotion", "忄": "emotion",
	"扌": "hand", "手": "hand", "足": "person", "走": "action", "辶": "action",
	"刀": "weapon", "刂": "weapon", "弓": "weapon", "戈": "weapon",
	"车": "vehicle", "舟": "vehicle", "门": "tool", "斤": "tool",
	"糸": "cloth", "纟": "cloth", "巾": "cloth", "衣": "cloth", "衤": "cloth",
	"食": "food", "饣": "food", "酉": "food",
	"目": "body", "耳": "body", "页": "body", "身": "body", "骨": "body",
	"王": "metal", "玉": "metal", "贝": "metal",
	"示": "light", "礻": "light", "鬼": "dark", "黑": "dark",
}


## 取一个字的意象定义
## 优先级：专属字 > emoji > 部首 > 兜底
func kind_of(ch: String, rad: String = "", emoji: String = "") -> Dictionary:
	var k: String = "default"
	if ch != "" and SPECIAL.has(ch):
		k = SPECIAL[ch]
	elif emoji != "" and EMOJI_MAP.has(emoji):
		k = EMOJI_MAP[emoji]
	elif rad != "":
		if RADICAL.has(rad):
			k = RADICAL[rad]
		elif rad.length() >= 1 and RADICAL.has(rad.substr(0, 1)):
			k = RADICAL[rad.substr(0, 1)]
	return KINDS.get(k, KINDS["default"])


func color_of(ch: String, rad: String = "", emoji: String = "") -> Color:
	return Color(kind_of(ch, rad, emoji).get("color", "#ffd23c"))

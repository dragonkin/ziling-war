class_name Terrain
extends Node2D
## 地形系统 —— 地面高度图（支持分段不同主题配色）
##
## 世界坐标：x 向右，y 向下。
## 每个场景段落由若干「地面段」拼接，每段有 x0/x1/gy，
## 还带 theme 字段决定该段的配色（这样跨场景能自然换色）。

const THEME_COLORS := {
	"water":  {"top": Color("#8a95a6"), "face": Color("#42506a"), "edge": Color("#c3cbd9")},
	"bamboo": {"top": Color("#9c8f6a"), "face": Color("#5e5439"), "edge": Color("#c4b58a")},
	"palace": {"top": Color("#d8c79a"), "face": Color("#8e7748"), "edge": Color("#f0e2bc")},
	"lava":   {"top": Color("#4a3a38"), "face": Color("#231818"), "edge": Color("#8a4a30")},
	"ruins":  {"top": Color("#8d8878"), "face": Color("#4b4839"), "edge": Color("#bbb59e")},
	"sky":    {"top": Color("#dfe8f2"), "face": Color("#8fa2ba"), "edge": Color("#ffffff")},
}

var segs: Array = []          # [{x0,x1,gy,theme}, ...]
var theme := "water"


func setup(p_segs: Array, p_theme: String) -> void:
	segs = p_segs.duplicate()
	segs.sort_custom(func(a, b): return a["x0"] < b["x0"])
	theme = p_theme
	queue_redraw()


## 查询某 x 处的地面 y
func ground_y_at(x: float) -> float:
	if segs.is_empty():
		return 520.0
	for s in segs:
		if x >= s["x0"] and x <= s["x1"]:
			return float(s["gy"])
	if x < segs[0]["x0"]:
		return float(segs[0]["gy"])
	return float(segs[segs.size() - 1]["gy"])


## 该点是否处在台阶边界（用于踩台动画）
func step_at(x: float, prev_x: float) -> bool:
	if segs.size() < 2:
		return false
	return abs(ground_y_at(prev_x) - ground_y_at(x)) > 6.0


## ★ 2026-09 用户选择「半透明地面」：背景图自带地面质感，实心填充会把背景盖成纯色。
##
## 改良（v2）：原来用「主题色半透明」，实测在废墟 / 宫阙这类暖灰背景上
## 地面色和背景几乎同色 → 仍然糊在一起、角色显浮空。
## 现在改成「中性暗色 + 上暗下渐隐」：暗化在任何背景上都必然降低亮度，
## 所以无论背景是什么色系，脚下都有一条清楚的地面；
## 主题色只保留在「台面薄条」和「脚底线」上，场景个性依旧看得出来。
const FLOOR_DARK := Color(0.05, 0.05, 0.09)   # 中性暗色（不带色相，不与任何背景撞色）
## 分 5 段做「上实下虚」渐变：脚下最实（读作"地面"），往下渐隐（不把下半屏糊成黑块）
const FLOOR_BANDS := [0.80, 0.66, 0.48, 0.34, 0.24]


func _draw() -> void:
	# ⚠️ 底部：注音字幕条在 602~716（比原来高，要放两行拼音+汉字），地面画到 586 即可
	var bottom := 586.0
	for s in segs:
		var x0: float = s["x0"]
		var x1: float = s["x1"]
		var gy: float = s["gy"]
		var th: String = s.get("theme", theme)
		var c: Dictionary = THEME_COLORS.get(th, THEME_COLORS["water"])
		var top: Color = c["top"]
		var edge: Color = c["edge"]
		# 地面比 bottom 还低时跳过（避免负高度）
		if gy >= bottom - 4.0:
			continue

		# ① 地面主体：中性暗色「上实下虚」渐变 —— 脚下最实，读作可站立的地面
		var bands: int = FLOOR_BANDS.size()
		var span: float = bottom - gy
		for i in bands:
			var y0: float = gy + span * float(i) / float(bands)
			var y1: float = gy + span * float(i + 1) / float(bands)
			var a: float = FLOOR_BANDS[i]
			draw_rect(Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0)),
				Color(FLOOR_DARK.r, FLOOR_DARK.g, FLOOR_DARK.b, a), true)

		# ② 表层土：紧贴脚下的主题色薄层（保留场景个性：水岸偏蓝、熔岩偏红）
		draw_rect(Rect2(Vector2(x0, gy + 1), Vector2(x1 - x0, 7)),
			Color(top.r, top.g, top.b, 0.50), true)

		# ③ 地平线：细而不刺眼的暖亮线（3px，不用纯白，避免"塑料感"）
		var line_col := Color(edge.r, edge.g, edge.b, 0.80)
		draw_rect(Rect2(Vector2(x0, gy - 3), Vector2(x1 - x0, 3)), line_col, true)

		# ④ 台阶竖边：有高差时勾出侧壁
		var step_l: bool = abs(_gy_of_seg_at(x0 - 20.0) - gy) > 6.0
		var step_r: bool = abs(_gy_of_seg_at(x1 + 20.0) - gy) > 6.0
		if step_l:
			var nl: float = _gy_of_seg_at(x0 - 20.0)
			draw_rect(Rect2(Vector2(x0, min(gy, nl)), Vector2(5, abs(nl - gy))),
				Color(edge.r, edge.g, edge.b, 0.62), true)
		if step_r:
			var nr: float = _gy_of_seg_at(x1 + 20.0)
			draw_rect(Rect2(Vector2(x1 - 5, min(gy, nr)), Vector2(5, abs(nr - gy))),
				Color(edge.r, edge.g, edge.b, 0.52), true)

		# ⑤ 石板缝：极淡竖纹，增加地面质感
		var n := int((x1 - x0) / 90.0)
		for i in range(1, n + 1):
			var xv := x0 + i * 90.0
			draw_rect(Rect2(Vector2(xv, gy + 18), Vector2(2, min(46.0, bottom - gy - 18))),
				Color(1.0, 1.0, 1.0, 0.06), true)

		# ⑥ 地平线雾带：地面线往上一小段用主题亮色做"大气透视"柔光，
		#    把背景与地面的硬接边化开，增强纵深层次（立体感关键一笔）
		var fog_h := 48.0
		var fbands := 6
		for fi in fbands:
			var fy0 := gy - fog_h + fog_h * float(fi) / float(fbands)
			var fy1 := gy - fog_h + fog_h * float(fi + 1) / float(fbands)
			var fa := 0.18 * (1.0 - float(fi) / float(fbands))
			draw_rect(Rect2(Vector2(x0, fy0), Vector2(x1 - x0, fy1 - fy0)),
				Color(edge.r, edge.g, edge.b, fa), true)


## 查某点地面高度（供台阶判定，不依赖 is_inside）
func _gy_of_seg_at(x: float) -> float:
	if segs.is_empty():
		return 520.0
	for s in segs:
		if x >= s["x0"] and x <= s["x1"]:
			return float(s["gy"])
	if x < segs[0]["x0"]:
		return float(segs[0]["gy"])
	return float(segs[segs.size() - 1]["gy"])

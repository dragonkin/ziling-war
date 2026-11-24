shader_type canvas_item;
// 大招元素兽 —— 生物感形变 v3
//
// v1：单一正弦行波 → 机械感（等速等幅的"弹簧"）
// v3：真生物的游动 = 多频叠加 + 身体扭转 + 湍流，本版三层齐上：
//   ① 主波：低频大摆（身体大弧度摆动），头 25% 幅度、尾 100%
//   ② 次波：中频小幅（肌肉蠕动），让主波不再是"完美正弦"
//   ③ 湍流：两个不可通约频率 sin 相乘 → 伪噪声，边缘絮状乱颤
//   ④ 水平剪切：uv.x 亦随高度偏移 → 身体"扭"而不是只"上下平移"
//
// ★ 为什么用 shader 而不是"切片 Sprite"：
//   切片会在片与片之间留下可见竖缝（ADD 混合下尤其明显）。
//   shader 是逐像素连续采样，天然无缝且更顺滑。

render_mode blend_add;

// ---- 波动参数（由 GDScript 按五行设定）----
uniform float u_t : hint_range(0.0, 100.0) = 0.0;   // 已播放时间
uniform float u_f = 6.8;          // 主波频率（越高越"利"）
uniform float u_amp = 0.055;      // 主波振幅（UV 单位，1.0 = 整张高度）
uniform float u_phi = 0.50;       // 列相位差（波沿身体传播的速度）
uniform float u_grow = 1.0;       // 生长 0→1（起手时收紧）
uniform float u_drift = 0.0;      // 尾部整体下垂量（龙尾下垂）
uniform float u_jitter = 0.0;     // 高频乱抖（雷系用）
uniform float u_twist = 0.0;      // ★ 水平剪切量（身体扭转，0=关）

void fragment() {
	float k = UV.x;                       // 0=头 1=尾
	float taper = 0.22 + 0.78 * k;        // 头几乎不动、尾大幅摆（生物特征）

	// ① 主波：沿身体向后传播
	float w1 = sin(u_t * u_f - k * u_phi);
	// ② 次波：2.3 倍频 + 0.4 相位偏移，打破"完美正弦"
	float w2 = sin(u_t * u_f * 2.3 - k * u_phi * 1.7 + 0.9) * 0.34;
	// ③ 湍流：两个不可通约频率相乘 → 周期极长的伪噪声，边缘乱颤
	float turb = sin(u_t * 5.1 + k * 9.0) * sin(u_t * 3.7 - k * 4.0) * 0.5
			+ sin(u_t * 11.3 + k * 17.0) * 0.22;

	float wave = (w1 + w2) * u_amp * taper
			+ turb * u_amp * 0.45 * taper * taper;   // 湍流越靠尾越乱
	float jit = sin(u_t * 34.0 + k * 60.0) * u_jitter;
	float dy = (wave + u_drift * k * k + jit) * u_grow;

	vec2 uv = UV;
	uv.y += dy;
	// ④ 水平剪切：上半身与下半身朝相反方向轻推 → 扭转感
	//    幅度与该列的纵向位移成比例（位移大的地方扭得多）
	uv.x += (uv.y - 0.5) * dy * u_twist * 4.0;

	// ★ 越界直接透明：否则边缘会"拉丝"出拖动痕迹
	if (uv.y < 0.0 || uv.y > 1.0 || uv.x < 0.0 || uv.x > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 c = texture(TEXTURE, uv);
		// 上下两端柔和渐隐，避免硬边
		float edge = smoothstep(0.0, 0.06, uv.y) * smoothstep(1.0, 0.94, uv.y);
		COLOR = vec4(c.rgb * COLOR.rgb, c.a) * COLOR.a * edge;
	}
}

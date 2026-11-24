shader_type canvas_item;
// ★ 2D 立绘「立体化」着色器 —— 在不改素材的前提下削弱平面感
//   ① 底部环境遮蔽：脚踝/裙摆压暗，把角色"压"进地面，产生接地体积
//   ② 顶部边缘光：从左上打一束光，人物上缘提亮（模拟体积受光）
//   ③ 侧缘暗部：右下方压暗，形成"正面亮/背面暗"的圆转
//   ④ 对比增强：整体提升层次，减少"印刷贴纸"的平铺感
//   ⑤ 噪点颗粒：加一点点银盐颗粒，消除纯色块的塑料感

uniform float ao_strength : hint_range(0.0, 1.5) = 0.55;   // 底部遮蔽强度
uniform float rim_strength : hint_range(0.0, 1.0) = 0.30;  // 顶缘光强度
uniform float rim_width : hint_range(0.0, 1.0) = 0.35;     // 顶缘光宽度（自上而下）
uniform float side_dark : hint_range(0.0, 1.0) = 0.16;     // 侧缘暗部
uniform float contrast : hint_range(0.5, 2.0) = 1.12;      // 对比增强
uniform float grain : hint_range(0.0, 0.1) = 0.018;        // 颗粒强度
uniform vec3 rim_color : source_color = vec3(1.0, 0.97, 0.88);
// 注：亮度/受击闪白仍由 modulate 驱动（canvas_item 的 modulate 会乘在 COLOR 之后），
//     这里不重复处理，避免变成"双重变暗"

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// 全透明像素直接丢弃，避免无谓计算与边缘毛刺
	if (tex.a < 0.02) {
		COLOR = vec4(0.0);
	} else {
		vec3 c = tex.rgb;

		// ① 底部环境遮蔽：UV.y 越大越靠下（canvas 坐标系 y 向下）
		float bot = smoothstep(0.55, 1.0, UV.y);
		c *= 1.0 - bot * ao_strength * 0.45;

		// ② 顶缘光：靠上的一段提亮 + 向光色偏移
		float rim = (1.0 - smoothstep(0.0, rim_width, UV.y)) * rim_strength;
		c = mix(c, c * rim_color, rim);

		// ③ 侧缘暗部：右下方渐暗 → 圆转的体积感
		float side = smoothstep(0.35, 1.0, UV.x) * side_dark;
		c *= 1.0 - side * smoothstep(0.3, 1.0, UV.y);

		// ④ 对比增强（围绕中灰做 S 曲线拉伸）
		c = clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0);

		// ⑤ 银盐颗粒：轻微打散纯色块
		float g = (hash(FRAGCOORD.xy) - 0.5) * grain;
		c = clamp(c + g, 0.0, 1.0);

		COLOR = vec4(c, tex.a);
	}
}

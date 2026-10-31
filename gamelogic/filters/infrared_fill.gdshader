shader_type spatial;
render_mode unshaded, depth_draw_never;
uniform vec4 thermal_color : source_color = vec4(1.0, 0.28, 0.035, 1.0);
void fragment() {
	// Обычная проверка глубины сохранена: заливка не показывает цель сквозь стены.
	ALBEDO = thermal_color.rgb;
}

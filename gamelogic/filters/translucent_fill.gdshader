shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 thermal_color : source_color = vec4(1.0, 0.28, 0.035, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.5;
void fragment() {
	ALBEDO = thermal_color.rgb;
	ALPHA = opacity;
}
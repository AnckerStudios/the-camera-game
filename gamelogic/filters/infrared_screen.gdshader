shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform bool ultraviolet_mode = false;
uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform vec4 cold_color : source_color = vec4(0.12, 0.34, 0.42, 1.0);
void fragment() {
	vec3 original = texture(screen_texture, SCREEN_UV).rgb;
	float luminance = dot(original, vec3(0.2126, 0.7152, 0.0722));
	vec3 cold = mix(vec3(0.015, 0.025, 0.07), cold_color.rgb, luminance);
	// Сохраняем тёплую заливку целей на фоне холодного окружения.
	float contrast = ultraviolet_mode ? min(original.g, original.b) - original.r : original.r - max(original.g, original.b);
	float heat = smoothstep(0.08, 0.45, contrast);
	vec3 infrared = mix(cold, original, heat);
	COLOR = vec4(mix(original, infrared, strength), 1.0);
}

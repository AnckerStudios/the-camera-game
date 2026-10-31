shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.65;
uniform float crt_strength : hint_range(0.0, 1.0) = 0.22;
uniform float vignette_start : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_end : hint_range(0.0, 1.0) = 0.85;
uniform float scanline_pixels : hint_range(1.0, 12.0) = 3.0;
uniform vec4 tint : source_color = vec4(0.01, 0.075, 0.09, 1.0);
void fragment() {
	vec2 centered = (UV - 0.5) * 2.0;
	float radial = length(centered) / 1.41421356;
	float mask = smoothstep(vignette_start, max(vignette_end, vignette_start + 0.001), radial);
	float stripe = 0.5 + 0.5 * sin(FRAGCOORD.y * 6.2831853 / scanline_pixels + TIME * 1.5);
	float opacity = mask * strength + mask * stripe * crt_strength;
	COLOR = vec4(tint.rgb, clamp(opacity, 0.0, 0.95));
}

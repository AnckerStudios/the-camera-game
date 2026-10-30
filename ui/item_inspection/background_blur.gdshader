shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_strength : hint_range(0.0, 5.0) = 2.5;
void fragment() {
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, blur_strength).rgb;
	COLOR = vec4(blurred * 0.45, 1.0);
}

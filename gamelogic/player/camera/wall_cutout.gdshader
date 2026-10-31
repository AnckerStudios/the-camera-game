shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_texture = false;
uniform float base_roughness = 1.0;
uniform float base_metallic = 0.0;
uniform vec3 texture_scale = vec3(1.0);
uniform vec3 texture_offset = vec3(0.0);
// Общие для всех стен; выставляются один раз за кадр из wall_cutout.gd.
global uniform vec2 wall_cutout_target_uv;
global uniform vec2 wall_cutout_viewport_size;

uniform float radius_pixels = 90.0;

uniform float interior_visibility : hint_range(0.01, 8.0, 0.01) = 2.0;


uniform bool cutout_enabled = false;
uniform int enemy_cutout_count = 0;
uniform vec4 enemy_cutouts[8];

// Минимальная видимость в центре постепенно растёт по всей площади круга.
float circle_visibility(float distance_to_center, float radius) {
	float radial_progress = smoothstep(0.0, max(radius, 0.001), distance_to_center);
	radial_progress = pow(radial_progress, max(interior_visibility, 0.01));
	float radial_visibility = radial_progress;
	return radial_visibility;
}

void fragment() {
	float visibility = 1.0;
	if (cutout_enabled && radius_pixels > 0.0) {
		float distance_pixels = length((SCREEN_UV - wall_cutout_target_uv) * wall_cutout_viewport_size);
		visibility = circle_visibility(distance_pixels, radius_pixels);
	}
	// Каждый круг вычисляет собственное расстояние до центра до объединения.
	for (int i = 0; i < enemy_cutout_count; i++) {
		float radius = enemy_cutouts[i].z;
		if (radius <= 0.0) { continue; }
		float distance_to_enemy = length((SCREEN_UV - enemy_cutouts[i].xy) * wall_cutout_viewport_size);
		visibility = min(visibility, circle_visibility(distance_to_enemy, radius));
	}
	vec4 color = base_color;
	if (has_texture) {
		color *= texture(base_texture, UV * texture_scale.xy + texture_offset.xy);
	}
	ALBEDO = color.rgb;
	// Одинаковый экранный порог для всех поверхностей не накапливает прозрачность слоёв.
	// Материал остаётся непрозрачным и корректно участвует в проверке глубины.
	vec2 pixel = floor(SCREEN_UV * wall_cutout_viewport_size);
	float threshold = fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
	if (visibility <= threshold) {
		discard;
	}
	ROUGHNESS = base_roughness;
	METALLIC = base_metallic;
}

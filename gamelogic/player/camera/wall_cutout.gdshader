shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_texture = false;
uniform float base_roughness = 1.0;
uniform float base_metallic = 0.0;
uniform vec3 texture_scale = vec3(1.0);
uniform vec3 texture_offset = vec3(0.0);
uniform vec2 target_uv = vec2(-10.0);
uniform vec2 viewport_size = vec2(1.0);

uniform float radius_pixels = 90.0;

// Минимальная доля сохраняемых пикселей в центре; к краю возрастает до 1.
uniform float interior_visibility : hint_range(0.0, 1.0, 0.01) = 0.02;

uniform bool cutout_enabled = false;
uniform int enemy_cutout_count = 0;
uniform vec4 enemy_cutouts[8];

// Минимальная видимость в центре постепенно растёт по всей площади круга.
float circle_visibility(float distance_to_center, float radius) {
	float radial_progress = smoothstep(0.0, max(radius, 0.001), distance_to_center);
	float radial_visibility = mix(interior_visibility, 1.0, radial_progress);
	return radial_visibility;
}

void fragment() {
	float visibility = 1.0;
	if (cutout_enabled && radius_pixels > 0.0) {
		float distance_pixels = length((SCREEN_UV - target_uv) * viewport_size);
		visibility = circle_visibility(distance_pixels, radius_pixels);
	}
	// Каждый круг вычисляет собственное расстояние до центра до объединения.
	for (int i = 0; i < enemy_cutout_count; i++) {
		float radius = enemy_cutouts[i].z;
		if (radius <= 0.0) { continue; }
		float distance_to_enemy = length((SCREEN_UV - enemy_cutouts[i].xy) * viewport_size);
		visibility = min(visibility, circle_visibility(distance_to_enemy, radius));
	}
	vec4 color = base_color;
	if (has_texture) {
		color *= texture(base_texture, UV * texture_scale.xy + texture_offset.xy);
	}
	ALBEDO = color.rgb;
	// Одинаковый экранный порог для всех поверхностей не накапливает прозрачность слоёв.
	// Материал остаётся непрозрачным и корректно участвует в проверке глубины.
	vec2 pixel = floor(SCREEN_UV * viewport_size);
	float threshold = fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
	if (visibility <= threshold) {
		discard;
	}
	ROUGHNESS = base_roughness;
	METALLIC = base_metallic;
}

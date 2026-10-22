shader_type spatial;
// Ground: blends trampled mud, sparse grass and forest floor by vertex colour
// (r = mud, g = forest floor, the rest = grass). Textures tile in world space.

uniform sampler2D mud_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float tile_size = 4.0;
uniform vec3 tint : source_color = vec3(0.8, 0.78, 0.76);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / tile_size;
	float mud = COLOR.r;
	float forest = COLOR.g * (1.0 - mud);
	float grass = clamp(1.0 - mud - forest, 0.0, 1.0);
	vec3 albedo = texture(mud_albedo, uv).rgb * 0.72 * mud
		+ texture(grass_albedo, uv * 0.8).rgb * grass
		+ texture(forest_albedo, uv * 0.9).rgb * forest;
	vec3 normal = texture(mud_normal, uv).rgb * mud
		+ texture(grass_normal, uv * 0.8).rgb * grass
		+ texture(forest_normal, uv * 0.9).rgb * forest;
	float rough = texture(mud_rough, uv).r * mud
		+ texture(grass_rough, uv * 0.8).r * grass
		+ texture(forest_rough, uv * 0.9).r * forest;
	ALBEDO = albedo * tint;
	NORMAL_MAP = normal;
	// Wet mud would glint like frost under the moon; keep the ground matte.
	ROUGHNESS = max(rough, 0.85);
	SPECULAR = 0.2;
}

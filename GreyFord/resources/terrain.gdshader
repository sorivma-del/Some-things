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

uniform float normal_strength = 1.0;
uniform bool yard_enabled = false;
uniform vec2 yard_center;
uniform vec2 yard_door;
uniform float yard_radius = 28.0;

float path_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0));
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / tile_size;
	float mud = COLOR.r;
	if (yard_enabled) {
		float yard = 1.0 - smoothstep(yard_radius - 6.0, yard_radius, length(world_pos.xz - yard_center));
		float tracks = max(COLOR.b, 1.0 - smoothstep(0.75, 1.65, path_distance(world_pos.xz, yard_door, yard_center + vec2(7.0, 7.0))));
		float hearth = 1.0 - smoothstep(2.5, 5.0, length(world_pos.xz - yard_center));
		float patches = 0.22 + 0.16 * sin(world_pos.x * 0.43) * sin(world_pos.z * 0.37);
		float yard_mud = max(patches, max(tracks, hearth) * 0.95);
		mud = mix(mud, yard_mud, yard);
	}
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
	NORMAL_MAP_DEPTH = normal_strength;
	// Wet mud would glint like frost under the moon; keep the ground matte.
	ROUGHNESS = max(rough, 0.85);
	SPECULAR = 0.2;
}

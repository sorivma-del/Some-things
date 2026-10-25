shader_type spatial;
render_mode cull_disabled;
uniform sampler2D diffuse_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D alpha_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	VERTEX.x += sin(TIME * 1.1 + center.x * 0.7 + center.z * 0.3) * max(VERTEX.y, 0.0) * 0.025;
}
void fragment() {
	ALBEDO = texture(diffuse_map, UV).rgb * vec3(0.65, 0.78, 0.6);
	ALPHA = texture(alpha_map, UV).r;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = 0.5;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.06, 0.12, 0.025);
}

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz * scale.x, 0), vec4(INV_VIEW_MATRIX[1].xyz * scale.y, 0), vec4(INV_VIEW_MATRIX[2].xyz * scale.z, 0), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 5.0 + vec2(TIME * -0.1, TIME * -0.18);
	float density = noise(p) * 0.65 + noise(p * 2.1) * 0.35;
	float edge = 1.0 - smoothstep(0.15, 0.5, length(UV - 0.5));
	ALBEDO = vec3(0.24, 0.26, 0.28);
	ALPHA = edge * smoothstep(0.22, 0.7, density) * COLOR.a * 0.6;
}

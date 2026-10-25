shader_type spatial;
render_mode cull_disabled;
varying float tint;
void vertex() {
	tint = INSTANCE_CUSTOM.r;
	vec3 center = MODEL_MATRIX[3].xyz;
	VERTEX.y += sin(TIME * 1.2 + center.x * 0.5 + center.z * 0.4) * VERTEX.x * 0.18;
}
void fragment() {
	ALBEDO = mix(vec3(0.27, 0.055, 0.012), vec3(0.52, 0.21, 0.025), tint);
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
	BACKLIGHT = vec3(0.11, 0.035, 0.005);
}

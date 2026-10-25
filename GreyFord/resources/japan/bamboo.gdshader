shader_type spatial;
render_mode cull_disabled;
void vertex() {
	float tip = clamp(VERTEX.x, 0.0, 1.1);
	vec3 center = MODEL_MATRIX[3].xyz;
	VERTEX.y += sin(TIME * 1.3 + center.x * 0.7 + center.z) * tip * 0.055;
}
void fragment() {
	ALBEDO = mix(vec3(0.07, 0.14, 0.045), vec3(0.16, 0.24, 0.075), UV.x);
	ROUGHNESS = 0.95;
	BACKLIGHT = vec3(0.07, 0.11, 0.035);
}

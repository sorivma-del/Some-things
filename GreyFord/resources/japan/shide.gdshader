shader_type spatial;
render_mode cull_disabled;
void vertex() {
	float hanging = clamp((3.0 - VERTEX.y) * 2.0, 0.0, 1.0);
	VERTEX.x += sin(TIME * 1.1 + VERTEX.x * 0.7 + VERTEX.z * 0.3) * hanging * 0.035;
}
void fragment() {
	ALBEDO = vec3(0.65, 0.63, 0.55);
	ROUGHNESS = 0.95;
	BACKLIGHT = vec3(0.05);
}

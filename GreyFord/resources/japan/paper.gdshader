shader_type spatial;
uniform float warmth = 0.02;
void fragment() {
	float fiber = sin(UV.y * 450.0) * sin(UV.x * 237.0) * 0.025;
	ALBEDO = vec3(0.62, 0.57, 0.44) + fiber;
	EMISSION = vec3(1.0, 0.48, 0.16) * warmth;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}

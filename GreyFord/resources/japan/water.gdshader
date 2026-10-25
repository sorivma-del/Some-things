shader_type spatial;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float a = sin(world_position.x * 5.0 + world_position.z * 2.2 + TIME * 0.7);
	float b = cos(world_position.z * 6.0 - world_position.x * 1.6 - TIME * 0.6);
	NORMAL_MAP = vec3(0.5 + a * 0.055, 0.5 + b * 0.055, 1.0);
	NORMAL_MAP_DEPTH = 0.4;
	ALBEDO = vec3(0.018, 0.05, 0.043);
	ROUGHNESS = 0.17;
	SPECULAR = 0.85;
	METALLIC = 0.05;
}

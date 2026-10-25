shader_type spatial;
uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float texture_grain = texture(grain, world_position.xz * 0.6).r;
	float rake = sin(world_position.x * 48.0 + sin(world_position.z * 0.4) * 0.3);
	ALBEDO = vec3(0.43, 0.425, 0.37) * (0.88 + texture_grain * 0.18 + rake * 0.025);
	ROUGHNESS = 0.98;
	SPECULAR = 0.12;
}

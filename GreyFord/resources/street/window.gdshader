shader_type spatial;
uniform float candle = 1.0;
void fragment() {
	float grime = 0.6 + 0.4 * sin(UV.x * 23.0 + sin(UV.y * 19.0)) * sin(UV.y * 31.0);
	float edge = smoothstep(0.0, 0.12, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	ALBEDO = vec3(0.035, 0.025, 0.015) * grime;
	EMISSION = vec3(0.28, 0.105, 0.025) * candle * grime * edge;
	ROUGHNESS = 0.5;
	SPECULAR = 0.35;
}

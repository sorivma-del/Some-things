shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying float phase;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	phase = MODEL_MATRIX[0].x * 2.7;
	VERTEX.x += sin(TIME * 3.7 + VERTEX.y * 4.0 + phase) * max(VERTEX.y + 0.4, 0.0) * 0.08;
}
void fragment() {
	float h = 1.0 - UV.y;
	float flow = noise(vec2(UV.x * 5.0 + phase, h * 5.0 - TIME * 2.1));
	float width = mix(0.44, 0.03, pow(h, 0.65));
	float edge = abs(UV.x - 0.5 + (flow - 0.5) * 0.27 * h);
	float mask = (1.0 - smoothstep(width * 0.45, width, edge)) * smoothstep(0.0, 0.1, h);
	mask *= 1.0 - smoothstep(0.6 + flow * 0.3, 1.0, h);
	vec3 color = mix(vec3(1.0, 0.7, 0.22), vec3(0.72, 0.16, 0.025), h);
	ALBEDO = color;
	EMISSION = color * 0.38;
	ALPHA = mask * 0.72;
}

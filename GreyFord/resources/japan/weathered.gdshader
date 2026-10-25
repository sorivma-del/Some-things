shader_type spatial;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bump_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.65, 0.6, 0.5, 1.0);
uniform float texture_scale = 0.7;
uniform float bump_strength = 0.3;
uniform float wetness = 0.45;
varying vec3 world_position;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
vec3 sample_tri(sampler2D tex, vec3 p, vec3 weights) {
	return texture(tex, p.yz).rgb * weights.x + texture(tex, p.xz).rgb * weights.y + texture(tex, p.xy).rgb * weights.z;
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	vec3 p = world_position * texture_scale;
	vec3 color = sample_tri(color_map, p, w) * tint.rgb;
	vec3 nx = texture(bump_map, p.yz).rgb * 2.0 - 1.0;
	vec3 ny = texture(bump_map, p.xz).rgb * 2.0 - 1.0;
	vec3 nz = texture(bump_map, p.xy).rgb * 2.0 - 1.0;
	vec3 mapped = normalize(vec3(nx.z * sign(n.x), nx.x, nx.y) * w.x + vec3(ny.x, ny.z * sign(n.y), ny.y) * w.y + vec3(nz.x, nz.y, nz.z * sign(n.z)) * w.z);
	NORMAL = normalize(mat3(VIEW_MATRIX) * normalize(mix(n, mapped, bump_strength)));
	float patches = smoothstep(0.48, 0.79, noise(world_position.xz * 0.75) * 0.7 + noise(world_position.xz * 2.3) * 0.3);
	float wet = patches * wetness * (0.25 + max(n.y, 0.0) * 0.75);
	float dirt = (1.0 - smoothstep(0.05, 0.8, world_position.y)) * noise(world_position.xz * 3.1);
	ALBEDO = color * (1.0 - wet * 0.22 - dirt * 0.14);
	float rough = texture(rough_map, p.yz).r * w.x + texture(rough_map, p.xz).r * w.y + texture(rough_map, p.xy).r * w.z;
	ROUGHNESS = mix(clamp(rough, 0.55, 1.0), 0.31, wet);
	SPECULAR = 0.36;
}

shader_type spatial;
uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_color : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float texture_grain = texture(grain, p * 0.13).r;
	float rake = sin(world_position.x * 48.0 + sin(world_position.z * 0.4) * 0.3);
	float edges = smoothstep(7.0, 11.5, abs(p.x));
	float patch = smoothstep(0.38, 0.65, texture_grain) * 0.5 + edges * 0.5;
	vec3 source = texture(gravel_color, p * 1.15).rgb;
	float luminance = dot(source, vec3(0.2126, 0.7152, 0.0722));
	vec3 gravel = mix(source, vec3(luminance), 0.6) * vec3(0.64, 0.67, 0.68);
	vec3 mud = texture(mud_color, p * 0.55).rgb * vec3(0.5, 0.56, 0.6);
	ALBEDO = mix(gravel, mud, clamp(patch, 0.0, 1.0)) * (0.97 + rake * 0.02);
	NORMAL_MAP = texture(gravel_normal, p * 1.15).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = mix(0.92, 0.45, patch);
	SPECULAR = 0.32;
}

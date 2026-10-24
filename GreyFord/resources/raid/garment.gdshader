shader_type spatial;
render_mode cull_disabled;
uniform sampler2D base_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform bool use_normal = false;
uniform vec4 fabric_color : source_color = vec4(0.22, 0.23, 0.18, 1.0);
uniform float surface_metallic = 0.0;
uniform float surface_roughness = 0.9;
varying vec3 garment_position;
void vertex() {
	garment_position = VERTEX;
}
void fragment() {
	vec4 source = texture(base_texture, UV);
	float shade = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float fade = 1.0 - smoothstep(0.005, 0.025, length(fwidth(garment_position)));
	float weave = sin(garment_position.x * 230.0) * sin(garment_position.y * 260.0) * 0.055 * fade * (1.0 - step(0.1, surface_metallic));
	ALBEDO = fabric_color.rgb * (0.65 + shade * 0.8 + weave);
	ROUGHNESS = clamp(surface_roughness + weave, 0.3, 1.0);
	METALLIC = surface_metallic;
	if (use_normal) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = 0.65;
	}
}

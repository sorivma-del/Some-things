shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.64, 0.68, 0.46, 1.0);
uniform float color_saturation = 0.22;
uniform float wind_strength = 0.09;
uniform float wind_speed = 1.3;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Основание остаётся на земле, верхушки мягко отклоняются от порывов.
	float tip = smoothstep(0.04, 1.0, VERTEX.y);
	float breeze = sin(TIME * wind_speed + world.x * 0.41 + world.z * 0.27);
	VERTEX.x += breeze * wind_strength * tip;
	VERTEX.z += cos(TIME * wind_speed * 0.7 + world.z * 0.33) * wind_strength * tip * 0.45;
}

void fragment() {
	vec4 color = texture(albedo_texture, UV);
	float grey = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(vec3(grey), color.rgb, color_saturation) * tint.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}

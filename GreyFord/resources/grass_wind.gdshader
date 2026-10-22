shader_type spatial;
render_mode cull_disabled;
// Grass blades swaying in a light wind: the higher a vertex, the further it bends.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec3 albedo : source_color = vec3(0.5, 0.48, 0.34);
uniform float sway = 0.08;
uniform float speed = 1.4;
uniform vec2 wind_dir = vec2(1.0, 0.3);
// Blades shrink away near the camera so they never fill the frame in front of Mara.
uniform float camera_clear_near = 1.8;
uniform float camera_clear_far = 4.5;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * speed + world.x * 0.35 + world.z * 0.2) * 0.6
		+ sin(TIME * speed * 2.3 + world.z * 0.9) * 0.4;
	float bend = max(VERTEX.y, 0.0) * sway * gust;
	VERTEX.xz += normalize(wind_dir) * bend;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float to_camera = distance(root.xz, CAMERA_POSITION_WORLD.xz);
	VERTEX *= smoothstep(camera_clear_near, camera_clear_far, to_camera);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb * albedo;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}

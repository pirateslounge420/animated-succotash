// Distant planet shell (FarShell): coarse terrain or sea far beyond the
// streamed chunks, for long views of distant mountains. Cut away near the
// camera, where detailed chunks take over.
shader_type spatial;
render_mode cull_back, diffuse_lambert;

uniform float hide_radius = 700.0;
uniform bool is_sea = false;
uniform vec3 sea_color : source_color = vec3(0.05, 0.25, 0.42);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (distance(world_pos, CAMERA_POSITION_WORLD) < hide_radius) {
		discard;
	}
	if (is_sea) {
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
		ROUGHNESS = 0.08;
		SPECULAR = 0.6;
		ALBEDO = mix(sea_color, sea_color * 0.6, fresnel);
	} else {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.95;
	}
}

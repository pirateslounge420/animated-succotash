// Distant planet shell (FarShell): coarse terrain or sea far beyond the
// streamed chunks, for long views of distant mountains. Cut away near the
// camera, where detailed chunks take over. Lit flat and fogged in bands
// like the near terrain, so the two meet without a visible change.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform float hide_radius = 700.0;
uniform bool is_sea = false;
uniform vec3 sea_color : source_color = vec3(0.02, 0.3, 0.62);
uniform sampler2D look_grain : filter_nearest, repeat_enable;

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
		ALBEDO = mix(sea_color, sea_color * 0.55, fresnel);
		EMISSION = look_glow_emission(world_pos, look_site_glow(world_pos, 1.0) * 0.6);
	} else {
		ALBEDO = COLOR.rgb;
	}
	ROUGHNESS = 1.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

// Distant sea (FarShell): the flat water beyond the streamed chunks, cut
// away near the camera where the chunks' own water takes over. The same
// palette as the near water (water.gdshader) with no texture (it's only
// ever seen far off, through haze): the day blue, no reflections or
// fresnel tint, and at night the same near self-lit ultramarine glow, so
// the far sea never shows as a darker band beyond the near water.
shader_type spatial;
render_mode cull_back, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform float hide_radius = 600.0;
uniform vec3 water_color : source_color = vec3(0.231, 0.471, 1.0); // TerrainChunk.WATER
uniform vec3 night_color : source_color = vec3(0.106, 0.235, 1.0); // #1B3CFF
uniform float night_glow = 0.6; // as water.gdshader

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Cut away where the chunks are (they cover the render distance,
	// look_draw_m, design §ER.1, and farther).
	float hide = look_draw_m > 0.0 ? min(hide_radius, look_draw_m * (true ? 0.86 : 0.97)) : hide_radius;
	if (distance(world_pos, CAMERA_POSITION_WORLD) < hide) {
		discard;
	}
	ALBEDO = water_color * (1.0 - 0.8 * look_night);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = night_color * look_night * night_glow;
	EMISSION += look_glow_emission(world_pos, look_site_glow(world_pos, 1.0) * 0.6);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

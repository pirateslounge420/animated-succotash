// Waterfalls (TerrainChunk, from RiverNetwork's drops): a falling sheet of
// water. UV.x runs across the fall in meters, UV.y down it in meters from
// the lip; UV2 carries the fall's (height, width), so every fall shares one
// material. Near-white at the crest where the water breaks over the lip
// (docs/WORLD_SYSTEMS_SPEC.md R1a), then streaks of white water sliding
// down over a bright blue sheet, thickening to foam toward the plunge pool;
// the edges fray. The streaks are Look's water texture stretched down the
// fall (linear-filtered with mipmaps), the same painted water as the river.
// No reflections or specular: vertex-lit Lambert like everything else. At
// night it glows from within, brighter than the river (the river's #1B3CFF
// body with #7FB0FF-to-white streaks), as the references' falls do.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform vec3 water_color : source_color = vec3(0.16, 0.42, 1.0);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform vec3 night_color : source_color = vec3(0.106, 0.235, 1.0); // #1B3CFF
uniform vec3 night_highlight : source_color = vec3(0.498, 0.69, 1.0); // #7FB0FF
uniform sampler2D look_tex_water : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_pos;
varying float height;
varying float width;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	height = UV2.x;
	width = UV2.y;
}

void fragment() {
	// Streaks: the texture stretched down the fall, sliding down at 3 m/s
	// (3600 s of it is a whole number of repeats, for TIME's hourly rollover).
	float y = UV.y - TIME * 3.0;
	float sa = texture(look_tex_water, vec2(UV.x / 2.5, y / 12.0)).g;
	float sb = texture(look_tex_water, vec2(UV.x / 1.5 + 0.41, y / 7.5 + 0.17)).g;
	float mottle = texture(look_tex_water, vec2(UV.x / 4.0, y / 15.0)).r;
	float streak = max(sa, sb);
	float depth01 = clamp(UV.y / max(height, 0.1), 0.0, 1.0);
	// White at the crest, streaky in the middle, churning at the foot.
	float crest = 1.0 - smoothstep(0.0, clamp(2.5 / max(height, 0.1), 0.08, 0.35), depth01);
	float foam = smoothstep(0.3, 0.7, streak) * 0.85 + smoothstep(0.55, 1.0, depth01) * 0.7;
	foam = clamp(max(foam, crest * 0.92), 0.0, 1.0);
	ALBEDO = mix(water_color * (0.85 + 0.3 * mottle), foam_color, foam);
	// Frayed edges.
	float edge = min(UV.x, width - UV.x);
	ALPHA = clamp(0.8 + 0.2 * foam, 0.0, 1.0) * smoothstep(0.0, 0.8, edge + streak * 0.6);
	// Glows from within at night: blue body, pale streaks, near-white crest.
	vec3 glow = mix(night_color, night_highlight, foam);
	glow = mix(glow, vec3(0.85, 0.93, 1.0), crest * 0.8);
	ALBEDO *= 1.0 - 0.7 * look_night;
	EMISSION = glow * look_night * 1.25 + foam_color * foam * 0.06;
	EMISSION += look_glow_emission(world_pos, look_site_glow(world_pos, 1.0) * 1.2);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

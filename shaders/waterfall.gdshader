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

uniform vec3 sheet_color : source_color = vec3(0.72, 0.91, 1.0); // #B8E8FF, look.json water.waterfall
uniform vec3 shadow_color : source_color = vec3(0.29, 0.54, 0.88); // #4A8AE0
uniform vec3 foam_color : source_color = vec3(0.94, 1.0, 1.0);
uniform float streak_tile_m = 0.6;
uniform float streak_scroll = 2.5;
uniform float glow_night = 1.6;
uniform vec3 night_color : source_color = vec3(0.106, 0.235, 1.0); // #1B3CFF
uniform vec3 night_highlight : source_color = vec3(0.498, 0.69, 1.0); // #7FB0FF
uniform sampler2D look_tex_water : filter_nearest_mipmap, repeat_enable; // §AG: a nearest tile, 2 mips, no anisotropy
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
	// §BU step 4: a flat sheet with the vertical streak tile scrolling
	// down at streak_scroll m/s, nearest-filtered (a tile stretched four
	// times taller than wide reads as streaks).
	float y = UV.y - TIME * streak_scroll;
	float sa = retro_tile(look_tex_water, vec2(UV.x / streak_tile_m, y / (streak_tile_m * 4.0))).g;
	float sb = retro_tile(look_tex_water, vec2(UV.x / (streak_tile_m * 1.7) + 0.41, y / (streak_tile_m * 6.0) + 0.17)).g;
	float mottle = retro_tile(look_tex_water, vec2(UV.x / 4.0, y / 15.0)).r;
	float streak = max(sa, sb);
	float depth01 = clamp(UV.y / max(height, 0.1), 0.0, 1.0);
	// White at the crest, streaky in the middle, churning at the foot.
	float crest = 1.0 - smoothstep(0.0, clamp(2.5 / max(height, 0.1), 0.08, 0.35), depth01);
	// The foam line at the foot: a hard band over the plunge.
	float foot = smoothstep(0.86, 0.93, depth01) * (0.7 + 0.3 * mottle);
	float foam = smoothstep(0.3, 0.7, streak) * 0.85 + smoothstep(0.55, 1.0, depth01) * 0.4 + foot;
	foam = clamp(max(foam, crest * 0.92), 0.0, 1.0);
	ALBEDO = mix(mix(shadow_color, sheet_color, 0.5 + 0.5 * mottle), foam_color, foam);
	// Frayed edges.
	float edge = min(UV.x, width - UV.x);
	ALPHA = clamp(0.8 + 0.2 * foam, 0.0, 1.0) * smoothstep(0.0, 0.8, edge + streak * 0.6);
	// Glows from within at night: blue body, pale streaks, near-white crest.
	vec3 glow = mix(night_color, night_highlight, foam);
	glow = mix(glow, vec3(0.85, 0.93, 1.0), crest * 0.8);
	ALBEDO *= 1.0 - 0.7 * look_night;
	EMISSION = glow * look_night * 1.25 * glow_night + foam_color * foam * 0.06;
	EMISSION += look_glow_emission(world_pos, look_site_glow(world_pos, 1.0) * 1.2);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

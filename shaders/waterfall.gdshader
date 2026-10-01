// Waterfalls (TerrainChunk, from RiverNetwork's drops): a falling sheet of
// water. UV.x runs across the fall in meters, UV.y down it in meters from
// the lip; UV2 carries the fall's (height, width), so every fall shares one
// material. Near-white at the crest where the water breaks over the lip
// (docs/WORLD_SYSTEMS_SPEC.md R1a), then streaks of white water sliding
// down over a bright blue sheet, thickening to foam toward the plunge pool;
// the edges fray. The streaks are the water's glint noise (WaterLook)
// stretched down the fall, two layers sliding down, nearest-filtered with
// mipmaps. No reflections or specular. By day it is lit and self-lit like
// the river (look.json water.self_lit) and the streaks' cores emit over
// 1.0, so they bloom (water.waterfall.streak_hdr). At night it glows from within, brighter than the river (the river's #1B3CFF
// body with #7FB0FF-to-white streaks), as the references' falls do.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform vec3 sheet_color : source_color = vec3(0.72, 0.91, 1.0); // #B8E8FF, look.json water.waterfall
uniform vec3 shadow_color : source_color = vec3(0.29, 0.54, 0.88); // #4A8AE0
uniform vec3 foam_color : source_color = vec3(0.94, 1.0, 1.0);
uniform float streak_tile_m = 1.6;
uniform float streak_stretch = 7.5;
uniform float streak_scroll = 2.5;
uniform float streak_hdr = 0.6;
uniform float glow_day = 1.35;
uniform float self_lit = 0.6;
uniform sampler2D glint_tex : filter_nearest_mipmap, repeat_enable; // WaterLook.glint_texture
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
	// Streaks: the noise stretched streak_stretch times taller than wide,
	// two layers sliding down at streak_scroll and 1.3 times it (with the
	// defaults 3600 s of each is a whole number of repeats, for TIME's
	// hourly rollover).
	float y = UV.y - TIME * streak_scroll;
	float tall = streak_tile_m * streak_stretch;
	float sa = retro_tex(glint_tex, vec2(UV.x / streak_tile_m, y / tall)).r;
	float sb = retro_tex(glint_tex, vec2(UV.x / (streak_tile_m * 1.7) + 0.41, (UV.y - TIME * streak_scroll * 1.3) / (tall * 1.5) + 0.17)).r;
	float mottle = retro_tile(look_tex_water, vec2(UV.x / 4.0, y / 15.0)).r;
	float streak = (sa + sb) * 0.5;
	float sheet = smoothstep(0.5, 0.68, streak); // about a third of the sheet
	float core = smoothstep(0.75, 0.85, streak); // the brightest tenth
	float depth01 = clamp(UV.y / max(height, 0.1), 0.0, 1.0);
	// White at the crest, streaky in the middle, churning at the foot.
	float crest = 1.0 - smoothstep(0.0, clamp(2.5 / max(height, 0.1), 0.08, 0.35), depth01);
	// The foam line at the foot: a hard band over the plunge.
	float foot = smoothstep(0.86, 0.93, depth01) * (0.7 + 0.3 * mottle);
	float foam = smoothstep(0.55, 1.0, depth01) * 0.4 * (0.5 + sheet) + foot;
	foam = clamp(max(foam, crest * 0.92), 0.0, 1.0);
	vec3 col = mix(shadow_color, sheet_color, clamp(sheet + 0.3 * (mottle - 0.5), 0.0, 1.0));
	col = mix(col, foam_color, foam) * glow_day;
	// Frayed edges.
	float edge = min(UV.x, width - UV.x);
	float white = max(foam, sheet);
	ALPHA = clamp(0.8 + 0.2 * white, 0.0, 1.0) * smoothstep(0.0, 0.8, edge + streak * 0.6);
	// Glows from within at night: blue body, pale streaks, near-white crest.
	vec3 glow = mix(night_color, night_highlight, white);
	glow = mix(glow, vec3(0.85, 0.93, 1.0), crest * 0.8);
	// By day lit and self-lit like the river; the streaks' cores emit
	// over 1.0 (they bloom) at any hour.
	ALBEDO = col * (1.0 - self_lit) * (1.0 - 0.7 * look_night);
	EMISSION = col * self_lit * (1.0 - look_night) + glow * look_night * 1.25 * glow_night
		+ sheet_color * streak_hdr * core * (1.0 - foam);
	EMISSION += look_glow_emission(world_pos, look_site_glow(world_pos, 1.0) * 1.2);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

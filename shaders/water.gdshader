// Oceans, lakes and rivers: flat, painted early-2000s console water
// (docs/WORLD_SYSTEMS_SPEC.md R1, R1a). No reflections of any kind: no
// sky or sun mirrored in it, no specular, no fresnel tint, no normal
// map. It's a bright, saturated blue under the same vertex-lit Lambert as
// everything else, slightly see-through looking straight down.
//
// The surface is Look's water texture (red: soft mottled body; green: soft
// highlight blobs), linear-filtered with mipmaps, in two layers at
// different scales, angles and speeds. Still water drifts slowly; on
// river ribbons (UV2.y = the ribbon's half width) both layers run
// downstream (UV.y is meters downstream) and the ribbon's edges fade into
// the still pool filling the rest of the channel. Highlights show where
// the two layers' blobs overlap, so they shift and swell instead of
// sliding by as one sheet. Rapids and the churn below falls (UV2.x)
// streak white foam racing downstream. Rain pocks it with flickering pale
// dots (StormFX).
//
// At night the water is near self-lit: it glows ultramarine #1B3CFF with
// #7FB0FF highlights (R1a), whatever the moonlight does. At glow ponds and
// other magical sites it also emits Look's teal/cobalt glow, bright enough
// to light the banks (Landmarks adds lights there too).
//
// UVs are meters and come from TerrainChunk: across the cube face for
// standing water, (across from the centerline, downstream) for rivers,
// each wrapped by a multiple of 300 m, which holds a whole number of both
// layers' repeats (6 m, and 7.5 m turned 3-4-5), so no chunk or segment
// seam shows. Speeds are chosen so the pattern also comes back to itself
// when the engine's TIME rolls over each hour.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

varying vec3 world_pos;
// How far fresh water has risen in heavy rain, m (StormFX).
uniform float water_rise = 0.0;

void vertex() {
	// Water meshes are flat with their normal up; heavy rain lifts them.
	VERTEX += NORMAL * water_rise;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Day body (TerrainChunk sets fresh and salt water apart).
uniform vec3 water_color : source_color = vec3(0.231, 0.471, 1.0); // #3B78FF
uniform vec3 highlight_color : source_color = vec3(0.45, 0.7, 1.0);
uniform vec3 foam_color : source_color = vec3(0.9, 0.95, 1.0);
// Night glow (R1a).
uniform vec3 night_color : source_color = vec3(0.106, 0.235, 1.0); // #1B3CFF
uniform vec3 night_highlight : source_color = vec3(0.498, 0.69, 1.0); // #7FB0FF
// Glow gain: 0.6 lands on #1B3CFF on screen through the grade.
uniform float night_glow = 0.6;
// Storms (StormFX): how soaked the land is (0-1; unused here now: a
// changing speed would make the scrolling lurch) and rain falling on the
// surface now (0-1: drops pock it).
uniform float storm_flow = 0.0;
uniform float rain_drops = 0.0;
uniform sampler2D look_tex_water : filter_linear_mipmap_anisotropic, repeat_enable;

const float TILE_A = 6.0; // meters per repeat
const float TILE_B = 7.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float river = step(0.01, UV2.y); // UV2.y: a river ribbon's half width
	float white = UV2.x;
	// Drift, m/s. Rivers run downstream (+UV.y) at 0.5 and 0.75 m/s;
	// still water wanders slowly. (Each times 3600 s is a whole number of
	// repeats, for the hourly TIME rollover.)
	vec2 drift_a = mix(vec2(1.0, 0.5) / 60.0, vec2(0.0, 0.5), river);
	vec2 drift_b = mix(vec2(-66.0, 12.0) / 3600.0, vec2(0.0, 0.75), river);
	vec2 la = texture(look_tex_water, (UV - drift_a * TIME) / TILE_A).rg;
	vec2 lb = texture(look_tex_water, mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * (UV - drift_b * TIME) / TILE_B).rg;
	// Mottled body: -1..1, darker and lighter blue, never grey.
	float body = (la.r + lb.r) - 1.0;
	// Soft highlights: strongest where both layers' blobs meet.
	float hl = clamp(la.g * lb.g * 2.0 + 0.3 * max(la.g, lb.g), 0.0, 1.0);

	ALBEDO = water_color * (1.0 + 0.28 * body);
	ALBEDO = mix(ALBEDO, highlight_color, hl * 0.5);
	vec3 glow = night_color * (1.0 + 0.22 * body);
	glow = mix(glow, night_highlight * 1.45, hl); // lands near #7FB0FF at the peaks

	if (rain_drops > 0.01) {
		// Raindrops: small pale pocks flickering on a 25 cm grid.
		vec2 cell = floor(UV * 4.0);
		float step_t = floor(TIME * 9.0);
		float hit = step(1.0 - 0.18 * rain_drops, hash(cell + vec2(step_t * 1.7, step_t * 2.3)));
		float dot_r = length(fract(UV * 4.0) - 0.5);
		float drop = hit * (1.0 - smoothstep(0.12, 0.24, dot_r)) * 0.6;
		ALBEDO = mix(ALBEDO, highlight_color, drop);
		glow = mix(glow, night_highlight, drop);
	}
	// A touch see-through looking down, solid toward the horizon (only how
	// much of the bed shows; nothing is reflected).
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALPHA = mix(0.96, 0.84, facing);
	// A river ribbon lies just over the still pool filling its channel:
	// its last 2.5 m each side fade into it, so no edge shows along the banks.
	float fade = mix(1.0, smoothstep(UV2.y, UV2.y - 2.5, abs(UV.x)), river);

	// White water (rivers): foam streaks, the texture stretched along the
	// current, racing downstream at 2.5 m/s.
	if (white > 0.01) {
		float y = UV.y - TIME * 2.5;
		float fa = texture(look_tex_water, vec2(UV.x / 3.0, y / 10.0)).g;
		float fb = texture(look_tex_water, vec2(UV.x / 1.8 + 0.37, y / 6.0 + 0.21)).g;
		float cover = 0.6 - 0.35 * white;
		float foam = smoothstep(cover, cover + 0.25, max(fa, fb)) * smoothstep(0.0, 0.3, white);
		foam = max(foam, 0.2 * white);
		ALBEDO = mix(ALBEDO, foam_color, foam);
		glow = mix(glow, night_highlight * 1.15, foam);
		ALPHA = mix(ALPHA, 0.98, foam);
	}

	// Near self-lit at night: the lit albedo fades back so the glow sets
	// the color.
	ALBEDO *= 1.0 - 0.8 * look_night;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = glow * look_night * night_glow;
	float site = look_site_glow(world_pos, 1.0);
	// Lit from within at magical sites, rippling with the texture.
	EMISSION += look_glow_emission(world_pos, site * (1.0 + 0.4 * body));
	ALPHA = mix(ALPHA, 0.92, site * look_glow) * fade;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

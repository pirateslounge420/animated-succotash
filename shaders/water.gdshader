// Oceans, lakes and rivers: flat, painted early-2000s console water
// (docs/WORLD_SYSTEMS_SPEC.md R1, R1a). No reflections of any kind: no
// sky or sun mirrored in it, no specular, no fresnel tint, no normal
// map. It's a bright, saturated blue under the same vertex-lit Lambert as
// everything else, slightly see-through looking straight down.
//
// The body is mottled by Look's water texture (the §AG tile's bands),
// nearest-filtered with mipmaps, in two layers at different scales,
// angles and speeds. Still water drifts slowly; on river ribbons (UV2.y =
// the ribbon's half width) both layers run downstream (UV.y is meters
// downstream) and the ribbon's edges fade into the still pool filling the
// rest of the channel. Rapids and the churn below falls (UV2.x) streak
// white foam racing downstream. Rain pocks it with flickering pale
// dots (StormFX).
//
// By day it glows (1 Oct look pass, look.json water): a deep electric
// blue body, part lit and part self-lit (self_lit), so it stays brighter
// than the land as the sun drops; calm still fresh water is a darker navy
// (calm_color, calm_share). Glints are emissive noise, never specular: two
// scrolling layers of nearest value noise (glint_tex), and where their
// product passes glint_cover the water flares cyan over 1.0 (it blooms).
//
// At night the water is near self-lit: it glows ultramarine #1B3CFF with
// the glints for highlights (R1a), whatever the moonlight does. At glow ponds and
// other magical sites it also emits Look's teal/cobalt glow, bright enough
// to light the banks (Landmarks adds lights there too).
//
// UVs are meters and come from TerrainChunk: across the cube face for
// standing water, (across from the centerline, downstream) for rivers,
// each wrapped by a multiple of 300 m, which holds a whole number of both
// layers' repeats (6 m, and 7.5 m turned 3-4-5), so no chunk or segment
// seam shows. Speeds are chosen so the pattern also comes back to itself
// when the engine's TIME rolls over each hour.
//
// Ripples near the camera (RippleSim): anything touching the water rings
// it, and each ring is painted as two soft bands, not lit: a light band
// (toward the highlight blue) over its crest and a dark band (a deeper
// blue, never black) over its trough. The bands keep the same two tones
// while a ring is big and fade as it dies away; under them the water's
// own mottling and sparkle calm, so the bands read as bands, while the
// water's grain roughens their edges and, finer, streaks them like
// brushwork (R1: crunchy texture on smooth shapes). The ripple buffer's
// slope (its surface normal) paints the side of each ring facing the key
// light (the moon at night, the sun by day) a little lighter; a hard
// splash churns pale for a moment. They fade out with distance into the
// static water above, and are looked up by scene position, so they run
// on across chunks, pools and river ribbons.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"
global uniform vec3 plant_wind;
#include "res://shaders/wind.gdshaderinc"

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
// §BU step 4 (look.json water): how much brighter than the scene the
// water reads by day and at night, and the scrolling caustic tile.
uniform float glow_day = 1.35;
uniform float glow_night = 1.6;
uniform float caustic_tile_m = 3.0; // the glint noise's repeat (m)
uniform float caustic_scroll = 0.25;
// 1 Oct look pass (look.json water): calm still water, the self-lit share
// of the day body, the band mottling, and the glints.
uniform vec3 calm_color : source_color = vec3(0.0, 0.021, 0.072);
uniform float calm_share = 0.0; // TerrainChunk/WaterLook: still fresh water
uniform float self_lit = 0.6;
uniform float body_mottle = 0.6;
uniform vec3 glint_color : source_color = vec3(0.27, 0.97, 1.0);
uniform float glint_hdr = 1.5;
uniform float glint_cover = 0.6;
uniform float glint_cover_calm = 0.78;
uniform float glint_night = 0.8;
// Value noise spread evenly over 0-1 (WaterLook.glint_texture).
uniform sampler2D glint_tex : filter_nearest_mipmap, repeat_enable;
// Storms (StormFX): how soaked the land is (0-1; unused here now: a
// changing speed would make the scrolling lurch) and rain falling on the
// surface now (0-1: drops pock it).
uniform float storm_flow = 0.0;
uniform float rain_drops = 0.0;
// A bioluminescent bay's stirred water (design 1 Oct §CK): HDR, so it
// blooms (retro.bloom takes only HDR above 1).
uniform float bay_hdr = 2.2;
uniform sampler2D look_tex_water : filter_nearest_mipmap, repeat_enable; // §AG: a nearest tile, 2 mips, no anisotropy

// Ripples (RippleSim sets these): the buffer (ripple_view.gdshader: R
// where each ring is in its swing, 1 crest .. 0 trough; G B slope along
// the window's axes; A how big the ripples are, eased), the window's
// center and axes in the scene; window x: 1 / window size (m), y: on
// (0-1), z-w: fade out between these distances from the camera (m).
global uniform sampler2D ripple_tex : filter_nearest, repeat_disable;
global uniform vec3 ripple_center;
global uniform vec3 ripple_axis_u;
global uniform vec3 ripple_axis_v;
global uniform vec4 ripple_window;
// Bands: x where light gives way to dark in the swing (0: even halves),
// y edge softness, z how far a light band goes toward the highlight
// blue, w how much a dark band deepens.
global uniform vec4 ripple_band;
// x, y: the ripple size (envelope over look.height_m) where rings start
// to show and where they're painted in full; z: how much the water's own
// mottling calms under them; w: the size where a splash churns pale.
global uniform vec4 ripple_ring;
// xyz: the key light across the water (scaled by how much lighter the
// side facing it is painted), w: splash foam.
global uniform vec4 ripple_light;
// Brushwork in the bands: x how strongly the grain streaks them, y the
// grain's repeats per meter.
global uniform vec2 ripple_brush;

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
	vec2 la = retro_tile(look_tex_water, (UV - drift_a * TIME) / TILE_A).rg;
	vec2 lb = retro_tile(look_tex_water, mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * (UV - drift_b * TIME) / TILE_B).rg;
	// Mottled body: -1..1, darker and lighter blue, never grey.
	float body = (la.r + lb.r) - 1.0;

	// Reading the river (design 4 Oct §ED.2, RiverPhases, phases.json):
	// on a river ribbon COLOR.r is its phase, 0 pool .. 6 fall. Three
	// layers at fixed speeds downstream (0.25, 0.75 and 2 m/s), blended by
	// phase: no layer's speed changes across the water, so nothing shears
	// as TIME runs, and each times 3600 s is whole repeats.
	float ph = COLOR.r * 6.0 * river;
	float w_slow = river * (1.0 - smoothstep(1.0, 2.0, ph));
	float w_mid = river * (smoothstep(1.0, 2.0, ph) - smoothstep(2.0, 3.0, ph));
	float w_fast = river * smoothstep(2.0, 3.0, ph);
	float pool = river * (1.0 - smoothstep(0.0, 1.0, ph));
	float rif = river * (smoothstep(1.5, 2.0, ph) - smoothstep(2.5, 3.0, ph));
	float leaf = 0.0;
	float fline = 0.0;
	float stone = 0.0;
	if (river > 0.5) {
		// pool: still, slow drift; glide: smooth, faint streaks; riffle:
		// broken, finer; run and on: fast, long streaks.
		float l0 = retro_tile(look_tex_water, (UV - vec2(0.0, 0.25) * TIME) / TILE_A).r;
		float l1 = retro_tile(look_tex_water, vec2(UV.x * 1.6, UV.y - 0.75 * TIME) / TILE_A).r;
		float l2 = retro_tile(look_tex_water, vec2(UV.x * 2.0 / TILE_A, (UV.y - 2.0 * TIME) / (TILE_A * 3.0))).r;
		body = (l0 * 2.0 - 1.0) * w_slow * mix(0.35, 0.8, smoothstep(0.0, 1.0, ph))
			+ (l1 * 2.0 - 1.0) * w_mid * 1.2 + (l2 * 2.0 - 1.0) * w_fast;
		// Foam lines (the direction, never in doubt): two thin pale lines
		// along the current, wandering, broken into dashes that drift
		// downstream, on the slow and the fast layer.
		float half_w = max(UV2.y, 0.5);
		for (int k = 0; k < 2; k++) {
			float sk = k == 0 ? 0.25 : 2.0;
			float wk = k == 0 ? (w_slow + w_mid) * (0.35 + 0.65 * smoothstep(0.0, 1.0, ph)) : w_fast * (1.0 - smoothstep(3.0, 4.0, ph));
			float y = UV.y - sk * TIME;
			for (int j = 0; j < 2; j++) {
				float side = j == 0 ? -0.32 : 0.28;
				float xo = half_w * side + (texture(look_tex_water, vec2(0.13 + 0.4 * float(j), UV.y / 60.0)).g - 0.5) * half_w * 0.5;
				float on_line = 1.0 - smoothstep(0.08, 0.16, abs(UV.x - xo));
				float dash = step(0.42, texture(look_tex_water, vec2(0.71 + 0.3 * float(j), y / (k == 0 ? 7.0 : 16.0))).r);
				fline = max(fline, on_line * dash * wk);
			}
		}
		// Drifting leaves on the slower water: a few dark flecks riding the
		// current (the slow layer on pools and glides, the middle one on a
		// riffle). Every 1/1.5 m cell times its speed x 3600 s is whole.
		vec2 c0 = vec2(UV.x, UV.y - 0.25 * TIME) * 1.5;
		vec2 c1 = vec2(UV.x, UV.y - 0.75 * TIME) * 1.5;
		float d0 = step(0.986, hash(floor(c0) + vec2(17.0, 3.0))) * (1.0 - smoothstep(0.14, 0.24, length(fract(c0) - 0.5)));
		float d1 = step(0.986, hash(floor(c1) + vec2(5.0, 29.0))) * (1.0 - smoothstep(0.14, 0.24, length(fract(c1) - 0.5)));
		leaf = d0 * w_slow + d1 * w_mid;
		// A riffle's stones showing: dark rounded backs fixed in the flow.
		vec2 sc = UV / 0.7;
		stone = rif * step(0.9, hash(floor(sc) + vec2(41.0, 7.0))) * (1.0 - smoothstep(0.2, 0.32, length(fract(sc) - 0.5)));
		// White water rises with the phase: a few streaks on a run, white
		// on a rapid, all white down a cascade.
		white = max(white, 0.2 * smoothstep(2.5, 3.5, ph) + 0.5 * smoothstep(3.5, 4.5, ph) + 0.3 * smoothstep(4.5, 5.5, ph));
	}

	// Ripples near the camera (RippleSim): `swing` +1 on a ring's crest ..
	// -1 in its trough (`swing_w` how fast it changes across a pixel),
	// `ring` how strongly it's painted (0 where calm or out of reach),
	// `lit_side` + on the side facing the key light, `brush` the grain
	// that streaks the bands. Derivatives and texture reads stay out here,
	// where every pixel takes the same branch.
	float swing = 0.0;
	float swing_w = 0.0;
	float ring = 0.0;
	float lit_side = 0.0;
	float churn = 0.0;
	float brush = 0.0;
	if (ripple_window.y > 0.0) {
		vec3 rel = world_pos - ripple_center;
		vec2 ruv = vec2(dot(rel, ripple_axis_u), dot(rel, ripple_axis_v)) * ripple_window.x + 0.5;
		vec4 rs = texture(ripple_tex, ruv);
		float edge = min(min(ruv.x, ruv.y), min(1.0 - ruv.x, 1.0 - ruv.y));
		float k = ripple_window.y * smoothstep(0.0, 0.08, edge)
			* (1.0 - smoothstep(ripple_window.z, ripple_window.w, distance(world_pos, CAMERA_POSITION_WORLD)));
		// The ripples' size, back from its easing (ripple_view.gdshader).
		float amp = rs.a * inversesqrt(max(1.0 - rs.a * rs.a, 1e-4));
		// Painted, not traced: the water's grain wobbles each band's edge.
		swing = rs.r * 2.0 - 1.0 + (la.r - 0.5) * 0.35;
		swing_w = fwidth(swing);
		ring = smoothstep(ripple_ring.x, ripple_ring.y, amp) * k;
		// Bands finer than a couple of pixels (far off, or seen edge on)
		// fade out instead of shimmering.
		ring *= 1.0 - smoothstep(0.5, 1.0, swing_w);
		vec2 slope = rs.gb * 2.0 - 1.0;
		vec2 light = vec2(dot(ripple_light.xyz, ripple_axis_u), dot(ripple_light.xyz, ripple_axis_v));
		lit_side = -dot(slope, light) * ring;
		// A hard splash churns pale for a moment, in broken patches.
		churn = smoothstep(ripple_ring.w, 2.0 * ripple_ring.w, amp * (0.75 + 0.5 * lb.g)) * ripple_light.w * k;
		// Brushwork (R1: crunchy texture on smooth shapes): the water
		// texture's grain, finer than the mottling calmed below, streaks
		// each band lighter and darker without breaking the ring's shape.
		brush = texture(look_tex_water, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * (UV - drift_a * TIME) * ripple_brush.y + vec2(0.37, 0.61)).r - 0.5;
		brush *= ripple_brush.x;
	}
	// Under painted rings the water's own mottling and sparkle calm, so
	// the bands read as bands.
	body *= 1.0 - ripple_ring.z * ring;
	// The wind on the water (design 3 Oct §DA, wind.json water): the gust
	// field here. Under calm_below_mps a mirror (its mottling stills);
	// past cats_paws_mps a gust's patch roughens as it slides over (the
	// glints break up, the blue deepens a little); from whitecaps_mps a
	// few pale pixel crests on open water (never on a river ribbon).
	float u_w = length(plant_wind) * wind_gust_field(world_pos, length(plant_wind)).x;
	vec3 wst = wind_water_state(u_w);
	body *= 1.0 - 0.6 * wst.z;

	// Calm: still fresh water away from any white water (not rivers, not
	// the sea: calm_share is 0 on salt water).
	float calm = calm_share * (1.0 - river) * (1.0 - smoothstep(0.0, 0.3, white));
	ALBEDO = mix(water_color, calm_color, calm) * (1.0 + body_mottle * body);
	// A pool lies still and a little deeper blue.
	ALBEDO = mix(ALBEDO, calm_color, pool * 0.16);
	// Glints: two layers of the noise, scrolling apart (downstream on
	// rivers); where both are high the water flares. Each layer's drift
	// times 3600 s is a whole number of its repeats at 0.25 m/s steps.
	vec2 ga = mix(vec2(0.6, 0.8), vec2(0.0, 2.0), river) * caustic_scroll;
	vec2 gb = mix(vec2(0.8, -0.6), vec2(0.0, 3.0), river) * caustic_scroll;
	float na = retro_tex(glint_tex, (UV - ga * TIME) / caustic_tile_m).r;
	float nb = retro_tex(glint_tex, mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * (UV - gb * TIME) / (caustic_tile_m * 1.25)).r;
	float cover = mix(glint_cover, glint_cover_calm, calm);
	float glint = smoothstep(cover, cover + 0.08, na * nb) * (1.0 - ripple_ring.z * ring);
	glint *= 1.0 - 0.75 * wst.x;
	ALBEDO *= 1.0 - 0.14 * wst.x;
	// The night body (the glints are added over it below; the §AG tile's
	// two-tone bands made the old highlight blend cover most of the water).
	vec3 glow = night_color * (1.0 + 0.22 * body);
	if (wst.y > 0.0 && river < 0.5) {
		// Crests: a pixel cell here and there on a half-metre grid, running
		// downwind with the gust.
		float sw = length(plant_wind);
		vec3 wd = sw > 0.01 ? plant_wind / sw : vec3(1.0, 0.0, 0.0);
		vec3 wc = normalize(cross(wd, NORMAL * mat3(VIEW_MATRIX)));
		vec2 cq = vec2(dot(world_pos, wd) - TIME * u_w * 0.4, dot(world_pos, wc)) * 2.0;
		float crest = step(1.0 - 0.035 * wst.y, hash(floor(cq) + floor(TIME * 1.5) * vec2(0.0, 7.31)));
		ALBEDO = mix(ALBEDO, foam_color, crest * 0.85);
		glow = mix(glow, night_highlight, crest * 0.6);
	}

	float bay_drop = 0.0;
	if (rain_drops > 0.01) {
		// Raindrops: small pale pocks flickering on a 25 cm grid.
		vec2 cell = floor(UV * 4.0);
		float step_t = floor(TIME * 9.0);
		float hit = step(1.0 - 0.18 * rain_drops, hash(cell + vec2(step_t * 1.7, step_t * 2.3)));
		float dot_r = length(fract(UV * 4.0) - 0.5);
		float drop = hit * (1.0 - smoothstep(0.12, 0.24, dot_r)) * 0.6;
		ALBEDO = mix(ALBEDO, highlight_color, drop);
		glow = mix(glow, night_highlight, drop);
		bay_drop = drop;
	}
	if (ring > 0.0 || churn > 0.0) {
		// Each ring's two bands, within the water's own blues: the light
		// one toward the highlight (#7FB0FF at night), the dark one a deeper
		// blue, never black; soft edged, a little lighter on the side
		// facing the key light.
		float soft = ripple_band.y + swing_w;
		float lit = smoothstep(ripple_band.x - soft, ripple_band.x + soft, swing);
		float shade = smoothstep(ripple_band.x - soft, ripple_band.x + soft, -swing);
		float to_light = clamp(lit * ring * ripple_band.z * (1.0 + lit_side) * (1.0 + brush), 0.0, 1.0);
		float deepen = clamp(shade * ring * ripple_band.w * (1.0 - lit_side) * (1.0 - brush), 0.0, 0.7);
		ALBEDO = mix(ALBEDO, highlight_color, to_light) * (1.0 - deepen);
		glow = mix(glow, night_highlight * 1.45, to_light) * (1.0 - deepen);
		ALBEDO = mix(ALBEDO, foam_color, churn);
		glow = mix(glow, night_highlight * 1.45, churn);
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
		glint *= 1.0 - foam;
		ALPHA = mix(ALPHA, 0.98, foam);
	}

	// The phase's marks over the body: foam lines pale, a riffle's stones
	// dark, a rapid's standing waves and a cascade's steps as pale bands
	// fixed across the flow.
	if (river > 0.5) {
		ALBEDO = mix(ALBEDO, foam_color, fline * 0.55);
		glow = mix(glow, night_highlight * 1.1, fline * 0.5);
		ALBEDO *= 1.0 - stone * 0.45;
		glow *= 1.0 - stone * 0.4;
		float standing = smoothstep(3.0, 4.0, ph);
		if (standing > 0.0) {
			float wob = texture(look_tex_water, vec2(UV.x / 4.0, UV.y / 9.0)).g;
			float band = fract(UV.y / mix(2.2, 3.4, smoothstep(4.0, 5.0, ph)) + wob * 0.35);
			float crest = step(0.7, band) * standing;
			ALBEDO = mix(ALBEDO, foam_color, crest * 0.8);
			glow = mix(glow, night_highlight * 1.15, crest * 0.8);
			glint *= 1.0 - crest;
		}
	}

	// By day the body is glow_day x its colour, self_lit of it emitted
	// (it holds its glow as the land darkens) and the rest lit; near
	// self-lit at night: the lit albedo fades back so the glow sets the
	// color. Glints are emission over the body, at any hour.
	vec3 body_col = ALBEDO * glow_day;
	ALBEDO = body_col * (1.0 - self_lit) * (1.0 - 0.8 * look_night) * (1.0 - glint);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = glow * look_night * night_glow * glow_night
		+ body_col * self_lit * (1.0 - look_night) * (1.0 - glint)
		+ glint_color * glint_hdr * glint * mix(1.0, glint_night, look_night);
	float site = look_site_glow(world_pos, 1.0);
	// Lit from within at magical sites, rippling with the texture.
	EMISSION += look_glow_emission(world_pos, site * (1.0 + 0.4 * body));
	// A bioluminescent bay (design 1 Oct §CK): dark until stirred; every
	// ripple ring, splash and raindrop lights blue-green and fades with it
	// (the ripple sim), brightest at night.
	float bay = look_bay_glow(world_pos);
	if (bay > 0.0) {
		float stirred = clamp(ring * 1.6 + churn * 2.0 + bay_drop * 1.5, 0.0, 1.0);
		EMISSION += vec3(0.25, 1.0, 0.75) * bay_hdr * stirred * bay * mix(0.15, 1.0, look_night);
	}
	ALPHA = mix(ALPHA, 0.92, site * look_glow) * fade;
	// The drifting leaves: dull, lit like the land, never glowing (only
	// things that give off light glow).
	if (leaf > 0.0) {
		ALBEDO = mix(ALBEDO, vec3(0.16, 0.13, 0.05), leaf);
		EMISSION *= 1.0 - leaf;
		ALPHA = max(ALPHA, leaf * fade);
	}
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

// Shared look for every world material (terrain, far terrain, plants,
// water, ruins). SkySystem sets these uniforms each frame through Look.
//
// Lighting is Godot's own, not here: every lit world shader is plain
// Lambert with no specular under one hard-shadowed sun (or moon) over a
// low, deep-blue ambient (SkySystem, data/look.json: dark and moody,
// bright only where the light hits). No custom light(), rim, sheen or
// gloss; the blue of the shadows is the ambient's, and the grade's.
//
// Fog is done here rather than by the Environment: smooth distance haze
// that eases in past a clear zone and thins with altitude, and a low mist
// that pools in valleys and under the canopy, measured by altitude above
// the planet (the world is a sphere: world Y means nothing), thickest at
// night. Both take the sky's colour for the hour (aerial perspective:
// distance goes lighter and bluer, never darker). No volumes, no walls.
// Writing FOG replaces the Environment's fog for the material.
//
// Glow is the bioluminescent night palette: at magical places (ruins,
// glow ponds, mythical territories) water, moss and plant tips emit a
// saturated teal/cobalt light at night. The nearest sites arrive as
// look_sites (scene position, radius) with look_site_kind (1 = ruins and
// mythical ground, where moss and plants glow too; lower = glow ponds,
// mostly the water itself); look_glow scales everything with darkness.

// Shared per-frame values are global shader uniforms (project settings,
// [shader_globals]): Look sets each once a frame, however many materials
// use them. Colors arrive already linear (Look converts them).
global uniform vec3 look_fog_color;
global uniform float look_fog_density; // per meter
const float look_fog_max = 0.96;
global uniform vec3 look_up; // viewer's local up
// Haze thins with altitude (an exponential atmosphere): planet center in
// scene space, radius, and the haze's scale height.
global uniform vec3 look_planet_center;
global uniform float look_planet_radius;
const float look_haze_height = 150.0; // 1.5 km times PlanetConst.HEIGHT_SCALE
// The haze's clear zone, metres (look.json retro.fog.start_m): the haze
// eases in over about this distance.
global uniform float look_fog_start_m;
// The render distance (m; ChunkManager.render_m(), design 6 Oct §ER.1):
// the fog reaches its full just inside it, so the world's edge is never
// seen. 0 = no far edge.
global uniform float look_draw_m;
// Low mist (look.json "mist"): look_mist_density per metre at and below
// the local ground mean (look_ground_m, its height above the planet
// radius: main samples a 250 m ring round the player), thinning above it
// with scale height look_mist_scale_m. Valleys sit below the mean, so
// they fill; flat forest floor sits at it, so the trunks stand in a low
// layer; hills and peaks rise out of it. (The old look_mist,
// look_height_density and look_height_m globals are unused now.)
global uniform float look_ground_m;
global uniform float look_mist_density;
global uniform float look_mist_scale_m;
// Detail tiles (§AG, look.json retro): the tiny tiles are drawn nearest,
// tiled hard every look_tile_m metres (x grass, y dirt, z sand, w stone;
// look_tile_m2 x bark, y leaves), and use at most look_max_mips mip levels
// (retro_tex) so far ground still sparkles with texel noise.
global uniform vec4 look_tile_m;
global uniform vec2 look_tile_m2;
global uniform float look_max_mips;
// Ground darkening under canopy when the sun casts no shadow map by day
// (§AG 6, retro.canopy_dark; 0 while it does: SkySystem.day_shadows()).
global uniform float look_canopy_dark;
global uniform float look_night;
// §AG tile contrast (data/look.json retro.tile_contrast): the detail tiles'
// light and dark pushed apart about their mid grey (0 = as painted).
global uniform float look_tile_contrast;
// §BU step 5b: within this of the eye the grass tile gains finer blade
// flecks (look.json ranges.grass_m), fading to the plain tile beyond.
global uniform float look_grass_m;
// The ambient floor (design 30 Sept §BD, look.json ambient_floor): the
// hour's floor colour times its energy times the sky visibility where the
// player stands (0 inside a tomb or cave), linear, added under everything
// as ambient after the darkening stack, so day shade is navy and night is
// a blue-grey lift, never black while any sky shows. look_floor_min: the
// least share a point in the open keeps under its own canopy shade.
global uniform vec3 look_floor;
global uniform float look_floor_min;
// Teal and cobalt (sRGB (0.05, 1.0, 0.85) and (0.15, 0.35, 1.0)), linear.
const vec3 look_glow_color = vec3(0.00394, 1.0, 0.69207);
const vec3 look_glow_color_b = vec3(0.01961, 0.10048, 1.0);
global uniform float look_glow; // 0 by day, 1 at night
// The nearest glowing sites: xyz scene position, w radius; their kinds
// packed four to a vec4.
global uniform vec4 look_site_0;
global uniform vec4 look_site_1;
global uniform vec4 look_site_2;
global uniform vec4 look_site_3;
global uniform vec4 look_site_4;
global uniform vec4 look_site_5;
global uniform vec4 look_site_6;
global uniform vec4 look_site_7;
global uniform vec4 look_site_kind_a;
global uniform vec4 look_site_kind_b;
global uniform int look_site_count;

// Lit villages (design 5 Oct §EE.1, look.json village_warmth; VillageWarmth
// sets these each frame). A lit village may go amber while the wild stays
// blue, so the warmth is local, never a switch on the whole frame:
// look_warm_tex holds the nearest LIT hearths, one texel each (xyz scene
// position, w the radius of its warm patch), look_warm_count of them;
// look_warm_village is the nearest village (xyz its middle, w its radius)
// and look_warm_lit its lit fraction (0 dead .. 1 every hearth lit);
// look_warm_ease is (hearth_ease, village_ease, village_fade) and
// look_warm_pool the firelight pooled round a lit hearth (rgb linear,
// a strength). Dead villages and the wild read 0 everywhere.
global uniform sampler2D look_warm_tex : filter_nearest, repeat_disable;
global uniform int look_warm_count;
global uniform vec4 look_warm_village;
global uniform float look_warm_lit;
global uniform vec3 look_warm_ease;
global uniform vec4 look_warm_pool;

// Haze thickens smoothly with distance (it used to step in flat bands).
float look_band(float f) {
	return f;
}

// The mist's mean density (0-1 of full) along a ray whose altitude above
// the ground mean runs evenly from a0 to a1 (over a few hundred metres the
// chord's sag on the planet is centimetres): full below 0, exp(-a / h)
// above, integrated exactly.
float look_mist_share(float a0, float a1, float h) {
	h = max(h, 0.1);
	float lo = min(a0, a1);
	float hi = max(a0, a1);
	float span = hi - lo;
	if (span < 0.01) {
		return exp(-max(lo, 0.0) / h);
	}
	float below = clamp(-lo / span, 0.0, 1.0);
	float above = h * (exp(-max(lo, 0.0) / h) - exp(-max(hi, 0.0) / h)) / span;
	return below + above;
}

vec4 look_fog(vec3 world_pos, vec3 cam_pos) {
	float dist = distance(world_pos, cam_pos);
	// Altitudes above the planet (the eye's, the point's).
	float hc = max(length(cam_pos - look_planet_center) - look_planet_radius, 0.0);
	float hp = length(world_pos - look_planet_center) - look_planet_radius;
	// Haze along the ray through air that thins with height: sea-level
	// density times the mean of exp(-altitude / H) between the two ends.
	float k = (hp - hc) / look_haze_height;
	float thin = exp(-hc / look_haze_height) * (abs(k) < 1e-3 ? 1.0 : (1.0 - exp(-k)) / k);
	// The clear zone: the haze's depth grows as dist^2 / (2 s) near the eye
	// and as dist - s far off, smoothly (no ring where it starts).
	float s = max(look_fog_start_m, 1.0);
	float haze_d = dist - s * (1.0 - exp(-dist / s));
	// Low mist: full at and below the ground mean, thinning above it.
	float mist = look_mist_share(hc - look_ground_m, hp - look_ground_m, look_mist_scale_m);
	float tau = haze_d * look_fog_density * min(thin, 1.5) + dist * look_mist_density * mist;
	// The far edge (§ER.1): more of the same haze, in the same lighter,
	// bluer colour, easing in over the render distance's last 40% so it's
	// full (look_fog_max) at 95% of it.
	if (look_draw_m > 0.0) {
		float e = smoothstep(0.55 * look_draw_m, 0.95 * look_draw_m, dist);
		tau += 3.5 * e * e;
	}
	float f = min(look_band(1.0 - exp(-tau)), look_fog_max);
	return vec4(look_fog_color, f);
}

// Glow color drifts between teal and cobalt across space and time.
vec3 look_glow_emission(vec3 world_pos, float amount) {
	float drift = 0.5 + 0.5 * sin(dot(world_pos, vec3(0.07, 0.05, 0.06)) + TIME * 0.4);
	float pulse = 0.8 + 0.2 * sin(TIME * 1.3 + dot(world_pos, vec3(0.3, 0.2, 0.25)));
	return mix(look_glow_color, look_glow_color_b, drift) * amount * look_glow * pulse;
}

// 0-1 closeness to the nearest glowing site; `kind_weight` 1 counts every
// site fully, 0 counts only ruins/mythical sites (kind 1).
// 0-1: how far the night's blue pull on a surface eases here, in a lit
// village (§EE.1): the most of a lit hearth's patch (hearth_ease at its
// heart, gone at its rim) and the village's own lit fraction across it.
float look_warm(vec3 world_pos) {
	float w = 0.0;
	if (look_warm_village.w > 0.0 && look_warm_lit > 0.0) {
		float d = distance(world_pos, look_warm_village.xyz);
		float rim = look_warm_village.w * (1.0 - look_warm_ease.z);
		w = look_warm_lit * look_warm_ease.y * (1.0 - smoothstep(rim, look_warm_village.w, d));
	}
	for (int i = 0; i < 16; i++) {
		if (i >= look_warm_count) {
			break;
		}
		vec4 h = texelFetch(look_warm_tex, ivec2(i, 0), 0);
		if (h.w <= 0.0) {
			continue;
		}
		float d = distance(world_pos, h.xyz);
		w = max(w, look_warm_ease.x * (1.0 - smoothstep(h.w * 0.35, h.w, d)));
	}
	return clamp(w, 0.0, 1.0);
}

// The firelight a lit hearth's windows and door pool on the ground and the
// walls round it (§EE.1: each relit hearth warms the ground round it), as
// an albedo-scale light (under 1: lit surfaces never bloom, R8), at night
// only. Zero away from lit hearths.
vec3 look_warm_pool_light(vec3 world_pos) {
	float p = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= look_warm_count) {
			break;
		}
		vec4 h = texelFetch(look_warm_tex, ivec2(i, 0), 0);
		if (h.w <= 0.0) {
			continue;
		}
		float f = 1.0 - smoothstep(0.0, h.w, distance(world_pos, h.xyz));
		p = max(p, f * f);
	}
	return look_warm_pool.rgb * look_warm_pool.a * p * look_night;
}

float look_site_glow(vec3 world_pos, float kind_weight) {
	if (look_site_count <= 0) {
		return 0.0;
	}
	vec4 sites[8] = vec4[8](look_site_0, look_site_1, look_site_2, look_site_3, look_site_4, look_site_5, look_site_6, look_site_7);
	float kinds[8] = float[8](look_site_kind_a.x, look_site_kind_a.y, look_site_kind_a.z, look_site_kind_a.w,
		look_site_kind_b.x, look_site_kind_b.y, look_site_kind_b.z, look_site_kind_b.w);
	float g = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= look_site_count) {
			break;
		}
		vec4 s = sites[i];
		float k = mix(step(0.99, kinds[i]), 1.0, kind_weight);
		// A bioluminescent bay (kind 0.2, design 1 Oct §CK) is not lit
		// like the others: look_bay_glow, where the water is stirred.
		k *= 1.0 - step(abs(kinds[i] - 0.2), 0.05);
		g = max(g, smoothstep(s.w, s.w * 0.35, distance(world_pos, s.xyz)) * k);
	}
	return g;
}

// 0-1 inside a bioluminescent bay (kind 0.2): the water shader lights it
// blue-green only where the ripples show it stirred.
float look_bay_glow(vec3 world_pos) {
	if (look_site_count <= 0) {
		return 0.0;
	}
	vec4 sites[8] = vec4[8](look_site_0, look_site_1, look_site_2, look_site_3, look_site_4, look_site_5, look_site_6, look_site_7);
	float kinds[8] = float[8](look_site_kind_a.x, look_site_kind_a.y, look_site_kind_a.z, look_site_kind_a.w,
		look_site_kind_b.x, look_site_kind_b.y, look_site_kind_b.z, look_site_kind_b.w);
	float g = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= look_site_count) {
			break;
		}
		if (abs(kinds[i] - 0.2) < 0.05) {
			vec4 s = sites[i];
			g = max(g, smoothstep(s.w, s.w * 0.6, distance(world_pos, s.xyz)));
		}
	}
	return g;
}

// A nearest-filtered detail tile at `uv`, its mip level picked as the
// hardware would but never past look_max_mips (fragment only).
vec4 retro_tex(sampler2D tex, vec2 uv) {
	vec2 st = uv * vec2(textureSize(tex, 0));
	vec2 dx = dFdx(st);
	vec2 dy = dFdy(st);
	float lod = 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-8));
	return textureLod(tex, uv, clamp(lod, 0.0, look_max_mips));
}

// One of Look's mid-grey modulation tiles (grass, dirt, sand, stone, bark,
// leaves, water: 0.5 = unchanged), nearest-filtered with at most
// look_max_mips mips, its contrast pushed by look_tile_contrast (§AG 1).
vec4 retro_tile(sampler2D tex, vec2 uv) {
	vec4 c = retro_tex(tex, uv);
	c.rgb = 0.5 + (c.rgb - 0.5) * (1.0 + look_tile_contrast);
	return c;
}

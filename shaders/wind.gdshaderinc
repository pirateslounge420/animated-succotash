// The wind you can see (design 3 Oct §DA, data/wind.json; Wind I). One
// wind: the weather's (the global plant_wind WeatherFX sets each frame,
// passed in as `mean`), with a gust field on top that every reader
// samples at its own position, so a gust is a patch of stronger air that
// runs across the ground. Written once here for the shaders and once in
// GDScript (Wind.gd, for the CPU readers); tools/wind_check.gd keeps the
// two in step. Change one, change the other.
//
// The field: two octaves of 3D value noise at gusts.patch_m (40 m, 12 m),
// in the planet's own frame (so the floating origin never moves it),
// carried downwind at the mean wind's speed in real seconds (frozen
// turbulence): Wind keeps the drift (the wind's travel, summed each frame)
// and sets wind_shift = -(planet centre) - drift, so a scene point's
// place in the field is world_pos + wind_shift. The noise repeats every
// 1024 cells, and Wind wraps the drift on that period, so the numbers
// stay small.
//
// gust factor = 1 + intensity x the noise (scaled to one standard
// deviation by wind_gust2.w), clamped to [lull_min, factor_max]; the
// direction veers by up to veer_deg from the octaves' difference; below
// calm_mps the field fades to 1 (still air). The weather's slow swell
// stays underneath as the mean.

// -(planet centre) - drift, scene space (Wind.gd).
global uniform vec3 wind_shift;
// gusts: intensity, factor_max, lull_min, calm_mps.
global uniform vec4 wind_gust;
// gusts: patch_m big, patch_m small, veer (radians), 1 / the noise's
// standard deviation.
global uniform vec4 wind_gust2;
// profile: z0_m (the ground round you), reference_height_m, shelter_floor,
// flutter.amount.
global uniform vec4 wind_prof;
// crowns: leaves_mps, twigs_mps, small_branches_mps, small_trees_mps.
global uniform vec4 wind_crowns;
// crowns: large_branches_mps, whole_trees_mps; flutter.from_mps;
// grass.lean_max.
global uniform vec4 wind_crowns2;
// grass: lean_from_mps, flatten_mps, sheen (0/1); 0.
global uniform vec4 wind_grass;
// crowns.sway_period_s: four heights (m), their periods (s), and the last
// pair in wind_sway_last.xy.
global uniform vec4 wind_sway_h;
global uniform vec4 wind_sway_s;
global uniform vec2 wind_sway_last;

// One lattice value, 0-1: an integer hash of the cell (repeating every
// 1024 cells on each axis). Wind.gd: _hash.
float wind_hash(ivec3 c) {
	uvec3 u = uvec3(c) & uvec3(1023u);
	uint h = u.x * 374761393u + u.y * 668265263u + u.z * 1440662683u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 16777215u) / 16777215.0;
}

// Smoothed value noise, 0-1. Wind.gd: _vnoise.
float wind_vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = p - i;
	vec3 w = f * f * (3.0 - 2.0 * f);
	ivec3 c = ivec3(i);
	float x00 = mix(wind_hash(c), wind_hash(c + ivec3(1, 0, 0)), w.x);
	float x10 = mix(wind_hash(c + ivec3(0, 1, 0)), wind_hash(c + ivec3(1, 1, 0)), w.x);
	float x01 = mix(wind_hash(c + ivec3(0, 0, 1)), wind_hash(c + ivec3(1, 0, 1)), w.x);
	float x11 = mix(wind_hash(c + ivec3(0, 1, 1)), wind_hash(c + ivec3(1, 1, 1)), w.x);
	return mix(mix(x00, x10, w.y), mix(x01, x11, w.y), w.z);
}

// The gust field at scene point `p` under a mean wind of `mean_mps`:
// (factor, veer in radians). Wind.gd: gust_field.
vec2 wind_gust_field(vec3 p, float mean_mps) {
	vec3 q = p + wind_shift;
	float a = wind_vnoise(q / wind_gust2.x) * 2.0 - 1.0;
	float b = wind_vnoise(q / wind_gust2.y + vec3(17.0, 31.0, 47.0)) * 2.0 - 1.0;
	float n = (0.85 * a + 0.15 * b) * wind_gust2.w;
	float calm = clamp(mean_mps / max(wind_gust.w, 1e-3), 0.0, 1.0);
	float f = clamp(1.0 + wind_gust.x * n, wind_gust.z, wind_gust.y);
	float veer = wind_gust2.z * clamp((a - b) * 1.9, -1.0, 1.0);
	return vec2(mix(1.0, f, calm), veer * calm);
}

// The gusted wind at `p` (m/s, a world vector: the mean times the factor,
// turned by the veer about `up`) and the factor in w. Wind.gd: gust_vec.
vec4 wind_gust_vec(vec3 p, vec3 mean, vec3 up) {
	float s = length(mean);
	vec2 g = wind_gust_field(p, s);
	vec3 v = mean * g.x;
	v = v * cos(g.y) + cross(up, v) * sin(g.y);
	return vec4(v, g.x);
}

// The share of the 10 m wind at `z` m up over open ground (the log
// profile, roughness wind_prof.x): grass tops about half, head height
// about 0.7, a treetop about 1.1. Wind.gd: profile.
float wind_profile(float z) {
	float z0 = max(wind_prof.x, 1e-4);
	return clamp(log(max(z, z0 * 1.5) / z0) / log(wind_prof.y / z0), 0.0, 1.5);
}

// Below the crowns: the share of the wind that gets through, by the
// spot's sky visibility (§BD). Wind.gd: shelter.
float wind_shelter(float sky) {
	return wind_prof.z + (1.0 - wind_prof.z) * clamp(sky, 0.0, 1.0);
}

// 0 below `from` m/s, rising to 1 by half again over it: when a movement
// starts (the Beaufort table, wind.json crowns). Wind.gd: gate.
float wind_gate(float u, float from) {
	return smoothstep(from * 0.85, from * 1.5, u);
}

// A trunk's own sway period (s) by its height (crowns.sway_period_s).
// Wind.gd: sway_period.
float wind_sway_period(float h) {
	if (h <= wind_sway_h.x) return wind_sway_s.x;
	if (h <= wind_sway_h.y) return mix(wind_sway_s.x, wind_sway_s.y, (h - wind_sway_h.x) / (wind_sway_h.y - wind_sway_h.x));
	if (h <= wind_sway_h.z) return mix(wind_sway_s.y, wind_sway_s.z, (h - wind_sway_h.y) / (wind_sway_h.z - wind_sway_h.y));
	if (h <= wind_sway_h.w) return mix(wind_sway_s.z, wind_sway_s.w, (h - wind_sway_h.z) / (wind_sway_h.w - wind_sway_h.z));
	if (h <= wind_sway_last.x) return mix(wind_sway_s.w, wind_sway_last.y, (h - wind_sway_h.w) / (wind_sway_last.x - wind_sway_h.w));
	return wind_sway_last.y;
}

// --- Wind III (design §DA point 4: water, cloud shadows) -----------------

// water: calm_below_mps, cats_paws_mps, whitecaps_mps; 0.
global uniform vec4 wind_water;
// The water's answer to the wind `u` (the gusted 10 m wind there, m/s):
// (roughness 0-1: the cat's paw, from cats_paws_mps; crests 0-1: from
// whitecaps_mps; calm 0-1: a mirror under calm_below_mps). Wind.gd:
// water_state.
vec3 wind_water_state(float u) {
	float rough = smoothstep(wind_water.y, wind_water.y * 1.6, u);
	float crest = smoothstep(wind_water.z, wind_water.z * 1.4, u);
	float calm = 1.0 - smoothstep(wind_water.x * 0.7, wind_water.x, u);
	return vec3(rough, crest, calm);
}

// Cloud shadows (wind.json cloud_shadows): x the strength by §CX's cover
// (0 outside from_cover..to_cover), y the noise threshold under which a
// point is in shadow (so the shaded share of the ground is the cover),
// z and w the two patch sizes (m). cloud_shift: -(planet centre) - the
// clouds' drift (Wind: the ground wind x speed_x, summed).
global uniform vec4 cloud_shadow;
global uniform vec3 cloud_shift;

// How much of the sun's direct light a cloud takes at scene point `p`
// (0 none, up to cloud_shadow.x). Wind.gd: cloud_shade.
float wind_cloud_shade(vec3 p) {
	if (cloud_shadow.x <= 0.0) {
		return 0.0;
	}
	vec3 q = p + cloud_shift;
	float n = 0.65 * wind_vnoise(q / cloud_shadow.w) + 0.35 * wind_vnoise(q / cloud_shadow.z + vec3(5.0, 9.0, 13.0));
	return n < cloud_shadow.y ? cloud_shadow.x : 0.0;
}

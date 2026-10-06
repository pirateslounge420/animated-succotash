// Pre-lit (design 6 Oct §ES.2; scripts/sky/prelit.gd, data/look.json
// "prelit"): the light is painted into the models, Dreamcast/GameCube
// style. The model's occlusion is baked into its vertex colours (Prelit);
// here, prelit_paint() lights the albedo from the sky above (the side
// facing down sinks toward the scene's shade colour, navy, or olive on a
// green), and prelit_light.gdshaderinc's light() lets the sun and moon only
// tint (their colour and strength, and where they're shadowed: no N.L) and
// the fire light round what it lights. look_prelit 0 puts the old live
// lighting back (PRELIT=0, an A/B). Include after look.gdshaderinc.

global uniform float look_prelit;
// The sun's and moon's tint strength (no N.L, so about the mean of the
// N.L it replaces).
global uniform float look_prelit_sun;
// The painted light on a face turned straight down (1 straight up).
global uniform float look_prelit_floor;
// The shade multipliers (linear): navy, and olive for green things.
global uniform vec3 look_prelit_navy;
global uniform vec3 look_prelit_olive;

float prelit_green(vec3 c) {
	return clamp((c.g - max(c.r, c.b)) / max(c.g, 1e-3) * 2.5, 0.0, 1.0);
}

// `albedo` lit by the painted light for a world-space normal `n_world`.
vec3 prelit_paint(vec3 albedo, vec3 n_world) {
	if (look_prelit < 0.5) {
		return albedo;
	}
	float sky = 0.5 + 0.5 * dot(normalize(n_world), look_up);
	float lit = mix(look_prelit_floor, 1.0, sky * sky * (3.0 - 2.0 * sky));
	vec3 shade = mix(look_prelit_navy, look_prelit_olive, prelit_green(albedo));
	return albedo * mix(shade * lit, vec3(1.0), lit);
}

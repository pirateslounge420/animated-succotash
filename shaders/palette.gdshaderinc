// The ground palette (docs/WORLD_SYSTEMS_SPEC.md R1a), shared by the
// world shaders (terrain, far terrain, plants, ruins). Include it after
// look.gdshaderinc: it reads `look_night` (0 by day, 1 at night).
//
// Each surface's own color (a biome's ground, a species' leaves or bark, a
// ruin's stone) is PULLED toward its R1a target rather than replaced: the
// hue and saturation move most of the way, the brightness keeps half of
// its own variety, so biomes and species still differ. As night falls
// (look_night) a second pull moves each surface toward its night target,
// so that under the moon grass lands on teal-blue, stone on slate-blue and
// bark on deep blue, never black.
//
// The targets below are albedos, not screen colors: the sun, the moon,
// the flat ambient, the grade and the post all shift them. They were tuned
// by rendering and sampling the screen (the screen colors each aims for
// are in the comments). The night targets look odd on paper (green for
// grass, near-neutral for stone): the moonlight and night ambient are
// already deep blue and the night grade crushes red and green, so the
// albedo has to hold on to green and red for the screen to land on #1E4A6A
// and #3E4C8C instead of pure ultramarine. If the night lighting changes,
// re-tune the night targets. Change the look here, not in each shader.

// Grass (§AG, data/look.json retro.colors): screen #3F6E2C in the sun,
// #224A18 base, #10270A deep, cooling toward #1E4A6A at night. Dark, not
// poison green: it reads bright only against the navy.
const vec3 pal_grass = vec3(0.07, 0.16, 0.0);
// Tree crowns: #1A3A14, a shade under the grass.
const vec3 pal_canopy = vec3(0.05, 0.075, 0.025);
const vec3 pal_grass_night = vec3(0.03, 0.47, 0.2);
// Dirt and paths (§AG): olive earth, #4A4626 to #8F803B in the sun.
const vec3 pal_dirt = vec3(0.85, 0.55, 0.04);
// Bark, the warm brown: #6B4A2E to #A07A4A.
const vec3 pal_bark = vec3(0.72, 0.39, 0.18);
const vec3 pal_bark_night = vec3(0.28, 0.26, 0.36);
// Stone: #6F7A8A by day, #3E4C8C at night. Moss #3F7A3A.
const vec3 pal_stone = vec3(0.42, 0.45, 0.5);
const vec3 pal_stone_night = vec3(0.46, 0.5, 0.52);
const vec3 pal_moss = vec3(0.2, 0.42, 0.08);
// Snow: #C8D8F0, with #6A82C0 in shadow (the blue ambient does the shadow).
const vec3 pal_snow = vec3(0.72, 0.82, 0.97);

float pal_luma(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

// Typical brightness of the source colors (biome ground, species leaves
// and bark, ruin stone): a source this bright lands exactly on the target.
const float pal_ref_luma = 0.4;

// `c` pulled toward `target` by `amount` (0-1): target's hue and
// saturation, keeping half of c's brightness difference from a typical
// source (pal_ref_luma), so brighter biomes and species stay brighter.
vec3 pal_pull(vec3 c, vec3 target, float amount) {
	float k = mix(1.0, pal_luma(c) / pal_ref_luma, 0.5);
	return mix(c, target * k, clamp(amount, 0.0, 1.0));
}

// 0-1: how green `c` is (green channel above red and blue).
float pal_greenness(vec3 c) {
	return smoothstep(0.0, 0.07, c.g - max(c.r, c.b) * 0.92);
}

// The ripple buffer as the water sees it (RippleSim): turns the packed
// simulation state (ripple_step.gdshader) into a plain texture the water
// shader can sample smoothly (linear filtering), once per texel instead
// of once per pixel:
//   R  where each ring is in its swing: 1 on a crest, 0 in a trough, 0.5
//      where the surface crosses its rest level (height over envelope);
//   G B  slope along the window's u and v axes (the surface normal), 0.5
//      flat, eased toward 0/1 for big ripples so small ones still read;
//   A  the envelope: how big the ripples passing here are, whichever part
//      of their swing they're in (0 calm, eased toward 1).
// The water paints R as its light and dark bands, as strongly as A says,
// so a ring shows the same two bands whether it's big or small.
//
// R and A are the rings alone: the surface less its mean over a ring of
// eight texels about half a meter out. That keeps the rings (a meter or
// two from crest to crest) and drops the broad, slow swell a big splash
// leaves inside its rings, which would otherwise paint as wide blotches.
// The rings' own height is (2R - 1) times the envelope.
//
// The envelope of a travelling wave: height h swings with speed v a
// quarter turn behind it, so sqrt(h^2 + (v / omega)^2) holds steady
// through the swing, omega = 2 pi c / wavelength (the rings' own
// wavelength, `band_wavelength_m` in data/water/ripples.json).
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D state : filter_nearest, repeat_disable;
uniform int size = 256;
uniform float texel_m = 0.25;
uniform float height_ref = 0.012;
uniform float slope_ref = 0.05;
uniform float omega = 4.6;

const float H_RANGE = 0.5; // as ripple_step.gdshader
const float V_RANGE = 4.0;
// Below this envelope (m) the water counts as calm (no phase to speak of).
const float CALM_M = 0.0003;

float unpack16(vec2 b, float range) {
	float n = floor(b.x * 255.0 + 0.5) * 256.0 + floor(b.y * 255.0 + 0.5);
	return (n >= 32768.0 ? n - 65536.0 : n) / 32767.0 * range;
}

vec2 cell(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(size - 1));
	vec4 t = texture(state, (vec2(p) + 0.5) / float(size));
	return vec2(unpack16(t.rg, H_RANGE), unpack16(t.ba, V_RANGE));
}

// Soft saturation: linear near 0, easing toward +-1.
float ease(float x) {
	return x * inversesqrt(1.0 + x * x);
}

void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy);
	vec2 c = cell(p);
	float he = cell(p + ivec2(1, 0)).x;
	float hw = cell(p - ivec2(1, 0)).x;
	float hs = cell(p + ivec2(0, 1)).x;
	float hn = cell(p - ivec2(0, 1)).x;
	vec2 slope = vec2(he - hw, hs - hn) / (2.0 * texel_m);
	// The rings: height and speed less their mean round a ring of texels
	// sqrt(5) out.
	ivec2 around[8] = {ivec2(2, 1), ivec2(1, 2), ivec2(-1, 2), ivec2(-2, 1),
		ivec2(-2, -1), ivec2(-1, -2), ivec2(1, -2), ivec2(2, -1)};
	vec2 mean = vec2(0.0);
	for (int i = 0; i < 8; i++) {
		mean += cell(p + around[i]);
	}
	vec2 w = c - mean * 0.125;
	float env = length(vec2(w.x, w.y / omega));
	COLOR = vec4(
		0.5 + 0.5 * w.x / max(env, CALM_M),
		0.5 + 0.5 * ease(slope.x / slope_ref),
		0.5 + 0.5 * ease(slope.y / slope_ref),
		ease(env / height_ref));
}

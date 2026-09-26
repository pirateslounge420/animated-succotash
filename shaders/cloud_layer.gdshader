// One cloud layer (CloudLayers): a transparent sphere shell around the
// planet at the layer's altitude, so peaks taller than it poke through
// and, from a summit above it, you look down on a sea of cloud.
//
//   kind 0  low: big puffy cumulus, bright sunlit sides, shaded bellies
//   kind 1  mid: altocumulus, smaller puffs in patchy rafts
//   kind 2  high: cirrus, thin streaks drawn out along the wind
//
// The pattern is 3D noise at the shell point (seamless round the planet),
// shifted by `drift` (meters, the layer's accumulated wind travel). Soft
// and painterly: edges feather out (wider far off, so they don't shimmer)
// with a wispy detail octave; thick cores darken, and one extra noise tap
// toward the sun (or moon) lights the sides facing it, with a silver
// lining where the cloud is thin.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

#include "res://shaders/look.gdshaderinc"

uniform int kind = 0;
uniform float radius = 65000.0; // shell radius, m (the mesh is a unit sphere)
uniform float cover = 0.4; // 0-1
uniform float feature_m = 700.0; // typical cloud size
uniform float max_alpha = 0.95;
uniform vec3 drift = vec3(0.0);
uniform vec3 wind_axis = vec3(1.0, 0.0, 0.0); // planet frame, unit
uniform vec3 light_dir = vec3(0.0, 1.0, 0.0); // sun or moon, planet frame, unit
uniform vec3 light_color : source_color = vec3(1.0);
uniform vec3 shade_color : source_color = vec3(0.7, 0.75, 0.9);
uniform float camera_above = 0.0; // 1 when the viewer is above this layer
uniform vec2 fog_ease_m = vec2(3000.0, 30000.0); // haze eases in over this range

varying vec3 shell_pos;
varying vec3 world_pos;

void vertex() {
	// The mesh is a unit sphere; the shell is `radius` meters out.
	VERTEX *= radius;
	shell_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// Three octaves, plus the mean (1/32) the dropped fourth one added, so
// cover reads the same. Sum is within [1/32, 29/32]; after the first
// octave the rest add at most 3/8 (EARLY_REST).
const float FBM_MEAN4 = 0.03125;
const float EARLY_REST = 0.375;

// Each octave is turned as well as scaled, so value noise's lattice
// doesn't line the clouds up into boxy, axis-aligned lumps.
const mat3 OCTAVE_TURN = mat3(vec3(0.0, 0.8, 0.6), vec3(-0.8, 0.36, -0.48), vec3(-0.6, -0.48, 0.64));

float fbm3(vec3 p) {
	float v = FBM_MEAN4;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise3(p);
		p = OCTAVE_TURN * p * 2.07 + vec3(17.0, 9.0, 23.0);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec3 up = normalize(shell_pos);
	vec3 p = up * radius + drift;
	vec3 q = p / feature_m;
	float edge = 1.0 - cover;
	float n;
	// The shape's first octave, and the same a little toward the light:
	// where the cloud thins toward the sun its side faces the sun.
	vec3 toward = light_dir - up * dot(light_dir, up);
	vec3 lq;
	float first;
	// Early outs (exact): the first octave bounds the fbm (the rest adds at
	// most EARLY_REST, the extra term at most 1), so where it can't reach
	// the cover threshold there's no cloud and the rest isn't worth
	// computing.
	if (kind == 2) {
		// Cirrus: stretched along the wind into long thin streaks.
		float along = dot(q, wind_axis);
		vec3 across = q - wind_axis * along;
		vec3 s = across * 3.0 + wind_axis * along * 0.35;
		first = vnoise3(s);
		if (0.75 * (0.5 * first + FBM_MEAN4 + EARLY_REST) + 0.25 < edge) {
			discard;
		}
		n = fbm3(s) * 0.75 + 0.25 * (1.0 - abs(2.0 * vnoise3(s * 2.3 + 5.0) - 1.0));
		lq = s;
	} else if (kind == 1) {
		// Altocumulus: small puffs, gathered into rafts by a coarse mask
		// (which scales them by at most 1.15).
		first = vnoise3(q * 1.6);
		if ((0.8 * (0.5 * first + FBM_MEAN4 + EARLY_REST) + 0.2) * 1.15 < edge) {
			discard;
		}
		float raft = smoothstep(0.35, 0.7, fbm3(q * 0.25 + 11.0));
		n = (fbm3(q * 1.6) * 0.8 + 0.2 * vnoise3(q * 4.0)) * (0.55 + 0.6 * raft);
		lq = q * 1.6;
	} else {
		// Cumulus: billowed fbm, big rounded heads.
		first = vnoise3(q);
		if (0.72 * (0.5 * first + FBM_MEAN4 + EARLY_REST) + 0.28 < edge) {
			discard;
		}
		n = fbm3(q) * 0.72 + 0.28 * (1.0 - abs(2.0 * vnoise3(q * 2.3 + 7.0) - 1.0));
		lq = q;
	}
	float body = n - edge;
	// Wisps: a fine octave frays the edges (only near them).
	if (body > -0.05 && body < 0.12) {
		body += (vnoise3(OCTAVE_TURN * q * 9.0 + 3.0) - 0.5) * 0.06;
	}
	if (body <= 0.0) {
		discard;
	}
	// Thick cores go to the shade color (the bellies, seen from below;
	// from above, the tops are lit). The side toward the light is brighter
	// and thin edges catch a silver lining.
	float thick = smoothstep(0.02, 0.35, body) * (1.0 - camera_above * 0.7);
	float facing = smoothstep(-0.25, 0.25, first - vnoise3(lq + toward * 0.5));
	float bright = (1.0 - thick) * 0.7 + facing * 0.3;
	vec3 col = mix(shade_color, light_color, bright);
	col = mix(col, light_color, (1.0 - smoothstep(0.0, 0.07, body)) * 0.5);
	if (kind == 2) {
		col = mix(light_color, col, 0.3);
	}
	ALBEDO = col;
	// Feathered edges, a little softer where the pattern is small on
	// screen.
	float soft = max(0.09, fwidth(body) * 2.0);
	ALPHA = max_alpha * smoothstep(0.0, soft, body);
	// Haze (thinning with height, like everything's) but eased off nearby:
	// a cloud a few km up or down shouldn't wash out.
	vec4 fog = look_fog(world_pos, CAMERA_POSITION_WORLD);
	fog.a *= smoothstep(fog_ease_m.x, fog_ease_m.y, distance(world_pos, CAMERA_POSITION_WORLD));
	FOG = fog;
}

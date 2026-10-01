// The Night Riders' bodies (NightRiderBody): one smooth skinned mesh whose
// vertex colors carry the palette (deep ultramarine and indigo) and baked
// creases. Vertex-lit like the rest of the world (Lambert, no specular,
// Look's fog). UV.x is the surface: 0 smooth leather and gloves (a faint
// grain), 1 hair (coat, mane, tail, feathering: Look's fur strokes), 2
// hoof (smooth), 3 cloth (the cloak: the strokes, fainter, finer), 4 void
// (the rider's face, the horse's eye sockets and nostrils: untextured, no
// sheen, the darkest thing on them).
//
// "Crunchy textures on smooth, rounded shapes" (R1): the strokes and a
// hard-edged grain are sampled triplanar in the body's REST pose (CUSTOM0
// position, CUSTOM1 normal), so the texture rides on the skin instead of
// sliding over the legs as they walk, at a scale where a texel is one to
// three screen pixels at walking distance (the mesh is in units of its
// height, ~2.7 m), so it reads as texture rather than blurring flat.
//
// R1a, nothing pure black: no color here is darker than floor_color, the
// night sky's darkest (#0A14A0; NightRiderBody sets it from SkySystem).
// Creases and dark strokes ease onto it (a smooth maximum, per channel)
// rather than stopping flat against it.
//
// At night they are "lit only by blue sheen" (the designer's night
// references: a dark armoured figure, a dark horse; deep blue with bright
// blue highlights, never flat black). Two parts:
//   night_shade  the world's light (the flat ultramarine fill, the moon)
//                reaches them only this much at night (look_night), so
//                they stand as deep blue masses, darker than the trunks
//                and the sky, rather than the flat mid-blue the fill
//                alone makes of them; the colors above are unchanged (by
//                day they're lit like anything else), and the night
//                grade's ultramarine veil keeps their darkest deep blue;
//   the sheen    a cold blue gloss on the coat and cloth, worked out like
//                the era's sphere-mapped sheen, from which way the surface
//                faces as you see it: along the edges turned away from
//                you, across the planes that face up and toward you (the
//                head, the crest, the shoulders, the hood), and on what
//                faces the sky, broken into streaks by the same strokes
//                and grain, so it's crunchy like the rest. It is emitted,
//                not lit, and it is what their shapes read by. The glossy
//                coat and hooves take it smoothest, the cloak most broken.
// Unlike the world's materials (look.gdshaderinc: no rim or sheen), this
// is for the riders only. NightRiderBody sets night_shade, sheen_color and
// sheen_amount from the species' data ("look", "palette").
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_fur : filter_nearest_mipmap, repeat_enable;
// Texture tiles per unit of the body's height.
uniform float fur_scale = 1.3;
uniform float grain_scale = 5.0;
// How strongly the strokes and the grain break up the color.
uniform float stroke_amount = 0.9;
uniform float crunch = 0.35;
// The darkest any of it may be, and how softly it eases onto that (a
// share of the floor).
uniform vec3 floor_color : source_color = vec3(0.039, 0.078, 0.627);
uniform float floor_soft = 0.3;
// How much of the world's light reaches them at night (1 = all).
uniform float night_shade = 0.25;
// The sheen: its color at full strength, overall amount (0 = none), how
// tightly it hugs the edges (a higher power: a thinner rim), how much
// falls on the planes facing up and toward you (from over your left
// shoulder, as the references are lit), and how much on what faces the
// sky.
uniform vec3 sheen_color : source_color = vec3(0.18, 0.4, 1.0);
uniform float sheen_amount = 1.2;
uniform float sheen_power = 1.8;
uniform float sheen_key = 0.5;
uniform float sheen_sky = 0.35;

varying vec3 world_pos;
varying vec3 rest_pos;
varying vec3 rest_nrm;

void vertex() {
	rest_pos = CUSTOM0.xyz;
	rest_nrm = CUSTOM1.xyz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 tri_weights() {
	vec3 n = abs(rest_nrm);
	n = n * n;
	return n / (n.x + n.y + n.z);
}

vec3 fur_strokes(float scale) {
	vec3 w = tri_weights();
	return texture(look_tex_fur, rest_pos.xy * scale).rgb * w.z + texture(look_tex_fur, rest_pos.zy * scale).rgb * w.x
		+ texture(look_tex_fur, rest_pos.xz * scale).rgb * w.y;
}

float grain_at(float scale) {
	vec3 w = tri_weights();
	return texture(look_grain, rest_pos.xy * scale).r * w.z + texture(look_grain, rest_pos.zy * scale).r * w.x
		+ texture(look_grain, rest_pos.xz * scale).r * w.y;
}

// Smooth maximum of `a` and `b` per channel (never below either).
vec3 soft_max(vec3 a, vec3 b, vec3 k) {
	vec3 d = a - b;
	return 0.5 * (a + b + sqrt(d * d + k * k));
}

void fragment() {
	int kind = int(round(UV.x));
	vec3 t = vec3(0.5);
	float k = 0.0;
	if (kind == 1) {
		t = fur_strokes(fur_scale);
		k = stroke_amount;
	} else if (kind == 3) {
		t = fur_strokes(fur_scale * 1.6);
		k = stroke_amount * 0.6;
	}
	float g = grain_at(grain_scale);
	float grain = kind == 2 ? crunch * 0.5 : crunch;
	if (kind == 4) {
		grain = 0.0;
	}
	vec3 base = COLOR.rgb * mix(vec3(1.0), t * 2.0, k);
	vec3 albedo = base * mix(1.0, g * 2.0, grain);
	ALBEDO = soft_max(albedo, floor_color, floor_color * floor_soft) * mix(1.0, night_shade, look_night);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// The sheen, by the facing in view space: edges turned away (a rim),
	// planes facing up and toward you, faces toward the sky; streaks where
	// the strokes and grain are light (they sit around 0.42 and 0.5;
	// stretched here so the breaks are crisp).
	vec3 n = normalize(NORMAL);
	float rim = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), sheen_power);
	float key = pow(clamp(dot(n, normalize(vec3(-0.6, 0.75, 0.25))), 0.0, 1.0), 4.0);
	vec3 up_v = normalize((VIEW_MATRIX * vec4(look_up, 0.0)).xyz);
	float sky = clamp(dot(n, up_v), 0.0, 1.0);
	float lit = rim + sheen_key * key + sheen_sky * sky * sky;
	float strokes = clamp((dot(fur_strokes(fur_scale * 1.3), vec3(0.333)) - 0.37) / 0.12, 0.0, 1.0);
	float speck = clamp((g - 0.4) / 0.22, 0.0, 1.0);
	float streak = 0.6 * mix(0.5, 1.0, speck); // leather and gloves
	if (kind == 3) {
		streak = pow(strokes, 1.5) * (0.45 + 0.55 * speck); // cloth: most broken
	} else if (kind == 1) {
		streak = mix(0.3, 1.0, strokes) * (0.6 + 0.4 * speck); // coat: glossy, broken by the hair
	} else if (kind == 2) {
		streak = 0.9; // hoof
	} else if (kind == 4) {
		streak = 0.0; // the void catches no light
	}
	EMISSION = sheen_color * (lit * streak * sheen_amount * look_night);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

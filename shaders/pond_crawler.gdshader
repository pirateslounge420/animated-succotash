// The Pond Crawler's body (PondCrawlerBody): one smooth skinned mesh with
// a crunchy, noisy hide (spec R1: crunchy textures on smooth rounded
// shapes), vertex-lit like the rest of the world (Lambert, no specular,
// Look's fog), and its one large slit eye.
//
// The hide is three of Look's painted textures, sampled triplanar in the
// body's REST pose (CUSTOM0 position, CUSTOM1 normal: the texture rides on
// the skin instead of swimming as the long arms bend): mottled, cracked
// stone for broad warty patches, pebbly dirt for the fine crunch, and the
// soft grain for large light and dark. On the hood (UV.x = 1) the mottle
// runs in long streaks down the folds. Claws (UV.x = 2) stay smooth.
//
// The eye is drawn here, per pixel, from the rest position: an almond
// slit across the face under the hood's brim (eye_center, eye_size), a
// brighter core along its middle, and a dark lid round it. It glows in
// eye_color (the species' `accent`, #2A6AFF), the one accent in the scene
// (spec R1a); per-instance eye_open narrows it (0 shut, 1 wide) and
// eye_glow dims it (dying). Drawn into the skin, it follows the face's
// curve at any mesh density. Its light is a real OmniLight3D (PondCrawler).
//
// Colors: UV2.x is the weight of the body color (the species' `color`,
// with each shape's shade and the baked creases in it), UV2.y of the pale
// color; COLOR holds fixed colors (claws). The body color is a slate
// albedo (#6E7590): the night light and grade crush red and green, so a
// near-neutral albedo lands on the world's deep night ultramarine with
// the texture showing in every channel, where a saturated blue one comes
// out flat violet-blue (R1a: tinted into the night, nothing pure black).
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_stone : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_dirt : filter_nearest_mipmap, repeat_enable;
uniform vec3 body_color = vec3(0.1, 0.12, 0.35);
uniform vec3 pale_color = vec3(0.2, 0.24, 0.5);
// 0-1+: how strongly the texture shows.
uniform float crunch = 1.3;
// The eye, in rest-pose meters: slit center on the face, half width and
// half height when wide open.
uniform vec3 eye_color : source_color = vec3(0.165, 0.416, 1.0);
uniform vec3 eye_center = vec3(0.0, 0.3, -0.6);
uniform vec2 eye_size = vec2(0.21, 0.06);
instance uniform float eye_open = 0.5;
instance uniform float eye_glow = 1.0;

varying vec3 rest_pos;
varying vec3 rest_nrm;
varying vec3 world_pos;

void vertex() {
	rest_pos = CUSTOM0.xyz;
	rest_nrm = CUSTOM1.xyz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Triplanar sample (rest space), red channel, `scale` repeats per meter;
// `stretch` elongates the pattern vertically (hood folds).
float tri(sampler2D t, float scale, float stretch) {
	vec3 w = abs(normalize(rest_nrm));
	w = w * w * w;
	w /= (w.x + w.y + w.z);
	vec3 p = rest_pos * scale;
	float a = texture(t, vec2(p.z, p.y / stretch)).r;
	float b = texture(t, p.xz).r;
	float c = texture(t, vec2(p.x, p.y / stretch)).r;
	return a * w.x + b * w.y + c * w.z;
}

// The same for the soft grain (its sampler is linear; one function may
// not take samplers of differing filters).
float tri_soft(sampler2D t, float scale, float stretch) {
	vec3 w = abs(normalize(rest_nrm));
	w = w * w * w;
	w /= (w.x + w.y + w.z);
	vec3 p = rest_pos * scale;
	float a = texture(t, vec2(p.z, p.y / stretch)).r;
	float b = texture(t, p.xz).r;
	float c = texture(t, vec2(p.x, p.y / stretch)).r;
	return a * w.x + b * w.y + c * w.z;
}

// 0-1 inside an almond `grow` times the slit's size (height times
// `open`), on the front of the face only; `soft` m edge.
float almond(float grow_x, float grow_y, float open, float soft) {
	if (rest_pos.z > eye_center.z + 0.16 || normalize(rest_nrm).z > -0.15) {
		return 0.0;
	}
	float x = (rest_pos.x - eye_center.x) / (eye_size.x * grow_x);
	if (abs(x) >= 1.0) {
		return 0.0;
	}
	float h = eye_size.y * grow_y * open * pow(1.0 - x * x, 0.8);
	float d = abs(rest_pos.y - eye_center.y) - h;
	return 1.0 - smoothstep(-soft, soft, d);
}

void fragment() {
	int kind = int(round(UV.x));
	vec3 base = COLOR.rgb + UV2.x * body_color + UV2.y * pale_color;
	float n = 0.0;
	if (kind != 2) {
		float stretch = kind == 1 ? 3.0 : 1.0;
		n = (tri(look_tex_stone, 1.9, stretch) - 0.5) * 1.6
			+ (tri(look_tex_dirt, 3.6, 1.0) - 0.5) * 1.5
			+ (tri_soft(look_grain_soft, 0.9, stretch) - 0.5) * 1.1;
	}
	vec3 albedo = base * clamp(1.0 + n * crunch, 0.3, 2.0);
	// The eye: a dark lid, the slit, a hot core.
	float lid = almond(1.3, 1.9, 1.0, 0.02);
	float slit = almond(1.0, 1.0, eye_open, 0.004);
	float core = almond(0.8, 0.36, eye_open, 0.003);
	albedo *= 1.0 - 0.6 * lid;
	albedo = mix(albedo, vec3(0.0), slit);
	ALBEDO = albedo;
	EMISSION = (eye_color * slit + mix(eye_color, vec3(1.0), 0.45) * core * 0.9) * eye_glow;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

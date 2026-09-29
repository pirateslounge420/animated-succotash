// Leaf litter on the ground (LitterField, design §AI 2-3): one patch per
// 4 m cell, a square a little bigger than the cell laid on the ground's
// slope, drawn with the dominant species' litter tile (a layer of
// litter_tiles, repeated every layer_tile_m[layer] m), nearest with at
// most two mips (§AG). Per patch (INSTANCE_CUSTOM): r its litter (kg/m2),
// g where it is in its rotting (0-4, the data/litter.json stages,
// mass-weighted), b its layer, a a seed.
//
// Shape: ragged at the edge (a noisy radius), a scatter of leaves over
// bare ground where the litter is thin and solid where it is deep, and
// past a few cm a low mound (up to max_raise_m) in the middle.
//
// Rotting (the same transform as tools/look/make_plant_tiles.py's
// litter_stage preview): each stage pulls the tile toward stage_to.rgb by
// stage_to.a, multiplies its HSV saturation and value (stage_svhh.x, .y),
// shows soil through the shared holes mask (litter_holes.png) for a share
// of its texels (.z) and scales the pile's height (.w); a patch between
// two stages blends them.
//
// Colours are raw values, like the species tiles and every vertex colour
// here.
shader_type spatial;
render_mode cull_back, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"
#include "res://shaders/palette.gdshaderinc"

uniform sampler2DArray litter_tiles : filter_nearest_mipmap, repeat_enable;
uniform sampler2D holes_tex : filter_nearest, repeat_enable;
uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform float layer_tile_m[48];
uniform float max_raise_m = 0.25;
uniform float cm_per_kg_m2 = 6.0;
uniform vec4 stage_to[5];
uniform vec4 stage_svhh[5];
const vec3 SOIL = vec3(0.16, 0.12, 0.08);

varying vec2 wuv;
varying float r_edge;
varying float v_mass;
varying float v_stage;
varying float v_layer;
varying vec3 world_pos;

float stage_height(float s) {
	int a = int(floor(s));
	int b = min(a + 1, 4);
	return mix(stage_svhh[a].w, stage_svhh[b].w, fract(s));
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 stage_apply(vec3 c, int s) {
	c = mix(c, stage_to[s].rgb, stage_to[s].a);
	vec3 h = rgb2hsv(c);
	h.y = min(h.y * stage_svhh[s].x, 1.0);
	h.z = min(h.z * stage_svhh[s].y, 1.0);
	return hsv2rgb(h);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec2 q = VERTEX.xz * 2.0;
	float r = length(q);
	v_mass = INSTANCE_CUSTOM.r;
	v_stage = clamp(INSTANCE_CUSTOM.g, 0.0, 4.0);
	v_layer = INSTANCE_CUSTOM.b;
	float depth_m = v_mass * cm_per_kg_m2 * 0.01 * stage_height(v_stage);
	VERTEX.y += clamp(depth_m - 0.03, 0.0, max_raise_m) * (1.0 - smoothstep(0.25, 1.0, r));
	float patch_m = length(MODEL_MATRIX[0].xyz);
	wuv = VERTEX.xz * patch_m + INSTANCE_CUSTOM.a * 17.0;
	r_edge = r;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	int layer = int(v_layer + 0.5);
	vec2 uv = wuv / max(layer_tile_m[layer], 0.1);
	vec2 st = uv * 32.0;
	vec2 dx = dFdx(st);
	vec2 dy = dFdy(st);
	float lod = clamp(0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-8)), 0.0, look_max_mips);
	vec3 tile = textureLod(litter_tiles, vec3(uv, float(layer)), lod).rgb;
	int s0 = int(floor(v_stage));
	int s1 = min(s0 + 1, 4);
	float f = fract(v_stage);
	vec3 c = mix(stage_apply(tile, s0), stage_apply(tile, s1), f);
	// Holes (skeletonised leaves): soil shows through the shared mask.
	float holes = mix(stage_svhh[s0].z, stage_svhh[s1].z, f);
	vec2 texel = floor(st);
	if (holes > 0.0 && texture(holes_tex, uv).r > 0.5 && hash2(texel + 3.7) < holes * 2.0) {
		c = SOIL;
	}
	// Thin litter is a scatter of leaves (a few texels each); deep litter
	// covers the ground. The edge is ragged.
	float cm = v_mass * cm_per_kg_m2;
	float cover = clamp(cm / 1.5, 0.12, 1.0);
	float leaf_cell = hash2(floor(st / 5.0) + float(layer) * 7.1);
	float n = texture(look_grain_soft, wuv * 0.21).r;
	float edge = 1.0 - smoothstep(0.62, 0.98, r_edge + (n - 0.5) * 0.6);
	ALPHA = step(leaf_cell, cover) * step(0.5, edge);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	float nk = look_night;
	c = pal_pull(c, pal_bark_night, 0.6 * nk);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

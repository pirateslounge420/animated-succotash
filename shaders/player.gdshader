// The player's body (PlayerBody, the wanderer): vertex-lit like the
// creatures (Lambert, no specular, Look's fog) over vertex colors that
// carry each part's color and its baked creases, with a coarse painted
// mottling everywhere and Look's weave on the cloth: R1's crunchy texture
// on smooth rounded shapes.
//
// UV.x is the material: 0 leather (gloves, boots, satchel, belt), 1 cloth
// (cloak, sleeves, hood, tunic, trousers), 2 the rust trim, 3 the hood's
// hollow, which no light reaches: a flat deep indigo (R1a: nothing pure
// black), whatever the light, so the face is never seen.
//
// `cloth`: the cloak. Its mesh is a sheet in grid space (UV2: column,
// row); the vertex stage lays it through the simulated points
// (cloak_nodes, ROWS x COLS, body space, from PlayerBody._simulate()) as
// a Catmull-Rom surface, offset along its normal by CUSTOM0.x (half the
// cloth's thickness plus the fold), the normal tilted by the fold's slope
// (CUSTOM0.z). CUSTOM0.y: +1 the outer face, -1 the lining, 2 the hem's
// edge, 3 and 4 the right and left front edges. Texture space is the
// grid, so the weave stays put on the moving cloth.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"
#include "res://shaders/prelit.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_weave : filter_nearest_mipmap, repeat_enable;
uniform vec3 hollow_color = vec3(0.0042, 0.0048, 0.028);
uniform bool cloth = false;
// A cloaked figure other than the player (CloakedFigure; the Falcon /
// Ganondorf rule: one body, a palette per person): the cloth recolored to
// `main_color` and the trim to `trim_color`, each keeping its shading
// (the vertex's brightness against the player's cloak or rust). Linear.
uniform bool recolor = false;
uniform vec3 main_color = vec3(0.016, 0.023, 0.15);
uniform vec3 trim_color = vec3(0.37, 0.06, 0.024);
uniform float base_lum = 0.03;
uniform float trim_lum = 0.12;

const int COLS = 16;
const int ROWS = 8;
uniform vec3 cloak_nodes[128];

varying vec3 tex_pos;
varying vec3 tex_nrm;
varying vec3 world_pos;

vec3 node(int r, int c) {
	return cloak_nodes[r * COLS + c];
}

// A grid point, extended past the edges in a straight line.
vec3 node_row(int r, int c) {
	int rc = clamp(r, 0, ROWS - 1);
	vec3 p = node(rc, c);
	if (r != rc) {
		p = 2.0 * p - node(rc + (r < 0 ? 1 : -1), c);
	}
	return p;
}

vec3 node_ex(int r, int c) {
	int cc = clamp(c, 0, COLS - 1);
	vec3 p = node_row(r, cc);
	if (c != cc) {
		p = 2.0 * p - node_row(r, cc + (c < 0 ? 1 : -1));
	}
	return p;
}

vec4 cr_w(float t) {
	float t2 = t * t;
	float t3 = t2 * t;
	return vec4(-0.5 * t3 + t2 - 0.5 * t, 1.5 * t3 - 2.5 * t2 + 1.0, -1.5 * t3 + 2.0 * t2 + 0.5 * t, 0.5 * t3 - 0.5 * t2);
}

vec4 cr_dw(float t) {
	float t2 = t * t;
	return vec4(-1.5 * t2 + 2.0 * t - 0.5, 4.5 * t2 - 5.0 * t, -4.5 * t2 + 4.0 * t + 0.5, 1.5 * t2 - t);
}

void vertex() {
	if (cloth) {
		vec2 g = UV2;
		int c0 = clamp(int(floor(g.x)), 0, COLS - 2);
		int r0 = clamp(int(floor(g.y)), 0, ROWS - 2);
		float tu = g.x - float(c0);
		float tv = g.y - float(r0);
		vec4 wu = cr_w(tu);
		vec4 dwu = cr_dw(tu);
		vec4 wv = cr_w(tv);
		vec4 dwv = cr_dw(tv);
		vec3 s = vec3(0.0);
		vec3 su = vec3(0.0);
		vec3 sv = vec3(0.0);
		for (int j = 0; j < 4; j++) {
			vec3 rp = vec3(0.0);
			vec3 rd = vec3(0.0);
			for (int i = 0; i < 4; i++) {
				vec3 p = node_ex(r0 - 1 + j, c0 - 1 + i);
				rp += wu[i] * p;
				rd += dwu[i] * p;
			}
			s += wv[j] * rp;
			su += wv[j] * rd;
			sv += dwv[j] * rp;
		}
		vec3 n = normalize(cross(su, sv));
		float mode = CUSTOM0.y;
		VERTEX = s + n * CUSTOM0.x;
		if (mode > 3.5) {
			NORMAL = normalize(su);
		} else if (mode > 2.5) {
			NORMAL = -normalize(su);
		} else if (mode > 1.5) {
			NORMAL = normalize(sv);
		} else {
			vec3 tilted = normalize(n - CUSTOM0.z * su / max(dot(su, su), 1e-6));
			NORMAL = tilted * sign(mode);
		}
		tex_pos = vec3(g.x * 0.13, g.y * 0.17, 0.0);
		tex_nrm = vec3(0.0, 0.0, 1.0);
	} else {
		tex_pos = VERTEX;
		tex_nrm = NORMAL;
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Projected from the side the surface faces (part space; the cloak's
// grid is flat, so it takes the first).
vec3 tri(sampler2D tex, float scale) {
	vec3 n = abs(tex_nrm);
	n = n * n;
	vec3 a = texture(tex, tex_pos.xy * scale).rgb;
	vec3 b = texture(tex, tex_pos.zy * scale).rgb;
	vec3 c = texture(tex, tex_pos.xz * scale).rgb;
	return (a * n.z + b * n.x + c * n.y) / (n.x + n.y + n.z);
}

void fragment() {
	int kind = int(round(UV.x));
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (kind == 3) {
		ALBEDO = vec3(0.0);
		EMISSION = hollow_color;
	} else {
		// Textures are gray around 0.5 (no change); `k` is how strongly
		// each material shows its texture.
		vec3 t;
		float k;
		// (2.6 and 3.2 repeats a metre until design 6 Oct §ES.2: a 64-px
		// weave at that is ~170-200 texels a metre, finer than a 270-line
		// pixel past a metre or two, and it crawled; ~32 now, about one
		// texel a pixel at walking distance.)
		if (kind == 1) {
			t = tri(look_tex_weave, 0.5);
			k = 1.0;
		} else if (kind == 2) {
			t = tri(look_tex_weave, 0.5);
			k = 0.6;
		} else {
			t = vec3(texture(look_grain_soft, (tex_pos.xy + tex_pos.zy) * 9.0).r);
			k = 0.45;
		}
		// Broad painted mottling over everything.
		float g = texture(look_grain_soft, (tex_pos.xy * 1.3 + tex_pos.zy * 1.7) * 2.2).r;
		vec3 base = COLOR.rgb;
		if (recolor && kind > 0) {
			float l = dot(base, vec3(0.2126, 0.7152, 0.0722));
			if (kind == 1) {
				// The whole outfit in the main color's family: the cloak
				// itself, the tunic and trousers lighter or darker as they were.
				base = main_color * clamp(l / base_lum, 0.25, 2.2);
			} else {
				base = trim_color * clamp(l / trim_lum, 0.3, 1.6);
			}
		}
		ALBEDO = base * mix(vec3(1.0), t * 2.0, k) * (0.7 + 0.6 * g);
	}
	// Pre-lit (design §ES.2): the painted light, from the sky above.
	ALBEDO = prelit_paint(ALBEDO, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

#include "res://shaders/prelit_light.gdshaderinc"

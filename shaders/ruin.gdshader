// Ruins (RuinBuilder): stone blocks, timber, snow blocks, thatch and hide,
// vertex-lit (Lambert, no specular, Look) with Look's textures mapped per
// face. UV.x is the material (RuinBuilder: 0 stone, 1 wood, 2 snow,
// 3 thatch, 4 leaves, 5 hide); UV.y the lichen in the stone (§DI,
// Overgrowth). Vertex alpha is moss: at night, near
// glowing sites (every ruin is one), the moss patches shine teal/cobalt.
// Stone colors come from RuinBuilder's palettes (R1a: blue-grey #6F7A8A);
// after dark stone, timber and moss cool toward their R1a night targets
// (palette.gdshaderinc). The vertex colours carry the contact shade
// (RuinBuilder._contact, look.json cavity: dark at the feet of walls and
// stones, under every block, inside towers and doorways); the stone is
// Look's cracked-slab tile at 16 texels a metre.
shader_type spatial;
render_mode cull_disabled, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"
#include "res://shaders/prelit.gdshaderinc"
#include "res://shaders/palette.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
// Look's detail tiles, nearest with at most two mips (§AG, retro_tex).
uniform sampler2D look_tex_stone : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_leaves : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_bark : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_grass : filter_nearest_mipmap, repeat_enable;

// Glow-moss (design §FG, GlowMoss; the crawler only, 0 patches anywhere
// else): glow_moss_count patches in glow_moss_data, row 0 a patch's middle
// (xyz, in the stone's own space: the tomb stands at the origin) and its
// radius, row 1 its wall's normal and its glow now. Colour linear.
// glow_moss_light: x how far its faint light reaches past the patch (m),
// y how strong that light is on the stone against the glow itself.
uniform sampler2D glow_moss_data : filter_nearest;
uniform int glow_moss_count = 0;
uniform vec3 glow_moss_color = vec3(0.05, 0.52, 0.36);
uniform vec2 glow_moss_light = vec2(0.9, 4.0);

varying vec3 world_pos;
varying vec3 obj_pos;
varying vec3 obj_normal;

// The glow-moss at `p` (normal `nrm`; `uv` the planar map on `axes`: 0 xz,
// 1 zy, 2 xy), where the moss tile reads `moss_v` (0-1), on stone of
// colour `albedo`: rgb its light, a how much of this texel is the patch's
// own moss (0 or 1). Worked out at the middle of the moss texel there, at
// the mip it's drawn at, so the patch keeps the moss's own texels: a texel
// is moss, and glows, where the moss tile is brighter than the patch's
// share asks (thickest at its heart, ragged at its rim); its light falls on
// the stone and floor round it, stepped texel by texel, never behind its
// wall.
vec4 glow_moss(vec3 p, vec3 nrm, vec2 uv, int axes, float moss_v, vec3 albedo) {
	vec2 tsz = vec2(textureSize(look_tex_leaves, 0));
	vec2 st = uv / look_tile_m2.y * tsz;
	vec2 dx = dFdx(st);
	vec2 dy = dFdy(st);
	float lod = clamp(floor(0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-8))), 0.0, look_max_mips);
	float tpm = tsz.x / look_tile_m2.y / exp2(lod);
	vec2 mid = (floor(uv * tpm) + 0.5) / tpm;
	vec3 q = p;
	if (axes == 0) {
		q.xz = mid;
	} else if (axes == 1) {
		q.zy = mid;
	} else {
		q.xy = mid;
	}
	vec3 e = vec3(0.0);
	float cover = 0.0;
	for (int i = 0; i < 64; i++) {
		if (i >= glow_moss_count) {
			break;
		}
		vec4 c = texelFetch(glow_moss_data, ivec2(i, 0), 0);
		float reach = c.w + glow_moss_light.x;
		float d = distance(q, c.xyz);
		if (d > reach) {
			continue;
		}
		vec4 m = texelFetch(glow_moss_data, ivec2(i, 1), 0);
		// Nothing behind the patch's own wall (its joints are a hand back).
		float front = step(-0.12, dot(q - c.xyz, m.xyz));
		// The patch: the moss's texels on its wall, by their brightness.
		float share = 1.0 - smoothstep(0.3 * c.w, c.w, d);
		float on = step(1.0 - 0.85 * share, moss_v) * step(0.04, share) * smoothstep(0.25, 0.6, dot(nrm, m.xyz)) * front;
		cover = max(cover, on);
		e += glow_moss_color * m.w * on;
		// Its faint light, from a hand off the wall.
		vec3 to = c.xyz + m.xyz * 0.15 - q;
		float ndl = dot(nrm, normalize(to));
		float k = 1.0 - clamp(length(to) / reach, 0.0, 1.0);
		e += albedo * glow_moss_color * m.w * glow_moss_light.y * k * k * (ndl > 0.0 ? 0.35 + 0.65 * ndl : 0.0) * front;
	}
	return vec4(e, cover);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

void fragment() {
	vec3 an = abs(obj_normal);
	vec2 uv = an.y > 0.6 ? obj_pos.xz : (an.x > an.z ? obj_pos.zy : obj_pos.xy);
	// Cracked stone tiled every look_tile_m.w, turning leafy where moss grows
	// (vertex alpha), with soft weathering: patches of light and dark a
	// meter or two across.
	int kind = int(round(UV.x));
	vec3 surface;
	if (kind == 1) {
		// Timber: grain runs along the face's longer way.
		surface = retro_tile(look_tex_bark, uv / look_tile_m2.x).rgb;
	} else if (kind == 2) {
		// Packed snow: a faint grain, cool and bright.
		surface = mix(vec3(0.5), retro_tile(look_tex_stone, uv / look_tile_m.w).rgb, 0.3) * vec3(0.97, 1.0, 1.04);
	} else if (kind == 3) {
		surface = retro_tile(look_tex_grass, uv / look_tile_m.x).rgb;
	} else if (kind == 4) {
		surface = retro_tile(look_tex_leaves, uv / look_tile_m2.y).rgb;
	} else if (kind == 5) {
		surface = vec3(0.45 + 0.1 * texture(look_grain_soft, uv * 1.5).r);
	} else if (kind == 6) {
		// Fitted stone (the dungeon's walls, FittedStone, Mike 6 Oct): the
		// joints are real geometry now, so the stone's grain without the
		// tile's painted cracks: the stone tile large and soft, and a fleck
		// on the 16-a-metre grid.
		vec2 tg6 = floor(uv * 16.0) + 0.5;
		float fl6 = fract(sin(dot(tg6, vec2(12.9898, 78.233))) * 43758.5453);
		surface = mix(vec3(0.5), retro_tile(look_tex_stone, uv / (look_tile_m.w * 2.3)).rgb, 0.3) * (0.94 + 0.12 * fl6);
	} else {
		surface = retro_tile(look_tex_stone, uv / look_tile_m.w).rgb;
	}
	// Lichen (design 3 Oct §DI, UV.y: the ruin's lichen column): pale
	// flecks painted into the stone's own tile at its 16 texels a metre
	// (look R9: detail in the albedo, matte, never an overlay), patchy
	// over a metre or two; grey-green with a few ochre ones.
	float lich = UV.y;
	if (kind == 0 && lich > 0.001) {
		vec2 tg = floor(uv * 16.0) + 0.5;
		float speck = fract(sin(dot(tg, vec2(12.9898, 78.233))) * 43758.5453);
		float blot = texture(look_grain_soft, tg / 16.0 * 0.55 + 0.31).r;
		float fleck = step(1.0 - lich, blot * 0.75 + speck * 0.25 + (lich - 0.5) * 0.1);
		vec3 tint = speck > 0.85 ? vec3(0.8, 0.66, 0.38) : vec3(0.72, 0.75, 0.55);
		surface = mix(surface, tint * (0.92 + 0.16 * speck), fleck);
	}
	vec3 moss = retro_tile(look_tex_leaves, uv / look_tile_m2.y).rgb;
	float weather = texture(look_grain_soft, uv * 0.12 + 0.5).r - 0.5;
	// R1a: greens toward moss; at night stone to slate, timber to deep blue,
	// moss to teal.
	vec3 col = COLOR.rgb;
	float gw = pal_greenness(col);
	// A lit village (§EE.1): its hearths ease the night's blue pull here.
	float nk = look_night * (1.0 - look_warm(world_pos));
	col = pal_pull(col, pal_moss, 0.5 * gw); // moss, ivy and turf toward R1a moss
	if (kind == 0 || kind == 6) {
		col = pal_pull(col, pal_stone_night, 0.75 * nk * (1.0 - gw));
	} else if (kind == 1) {
		col = pal_pull(col, pal_bark_night, 0.6 * nk * (1.0 - gw));
	}
	col = pal_pull(col, pal_grass_night, 0.7 * nk * gw);
	ALBEDO = col * mix(surface, moss, clamp(COLOR.a * 1.2, 0.0, 1.0) * (kind == 0 || kind == 1 || kind == 6 ? 1.0 : 0.0)) * 2.0 * (1.0 + weather * 0.45);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float patch = texture(look_grain_soft, uv * 0.06).r; // moss patches ~0.5-2 m
	// Patches only (heavy moss on wet ruins shouldn't light whole walls).
	float glow = look_site_glow(world_pos, 0.0) * min(COLOR.a, 0.6) * smoothstep(0.58, 0.72, patch);
	EMISSION = look_glow_emission(world_pos, glow * 1.3) + look_warm_pool_light(world_pos);
	if (glow_moss_count > 0) {
		vec4 gm = glow_moss(obj_pos, normalize(obj_normal), uv, an.y > 0.6 ? 0 : (an.x > an.z ? 1 : 2), dot(moss, vec3(0.3333)), ALBEDO);
		// The patch is moss: its texels take the moss's colour (R1a).
		ALBEDO = mix(ALBEDO, pal_moss * moss * 2.0, gm.a * 0.6);
		EMISSION += gm.rgb;
	}
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
	// Pre-lit (design §ES.2): the painted light, from the sky above.
	ALBEDO = prelit_paint(ALBEDO, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

#include "res://shaders/prelit_light.gdshaderinc"

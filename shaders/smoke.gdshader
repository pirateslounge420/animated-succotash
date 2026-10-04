// A column of smoke (design 3 Oct §CV, data/smoke.json): over a lit hearth,
// out of a stack, or a wildfire's plume. The flame's family (§BZ): a few
// camera-facing cards (Smoke builds `look.cards` of them round the column's
// spine, each its own phase), noise scrolled upward and posterised to
// three flat bands on a coarse texel grid, cut out by a 4x4 dither, no soft
// alpha. Pale blue-grey (colour_near) with a shaded side (colour_shade),
// lighter and bluer with distance (colour_far), never a neutral grey.
//
// Each card is a strip of quads, x -0.5..0.5 across, y 0..1 up (Smoke's
// mesh). The vertex stage lays it in the world (world_vertex_coords): up
// the fire's own up from `base`, `top_m` tall and `width_m` wide at the
// foot, widening as it climbs, leaning along `lean` (metres sideways per
// metre up, the weather's wind, more toward the top by `shear`), turned
// to face the camera about the column. `pool` (0-1): on a still dawn the
// smoke stops rising at pool_m and spreads pool_spread_m flat. `density`
// (0-1) is how solid it draws (the fire's state, rain); `night` (0-1)
// hides all but the first fire_lit_m, lit warm by the fire (smoke gives
// off no light).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, world_vertex_coords;

#include "res://shaders/look.gdshaderinc"
global uniform vec3 plant_wind;
#include "res://shaders/wind.gdshaderinc"

uniform sampler2D look_grain_soft : filter_nearest, repeat_enable;
uniform vec3 base = vec3(0.0);
uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 lean = vec3(0.0);
uniform float shear = 1.5;
uniform float top_m = 60.0;
uniform float width_m = 4.0;
uniform float density = 1.0;
uniform float pool = 0.0;
uniform float pool_m = 18.0;
uniform float pool_spread_m = 90.0;
uniform float night = 0.0;
uniform float fire_lit_m = 8.0;
uniform float rise_mps = 1.2;
uniform vec2 texels = vec2(16.0, 24.0);
uniform vec3 colour_near = vec3(0.27, 0.35, 0.58);
uniform vec3 colour_far = vec3(0.45, 0.54, 0.81);
uniform vec3 colour_shade = vec3(0.1, 0.14, 0.35);
uniform vec3 fire_lit = vec3(0.9, 0.35, 0.12);
uniform float far_m = 3200.0;
// The wind on it (design §DA, wind.json smoke): below shelter_m (the
// crowns over a hearth under trees) it rises straight; above, its lean
// follows the gust field at each height, not only the mean; `gust` is the
// field's factor at the fire, which shreds the cards near it.
uniform float shelter_m = 0.0;
uniform float gust = 1.0;
instance uniform float card_phase = 0.0;
instance uniform float card_off = 0.0;

varying vec2 v_uv;
varying float v_h;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void vertex() {
	float y = VERTEX.y;
	float h = y * top_m;
	// Pooling: the top of a calm dawn's smoke lies flat at pool_m.
	float hp = mix(h, min(h, pool_m) + max(h - pool_m, 0.0) * 0.08, pool);
	float w = width_m * (0.55 + 1.6 * y) + pool * smoothstep(pool_m * 0.6, pool_m, h) * pool_spread_m * y;
	vec3 up = normalize(up_dir);
	// Straight up through the crowns, then leaning with the gust there.
	float lh = max(hp - shelter_m, 0.0);
	float g = wind_gust_field(base + up * hp, length(plant_wind)).x;
	vec3 spine = base + up * hp + lean * lh * (1.0 + shear * y * y) * g;
	vec3 to_cam = CAMERA_POSITION_WORLD - spine;
	vec3 right = cross(up, to_cam);
	right = length(right) > 1e-4 ? normalize(right) : vec3(1.0, 0.0, 0.0);
	VERTEX = spine + right * (VERTEX.x + card_off) * w;
	v_uv = vec2(UV.x, y);
	v_h = hp;
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The texel grid; the noise climbs in whole rows.
	vec2 q = (floor(v_uv * texels) + 0.5) / texels;
	float raw = TIME * rise_mps / max(top_m, 1.0) + card_phase;
	float t1 = floor(raw * texels.y) / texels.y;
	float n1 = texture(look_grain_soft, vec2(q.x * 0.7 + card_phase, (q.y - t1) * 0.8)).r;
	float n2 = texture(look_grain_soft, vec2(q.x * 1.6 - card_phase, (q.y - t1 * 1.7) * 1.9)).r;
	float n = n1 * 0.65 + n2 * 0.35;
	// The column's body: solid in the middle, ragged at its sides and top.
	float x = abs(q.x * 2.0 - 1.0);
	float body = (1.0 - smoothstep(0.35, 1.0, x + (n - 0.5) * 0.6)) * (1.0 - smoothstep(0.55, 1.0, q.y + (n - 0.5) * 0.4));
	body *= smoothstep(0.0, 0.05, q.y);
	float a = body * density * (0.55 + 0.6 * n);
	// At night only the first fire_lit_m, lit by the fire below.
	a *= mix(1.0, 1.0 - smoothstep(fire_lit_m * 0.5, fire_lit_m, v_h), night);
	// A gust at the fire tears the low column into rags.
	float shred = smoothstep(1.15, 1.5, gust) * (1.0 - smoothstep(4.0, 14.0, v_h));
	a *= 1.0 - shred * step(0.45, n2);
	if (a < bayer4(FRAGCOORD.xy)) {
		discard;
	}
	// Three flat bands: the shaded side, the body, the lit edge.
	float dist = distance(world_pos, CAMERA_POSITION_WORLD);
	vec3 near_c = mix(colour_near, colour_far, smoothstep(far_m * 0.15, far_m, dist));
	float shade = n * 0.7 + (1.0 - x) * 0.3;
	vec3 c = shade > 0.62 ? mix(near_c, colour_far, 0.35) : (shade > 0.38 ? near_c : mix(colour_shade, near_c, 0.35));
	// By day the sky lights it; at night only the fire does, near its foot.
	c *= mix(1.0, 0.0, night);
	c += fire_lit * night * (1.0 - smoothstep(0.0, fire_lit_m, v_h)) * 0.6;
	ALBEDO = c;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

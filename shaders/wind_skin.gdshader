// A streaming skin over the ground in a gust (design 3 Oct §DA point 4,
// data/wind.json litter.kinds: sand, snow, dust; WindLitter): a low
// ground-level card whose streaks scroll downwind with the gusted wind
// there, cut out by the 4x4 dither (no soft alpha), lit like the ground
// (it gives off no light). skin_alpha: how far the gust is past the
// kind's from_mps (0-1); skin_wind: that gust (m/s, world).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, vertex_lighting, shadows_disabled;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform vec3 skin_color : source_color = vec3(0.86, 0.78, 0.58);
uniform float streak = 0.55;
instance uniform float skin_alpha = 0.0;
instance uniform vec3 skin_wind = vec3(0.0);

varying vec2 v_flow;
varying vec3 v_world;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[x + y * 4]) + 0.5) / 16.0;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 lw = (inverse(MODEL_MATRIX) * vec4(skin_wind, 0.0)).xyz;
	v_flow = lw.xz;
}

void fragment() {
	vec2 local = (UV - 0.5) * 8.0;
	float s = length(v_flow);
	vec2 along = s > 0.01 ? v_flow / s : vec2(1.0, 0.0);
	vec2 across = vec2(-along.y, along.x);
	// Streaks: noise stretched along the wind, scrolling at most of its
	// speed, on a 16 px-a-metre grid.
	vec2 q = vec2(dot(local, along), dot(local, across));
	q = floor(q * 16.0) / 16.0;
	float n = texture(look_grain_soft, vec2((q.x - TIME * s * 0.7) * 0.06, q.y * 0.9)).r;
	float n2 = texture(look_grain_soft, vec2((q.x - TIME * s * 0.9) * 0.15 + 0.37, q.y * 2.3)).r;
	float a = smoothstep(1.0 - streak, 1.0, n * 0.7 + n2 * 0.5) * skin_alpha;
	// Fade toward the card's edge so the patches join without seams.
	a *= 1.0 - smoothstep(2.6, 4.0, length(local));
	if (a < bayer4(FRAGCOORD.xy) * 0.9 + 0.05) {
		discard;
	}
	ALBEDO = skin_color * 0.8;
	FOG = look_fog(v_world, CAMERA_POSITION_WORLD);
}

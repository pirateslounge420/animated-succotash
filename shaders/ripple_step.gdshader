// One step of the water ripple simulation (RippleSim): a damped wave
// equation on the ripple height buffer, drawn into one of two SubViewports
// that take turns (ping-pong), each reading the other's last state.
//
// State per texel: surface height h (m, + up) and its vertical speed v
// (m/s), each packed as a signed 16-bit number into two 8-bit channels
// (RG = h, BA = v), because 2D render targets are 8 bits per channel in
// every renderer (and exact: no filtering, no color conversion). All-zero
// bytes decode to a flat, still surface, so a cleared buffer is calm.
//
// Each step:
//   * the window may have moved with the camera by whole texels (`shift`):
//     texel p now holds what texel p + shift held, and water coming in
//     from outside is calm;
//   * waves spread: v += dt * c^2 * laplacian(h), then v is damped, and a
//     weak spring pulls h back to the flat level (so no dent stays);
//   * contacts kick v down at their footprint (`stamps`, one line segment
//     each: a splash is a point, a wake the segment its body moved along
//     this step), with a zero-sum profile: pushed down under the body,
//     up around it, as displaced water is;
//   * rain: the window is cut into cells of `rain_cell` texels; each may
//     take a drop this step (chance `rain_p`) at a random spot in it, a
//     small zero-sum kick of `rain_radius` texels (each texel checks its
//     own cell and the eight around it);
//   * h += v * dt, with a little smoothing against grid noise, and a
//     sponge at the window's border so rings leave it instead of
//     bouncing back.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D state : filter_nearest, repeat_disable;
uniform int size = 256;
uniform ivec2 shift = ivec2(0);
uniform float dt = 0.0333;
// dt * (c / texel)^2, per texel-unit laplacian.
uniform float c2_dt = 0.1;
// exp(-damping * dt) and dt * flatten.
uniform float damping = 0.98;
uniform float flatten_dt = 0.01;
// 1 - exp(-smoothing * dt): pull toward the neighbours' mean.
uniform float smoothing = 0.05;
uniform float edge_texels = 20.0;
uniform bool reset = false;
// Stamps: a = (start.xy, end.xy) in texels of this step's window; b.x =
// footprint radius (texels), b.y = downward kick (m/s) at the center,
// b.z = how line-like the profile is (0 point, 1 long segment).
const int MAX_STAMPS = 32;
uniform vec4 stamp_a[MAX_STAMPS];
uniform vec4 stamp_b[MAX_STAMPS];
uniform int stamp_count = 0;
uniform float rain_p = 0.0;
uniform float rain_push = 0.0;
uniform int rain_cell = 4;
uniform float rain_radius = 1.5;
// Changes every step; `origin` is the window's absolute texel origin, so
// drops keep to cells fixed on the water as the window moves.
uniform uint seed = 0u;
uniform ivec2 origin = ivec2(0);

const float H_RANGE = 0.5; // m
const float V_RANGE = 4.0; // m/s

float unpack16(vec2 b, float range) {
	float n = floor(b.x * 255.0 + 0.5) * 256.0 + floor(b.y * 255.0 + 0.5);
	return (n >= 32768.0 ? n - 65536.0 : n) / 32767.0 * range;
}

// Rounded toward zero, so tiny values die out instead of lingering.
vec2 pack16(float x, float range) {
	float q = clamp(x / range, -1.0, 1.0) * 32767.0;
	q = sign(q) * floor(abs(q));
	float n = q < 0.0 ? q + 65536.0 : q;
	float hi = floor(n / 256.0);
	return vec2(hi, n - hi * 256.0) / 255.0;
}

// (h, v) of the last state at texel p; calm outside the window.
vec2 cell(ivec2 p) {
	if (p.x < 0 || p.y < 0 || p.x >= size || p.y >= size) {
		return vec2(0.0);
	}
	vec4 t = texture(state, (vec2(p) + 0.5) / float(size));
	return vec2(unpack16(t.rg, H_RANGE), unpack16(t.ba, V_RANGE));
}

float hash(uvec3 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	v ^= v >> 16u;
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	return float(v.x >> 8u) / 16777216.0;
}

void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy);
	if (reset) {
		COLOR = vec4(0.0);
	} else {
		ivec2 q = p + shift;
		vec2 c = cell(q);
		float hn = cell(q + ivec2(0, -1)).x;
		float hs = cell(q + ivec2(0, 1)).x;
		float he = cell(q + ivec2(1, 0)).x;
		float hw = cell(q + ivec2(-1, 0)).x;
		float around = hn + hs + he + hw;
		float v = (c.y + c2_dt * (around - 4.0 * c.x) - flatten_dt * c.x) * damping;

		vec2 fp = vec2(p);
		for (int i = 0; i < MAX_STAMPS; i++) {
			if (i >= stamp_count) {
				break;
			}
			vec4 a = stamp_a[i];
			vec4 b = stamp_b[i];
			vec2 ab = a.zw - a.xy;
			float t = clamp(dot(fp - a.xy, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
			vec2 d = fp - a.xy - ab * t;
			float u = dot(d, d) / (b.x * b.x);
			if (u < 9.0) {
				// Zero-sum: down in the middle, up in a ring round it (the
				// 1D form across a long wake, the 2D form round a point).
				v -= b.y * (1.0 - mix(1.0, 2.0, b.z) * u) * exp(-u);
			}
		}
		if (rain_p > 0.0) {
			ivec2 ap = p + origin;
			ivec2 home = ivec2(floor(vec2(ap) / float(rain_cell)));
			float r2 = rain_radius * rain_radius;
			for (int j = -1; j <= 1; j++) {
				for (int i = -1; i <= 1; i++) {
					ivec2 cc = home + ivec2(i, j);
					uvec3 key = uvec3(uvec2(cc + ivec2(40000)), seed);
					if (hash(key) < rain_p) {
						vec2 at = (vec2(cc) + vec2(hash(key + uvec3(0u, 0u, 7919u)), hash(key + uvec3(0u, 0u, 104729u)))) * float(rain_cell);
						vec2 d = vec2(ap) - at;
						float u = dot(d, d) / r2;
						if (u < 9.0) {
							v -= rain_push * (1.0 - u) * exp(-u);
						}
					}
				}
			}
		}

		float h = c.x + v * dt;
		h = mix(h, around * 0.25, smoothing);
		// The sponge along the border.
		float e = min(min(fp.x, fp.y), min(float(size - 1) - fp.x, float(size - 1) - fp.y));
		float soak = 1.0 - smoothstep(0.0, edge_texels, e);
		float keep = 1.0 - 0.18 * soak * soak;
		COLOR = vec4(pack16(h * keep, H_RANGE), pack16(v * keep, V_RANGE));
	}
}

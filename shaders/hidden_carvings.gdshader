shader_type spatial;
// The Aztec temple's hidden carvings (design §FN.5, queue 83; HiddenCarvings):
// marks cut into the stone that sober eyes miss, drawn only while the brew's
// vision runs. Unshaded: the glow is the paint's own, it casts no light and
// nothing reads it (visions.json rule.kept_inside.glow_is_not_light). Each
// panel's kind and seed are per instance:
//   kind 0     glyph cells: a 5 x 5 block glyph mirrored across its middle
//              (the day-sign panels' own grammar), the cells multiplying and
//              changing while the brew lasts
//   kind 1..4  the picture-history (placeholders; Claude (chat) writes the
//              story later): 1 footprints walking (a codex's journey),
//              2 reeds standing in water, 3 a stepped temple with its stair,
//              4 a rayed disc (no face: nothing is added that is not stone)
// The geometry breathes: the panel's lines swell and ease on a slow wave.
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled, depth_prepass_alpha;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float t = 0.0;
uniform vec3 stone : source_color = vec3(0.43, 0.23, 0.19);
uniform vec3 glow : source_color = vec3(0.5, 1.0, 0.82);
uniform float glow_amount = 0.75;
uniform float breathe = 0.05;
uniform float breathe_hz = 0.12;
uniform float change_s = 2.5;
uniform float cells_max = 3.0;
instance uniform float kind = 0.0;
instance uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A 5 x 5 glyph mirrored across its middle column, from `s`; `q` in 0..1.
float glyph(vec2 q, float s) {
	if (q.x < 0.08 || q.x > 0.92 || q.y < 0.08 || q.y > 0.92) {
		return 0.0;
	}
	vec2 g = (q - 0.08) / 0.84 * 5.0;
	vec2 c = floor(g);
	float col = c.x > 2.0 ? 4.0 - c.x : c.x;
	float on = step(0.45, hash(vec2(col, c.y) + s * 17.0));
	if (col == 2.0 && c.y == 2.0) {
		on = 1.0;
	}
	vec2 f = fract(g);
	float inside = step(0.1, f.x) * step(f.x, 0.9) * step(0.1, f.y) * step(f.y, 0.9);
	return on * inside;
}

float ring(vec2 p, vec2 c, float r, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.015, abs(length(p - c) - r));
}

float disc(vec2 p, vec2 c, vec2 r) {
	return 1.0 - smoothstep(0.9, 1.05, length((p - c) / r));
}

float box(vec2 p, vec2 lo, vec2 hi) {
	return step(lo.x, p.x) * step(p.x, hi.x) * step(lo.y, p.y) * step(p.y, hi.y);
}

float picture(vec2 p, float k, float sw) {
	float m = 0.0;
	if (k < 1.5) {
		// Footprints walking from one corner to the other.
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			vec2 c = vec2(0.12 + fi * 0.15, 0.25 + fi * 0.1 + (mod(fi, 2.0) - 0.5) * 0.12);
			m = max(m, disc(p, c, vec2(0.035, 0.06) * sw));
			m = max(m, disc(p, c + vec2(0.0, 0.08), vec2(0.02, 0.018) * sw));
		}
	} else if (k < 2.5) {
		// Reeds standing in water: wave lines, upright stems.
		for (int i = 0; i < 3; i++) {
			float y = 0.12 + float(i) * 0.08;
			m = max(m, 1.0 - smoothstep(0.012 * sw, 0.02 * sw, abs(p.y - y - 0.025 * sin(p.x * 25.0))));
		}
		for (int i = 0; i < 7; i++) {
			float x = 0.14 + float(i) * 0.12;
			m = max(m, box(p, vec2(x - 0.01 * sw, 0.3), vec2(x + 0.01 * sw, 0.7 + 0.15 * hash(vec2(float(i), 3.0)))));
			m = max(m, disc(p, vec2(x, 0.82 + 0.1 * hash(vec2(float(i), 3.0))), vec2(0.03, 0.06) * sw));
		}
	} else if (k < 3.5) {
		// A stepped temple, its stair up the middle, a shrine on top.
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float hw = 0.42 - fi * 0.08;
			float y0 = 0.1 + fi * 0.14;
			m = max(m, box(p, vec2(0.5 - hw, y0), vec2(0.5 + hw, y0 + 0.13)) * (1.0 - box(p, vec2(0.5 - hw + 0.02 * sw, y0 + 0.02 * sw), vec2(0.5 + hw - 0.02 * sw, y0 + 0.11))));
		}
		m = max(m, box(p, vec2(0.45, 0.1), vec2(0.55, 0.66)) * step(0.5, fract(p.y * 18.0)));
		m = max(m, box(p, vec2(0.4, 0.68), vec2(0.6, 0.86)));
	} else {
		// A rayed disc.
		vec2 c = vec2(0.5, 0.5);
		m = max(m, ring(p, c, 0.2, 0.04 * sw));
		m = max(m, ring(p, c, 0.1, 0.03 * sw));
		float a = atan(p.y - c.y, p.x - c.x);
		float r = length(p - c);
		float ray = step(0.8, fract(a / 6.2831853 * 8.0 + 0.1)) * step(0.27, r) * step(r, 0.42);
		m = max(m, ray);
	}
	return m;
}

void fragment() {
	vec2 q = UV;
	q.y = 1.0 - q.y;
	float wave = sin(t * 6.2831853 * breathe_hz + seed * 1.7);
	// Breathing: the panel's field swells and eases about its middle.
	q = (q - 0.5) * (1.0 - breathe * wave) + 0.5;
	float m = 0.0;
	if (kind < 0.5) {
		// The cells multiply while the brew lasts (1 x 1 up to cells_max
		// across), and each cell's glyph changes every change_s seconds.
		float n = clamp(floor(1.0 + (cells_max - 1.0) * (0.5 + 0.5 * sin(t * 0.21 + seed))), 1.0, cells_max);
		vec2 g = q * n;
		vec2 c = floor(g);
		float tick = floor(t / max(change_s, 0.1) + hash(c + seed));
		m = glyph(fract(g), seed * 3.1 + c.x * 7.0 + c.y * 13.0 + tick * 0.37);
	} else {
		m = picture(q, kind, 1.0 + 0.4 * wave);
	}
	float pulse = 0.5 + 0.5 * sin(t * 2.3 + seed * 5.0 + (q.x + q.y) * 3.0);
	vec3 col = mix(stone * 0.55, glow, glow_amount * (0.55 + 0.45 * pulse));
	ALBEDO = col;
	ALPHA = m * clamp(reveal, 0.0, 1.0);
}

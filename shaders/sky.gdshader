// Planet sky (DESIGN.md "Visual & Tone References", "Lighting & Day-Night
// Cycle"). All colors and directions are fed each frame by SkySystem, which
// derives them continuously from the sun and moon elevation at the
// player's position. Directions are in world space; `up_dir` is the
// player's local up, since "up" changes as you walk around the planet.
//
// Drawn in flat color bands (N64/PS1 style) rather than a smooth
// gradient: the zenith-to-horizon ramp is stepped, the haze near the
// horizon matches the banded ground fog (fog_color). Clouds are separate
// layers at altitude (CloudLayers).
shader_type sky;

uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 east_dir = vec3(1.0, 0.0, 0.0);
uniform vec3 north_dir = vec3(0.0, 0.0, -1.0);

uniform vec3 zenith_color : source_color = vec3(0.2, 0.5, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.6, 0.85, 1.0);
uniform vec3 ground_color : source_color = vec3(0.2, 0.22, 0.25);
uniform float horizon_sharpness = 2.5;
uniform float sky_bands = 5.0;
uniform vec3 fog_color : source_color = vec3(0.6, 0.8, 1.0);

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_visible = 1.0;

uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 moon_tint : source_color = vec3(0.62, 0.76, 1.0); // blue-white, like the references
uniform float moon_radius = 0.19; // radians (~11 degrees); deliberately huge, the night's centerpiece
uniform float moon_phase = 3.14159; // elongation: 0 new, PI full
uniform float moon_brightness = 1.0;
uniform float day_amount = 0.0; // 0 at night, 1 in full day (a pale moon)

// Shooting stars and meteors (SkyEvents): streaks from tail to head, in
// the viewer's sky; color alpha is brightness.
uniform int streak_count = 0;
uniform vec3 streak_head[3];
uniform vec3 streak_tail[3];
uniform vec4 streak_color[3];
uniform float streak_width[3];

uniform float star_visibility = 0.0; // 0 by day, 1 on a clear night
uniform float star_rotation = 0.0; // subsolar longitude; stars turn with the sun

uniform vec2 glyph_stars[24];
uniform int glyph_count = 0;
uniform vec3 glyph_color : source_color = vec3(0.4, 0.7, 1.0);
uniform float glyph_visibility = 0.0;


float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(vec3(i, 1.0));
	float b = hash13(vec3(i + vec2(1.0, 0.0), 1.0));
	float c = hash13(vec3(i + vec2(0.0, 1.0), 1.0));
	float d = hash13(vec3(i + vec2(1.0, 1.0), 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

vec3 rotate_y(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}

// Distance from p to segment ab.
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
	return length(pa - ba * h);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = dot(d, up_dir);

	// Gradient, measured against the local horizon.
	vec3 col;
	if (h >= 0.0) {
		float t = pow(h, 1.0 / horizon_sharpness);
		float x = t * sky_bands;
		float fl = floor(x);
		t = (fl + smoothstep(0.49, 0.51, x - fl)) / sky_bands; // near-hard band edges
		col = mix(horizon_color, zenith_color, t);
		// Haze band hugging the horizon, same color as the ground fog.
		col = mix(col, fog_color, (1.0 - step(0.06, h)) * 0.6 + (1.0 - step(0.02, h)) * 0.3);
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
	}

	// Sun: disc plus warm glow.
	float sd = dot(d, sun_dir);
	col += sun_color * sun_visible * (smoothstep(0.9994, 0.9997, sd) * 6.0 + pow(max(sd, 0.0), 180.0) * 0.6 + pow(max(sd, 0.0), 12.0) * 0.12);

	if (!AT_CUBEMAP_PASS) {
		float night_mask = smoothstep(-0.02, 0.05, h);
		vec3 sky_base = col; // before stars (the moon hides them)

		// Stars, fixed to the celestial sphere so they wheel with the sun.
		if (star_visibility > 0.001 && h > -0.05) {
			vec3 sd3 = rotate_y(d, -star_rotation) * 110.0;
			vec3 cell = floor(sd3);
			float pick = hash13(cell);
			if (pick > 0.93) {
				vec3 center = cell + hash33(cell);
				float dist = length(sd3 - center);
				float twinkle = 0.6 + 0.4 * sin(TIME * (1.5 + pick * 4.0) + pick * 40.0);
				col += vec3(0.9, 0.93, 1.0) * smoothstep(0.24, 0.0, dist) * star_visibility * twinkle * (pick - 0.93) * 22.0 * night_mask;
			}
		}

		// Moon disc in a tangent frame around its center.
		float mc = dot(d, moon_dir);
		if (mc > 0.0) {
			vec3 t1 = normalize(cross(up_dir, moon_dir) + vec3(1e-4, 0.0, 0.0));
			vec3 t2 = cross(moon_dir, t1);
			float sr = sin(moon_radius);
			vec2 p = vec2(dot(d, t1), dot(d, t2)) / sr;
			float r = length(p);
			// Bright side points toward the sun as seen on the sky.
			vec3 sp = sun_dir - moon_dir * dot(sun_dir, moon_dir);
			vec2 bright = vec2(dot(sp, t1), dot(sp, t2));
			bright = length(bright) > 1e-3 ? normalize(bright) : vec2(1.0, 0.0);
			float illum = (1.0 - cos(moon_phase)) * 0.5;
			if (r < 1.0) {
				vec3 n = vec3(p, sqrt(1.0 - r * r));
				// Lit from the sun's direction on the sky, so the crescent
				// tilts correctly for the viewer's latitude and hour.
				vec3 l = vec3(bright * sin(moon_phase), -cos(moon_phase));
				// A slightly rough terminator: highlands catch light first.
				float rough = (fbm(p * 7.0 + 11.0) - 0.5) * 0.12;
				float lit = smoothstep(-0.03, 0.06, dot(n, l) + rough);
				// Dark maria against bright highlands, dimmer toward the limb.
				float maria = fbm(p * 2.6 + 3.0);
				float albedo = mix(0.5, 1.0, smoothstep(0.4, 0.6, maria)) * mix(0.68, 1.0, sqrt(n.z));
				// Earthshine: a crescent's dark side faintly lit by the Earth,
				// which is nearly full as seen from there.
				float earthshine = 0.22 * pow(1.0 - illum, 2.0) * (1.0 - lit);
				// The disc adds its light to the sky behind it (stars hidden),
				// so the dark side reads as sky at dusk, not a black hole.
				// At night the lit part just crosses the glow threshold (a
				// soft bloom that keeps the maria visible); by day it's a
				// pale ghost.
				float lit_gain = mix(1.35, 0.4, day_amount);
				vec3 disc = sky_base + moon_tint * albedo * (lit * lit_gain + earthshine * (1.0 - day_amount)) * moon_brightness;
				float edge = smoothstep(1.0, 0.97, r);
				col = mix(col, disc, edge * night_mask);
			}
			// Halo: as bright as the lit area, and leaning toward the lit
			// limb, so a crescent's glow follows the crescent.
			float toward = r > 1e-3 ? dot(p / r, bright) : 0.0;
			float shape = mix(1.0, smoothstep(-0.7, 0.9, toward), 1.0 - illum);
			float halo = (exp(-max(r - 1.0, 0.0) * 1.4) * 0.4 + exp(-max(r - 1.0, 0.0) * 0.35) * 0.14) * moon_brightness * pow(illum, 1.3) * shape;
			col += moon_tint * halo * night_mask * (1.0 - day_amount);

			// Today's mansion glyph beside the moon.
			if (glyph_visibility > 0.001) {
				// In moon radii; kept to the same angular size as before the
				// moon grew.
				vec2 origin = vec2(1.75, 0.45);
				float scale = 0.55;
				vec2 q = p - origin;
				if (length(q) < scale * 1.6) {
					float glow = 0.0;
					float line = 1e3;
					vec2 prev = glyph_stars[0] * scale;
					for (int i = 0; i < 24; i++) {
						if (i >= glyph_count) {
							break;
						}
						vec2 s = glyph_stars[i] * scale;
						glow += smoothstep(0.1, 0.0, length(q - s));
						if (i > 0) {
							line = min(line, seg_dist(q, prev, s));
						}
						prev = s;
					}
					float lines = smoothstep(0.03, 0.0, line) * 0.35;
					col += glyph_color * (glow + lines) * glyph_visibility * night_mask;
				}
			}
		}
		// Shooting stars and meteors: a tapering trail brightest at the
		// head, with a glowing head (meteors bloom).
		for (int i = 0; i < 3; i++) {
			if (i >= streak_count) {
				break;
			}
			vec3 hd = streak_head[i];
			vec3 tl = streak_tail[i];
			vec3 seg = hd - tl;
			float along = clamp(dot(d - tl, seg) / max(dot(seg, seg), 1e-8), 0.0, 1.0);
			// Back onto the sky sphere (the chord sags inside it).
			float dist = length(d - normalize(tl + seg * along));
			float w = streak_width[i] * (0.35 + 0.65 * along);
			float trail = smoothstep(w, 0.0, dist) * along * along;
			float head = exp(-length(d - hd) / (streak_width[i] * 1.6));
			col += streak_color[i].rgb * streak_color[i].a * (trail + head * 1.5) * night_mask;
		}
	}

	COLOR = col;
}

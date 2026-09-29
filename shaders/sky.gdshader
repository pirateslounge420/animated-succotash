// Planet sky (DESIGN.md "Visual & Tone References", "Lighting & Day-Night
// Cycle"). All colors and directions are fed each frame by SkySystem, which
// derives them continuously from the sun and moon elevation at the
// player's position. Directions are in world space; `up_dir` is the
// player's local up, since "up" changes as you walk around the planet.
//
// A painted panoramic skybox in the manner of 2001-2004 console games
// (docs/WORLD_SYSTEMS_SPEC.md R1/R1a, design §AG): a three-stop gradient,
// zenith -> mid -> horizon (by day the reference's deep blue, #0810B8
// overhead through #3560D0 to #7A90E0 at the horizon, data/look.json
// retro.colors; around sunset the sunset bands; bright ultramarine at
// night, #0A14A0 to #1B2ED8), haze hugging the horizon in the ground fog's
// color (fog_color, the horizon's own: no white band) and a warm glow on
// the sun's side. The sun is a big soft disc (sun_disc_deg across, 8 by
// default) fading out radially, not a point: no bloom does it. SkySystem sends these already corrected for the exposure
// and adjustment, so they read true on screen.
// Over it, two panoramas:
//   * clouds, in the viewer's sky: the §AG hand-painted cloud tile
//     (512 x 128, nearest-filtered so it bands with the dither; SkyPaint
//     bakes one only without it): banks piled over the horizon and
//     streaks higher up, greyscale, thresholded by the weather's cover
//     and tinted by the sky for the hour (lit tops, sky-blue bellies, the
//     sunset bands at sunset, warm near the sun). Two layers of it: a far
//     one, far_scale times smaller, squeezed toward the horizon and
//     turning slowly (cloud_scroll_far), hazier; and the near one over it
//     (cloud_scroll). They sit in front of the sun, moon and stars and go
//     into the radiance cubemap too;
//   * a fixed starfield with a milky band, turned with the sun, plus a
//     dense speckle of faint stars drawn per pixel (denser in the band).
// The moon is a big disc (~11 degrees) with phases, the night's centerpiece.
// Weather clouds overhead are separate layers at altitude (CloudLayers).
shader_type sky;

uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 east_dir = vec3(1.0, 0.0, 0.0);
uniform vec3 north_dir = vec3(0.0, 0.0, -1.0);

uniform vec3 zenith_color : source_color = vec3(0.2, 0.5, 0.95);
uniform vec3 mid_color : source_color = vec3(0.4, 0.68, 0.98);
uniform vec3 horizon_color : source_color = vec3(0.6, 0.85, 1.0);
uniform vec3 ground_color : source_color = vec3(0.2, 0.22, 0.25);
uniform float horizon_sharpness = 2.5;
uniform vec3 fog_color : source_color = vec3(0.6, 0.8, 1.0);

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 sun_disc_color : source_color = vec3(1.0, 0.97, 0.6);
uniform float sun_disc_deg = 8.0; // across
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

uniform float lightning = 0.0; // 0-1 a lightning flash (StormFX)
uniform float star_visibility = 0.0; // 0 by day, 1 on a clear night
uniform float star_rotation = 0.0; // subsolar longitude; stars turn with the sun

// The painted panoramas (SkyPaint). Clouds: R bank density, G bank
// shading, B streak density; u azimuth from east, v elevation. Stars:
// R brightness, G warmth, B milky band; equirectangular, celestial frame.
uniform sampler2D cloud_pano : filter_nearest, repeat_enable;
uniform sampler2D star_pano : filter_linear, repeat_enable;
uniform float cloud_scroll = 0.0; // turns; the near clouds drift round
uniform float cloud_scroll_far = 0.0; // turns; the far layer
uniform float far_scale = 2.2; // the far layer's features, this many times smaller
uniform float bank_cover = 0.4; // 0-1, from the weather
uniform float streak_cover = 0.4; // 0-1
uniform vec3 cloud_lit : source_color = vec3(1.0);
uniform vec3 cloud_shade : source_color = vec3(0.7, 0.78, 0.95);
uniform vec3 band_color : source_color = vec3(0.3, 0.42, 0.85);
uniform float star_gain = 1.6;
uniform float speckle_gain = 0.9; // the faint per-pixel speckle
uniform float band_gain = 0.3;

uniform vec2 glyph_stars[24];
uniform int glyph_count = 0;
uniform vec3 glyph_color : source_color = vec3(0.4, 0.7, 1.0);
uniform float glyph_visibility = 0.0;


vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
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

// One layer of the painted clouds: `cp` the tile's channels (r bank
// density, g lit/shaded, b streak density) seen in direction `d` at
// height `h` over the horizon; `haze` extra horizon haze (the far layer).
// Returns the color and how much it covers.
vec4 cloud_layer(vec3 cp, vec3 d, float h, float haze_extra) {
	float be = mix(0.8, 0.22, bank_cover);
	float bank_a = smoothstep(be - 0.06, be + 0.08, cp.r);
	float se = mix(0.86, 0.3, streak_cover);
	float streak_a = smoothstep(se - 0.08, se + 0.22, cp.b) * 0.65;
	float thick = smoothstep(be, be + 0.3, cp.r);
	// Near the sun (or the moon, at night) they glow, the thin parts
	// most.
	float sdc = max(dot(d, sun_dir), 0.0);
	float mdc = max(dot(d, moon_dir), 0.0);
	vec3 glow = sun_color * sun_visible * (pow(sdc, 8.0) * 0.45 + pow(sdc, 64.0) * 0.9)
		+ moon_tint * moon_brightness * (1.0 - day_amount) * pow(mdc, 24.0) * 0.5 * (1.0 - cos(moon_phase));
	vec3 bank_col = mix(cloud_shade, cloud_lit, cp.g) + glow * (1.1 - thick);
	vec3 streak_col = mix(cloud_shade, cloud_lit, 0.85) + glow;
	// Low, far clouds sink into the horizon haze.
	float haze = clamp((1.0 - smoothstep(0.0, 0.1, h)) * 0.55 + haze_extra, 0.0, 1.0);
	bank_col = mix(bank_col, fog_color, haze);
	streak_col = mix(streak_col, fog_color, haze);
	float a = max(bank_a, streak_a);
	vec3 c = mix(streak_col, bank_col, bank_a / max(a, 1e-4));
	return vec4(c, a);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = dot(d, up_dir);

	// Gradient, measured against the local horizon.
	vec3 col;
	if (h >= 0.0) {
		float t = pow(h, 1.0 / horizon_sharpness);
		col = t < 0.5 ? mix(horizon_color, mid_color, smoothstep(0.0, 1.0, t * 2.0))
			: mix(mid_color, zenith_color, smoothstep(0.0, 1.0, t * 2.0 - 1.0));
		// Soft haze hugging the horizon, the same color as the ground fog.
		col = mix(col, fog_color, (1.0 - smoothstep(0.0, 0.12, h)) * 0.85);
		// Warm glow low on the sun's side (strongest near sunrise/sunset).
		vec3 flat_d = normalize(d - up_dir * h + up_dir * 1e-4);
		vec3 flat_sun = normalize(sun_dir - up_dir * dot(sun_dir, up_dir) + up_dir * 1e-4);
		float side = max(dot(flat_d, flat_sun), 0.0);
		float low_sun = 1.0 - smoothstep(0.0, 0.5, abs(dot(sun_dir, up_dir)));
		col += sun_color * sun_visible * pow(side, 3.0) * (1.0 - smoothstep(0.0, 0.35, h)) * (0.08 + 0.22 * low_sun);
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
	}

	// Sun: a big soft disc, bright in the middle and fading out to its
	// rim, a fainter corona round it, and the wide warm glow.
	float sd = dot(d, sun_dir);
	float sr = acos(clamp(sd, -1.0, 1.0)) / radians(sun_disc_deg * 0.5);
	float disc = 1.0 - smoothstep(0.35, 1.0, sr);
	float corona = pow(1.0 - clamp(sr / 2.5, 0.0, 1.0), 3.0);
	col = mix(col, sun_disc_color * 1.15, clamp(disc * 1.2, 0.0, 1.0) * sun_visible);
	col += sun_disc_color * sun_visible * corona * 0.3;
	col += sun_color * sun_visible * pow(max(sd, 0.0), 12.0) * 0.12;

	if (!AT_CUBEMAP_PASS) {
		float night_mask = smoothstep(-0.02, 0.05, h);
		vec3 sky_base = col; // before stars (the moon hides them)

		// The baked starfield, fixed to the celestial sphere so it wheels
		// with the sun: blue-white to orange stars and the milky band.
		if (star_visibility > 0.001 && h > -0.05) {
			vec3 c = rotate_y(d, -star_rotation);
			vec2 suv = vec2(atan(c.x, c.z) / TAU + 0.5, acos(clamp(c.y, -1.0, 1.0)) / PI);
			vec3 st = textureLod(star_pano, suv, 0.0).rgb;
			vec3 tint = mix(vec3(0.78, 0.86, 1.0), vec3(1.0, 0.76, 0.48), st.g);
			col += (tint * st.r * star_gain + band_color * st.b * band_gain) * star_visibility * night_mask;
			// Dense speckle: a faint star in a share of the cells of a
			// grid ~0.3 degrees apart (more in the milky band), each
			// pulled onto the sphere and about a pixel and a half wide.
			vec3 sp = c * 190.0;
			vec3 cell = floor(sp);
			float pick = hash13(cell + 71.0);
			float dens = 0.07 + 0.14 * st.b;
			if (pick < dens) {
				vec3 center = normalize(cell + 0.25 + 0.5 * hash33(cell)) * 190.0;
				float mag = pick / dens;
				float b = smoothstep(0.45, 0.0, length(sp - center)) * (0.2 + 0.8 * mag * mag * mag);
				col += vec3(0.85, 0.9, 1.0) * b * speckle_gain * star_visibility * night_mask;
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
			// A tight blue-white glow, and a wider one in ultramarine so the
			// sky round the moon brightens without going grey.
			float halo_amt = moon_brightness * pow(illum, 1.3) * shape;
			vec3 halo = moon_tint * exp(-max(r - 1.0, 0.0) * 1.4) * 0.4
				+ vec3(0.12, 0.2, 1.0) * exp(-max(r - 1.0, 0.0) * 0.6) * 0.08;
			// (Faded out well before the tangent frame ends at 90 degrees.)
			col += halo * halo_amt * night_mask * (1.0 - day_amount) * smoothstep(0.0, 0.35, mc);

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

	// The painted clouds, over everything above the horizon: the far
	// layer, then the near one over it.
	if (h > -0.01) {
		float el = asin(clamp(h, 0.0, 1.0)) / (0.5 * PI);
		float az = atan(dot(d, north_dir), dot(d, east_dir)) / TAU;
		float fade = smoothstep(-0.01, 0.015, h);
		// (v stops half a texel short of the top row: it would otherwise
		// wrap and blend the zenith with the horizon.) The far layer
		// repeats a whole number of times round the sky, so no seam.
		float top = 1.0 - 0.5 / 128.0;
		float far_rep = max(1.0, round(far_scale));
		vec4 far_c = cloud_layer(textureLod(cloud_pano, vec2(az * far_rep + cloud_scroll_far, min(el * far_scale, top)), 0.0).rgb, d, h, 0.35);
		far_c.a *= (1.0 - smoothstep(0.75, 1.0, el * far_scale)) * (1.0 - smoothstep(0.28, 0.55, el));
		col = mix(col, far_c.rgb, far_c.a * fade * 0.85);
		vec4 near_c = cloud_layer(textureLod(cloud_pano, vec2(az + cloud_scroll, min(el, top)), 0.0).rgb, d, h, 0.0);
		// Toward the zenith the panorama's columns all meet at a point (from
		// play: looking straight up, the clouds converged): it fades out
		// there, and overhead is the weather's flat cloud decks'
		// (CloudLayers).
		near_c.a *= 1.0 - smoothstep(0.28, 0.55, el);
		col = mix(col, near_c.rgb, near_c.a * fade);
	}

	// Lightning lights the whole sky for an instant.
	col = mix(col, vec3(0.8, 0.85, 1.0), lightning * 0.55);
	COLOR = col;
}

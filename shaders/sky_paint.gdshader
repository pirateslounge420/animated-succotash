// The painted sky panoramas (SkyPaint): drawn once at startup into
// offscreen textures that sky.gdshader then samples every frame, the
// hand-painted skybox of 2001-2004 console games done procedurally.
//
//   layer 0  clouds, 2048 x 512, the viewer's sky: u azimuth (0-1 round
//            from east), v elevation (0 at the horizon, 1 overhead).
//            R  cloud-bank density: soft banks piled low over the horizon,
//               thinning upward, with brushy horizontal striations
//            G  bank shading: 1 on lit tops, 0 on shaded bellies
//            B  streak density: long wispy horizontal streaks higher up
//            The sky shader thresholds R and B by the weather's cover, so
//            the same painting grows from a few banks to an overcast sky.
//            Both fade out above ~60 degrees, where the panorama pinches
//            to a point: the zenith stays clear.
//   layer 1  stars, 2048 x 1024 equirectangular in the celestial frame
//            (the sky shader turns it with the sun):
//            R  star brightness (three sizes; the brightest with a small
//               four-point glint)
//            G  star warmth (0 blue-white, 1 orange)
//            B  the milky band's glow, with dark rifts
//
// Noise wraps seamlessly round the azimuth (sampled on a cylinder for the
// clouds, on the sphere for the stars). Cost is irrelevant: it runs once.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform int layer = 0;

const float DEG = 0.01745329;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec2 hash23(vec3 p) {
	vec3 q = fract(p * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

// Octaves turn as well as scale (no lattice-aligned lumps); about 0-1,
// mean 0.5.
const mat3 TURN = mat3(vec3(0.0, 0.8, 0.6), vec3(-0.8, 0.36, -0.48), vec3(-0.6, -0.48, 0.64));

float fbm(vec3 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	float norm = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= octaves) {
			break;
		}
		v += a * vnoise(p);
		norm += a;
		p = TURN * p * 2.03 + vec3(17.0, 9.0, 23.0);
		a *= 0.5;
	}
	return v / norm;
}

// A point on a cylinder round the viewer, so noise wraps in azimuth:
// features about `h_deg` of azimuth wide and `v_deg` of elevation tall.
vec3 cyl(float az, float el_deg, float h_deg, float v_deg) {
	float r = 360.0 / (6.2831853 * h_deg);
	return vec3(cos(az) * r, sin(az) * r, el_deg / v_deg);
}

// ---- Clouds ----

// Unthresholded bank density, about 0.5 at the fair-weather edge.
float bank(float az, float el) {
	vec3 q = cyl(az, el, 20.0, 6.0);
	// Warp for flowing, brushed shapes rather than noise blobs.
	vec3 w = vec3(fbm(q * 0.45 + 3.1, 3), fbm(q * 0.45 + 7.7, 3), fbm(q * 0.45 + 1.3, 3)) - 0.5;
	q += w * vec3(1.1, 1.1, 0.7);
	float n = fbm(q, 4);
	// Billowed heads.
	n = n * 0.7 + 0.3 * (1.0 - abs(2.0 * vnoise(q * 2.2 + 5.0) - 1.0));
	// Piled low over the horizon, thinning upward, clear overhead.
	float prof = smoothstep(0.0, 3.0, el) * (1.0 - smoothstep(9.0, 34.0, el)) * 0.18
		- smoothstep(26.0, 62.0, el) * 0.35;
	// A few big banks higher up, where the coarse pattern is strong.
	prof += smoothstep(0.58, 0.72, fbm(cyl(az, el, 70.0, 22.0), 3)) * (1.0 - smoothstep(40.0, 70.0, el)) * 0.18;
	return (n - 0.5) * 1.7 + prof + 0.34;
}

// Fine horizontal brush hairs, 0-1.
float brush(float az, float el) {
	return fbm(cyl(az, el, 7.0, 0.42), 4);
}

void cloud_layer(vec2 uv, out vec4 col) {
	float az = uv.x * 6.2831853;
	float el = uv.y * 90.0;
	float hair = brush(az, el);
	float d = bank(az, el) + (hair - 0.5) * 0.08;
	// Shading from where the cloud is: more cloud below than above = the
	// lit top; more above = the shaded belly.
	float below = bank(az, el - 2.2);
	float above = bank(az, el + 2.2);
	float lit = smoothstep(-0.16, 0.2, below - above);
	lit = clamp(lit + (hair - 0.5) * 0.5, 0.0, 1.0);
	// Low, distant banks are flatter and paler.
	lit = mix(0.7, lit, smoothstep(0.5, 6.0, el));

	// Streaks: long thin wisps, gently undulating, laid along great
	// circles through a point on the horizon, so like real cloud streets
	// they run straight overhead and converge toward the horizon in
	// perspective. (lat, lon): angles about that horizon point.
	vec3 v = vec3(cos(el * DEG) * cos(az), cos(el * DEG) * sin(az), sin(el * DEG));
	vec3 pole = normalize(vec3(0.8, 0.6, 0.0));
	vec3 side = vec3(-pole.y, pole.x, 0.0);
	float lat = asin(clamp(dot(v, pole), -1.0, 1.0)) / DEG;
	float lon = atan(v.z, dot(v, side)) / DEG;
	vec3 sp = vec3(lat / 32.0, lon / 3.6, 0.0);
	float wave = (fbm(vec3(lat / 50.0, lon / 25.0, 3.0), 3) - 0.5) * 3.0;
	sp.y += wave * 2.0;
	sp.xy += (vec2(fbm(sp * 0.5 + 11.0, 3), fbm(sp * 0.5 + 21.0, 3)) - 0.5) * vec2(0.8, 1.0);
	float s = fbm(sp, 5) * 0.75 + fbm(vec3(lat / 9.0, lon / 1.0 + wave * 4.0, 7.0), 3) * 0.25;
	float sprof = smoothstep(5.0, 16.0, el) * (1.0 - smoothstep(45.0, 85.0, el) * 0.75);
	float streak = (s - 0.5) * 2.2 + (sprof - 1.0) * 0.45 + 0.4;
	// Brush hairs thread through the streaks too.
	streak += (fbm(vec3(lat / 6.0, lon / 0.6 + wave * 6.0, 9.0), 4) - 0.5) * 0.14;

	// A clean zenith. This panorama pinches to a point overhead (every
	// azimuth meets there), so anything painted high up converges into a
	// smeared starburst: banks are gone by 62 degrees and streaks fade out
	// between 50 and 70, leaving the top of the sky clear for the stars
	// and the milky band.
	d *= 1.0 - smoothstep(40.0, 62.0, el);
	streak = clamp(streak, 0.0, 1.0) * (1.0 - smoothstep(50.0, 70.0, el));
	col = vec4(clamp(d, 0.0, 1.0), lit, streak, 1.0);
}

// ---- Stars ----

vec3 face_dir(int face, vec2 f) {
	vec3 d = vec3(f.x, f.y, -1.0);
	if (face == 0) {
		d = vec3(1.0, f.x, f.y);
	} else if (face == 1) {
		d = vec3(-1.0, f.x, f.y);
	} else if (face == 2) {
		d = vec3(f.x, 1.0, f.y);
	} else if (face == 3) {
		d = vec3(f.x, -1.0, f.y);
	} else if (face == 4) {
		d = vec3(f.x, f.y, 1.0);
	}
	return d;
}

// One star layer: a grid of `n` cells on each cube face, a star in a
// share `prob` of them, kept off the cell edges so it's never clipped.
// Returns (brightness, warmth).
vec2 star_layer(vec3 c, float n, float prob, float sigma, float gain, float seed, float glint) {
	vec3 a = abs(c);
	int face;
	vec2 f;
	if (a.x >= a.y && a.x >= a.z) {
		face = c.x > 0.0 ? 0 : 1;
		f = c.yz / a.x;
	} else if (a.y >= a.z) {
		face = c.y > 0.0 ? 2 : 3;
		f = c.xz / a.y;
	} else {
		face = c.z > 0.0 ? 4 : 5;
		f = c.xy / a.z;
	}
	vec2 cell = floor((f * 0.5 + 0.5) * n);
	vec3 key = vec3(cell, float(face) * 131.0 + seed);
	float pick = hash13(key);
	if (pick > prob) {
		return vec2(0.0);
	}
	vec2 off = 0.3 + 0.4 * hash23(key + 5.0);
	vec3 sdir = normalize(face_dir(face, (cell + off) / n * 2.0 - 1.0));
	vec3 o = c - sdir;
	float r = length(o);
	float mag = hash13(key + 9.0);
	float b = exp(-(r * r) / (sigma * sigma)) * gain * (0.45 + 0.55 * mag);
	if (glint > 0.0) {
		// A small four-point glint, painted on the brightest.
		vec3 t1 = normalize(cross(sdir, vec3(0.0, 1.0, 0.0)) + vec3(1e-4));
		vec3 t2 = cross(sdir, t1);
		vec2 p = vec2(dot(o, t1), dot(o, t2)) / sigma;
		float spike = exp(-abs(p.y) * 2.2 - abs(p.x) / glint) + exp(-abs(p.x) * 2.2 - abs(p.y) / glint);
		b += spike * 0.55 * gain * mag;
	}
	float tone = hash13(key + 17.0);
	float warm = tone > 0.9 ? 1.0 : (tone > 0.78 ? 0.55 : (tone > 0.6 ? 0.25 : 0.0));
	return vec2(b, warm * smoothstep(0.0, 0.05, b));
}

void star_layer_all(vec2 uv, out vec4 col) {
	float lon = (uv.x - 0.5) * 6.2831853;
	float colat = uv.y * 3.14159265;
	vec3 c = vec3(sin(colat) * sin(lon), cos(colat), sin(colat) * cos(lon));
	float texel = 6.2831853 / 2048.0;

	// The milky band: a soft glow along a great circle tilted to the
	// celestial equator, clumpy, with dark rifts down its middle.
	vec3 axis = normalize(vec3(0.42, 0.62, -0.66));
	float bc = dot(c, axis);
	float clump = fbm(c * 3.2 + 4.0, 5);
	float band = exp(-bc * bc / (0.2 * 0.2)) * smoothstep(0.3, 0.7, clump) * 0.8
		+ exp(-bc * bc / (0.08 * 0.08)) * fbm(c * 7.0 + 2.0, 4) * 0.55
		+ exp(-bc * bc / (0.45 * 0.45)) * 0.12;
	float rift = smoothstep(0.52, 0.66, fbm(c * 5.0 + 9.0, 4)) * exp(-pow(bc - 0.03, 2.0) / (0.06 * 0.06));
	band = clamp(band * (1.0 - 0.75 * rift), 0.0, 1.0);

	// Faint (denser in the band), medium and bright stars.
	vec2 s1 = star_layer(c, 120.0, 0.04 + 0.3 * band, texel * 0.75, 0.5, 1.0, 0.0);
	vec2 s2 = star_layer(c, 44.0, 0.13, texel * 1.05, 0.8, 2.0, 0.0);
	vec2 s3 = star_layer(c, 13.0, 0.2, texel * 1.5, 1.0, 3.0, 3.2);
	float bright = s1.x + s2.x + s3.x;
	float warm = s3.x > s2.x && s3.x > s1.x ? s3.y : (s2.x > s1.x ? s2.y : s1.y);
	col = vec4(clamp(bright, 0.0, 1.0), warm, band, 1.0);
}

void fragment() {
	vec4 c;
	if (layer == 0) {
		cloud_layer(UV, c);
	} else {
		star_layer_all(UV, c);
	}
	COLOR = c;
}

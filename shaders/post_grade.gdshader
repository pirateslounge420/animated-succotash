// Full-screen grade, the last step of the look (design reconciliation,
// Session 2 section C: dark and moody at every hour; §AG: the reference
// clips' hard colour). It runs at the fixed internal resolution (§Y, §ES:
// 480 lines by default, Display), before the nearest-neighbour upscale to the window, so
// every dither and grain pixel is a screen block.
//
// Two presets, day and night (data/look.json, set by PostGrade), never one
// curve through the middle: the frame is graded by each preset in full and
// the two results crossfade by `night` (0 by day, 1 at night; only dusk and
// dawn see a mix). A preset: exposure, mids (a power curve that pulls the
// midtones down and keeps black and white), saturation, teal (greens toward
// forest/teal), the darks toned toward a navy (`shadow_color`; green darks
// toward a dark olive instead, by `olive_amount`), the lights drawn toward a
// cyan-white (`highlight_color`), contrast, and a vignette (look pass, 1 Oct:
// the world dark but very saturated, shade never grey).
//
// Every step keeps the pixel's hue unless it means to move it: mids and
// contrast scale the pixel by a curve of its brightest channel, saturation
// scales each channel's distance below that channel (so a saturated blue
// never drifts to purple, as a per-channel or luma-based push does), and the
// toning moves hue and saturation toward the target's in HSV at the pixel's
// own luma. Oranges and golds (firelight, the flame, sunlit earth: hue in
// look.json grade.protect_hue_deg with chroma over protect_chroma) skip the
// grade, the night pull and the tints entirely, so the one warm accent
// lands on screen as the fire made it, against all the blue.
//
// Always, after the grade: slight color bleed before it (each pixel's
// color, not its brightness, averaged with its horizontal neighbors), a
// faint moving film grain and a hard ordered dither: each channel floored
// to `levels` steps (2^bits_per_channel - 1, 31 at 5 bits) through a 4x4
// Bayer pattern, at `dither` strength (1: every pixel on the 5-bit grid,
// data/look.json retro). Before the grain, a shadow floor (§BD,
// look.json ambient_floor, driven per frame): the darks are lifted to
// navy, or to the olive at the same brightness under green pixels by day,
// so the darkest pixels in the open never read black. No sharpening; the
// bloom is the environment's (look.json retro.bloom), on the HDR scene
// before this. Inside a magical site at night (`magic`) contrast climbs a
// little so the glow reads against the dark.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float night = 0.0;
uniform float magic = 0.0;
uniform float bleed = 0.6; // 0-1: how much color spreads sideways
uniform float grain = 0.025; // film grain amplitude
uniform float dither = 0.25; // 0-1 ordered dither strength; 0 = off
uniform float levels = 31.0; // steps per channel: 2^bits - 1
uniform vec3 shadow_floor = vec3(0.031, 0.047, 0.29); // display space; driven per frame (§BD: the hour's floor, 0 enclosed)
// Night is one colour (§BU, 1 Oct, replacing the mesopic grey): below
// pull_luma the pixel's hue collapses toward the floor's blue at its own
// brightness, saturation kept, by night_pull (night x look.json
// ambient_floor.night.pull_to_floor).
uniform float night_pull = 0.0;
uniform float pull_luma = 0.35;
// The presets: x day, y night.
uniform vec2 exposure = vec2(1.0, 1.0);
uniform vec2 mids = vec2(1.3, 1.35);
uniform vec2 saturation = vec2(1.35, 1.3);
uniform vec2 teal = vec2(0.6, 0.5);
uniform vec3 shadow_color_day = vec3(0.024, 0.094, 0.424); // display space, #06186C
uniform vec3 shadow_color_night = vec3(0.024, 0.094, 0.424);
uniform vec2 shadow_tint_amount = vec2(0.55, 0.4);
uniform vec3 highlight_color_day = vec3(0.847, 0.973, 1.0); // #D8F8FF
uniform vec3 highlight_color_night = vec3(0.784, 0.941, 1.0); // #C8F0FF
uniform vec2 highlight_amount = vec2(0.3, 0.25);
uniform vec2 olive_amount = vec2(1.0, 0.0);
uniform vec2 contrast = vec2(1.12, 1.1);
uniform vec2 vignette = vec2(0.12, 0.4);
// Hurt (design 4 Oct §EA, Harm): the dark reaching in at the edges and the
// colour drained toward its navy; the shadow floor below keeps it navy.
uniform float harm_vignette = 0.0;
uniform float harm_desat = 0.0;
// Shared by both presets (look.json grade).
uniform vec3 olive_color = vec3(0.118, 0.188, 0.039); // #1E300A
uniform vec2 olive_greenness = vec2(0.05, 0.3); // (G - max(R, B)) / G: not green .. green
uniform vec2 shadow_range = vec2(0.02, 0.3); // luma: fully toned .. untouched
uniform float highlight_from = 0.5; // luma where the cyan-white starts
uniform vec2 protect_hue = vec2(-20.0, 62.0); // degrees, red = 0
uniform float protect_feather = 10.0;
uniform vec2 protect_chroma = vec2(0.12, 0.25); // brightest minus darkest channel
// A lit village round the eye (design 5 Oct §EE.1, look.json
// village_warmth.grade; VillageWarmth): 0 in the wild and in a dead
// village, up to 1 standing in one with every hearth lit. It lifts the
// night pull, the night's teal and cyan-white lights and the navy floor,
// takes the darks toward firelit brown, and lets dimmer firelit stone keep
// its orange (protect).
uniform float warmth = 0.0;
uniform float warm_pull_ease = 0.85;
uniform float warm_teal_ease = 0.8;
uniform float warm_highlight_ease = 0.75;
uniform vec3 warm_shadow_color = vec3(0.075, 0.055, 0.047); // #130E0C
uniform float warm_shadow_mix = 0.65;
uniform float warm_protect_scale = 0.4;
// One firelight (design §EX.6; the crawler sets it, crawler.json
// firelight): where every bright warm-or-white pixel is lit by fire (no
// sun underground; the vents' daylight is blue), a bright pixel the fire
// blew pale or white (its channels clipped one by one) is put back on the
// fire's amber (`fire_white_tint`, the fire's colour lifted a little
// toward white), the paler the more (`fire_white_chroma`), before the
// grade, so the grade's protection keeps it: the stone right at
// the torch stays amber, never pulled cyan-white. 0 off (the open world).
uniform float fire_whites = 0.0;
uniform vec3 fire_white_tint = vec3(1.0, 0.52, 0.25);
uniform vec2 fire_white_chroma = vec2(0.3, 0.6); // chroma: fully pale .. untouched

// 4x4 Bayer thresholds, 0-15.
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float luma_of(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// HSV in 0-1 (hue 0-1 from red).
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

float max3(vec3 c) {
	return max(c.r, max(c.g, c.b));
}

// 0-1: how green (green channel above both others, as a share of it).
float greenness(vec3 c) {
	return smoothstep(olive_greenness.x, olive_greenness.y, (c.g - max(c.r, c.b)) / max(c.g, 1e-3));
}

// 0-1: an orange or gold with real chroma (the fire, its light, sunlit
// earth): the grade leaves it alone.
float protect(vec3 c) {
	float h = rgb2hsv(max(c, vec3(0.0))).x * 360.0;
	h = h > 180.0 ? h - 360.0 : h;
	float w = smoothstep(protect_hue.x - protect_feather, protect_hue.x, h) * (1.0 - smoothstep(protect_hue.y, protect_hue.y + protect_feather, h));
	vec2 pc = protect_chroma * mix(1.0, warm_protect_scale, warmth);
	return w * smoothstep(pc.x, pc.y, max3(c) - min(c.r, min(c.g, c.b)));
}

// `c` scaled so its brightest channel is `v` (hue and saturation kept).
vec3 to_value(vec3 c, float v) {
	return c * (v / max(max3(c), 1e-5));
}

// One preset's grade of `c` (display space, 0-1); `prot` of it is left as
// it came (oranges and golds).
vec3 grade(vec3 c, float expo, float m, float sat, float tl, vec3 shadow_col, float tint_amt, vec3 hi_col, float hi_amt, float olive_amt, float k, float vig, float prot, vec2 uv) {
	vec3 src = c;
	c = max(c * expo, vec3(0.0));
	// Mids down: a power curve through black and white on the brightest
	// channel, the pixel scaled by it.
	c = to_value(c, pow(min(max3(c), 1.0), m));
	// Saturation without a hue shift: each channel's distance below the
	// brightest scaled (HSV saturation), at most fully saturated.
	float v = max3(c);
	float s = (v - min(c.r, min(c.g, c.b))) / max(v, 1e-5);
	c = vec3(v) - (vec3(v) - c) * (min(s * sat, 1.0) / max(s, 1e-5));
	// Greens toward forest/teal: less red, blue drawn up toward the green,
	// a touch deeper.
	float g = greenness(c);
	c.r *= 1.0 - 0.35 * tl * g;
	c.b += (c.g - c.b) * 0.4 * tl * g;
	c.g *= 1.0 - 0.06 * tl * g;
	// The darks toward navy (green darks toward olive): hue and saturation
	// moved in HSV toward the target's, at the pixel's own luma; a grey
	// takes the target's hue outright.
	float y = luma_of(c);
	float w = tint_amt * (1.0 - smoothstep(shadow_range.x, shadow_range.y, y));
	vec3 tn = rgb2hsv(shadow_col);
	vec3 to = rgb2hsv(olive_color);
	float gr = greenness(c) * olive_amt;
	float ht = tn.x + (fract(to.x - tn.x + 0.5) - 0.5) * gr;
	float st = mix(tn.y, to.y, gr);
	vec3 hsv = rgb2hsv(max(c, vec3(0.0)));
	float wh = w + (1.0 - w) * (1.0 - smoothstep(0.0, 0.2, hsv.y));
	hsv.x = fract(hsv.x + (fract(ht - hsv.x + 0.5) - 0.5) * wh);
	hsv.y = mix(hsv.y, st, w);
	vec3 t = hsv2rgb(hsv);
	t *= y / max(luma_of(t), 1e-5);
	c = t / max(max3(t), 1.0);
	// The lights toward cyan-white.
	c = mix(c, hi_col, hi_amt * smoothstep(highlight_from, 1.0, y));
	// Contrast about a low pivot (keeps the mids down), on the brightest
	// channel: a power curve through 0.4, so the darks stay coloured.
	c = to_value(c, min(0.4 * pow(max3(c) / 0.4, k), 1.0));
	// Oranges and golds as they came.
	c = mix(c, src, prot);
	// Vignette.
	vec2 vc = uv - 0.5;
	c *= mix(1.0, smoothstep(0.95, 0.3, length(vc * vec2(1.0, 0.8))), vig);
	return c;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;

	// Color bleed: keep this pixel's brightness, blend its color with the
	// pixels 1.5 px either side.
	vec3 l = texture(screen_tex, SCREEN_UV - vec2(px.x * 1.5, 0.0)).rgb;
	vec3 r = texture(screen_tex, SCREEN_UV + vec2(px.x * 1.5, 0.0)).rgb;
	vec3 wide = (l + r + 2.0 * c) * 0.25;
	float y = luma_of(c);
	vec3 col = mix(c, wide - vec3(luma_of(wide)) + y, bleed);

	// Firelit whites back to the fire's amber (§EX.6): bright, not blue,
	// not already a protected orange; the dark and the blue untouched.
	if (fire_whites > 0.0) {
		// The paler the pixel, the more it goes back: white fully, pale
		// yellow (the clip's way from amber to white) part-way, a strong
		// colour (a flame's tongue, deep amber stone) not at all.
		float pale = 1.0 - smoothstep(fire_white_chroma.x, fire_white_chroma.y, max3(col) - min(col.r, min(col.g, col.b)));
		float fw = fire_whites * smoothstep(highlight_from, 1.0, max3(col)) * step(col.b, col.r + 0.02) * pale;
		col = mix(col, col * fire_white_tint, fw);
	}

	// The two presets, each in full, crossfaded by night.
	float prot = protect(col);
	vec3 day_c = grade(col, exposure.x, mids.x, saturation.x, teal.x, shadow_color_day, shadow_tint_amount.x, highlight_color_day, highlight_amount.x, olive_amount.x, contrast.x, vignette.x, prot, SCREEN_UV);
	// In a lit village the night preset warms (§EE.1): less teal, less
	// cyan-white, the darks toward firelit brown.
	vec3 night_shadow = mix(shadow_color_night, warm_shadow_color, warmth * warm_shadow_mix);
	vec3 night_c = grade(col, exposure.y, mids.y, saturation.y, teal.y * (1.0 - warmth * warm_teal_ease), night_shadow, shadow_tint_amount.y, highlight_color_night, highlight_amount.y * (1.0 - warmth * warm_highlight_ease), olive_amount.y, contrast.y, vignette.y, prot, SCREEN_UV);
	col = mix(day_c, night_c, night);
	col = (col - 0.4) * (1.0 + 0.15 * magic * night) + 0.4;
	if (harm_vignette > 0.0 || harm_desat > 0.0) {
		vec3 navy = max(shadow_floor, vec3(0.002, 0.004, 0.02));
		float hy = luma_of(col);
		col = mix(col, navy * (hy / max(luma_of(navy), 1e-4)), harm_desat * (1.0 - protect(col)));
		float r = length((SCREEN_UV - 0.5) * vec2(1.0, 0.8));
		col *= 1.0 - harm_vignette * smoothstep(0.62 - 0.5 * harm_vignette, 0.75, r) - harm_vignette * harm_vignette * 0.5;
		col = max(col, vec3(0.0));
	}
	// Night is one colour: the darks take the floor's hue at their own
	// brightness and their own saturation (the hue collapses, the chroma
	// does not, so the preset's saturation knob still sets how blue the
	// night is); the lit things (a fire, the moon on water) keep theirs.
	// Oranges and golds keep their warmth.
	float yd = luma_of(col);
	vec3 fdir = max(shadow_floor, vec3(0.002, 0.004, 0.02));
	float s_px = (max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b))) / max(max(col.r, max(col.g, col.b)), 1e-4);
	float s_fl = (max(fdir.r, max(fdir.g, fdir.b)) - min(fdir.r, min(fdir.g, fdir.b))) / max(max(fdir.r, max(fdir.g, fdir.b)), 1e-4);
	vec3 one = mix(vec3(yd), fdir * (yd / max(luma_of(fdir), 1e-4)), clamp(s_px / max(s_fl, 1e-3), 0.0, 1.0));
	col = mix(col, one, night_pull * (1.0 - warmth * warm_pull_ease) * (1.0 - prot) * (1.0 - smoothstep(pull_luma * 0.6, pull_luma * 1.6, yd)));
	// Shadow floor: the darks come up to navy (each channel at least the
	// floor's, easing off above the floor's own brightness); under a green
	// pixel by day, to the olive at the floor's brightness instead.
	float olive_now = mix(olive_amount.x, olive_amount.y, night) * greenness(max(col, vec3(0.0)));
	vec3 fcol = mix(shadow_floor, olive_color * (luma_of(shadow_floor) / max(luma_of(olive_color), 1e-4)), olive_now);
	// In a lit village the floor is firelit brown, not navy (R3, §EE.1).
	fcol = mix(fcol, warm_shadow_color * (luma_of(fcol) / max(luma_of(warm_shadow_color), 1e-4)), warmth * warm_shadow_mix * night);
	float fl = luma_of(fcol);
	col = mix(col, max(col, fcol), 1.0 - smoothstep(fl, fl * 4.0, luma_of(col)));
	float luma = luma_of(col);

	// Faint film grain, strongest in the midtones, changing every frame.
	float g = hash(FRAGCOORD.xy + fract(TIME * 7.13) * 91.7) - 0.5;
	col += g * grain * (1.0 - abs(luma * 2.0 - 1.0) * 0.6);

	// Ordered dither: each channel floored to `levels` steps (5 bits)
	// with a 4x4 Bayer threshold, mixed in at `dither` (1: every pixel
	// on the grid, the reference's 15-bit colour).
	ivec2 bp = ivec2(mod(FRAGCOORD.xy, 4.0));
	float thr = (BAYER[bp.y * 4 + bp.x] + 0.5) / 16.0;
	vec3 q = floor(clamp(col, 0.0, 1.0) * levels + thr) / levels;
	col = mix(col, q, dither);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}

// Full-screen grade, the last step of the look (design reconciliation,
// Session 2 section C: dark and moody at every hour; §AG: the reference
// clips' hard colour). It runs at the fixed internal resolution (§Y: 480
// lines, Display), before the nearest-neighbour upscale to the window, so
// every dither and grain pixel is a screen block.
//
// Two presets, day and night (data/look.json, set by PostGrade), never one
// curve through the middle: the frame is graded by each preset in full and
// the two results crossfade by `night` (0 by day, 1 at night; only dusk and
// dawn see a mix). A preset: exposure, mids (a power curve that pulls the
// midtones down and keeps black and white), saturation about the luma,
// teal (greens toward forest/teal), a blue shadow tint over the darks,
// contrast, and a vignette. Warm pixels (firelight, lanterns: red well
// above blue) skip the shadow tint so the warm accent stays orange.
//
// Always, after the grade: slight color bleed before it (each pixel's
// color, not its brightness, averaged with its horizontal neighbors), a
// faint moving film grain and a hard ordered dither: each channel floored
// to `levels` steps (2^bits_per_channel - 1, 31 at 5 bits) through a 4x4
// Bayer pattern, at `dither` strength (1: every pixel on the 5-bit grid,
// data/look.json retro). Before the grain, a shadow floor (§AG,
// retro.colors.shadow_floor, #080C4A): the darks are lifted to navy, so
// the darkest pixels in the open read navy, never black. No bloom, no
// sharpening. Inside a magical site at night (`magic`) contrast climbs a
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
uniform vec3 shadow_tint_day = vec3(0.7, 0.85, 1.45);
uniform vec3 shadow_tint_night = vec3(0.55, 0.7, 1.6);
uniform vec2 shadow_tint_amount = vec2(0.45, 0.55);
uniform vec2 contrast = vec2(1.12, 1.1);
uniform vec2 vignette = vec2(0.12, 0.4);

// 4x4 Bayer thresholds, 0-15.
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float luma_of(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// One preset's grade of `c` (display space, 0-1).
vec3 grade(vec3 c, float expo, float m, float sat, float tl, vec3 tint, float tint_amt, float k, float vig, vec2 uv) {
	float warm = smoothstep(0.06, 0.25, c.r - c.b);
	c *= expo;
	// Mids down: a power curve through black and white.
	c = pow(max(c, vec3(0.0)), vec3(m));
	// Saturation about the luma.
	float y = luma_of(c);
	c = max(mix(vec3(y), c, sat), vec3(0.0));
	// Greens toward forest/teal: less red, blue drawn up toward the green,
	// a touch deeper.
	float g = clamp((c.g - max(c.r, c.b)) * 4.0, 0.0, 1.0);
	c.r *= 1.0 - 0.35 * tl * g;
	c.b += (c.g - c.b) * 0.4 * tl * g;
	c.g *= 1.0 - 0.06 * tl * g;
	// Blue shadows: the darks tinted, the lights left alone.
	y = luma_of(c);
	float dark = 1.0 - smoothstep(0.02, 0.4, y);
	c = mix(c, c * tint, tint_amt * dark * (1.0 - warm));
	// Contrast about a low pivot (keeps the mids down).
	c = (c - 0.4) * k + 0.4;
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

	// The two presets, each in full, crossfaded by night.
	vec3 day_c = grade(col, exposure.x, mids.x, saturation.x, teal.x, shadow_tint_day, shadow_tint_amount.x, contrast.x, vignette.x, SCREEN_UV);
	vec3 night_c = grade(col, exposure.y, mids.y, saturation.y, teal.y, shadow_tint_night, shadow_tint_amount.y, contrast.y, vignette.y, SCREEN_UV);
	col = mix(day_c, night_c, night);
	col = (col - 0.4) * (1.0 + 0.15 * magic * night) + 0.4;
	// Night is one colour: the darks take the floor's hue at their own
	// brightness, fully saturated; the lit things (a fire, the moon on
	// water) keep theirs. Warm pixels keep their warmth.
	float yd = luma_of(col);
	vec3 fdir = max(shadow_floor, vec3(0.002, 0.004, 0.02));
	vec3 one = fdir * (yd / max(luma_of(fdir), 1e-4));
	float warm_px = smoothstep(0.06, 0.25, col.r - col.b);
	col = mix(col, one, night_pull * (1.0 - warm_px) * (1.0 - smoothstep(pull_luma * 0.6, pull_luma * 1.6, yd)));
	// Shadow floor: the darks come up to navy (each channel at least the
	// floor's, easing off above the floor's own brightness).
	float fl = luma_of(shadow_floor);
	col = mix(col, max(col, shadow_floor), 1.0 - smoothstep(fl, fl * 4.0, luma_of(col)));
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

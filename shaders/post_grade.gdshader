// Full-screen grade, the last step of the look: a 2000-2004 console frame
// (Dreamcast / GameCube; docs/WORLD_SYSTEMS_SPEC.md R1). The 3D renders at
// 0.8 scale and is upscaled smoothly, for the era's 480p softness.
//
// Always: slight color bleed (each pixel's color, not its brightness,
// averaged with its horizontal neighbors, like composite video), a mild
// ultramarine haze that keeps shadows off pure black (R1a: nothing pure
// black, blue rather than grey), a vibrance boost for greens and blues, a
// faint moving film grain, and a light ordered dither (a 4x4 Bayer
// pattern toward 5 bits per channel, mixed in at a quarter strength;
// `dither` 0 turns it off). No sharpening, no bloom.
//
// Night: `night` cools the shadows toward cobalt without lifting the
// highlights, and a soft vignette frames the scene; the haze thickens and
// turns ultramarine, so the darkest corner is deep blue, never black.
// Warm pixels (firelight, lanterns: red well above blue) skip the cooling,
// so the one warm accent stays orange against the blue. Inside a magical
// site (`magic`) contrast climbs a little so the glow reads against the
// dark.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float night = 0.0;
uniform float magic = 0.0;
uniform float vibrance = 0.3;
uniform float bleed = 0.6; // 0-1: how much color spreads sideways
uniform float haze = 0.08; // 0-1: the veil lifting the darks by day
uniform vec3 haze_color = vec3(0.12, 0.18, 0.55); // ultramarine, not grey
uniform float night_haze = 0.25; // the veil at night (R1a night sky blue)
uniform vec3 night_haze_color = vec3(0.08, 0.14, 0.75);
uniform float grain = 0.025; // film grain amplitude
uniform float dither = 0.25; // 0-1 ordered dither strength; 0 = off

// 4x4 Bayer thresholds, 0-15.
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float luma_of(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
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

	// Vibrance: saturate the less-saturated colors most (keeps already
	// vivid ones from clipping), with extra push for greens and blues.
	float luma = luma_of(col);
	float sat = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
	float gb = smoothstep(0.0, 0.2, max(col.g, col.b) - col.r);
	col = mix(vec3(luma), col, 1.0 + vibrance * (1.0 - sat) * (0.25 + 0.75 * gb) * (1.0 - night * 0.5));

	// Emerald: yellowish greens shift cooler and deeper (mossy, not lime).
	float greenness = clamp((col.g - max(col.r, col.b)) * 4.0, 0.0, 1.0);
	col.r *= 1.0 - 0.2 * greenness;
	col.b *= 1.0 + 0.08 * greenness;

	// Night: cool the shadows toward cobalt without lifting the highlights.
	// Firelit pixels (red well above blue) keep their warmth.
	luma = luma_of(col);
	float warm = smoothstep(0.06, 0.25, col.r - col.b);
	vec3 night_tint = mix(vec3(0.2, 0.3, 0.55), vec3(0.8, 0.86, 1.0), smoothstep(0.0, 0.6, luma));
	col = mix(col, col * night_tint * 1.15, night * 0.5 * (1.0 - warm));
	float contrast = 1.0 + 0.15 * magic * night;
	col = (col - 0.5) * contrast + 0.5;

	// Night vignette frames the scene (before the haze, so the corners
	// are lifted to deep blue too).
	vec2 vc = SCREEN_UV - 0.5;
	col *= mix(1.0, smoothstep(0.9, 0.3, length(vc * vec2(1.0, 0.8))), night * 0.4);

	// Mild haze: an ultramarine veil over the darks, thicker at night, so
	// shadows are deep blue, never pure black or grey.
	luma = luma_of(col);
	vec3 veil = mix(haze_color, night_haze_color, night);
	float dark = 1.0 - smoothstep(0.0, mix(0.5, 0.2, night), luma);
	col = mix(col, veil, mix(haze, night_haze, night) * dark);

	// Faint film grain, strongest in the midtones, changing every frame.
	float g = hash(FRAGCOORD.xy + fract(TIME * 7.13) * 91.7) - 0.5;
	col += g * grain * (1.0 - abs(luma * 2.0 - 1.0) * 0.6);

	// Light ordered dither: each channel rounded to 5 bits through a 4x4
	// Bayer pattern, mixed in at `dither` (a quarter by default).
	ivec2 bp = ivec2(mod(FRAGCOORD.xy, 4.0));
	float thr = (BAYER[bp.y * 4 + bp.x] + 0.5) / 16.0 - 0.5;
	vec3 q = floor(clamp(col, 0.0, 1.0) * 31.0 + 0.5 + thr) / 31.0;
	col = mix(col, q, dither);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}

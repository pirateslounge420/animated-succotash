// Full-screen grade, the last step of the look.
//
// Always: crunchy sharpening (a tight unsharp mask plus a wider "clarity"
// mask on luminance, so textures pop by day as well as at night), and
// PS1-style color depth. The image is quantized to 5 bits per
// channel (15-bit color) through a 4x4 ordered (Bayer) dither, the fine
// crosshatch of the era, and greens and blues get a vibrance boost.
//
// Night (DESIGN.md: surfaces read crunchy, over-sharpened and wet, like
// heavily graded PS2 / Oblivion-era 3D): `night` fades in an unsharp-mask
// sharpen, crushed contrast and a cobalt/violet push in the shadows.
// Inside a magical site (`magic`) contrast climbs further so the glow
// reads like neon against black.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float night = 0.0;
uniform float magic = 0.0;
uniform float sharpen = 1.4; // night
uniform float day_sharpen = 1.0;
uniform float clarity = 0.5;
uniform float color_levels = 32.0; // per channel: 5 bits
uniform float vibrance = 0.3;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 blur = (texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb
		+ texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)).rgb) * 0.25;
	float amount = mix(day_sharpen, sharpen, night);
	vec3 col = c + (c - blur) * amount;
	// Clarity: local contrast against a wider (3 px) blur, luminance only.
	vec3 wide = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		wide += texture(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * px * 3.0).rgb;
	}
	wide *= 0.125;
	vec3 lw = vec3(0.299, 0.587, 0.114);
	col += (dot(c, lw) - dot(wide, lw)) * clarity;

	// Vibrance: saturate the less-saturated colors most (keeps already
	// vivid ones from clipping), with extra push for greens and blues.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float sat = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
	float gb = smoothstep(0.0, 0.2, max(col.g, col.b) - col.r);
	col = mix(vec3(luma), col, 1.0 + vibrance * (1.0 - sat) * (0.25 + 0.75 * gb) * (1.0 - night * 0.5));

	// Emerald: yellowish greens shift cooler and deeper (the references'
	// greens are emerald, not lime).
	float greenness = clamp((col.g - max(col.r, col.b)) * 4.0, 0.0, 1.0);
	col.r *= 1.0 - 0.28 * greenness;
	col.b *= 1.0 + 0.12 * greenness;

	// Crush the blacks a little: deep shadows, not lifted grey ones.
	col = max(col - 0.025, vec3(0.0)) * 1.03;

	// Night: cool the shadows toward cobalt/violet without lifting the
	// highlights, then crush.
	luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 night_tint = mix(vec3(0.2, 0.18, 0.5), vec3(0.78, 0.84, 1.0), smoothstep(0.0, 0.6, luma));
	col = mix(col, col * night_tint * 1.15, night * 0.5);
	float contrast = 1.0 + 0.1 * night + 0.25 * magic * night;
	col = (col - 0.5) * contrast + 0.5 - 0.04 * magic * night;

	// 15-bit color through an ordered dither.
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float threshold = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5;
	col = floor(clamp(col, 0.0, 1.0) * (color_levels - 1.0) + 0.5 + threshold) / (color_levels - 1.0);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}

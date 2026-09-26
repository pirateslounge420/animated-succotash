// Full-screen grade, the last step of the look: a 2000-2004 console frame
// (Dreamcast / GameCube; docs/WORLD_SYSTEMS_SPEC.md R1). The 3D renders at
// 0.8 scale and is upscaled smoothly, for the era's 480p softness.
//
// Always: slight color bleed (each pixel's color, not its brightness,
// averaged with its horizontal neighbors, like composite video), a mild
// cool haze that keeps shadows off pure black, a vibrance boost for
// greens and blues, and a faint moving film grain. No sharpening, no
// dithered color depth.
//
// Night: `night` cools the shadows toward cobalt without lifting the
// highlights, and a soft vignette frames the scene. Inside a magical site
// (`magic`) contrast climbs a little so the glow reads against the dark.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float night = 0.0;
uniform float magic = 0.0;
uniform float vibrance = 0.3;
uniform float bleed = 0.6; // 0-1: how much color spreads sideways
uniform float haze = 0.05; // 0-1: the veil lifting the darks
uniform vec3 haze_color = vec3(0.16, 0.2, 0.32);
uniform float grain = 0.025; // film grain amplitude

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
	luma = luma_of(col);
	vec3 night_tint = mix(vec3(0.22, 0.24, 0.55), vec3(0.8, 0.86, 1.0), smoothstep(0.0, 0.6, luma));
	col = mix(col, col * night_tint * 1.15, night * 0.5);
	float contrast = 1.0 + 0.15 * magic * night;
	col = (col - 0.5) * contrast + 0.5;

	// Mild haze: a cool veil over the darks, so shadows are deep blue-grey,
	// never pure black.
	col = mix(col, haze_color, haze * (1.0 - smoothstep(0.0, 0.5, luma)));

	// Night vignette frames the scene.
	vec2 vc = SCREEN_UV - 0.5;
	col *= mix(1.0, smoothstep(0.9, 0.3, length(vc * vec2(1.0, 0.8))), night * 0.4);

	// Faint film grain, strongest in the midtones, changing every frame.
	float g = hash(FRAGCOORD.xy + fract(TIME * 7.13) * 91.7) - 0.5;
	col += g * grain * (1.0 - abs(luma * 2.0 - 1.0) * 0.6);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}

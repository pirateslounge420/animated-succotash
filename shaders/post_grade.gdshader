// Full-screen grade (DESIGN.md "Night": surfaces read crunchy,
// over-sharpened and wet, like heavily graded PS2 / Oblivion-era 3D).
// `night` fades it in with darkness: an unsharp-mask sharpen, a little
// crushed contrast, and a cool cobalt/violet push in the shadows. Daytime
// gets only a light gloss boost (Frutiger Aero).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float night = 0.0;
uniform float sharpen = 1.4;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 blur = (texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb
		+ texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)).rgb) * 0.25;
	float amount = mix(0.25, sharpen, night);
	vec3 col = c + (c - blur) * amount;
	// Cool the shadows toward cobalt/violet at night.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 night_tint = mix(vec3(0.12, 0.1, 0.32), vec3(0.75, 0.8, 1.0), smoothstep(0.0, 0.6, luma));
	col = mix(col, col * night_tint * 1.6, night * 0.45);
	col = mix(col, (col - 0.5) * 1.08 + 0.5, night);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}

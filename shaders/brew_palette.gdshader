shader_type canvas_item;
// A brew's palette swap over the frame (design §FN.5, queue 83; BrewVision,
// data/brew.json plants.<id>.vision.palette): the frame's own light read
// into a three-colour ramp (shadow, mid, high) and mixed over it by
// `amount` (the vision's strength now: easing in, held, fading); the ramp
// breathes, a slow wave across the frame (breathe, breathe_hz), so the
// geometry seems to swell and ease. It only draws: no light, no rule.
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float t = 0.0;
uniform vec3 shadow_col : source_color = vec3(0.12, 0.05, 0.25);
uniform vec3 mid_col : source_color = vec3(0.15, 0.55, 0.48);
uniform vec3 high_col : source_color = vec3(0.98, 0.8, 0.45);
uniform float breathe = 0.06;
uniform float breathe_hz = 0.12;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float w = sin(t * 6.2831853 * breathe_hz + (SCREEN_UV.x * 1.3 + SCREEN_UV.y) * 6.0);
	float k = clamp(l * 1.6 + breathe * w, 0.0, 1.0);
	vec3 ramp = k < 0.5 ? mix(shadow_col, mid_col, k * 2.0) : mix(mid_col, high_col, (k - 0.5) * 2.0);
	// Keep the frame's darks dark: the ramp scaled toward the light there.
	ramp *= 0.35 + 0.65 * smoothstep(0.0, 0.25, l);
	COLOR = vec4(mix(c, ramp, clamp(amount, 0.0, 1.0)), 1.0);
}

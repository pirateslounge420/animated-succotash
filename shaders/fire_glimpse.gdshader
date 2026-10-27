// The glimpse of a realm in the hub fire (design §GH.1.3, CrawlerAreas): a
// view of the realm (its viewport) on a card hung over the fire, soft at the
// edge, wavering with the heat, tinted toward the song's colour at its rim,
// fading in with the song (`show`).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D view : filter_linear, repeat_disable;
uniform float show = 0.0;
uniform float waver = 0.012;
uniform vec3 rim_colour = vec3(0.25, 0.8, 1.0);

void fragment() {
	vec2 uv = UV;
	// The heat: the view ripples upward, more toward the top.
	uv.x += sin(uv.y * 24.0 - TIME * 4.0) * waver * (0.4 + uv.y);
	uv.y += sin(uv.x * 17.0 + TIME * 2.6) * waver * 0.6;
	vec3 c = texture(view, vec2(uv.x, uv.y)).rgb;
	// Soft oval edge, the rim taking the song's colour.
	vec2 d = (UV - 0.5) * vec2(1.0, 1.25);
	float r = length(d) * 2.0;
	float edge = 1.0 - smoothstep(0.55, 1.0, r);
	c = mix(c, rim_colour * 1.5, smoothstep(0.45, 0.95, r) * 0.6);
	ALBEDO = c;
	ALPHA = edge * clamp(show, 0.0, 1.0) * 0.92;
}

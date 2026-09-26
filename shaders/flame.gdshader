// A tongue of campfire flame: a camera-facing card (turning about its own
// up axis, the fire's up on the planet) drawn additively, so tongues
// overlapping build a hot core. The shape is a teardrop, round at the
// base and drawn to a point, licked sideways and torn at the top by grain
// scrolling up; color runs from the R1a fire core (#FFB020) through the
// coals' orange (#FF4A00) to a deep red edge, with only a small gold
// heart, so the fire reads orange-gold rather than white.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform float phase = 0.0; // so tongues don't move together
uniform float strength = 0.3;
uniform vec3 edge_color : source_color = vec3(0.6, 0.1, 0.0);
uniform vec3 coal_color : source_color = vec3(1.0, 0.29, 0.0); // #FF4A00
uniform vec3 core_color : source_color = vec3(1.0, 0.69, 0.125); // #FFB020
uniform vec3 heart_color : source_color = vec3(1.0, 0.74, 0.24);

void vertex() {
	vec3 up = MODEL_MATRIX[1].xyz;
	float h = length(up);
	up /= h;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	vec3 right = cross(up, to_cam);
	right = length(right) > 1e-4 ? normalize(right) : normalize(MODEL_MATRIX[0].xyz);
	vec3 fwd = cross(right, up);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0), vec4(up * h, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float y = 1.0 - UV.y; // 0 at the base, 1 at the tip
	float t = TIME * 1.6 + phase;
	float n1 = texture(look_grain_soft, vec2(UV.x * 0.6 + phase, y * 0.55 - t * 0.9)).r - 0.5;
	float n2 = texture(look_grain_soft, vec2(UV.x * 1.3 - phase, y * 1.2 - t * 1.7)).r - 0.5;
	// Licked sideways, more toward the tip; the height breathes.
	x += (n1 * 0.9 + n2 * 0.35) * y;
	y += n2 * 0.12 * y;
	float width = sqrt(clamp(y / 0.16, 0.0, 1.0)) * pow(clamp(1.0 - y, 0.0, 1.0), 0.85);
	float d = abs(x) / max(width, 1e-3);
	float body = 1.0 - smoothstep(0.55, 1.0, d);
	// Torn tip: flecks of flame break off toward the top.
	body *= smoothstep(0.0, 0.35, width + n2 * 0.3);
	float heat = clamp((1.0 - d) * (1.1 - y * 0.8), 0.0, 1.0);
	vec3 col = mix(edge_color, coal_color, smoothstep(0.0, 0.35, heat));
	col = mix(col, core_color, smoothstep(0.35, 0.7, heat));
	col = mix(col, heart_color, smoothstep(0.8, 0.98, heat));
	ALBEDO = col * strength;
	ALPHA = body;
}

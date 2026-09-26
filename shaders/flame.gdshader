// A tongue of campfire flame: a camera-facing card (turning about its own
// up axis, the fire's up on the planet) drawn additively, so tongues
// overlapping build a hot core. The shape is a teardrop, round at the
// base and drawn to a point, licked sideways and torn at the top by grain
// scrolling up; color runs from a white-yellow heart through orange to a
// deep red edge.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform float phase = 0.0; // so tongues don't move together
uniform float strength = 2.2;

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
	vec3 col = mix(vec3(0.55, 0.06, 0.01), vec3(1.0, 0.36, 0.04), smoothstep(0.0, 0.35, heat));
	col = mix(col, vec3(1.0, 0.78, 0.3), smoothstep(0.35, 0.7, heat));
	col = mix(col, vec3(1.0, 0.97, 0.82), smoothstep(0.72, 0.95, heat));
	ALBEDO = col * strength;
	ALPHA = body;
}

// Glowing eye points (the Night Riders' red eyes; NightRiderBody.eye()):
// a small camera-facing disc of flat color with a soft halo, the scene's
// one warm accent against the night. It is `radius_m` across up close but
// never shrinks below `min_px` pixels, so the eyes still read as points in
// the dark at a distance, and it is drawn `pull_m` nearer the camera so
// the head around it doesn't swallow it (the head still hides it from
// behind). Fog dims it less than it dims the bodies: a light in the haze.
// It fades with the body (the model's scale against `full_scale`).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/look.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.165, 0.165);
uniform float radius_m = 0.02;
uniform float min_px = 1.4;
uniform float pull_m = 0.05;
// The halo reaches this many core radii.
uniform float halo = 2.2;
uniform float full_scale = 1.0;

varying float v_fog;
varying float v_fade;

void vertex() {
	vec4 c = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float dist = max(length(c.xyz), 0.01);
	// One pixel's size at this distance.
	float px = 2.0 * dist / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float r = max(radius_m, min_px * px) * halo;
	c.xyz *= max(dist - pull_m, 0.02) / dist;
	c.xy += VERTEX.xy * r;
	POSITION = PROJECTION_MATRIX * c;
	vec3 wp = (INV_VIEW_MATRIX * c).xyz;
	v_fog = look_fog(wp, CAMERA_POSITION_WORLD).a;
	v_fade = clamp(length(MODEL_MATRIX[0].xyz) / max(full_scale, 1e-4), 0.0, 1.0);
}

void fragment() {
	// 0 at the center, 1 at the core's edge, `halo` at the quad's edge.
	float d = length(UV * 2.0 - 1.0) * halo;
	float core = 1.0 - smoothstep(0.6, 1.0, d);
	float glow = (1.0 - smoothstep(1.0, halo, d)) * 0.3;
	ALBEDO = mix(color, look_fog_color, v_fog * 0.5);
	ALPHA = max(core, glow) * v_fade * (1.0 - v_fog * 0.6);
}

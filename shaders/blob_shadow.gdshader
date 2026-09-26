// Blob shadows (BlobShadow): a soft dark disc on the ground under the
// player, creatures and camp folk, the 2001-2004 consoles' stand-in for
// shadow maps (nothing casts a real shadow). One flat quad in the
// character's upright frame, radius 1 (the node's scale sizes it; x and z
// may differ for long bodies). Drawn a little closer to the camera than it
// is, by a share of its size, so bumps and slopes under it don't cut it;
// fades out with distance and haze.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/look.gdshaderinc"

uniform float strength = 0.8;
uniform vec3 shadow_color : source_color = vec3(0.02, 0.03, 0.07);
const float fade_start = 35.0;
const float fade_end = 60.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float r = max(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = length(vp.xyz);
	vp.xyz *= max(d - (0.3 * r + 0.08), 0.05) / d;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = strength * (1.0 - smoothstep(0.55, 1.0, d));
	float dist = distance(world_pos, CAMERA_POSITION_WORLD);
	a *= (1.0 - look_fog(world_pos, CAMERA_POSITION_WORLD).a) * (1.0 - smoothstep(fade_start, fade_end, dist));
	ALBEDO = shadow_color;
	ALPHA = a;
}

// Firelight pooled on the ground round a campfire (Campfire): a flat disc
// drawn additively in the R1a ground-pool orange (#FF7A2A), brightest at
// the fire and fading out over its radius, flickering with the flames.
// The fire's OmniLight lights the folk and props; on its own it can't make
// green grass read orange (green ground under orange light goes olive), so
// fire_glow_warm.gdshader first filters the ground warm and this pool then
// paints the firelight on, the way the 2001-2004 consoles did, with a
// light decal, like the blob shadows. It shows only after dark
// (look_night), so it never tints sunlit ground. Drawn a little toward the
// camera, by a share of its size, so bumps under it don't cut it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/look.gdshaderinc"

uniform vec3 glow_color : source_color = vec3(1.0, 0.478, 0.165); // #FF7A2A
uniform float strength = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float r = max(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = length(vp.xyz);
	vp.xyz *= max(d - (0.12 * r + 0.1), 0.05) / d;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float fall = 1.0 - smoothstep(0.0, 1.0, d);
	// The same beat as Campfire.flicker (time * 9).
	float f = TIME * 9.0;
	float flicker = 0.85 + 0.1 * sin(f) + 0.07 * sin(f * 2.3 + 1.0) + 0.05 * sin(f * 5.1);
	float haze = 1.0 - look_fog(world_pos, CAMERA_POSITION_WORLD).a;
	ALBEDO = glow_color * fall * fall * strength * flicker * look_night * haze;
}

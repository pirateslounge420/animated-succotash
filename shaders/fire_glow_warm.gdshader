// The first half of the firelight pool (Campfire; the second half is
// fire_glow.gdshader): the same disc, drawn multiplied, filters the
// ground under it warm (green and blue held back toward the middle), so
// the blue-green night grass under the fire turns orange where the pool
// then adds its light, instead of the yellow-olive that green grass gives
// under an orange light. After dark only; drawn toward the camera like
// the pool.
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/look.gdshaderinc"

uniform vec3 filter_color : source_color = vec3(1.0, 0.34, 0.16);
uniform float strength = 1.0;

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
	// Full strength over the inner third, so the fire's own light on the
	// grass there turns orange, fading out to the rim.
	float fall = smoothstep(1.0, 0.3, d);
	float haze = 1.0 - look_fog(world_pos, CAMERA_POSITION_WORLD).a;
	ALBEDO = mix(vec3(1.0), filter_color, fall * strength * look_night * haze);
}

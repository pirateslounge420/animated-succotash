// A falling leaf (LeafSeason, design §AI 1): the species' own leaf card
// (§AH), a billboard facing the camera that spins about the view and
// flips (its width swings through edge-on) as it flutters down; the
// deciduous species' autumn leaf by sp_autumn. Unshaded (a card this small
// only reads in its own colour), dimmed toward night, fogged like the
// plants, cut out at its silhouette. The instance's scale is the leaf's
// size; INSTANCE_CUSTOM.x its phase.
shader_type spatial;
render_mode cull_disabled, unshaded;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D sp_leaf : filter_nearest_mipmap, repeat_disable;
uniform sampler2D sp_leaf_autumn : filter_nearest_mipmap, repeat_disable;
uniform float sp_autumn = 0.0;
uniform float flutter = 0.8;

varying vec3 world_pos;

void vertex() {
	float ph = INSTANCE_CUSTOM.x;
	float spin = TIME * (1.2 + 0.4 * sin(ph)) * flutter + ph;
	float flip = cos(TIME * 2.3 * flutter + ph * 1.7);
	vec2 v = VERTEX.xy;
	v.x *= max(abs(flip), 0.12);
	v = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * v;
	vec3 center = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	// (VERTEX is the quad's own corner, +-0.5; the billboard is built in
	// world space and handed back in the instance's frame.)
	world_pos = center + (right * v.x + up * v.y) * size;
	mat4 inv = inverse(MODEL_MATRIX);
	VERTEX = (inv * vec4(world_pos, 1.0)).xyz;
	NORMAL = normalize((inv * vec4(INV_VIEW_MATRIX[2].xyz, 0.0)).xyz);
}

void fragment() {
	vec4 a = retro_tex(sp_leaf, UV);
	vec4 b = retro_tex(sp_leaf_autumn, UV);
	ALBEDO = mix(a.rgb, b.rgb, sp_autumn) * mix(0.85, 0.12, look_night);
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

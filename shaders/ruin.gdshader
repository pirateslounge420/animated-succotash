// Ruins (RuinBuilder): stacked stone blocks lit flat (Lambert, no
// specular) with the shared low-res grain mapped per face, and the shared
// banded fog. Vertex alpha is moss: at night, near glowing sites (every
// ruin is one), the moss patches shine teal/cobalt.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain : filter_nearest, repeat_enable;

varying vec3 world_pos;
varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

void fragment() {
	vec3 an = abs(obj_normal);
	vec2 uv = an.y > 0.6 ? obj_pos.xz : (an.x > an.z ? obj_pos.zy : obj_pos.xy);
	float g = texture(look_grain, uv * 0.3).r;
	ALBEDO = COLOR.rgb * mix(0.72, 1.2, g);
	ROUGHNESS = 1.0;
	float glow = look_site_glow(world_pos, 0.0) * COLOR.a * smoothstep(0.35, 0.6, g);
	EMISSION = look_glow_emission(world_pos, glow * 2.6);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

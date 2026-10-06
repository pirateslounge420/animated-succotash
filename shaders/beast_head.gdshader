// A beast's head under a cloaked figure's hood (design 5 Oct §EO.1,
// BeastHeads; data/zodiac_heads.json look): vertex-lit like the body
// (Lambert, no specular, Look's fog) over vertex colours, with the
// body's coarse painted mottling. Only up close does it show: from
// near_m out to gone_m it fades into the hood's flat dark hollow (the
// same colour PlayerBody's hollow is drawn in), so from further off the
// figure is a person with an empty hood. hood_shade dims what light gets
// into the hood, so a face shows best by firelight.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_disabled;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform vec3 hollow_color = vec3(0.0042, 0.0048, 0.028);
uniform float near_m = 4.0;
uniform float gone_m = 8.0;
uniform float hood_shade = 0.6;

varying vec3 world_pos;
varying vec3 tex_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tex_pos = VERTEX;
}

void fragment() {
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float far = smoothstep(near_m, gone_m, distance(world_pos, CAMERA_POSITION_WORLD));
	float g = texture(look_grain_soft, (tex_pos.xy * 1.3 + tex_pos.zy * 1.7) * 9.0).r;
	ALBEDO = COLOR.rgb * (0.7 + 0.6 * g) * hood_shade * (1.0 - far);
	EMISSION = hollow_color * far;
}

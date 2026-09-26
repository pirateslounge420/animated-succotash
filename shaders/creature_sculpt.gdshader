// Sculpted creature bodies (SculptedBodies): one smooth skinned mesh
// whose vertex colors carry the coat (blended across joins, painted
// muzzles and socks) and baked creases. Vertex-lit like the rest of the
// world (Lambert, no specular, Look). UV.x is the surface: 0 skin (a faint
// grain), 1 fur (Look's fur strokes, triplanar in the body's own space),
// 2 horn, hoof, nose (smooth), 3 hide (clothing: the strokes, fainter).
//
// People's bodies carry skin and hide as weights (UV2, occlusion baked
// in) for this material's `skin_color` and `hide_color`, so one mesh
// serves everyone; COLOR holds the rest (hair, paint, trim).
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_fur : filter_linear_mipmap, repeat_enable;
uniform vec3 skin_color = vec3(0.0);
uniform vec3 hide_color = vec3(0.0);

varying vec3 world_pos;
varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 fur(float scale) {
	vec3 n = abs(obj_normal);
	n = n * n;
	vec3 a = texture(look_tex_fur, obj_pos.xy * scale).rgb;
	vec3 b = texture(look_tex_fur, obj_pos.zy * scale).rgb;
	vec3 c = texture(look_tex_fur, obj_pos.xz * scale).rgb;
	return (a * n.z + b * n.x + c * n.y) / (n.x + n.y + n.z);
}

void fragment() {
	int kind = int(round(UV.x));
	vec3 t = vec3(0.5);
	float k = 0.0;
	if (kind == 1) {
		t = fur(9.0);
		k = 0.8;
	} else if (kind == 3) {
		t = fur(11.0);
		k = 0.45;
	} else if (kind == 0) {
		t = vec3(texture(look_grain_soft, (obj_pos.xy + obj_pos.zy) * 14.0).r);
		k = 0.35;
	}
	vec3 base = COLOR.rgb + UV2.x * skin_color + UV2.y * hide_color;
	ALBEDO = base * mix(vec3(1.0), t * 2.0, k);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

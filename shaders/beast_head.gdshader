// A beast's head on a cloaked figure (design 5 Oct §EO.1, 6 Oct §EQ;
// BeastHeads; data/zodiac_heads.json look, data/beast_head_fit.json):
// vertex-lit like the body (Lambert, no specular, Look's fog) over vertex
// colours, with the body's coarse painted mottling. The head is life-sized
// and out of the hood, so its silhouette shows at every distance (§EQ.2);
// only the face's painted detail (eyes, nose, stripes, the muzzle's paler
// fur, horn and comb colours) comes in up close: from gone_m in to near_m
// the vertex colours fade in over the animal's plain fur (fur_color).
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_disabled;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform float near_m = 4.0;
uniform float gone_m = 8.0;
// Linear.
uniform vec3 fur_color = vec3(0.2);

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
	ALBEDO = mix(COLOR.rgb, fur_color, far) * (0.7 + 0.6 * g);
}

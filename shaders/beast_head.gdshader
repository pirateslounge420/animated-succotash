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
#include "res://shaders/prelit.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform float near_m = 4.0;
uniform float gone_m = 8.0;
// Linear.
uniform vec3 fur_color = vec3(0.2);
// Big texels (design 6 Oct §FH; PlayerBody.set_texels(), the folk at a
// hearth, on the head's own copy of this material): the fur's grain one
// value a texel on a grid of texel_m texels a metre in the head's own
// space, on the face's own plane, as player.gdshader paints the body.
// 0: the fine soft grain.
uniform float texel_m = 0.0;

varying vec3 world_pos;
varying vec3 tex_pos;
varying vec3 tex_nrm;

// The colour `c` carried to `mid` on the texel plane (`uv` here) along its
// own slope on the screen (player.gdshader's texel_paint).
vec3 texel_paint(vec3 c, vec2 uv, vec2 mid) {
	vec2 ux = dFdx(uv);
	vec2 uy = dFdy(uv);
	vec3 cx = dFdx(c);
	vec3 cy = dFdy(c);
	float det = ux.x * uy.y - ux.y * uy.x;
	if (abs(det) < 1e-14) {
		return c;
	}
	vec2 d = mid - uv;
	vec2 s = vec2(uy.y * d.x - uy.x * d.y, ux.x * d.y - ux.y * d.x) / det;
	s = clamp(s, vec2(-6.0), vec2(6.0));
	return max(c + cx * s.x + cy * s.y, vec3(0.0));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tex_pos = VERTEX;
	tex_nrm = NORMAL;
}

void fragment() {
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float far = smoothstep(near_m, gone_m, distance(world_pos, CAMERA_POSITION_WORLD));
	if (texel_m > 0.0) {
		// The texel this pixel is in, the paint read at its middle (as
		// player.gdshader's texel_paint), a fleck of its own and the broad
		// mottling read once.
		vec3 an = abs(tex_nrm);
		vec2 uv = an.y > 0.6 ? tex_pos.xz : (an.x > an.z ? tex_pos.zy : tex_pos.xy);
		vec2 tg = floor(uv * texel_m) + 0.5;
		vec3 paint = texel_paint(COLOR.rgb, uv, tg / texel_m);
		float fl = fract(sin(dot(tg, vec2(12.9898, 78.233))) * 43758.5453);
		float g = texture(look_grain_soft, tg / texel_m * 0.35 + 0.61).r;
		ALBEDO = mix(paint, fur_color, far) * (1.0 + 0.2 * (fl - 0.5)) * (0.75 + 0.5 * g);
	} else {
		float g = texture(look_grain_soft, (tex_pos.xy * 1.3 + tex_pos.zy * 1.7) * 9.0).r;
		ALBEDO = mix(COLOR.rgb, fur_color, far) * (0.7 + 0.6 * g);
	}
	// Pre-lit (design §ES.2): the painted light, from the sky above.
	ALBEDO = prelit_paint(ALBEDO, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

#include "res://shaders/prelit_light.gdshaderinc"

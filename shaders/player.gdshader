// The player's body (PlayerBody): the creature shader's lighting (Lambert
// with colored shadows, rim light, sheen, moonlit edge) over vertex colors
// that carry each part's color and its painted-in folds, modulated by one
// of the world's painterly textures per part.
//
// Per-vertex UV: x = material (0 skin, 1 woven fiber, 2 fur, 3 leather,
// 4 bone/wood, 5 hair), y = how freely it hangs (0 fixed .. 1 the robe's
// hem and the ends of the hair), which `motion` swings back as the player
// moves and a slow flutter keeps alive at rest.
shader_type spatial;
render_mode diffuse_lambert;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain : filter_nearest, repeat_enable;
uniform sampler2D look_tex_weave : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_fur : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_bark : filter_nearest_mipmap, repeat_enable;
uniform float motion = 0.0; // 0 still .. 1 sprinting

varying vec3 world_pos;
varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	float w = UV.y * UV.y;
	// Trail behind (+Z is the back) and flutter a little.
	float flutter = sin(TIME * 2.1 + VERTEX.y * 5.0 + VERTEX.x * 7.0) + 0.5 * sin(TIME * 3.7 + VERTEX.x * 11.0);
	VERTEX.z += w * (motion * 0.13 + flutter * 0.01 * (0.5 + motion));
	VERTEX.y += w * motion * 0.03;
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Object-space projection from the side the surface faces.
vec3 tri(sampler2D tex, float scale) {
	vec3 n = abs(obj_normal);
	n = n * n;
	vec3 a = texture(tex, obj_pos.xy * scale).rgb;
	vec3 b = texture(tex, obj_pos.zy * scale).rgb;
	vec3 c = texture(tex, obj_pos.xz * scale).rgb;
	return (a * n.z + b * n.x + c * n.y) / (n.x + n.y + n.z);
}

void fragment() {
	int kind = int(round(UV.x));
	// Textures are gray around 0.5 (no change); `k` is how strongly each
	// material shows its texture.
	vec3 t;
	float k;
	if (kind == 1) {
		t = tri(look_tex_weave, 2.2);
		k = 0.9;
	} else if (kind == 2) {
		t = tri(look_tex_fur, 2.6);
		k = 1.1;
	} else if (kind == 3) {
		t = vec3(texture(look_grain, (obj_pos.xy + obj_pos.zy) * 1.5).r);
		k = 0.6;
	} else if (kind == 4) {
		t = tri(look_tex_bark, 3.0);
		k = 0.5;
	} else if (kind == 5) {
		// Hair: long vertical streaks, the fur texture stretched down.
		t = texture(look_tex_fur, vec2(obj_pos.x + obj_pos.z, obj_pos.y * 0.25) * 3.0).rgb;
		k = 0.9;
	} else {
		t = vec3(texture(look_grain, (obj_pos.xy + obj_pos.zy) * 3.0).r);
		k = 0.25;
	}
	ALBEDO = COLOR.rgb * mix(vec3(1.0), t * 2.0, k);
	// Roughness carries each material's gloss to light(): woven cloth and
	// fur nearly matte, skin soft, hair and leather glossier.
	float rough = 0.55;
	if (kind == 1) {
		rough = 0.82;
	} else if (kind == 2) {
		rough = 0.88;
	} else if (kind == 3) {
		rough = 0.42;
	} else if (kind == 4) {
		rough = 0.6;
	} else if (kind == 5) {
		rough = 0.45;
	}
	ROUGHNESS = rough;
	SPECULAR = 0.0;
	EMISSION = look_rim(NORMAL, VIEW, 0.45) + look_gloss(NORMAL, VIEW, 0.22 * (1.0 - rough));
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

void light() {
	DIFFUSE_LIGHT += look_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL);
	DIFFUSE_LIGHT += look_rim_light(NORMAL, VIEW, LIGHT_COLOR, 0.75, 0.45, 0.4, ALBEDO);
	float gl = 1.0 - ROUGHNESS;
	SPECULAR_LIGHT += look_sheen(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, mix(8.0, 40.0, gl), gl * 0.85);
}

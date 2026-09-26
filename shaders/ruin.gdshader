// Ruins (RuinBuilder): stone blocks, timber, snow blocks, thatch and hide,
// lit flat (Lambert, no specular) with Look's textures mapped per face,
// and a rim light on edges (lit by sun and moon, plus a moonlit edge after
// dark). UV.x is the material (RuinBuilder: 0 stone, 1 wood, 2 snow,
// 3 thatch, 4 leaves, 5 hide). Vertex alpha is moss: at night, near
// glowing sites (every ruin is one), the moss patches shine teal/cobalt.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_stone : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_leaves : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_bark : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_grass : filter_nearest_mipmap, repeat_enable;

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
	// Mottled stone (texels about 1.5 cm), turning leafy where moss grows
	// (vertex alpha), with soft weathering: patches of light and dark a
	// meter or two across.
	int kind = int(round(UV.x));
	vec3 surface;
	if (kind == 1) {
		// Timber: grain runs along the face's longer way.
		surface = texture(look_tex_bark, vec2(uv.x * 1.8, uv.y * 0.45)).rgb;
	} else if (kind == 2) {
		// Packed snow: a faint grain, cool and bright.
		surface = mix(vec3(0.5), texture(look_tex_stone, uv * 0.7).rgb, 0.3) * vec3(0.97, 1.0, 1.04);
	} else if (kind == 3) {
		surface = texture(look_tex_grass, uv * 1.4).rgb;
	} else if (kind == 4) {
		surface = texture(look_tex_leaves, uv * 0.9).rgb;
	} else if (kind == 5) {
		surface = vec3(0.45 + 0.1 * texture(look_grain_soft, uv * 1.5).r);
	} else {
		surface = texture(look_tex_stone, uv * 0.55).rgb;
	}
	vec3 moss = texture(look_tex_leaves, uv * 1.1).rgb;
	float weather = texture(look_grain_soft, uv * 0.12 + 0.5).r - 0.5;
	ALBEDO = COLOR.rgb * mix(surface, moss, clamp(COLOR.a * 1.2, 0.0, 1.0) * (kind == 0 || kind == 1 ? 1.0 : 0.0)) * 2.0 * (1.0 + weather * 0.45);
	ROUGHNESS = 0.75; // shapes the rim only (see foliage.gdshader)
	// No reflections of the sky; the only highlight is light()'s sheen.
	SPECULAR = 0.0;
	float patch = texture(look_grain_soft, uv * 0.06).r; // moss patches ~0.5-2 m
	// Patches only (heavy moss on wet ruins shouldn't light whole walls).
	float glow = look_site_glow(world_pos, 0.0) * min(COLOR.a, 0.6) * smoothstep(0.58, 0.72, patch);
	EMISSION = look_glow_emission(world_pos, glow * 1.3) + look_rim(NORMAL, VIEW, 0.2);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

// Lambert with colored shadows and a light rim (0.12: big flat faces seen
// at grazing angles would otherwise flood with rim light).
void light() {
	DIFFUSE_LIGHT += look_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL);
	DIFFUSE_LIGHT += look_rim_light(NORMAL, VIEW, LIGHT_COLOR, ROUGHNESS, 0.12, 0.3, ALBEDO);
	// Worn, slightly polished stone.
	SPECULAR_LIGHT += look_sheen(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, 16.0, 0.12);
}

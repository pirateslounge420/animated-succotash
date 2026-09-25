// Ruins (RuinBuilder): stacked stone blocks lit flat (Lambert, no
// specular) with the shared low-res grain mapped per face, and the shared
// banded fog, and a rim light on block edges (lit by sun and moon, plus a
// moonlit edge after dark). Vertex alpha is moss: at night, near glowing sites (every
// ruin is one), the moss patches shine teal/cobalt.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain : filter_nearest, repeat_enable;
uniform sampler2D look_tex_stone : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_leaves : filter_nearest_mipmap, repeat_enable;

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
	// Mottled stone, turning leafy where moss grows (vertex alpha).
	vec3 stone = texture(look_tex_stone, uv * 0.35).rgb;
	vec3 moss = texture(look_tex_leaves, uv * 0.8).rgb;
	ALBEDO = COLOR.rgb * mix(stone, moss, clamp(COLOR.a * 1.2, 0.0, 1.0)) * 2.0;
	ROUGHNESS = 0.75; // shapes the rim only (see foliage.gdshader)
	// No reflections of the sky; the only highlight is light()'s sheen.
	SPECULAR = 0.0;
	float patch = texture(look_grain, uv * 0.06).r; // moss patches ~0.5-2 m
	// Patches only (heavy moss on wet ruins shouldn't light whole walls).
	float glow = look_site_glow(world_pos, 0.0) * min(COLOR.a, 0.6) * smoothstep(0.58, 0.72, patch);
	EMISSION = look_glow_emission(world_pos, glow * 2.0) + look_rim(NORMAL, VIEW, 0.2);
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

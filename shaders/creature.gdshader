// Creature and prop bodies (CreatureBodies): one color per part, lit like
// the rest of the world (wrapped Lambert with colored shadows, Look), with
// the glossy finish of GameCube-era figures: a Blinn-Phong sheen, the sky
// in the silhouette at grazing angles (fresnel gloss), a rim light, and
// the moonlit edge after dark.
shader_type spatial;
render_mode diffuse_lambert;

#include "res://shaders/look.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.5);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo;
	// Roughness only shapes the rim (specular is off).
	ROUGHNESS = 0.75;
	// No reflections of the sky; the only highlight is light()'s sheen.
	SPECULAR = 0.0;
	EMISSION = look_rim(NORMAL, VIEW, 0.45) + look_gloss(NORMAL, VIEW, 0.16);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

void light() {
	DIFFUSE_LIGHT += look_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL);
	DIFFUSE_LIGHT += look_rim_light(NORMAL, VIEW, LIGHT_COLOR, ROUGHNESS, 0.45, 0.4, ALBEDO);
	SPECULAR_LIGHT += look_sheen(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, 24.0, 0.5);
}

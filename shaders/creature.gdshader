// Creature and prop bodies (CreatureBodies): one flat color per part, lit
// like the rest of the world: Lambert with colored shadows (Look), a rim
// light on silhouettes, and the moonlit edge after dark.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

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
	EMISSION = look_rim(NORMAL, VIEW, 0.45);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

void light() {
	DIFFUSE_LIGHT += look_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL);
	DIFFUSE_LIGHT += look_rim_light(NORMAL, VIEW, LIGHT_COLOR, ROUGHNESS, 0.45, 0.4, ALBEDO);
}

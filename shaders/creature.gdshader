// Creature and prop bodies (CreatureBodies): one color per part,
// vertex-lit like the rest of the world (Lambert, no specular, Look).
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"
#include "res://shaders/prelit.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.5);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
	// Pre-lit (design §ES.2): the painted light, from the sky above.
	ALBEDO = prelit_paint(ALBEDO, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

#include "res://shaders/prelit_light.gdshaderinc"

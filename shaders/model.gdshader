// Imported models (ModelLibrary): the model's own texture and color,
// vertex-lit like the rest of the world (Lambert, no specular, Look) and
// fogged like it.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = false;
uniform bool use_vertex_color = false;
uniform float alpha_scissor = 0.0; // > 0: cut out below this alpha
uniform float emission_energy = 0.0;
uniform vec3 emission_color : source_color = vec3(0.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = albedo_color;
	if (use_texture) {
		c *= texture(albedo_texture, UV);
	}
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = c.rgb;
	if (alpha_scissor > 0.0) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = emission_color * emission_energy;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

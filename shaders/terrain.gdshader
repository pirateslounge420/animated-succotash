// Ground. Flat-shaded low-poly faces colored per face (vertex colors from
// TerrainChunk), lit flat: Lambert diffuse on face normals and no PBR
// specular, so each triangle reads as one solid color like GameCube-era
// terrain. A 32 px nearest-filtered grain (Look) adds crunchy texture.
//
// `wetness` rises at night: a hard-edged toon highlight gives the spec's
// wet, over-sharpened moonlit sheen without smooth PBR shading. Near
// magical sites, patches of moss glow at night.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_toon;

#include "res://shaders/look.gdshaderinc"

uniform float wetness = 0.0;
uniform sampler2D look_grain : filter_nearest, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float g = texture(look_grain, UV * 0.25).r;
	ALBEDO = COLOR.rgb * mix(0.8, 1.2, g);
	ROUGHNESS = mix(1.0, 0.55, wetness);
	SPECULAR = 0.35 * wetness;
	// Glowing moss creeps over the ground at magical places, in patches.
	float glow = look_site_glow(world_pos, 0.3) * smoothstep(0.64, 0.8, g);
	EMISSION = look_glow_emission(world_pos, glow * 0.55);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

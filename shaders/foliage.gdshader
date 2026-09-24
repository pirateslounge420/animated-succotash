// Vegetation placeholders (DESIGN.md "Weather System > Physical
// expression": local wind drives foliage animation). Meshes carry their
// color in vertex RGB and how much each vertex may sway in vertex alpha
// (0 at the roots, 1 at the crown), so trunks stay put and crowns move.
// Wind comes from the live weather: `wind_vector` is set each frame on the
// one material every plant shares (PlantMeshes.material()); its direction
// sets which way crowns lean and its strength how far and how fast.
//
// Lit flat (Lambert, no specular) like the terrain, with a rim light on
// silhouettes (lit by sun and moon, plus a moonlit edge after dark). Near
// magical sites, about half the plants glow at their tips at night.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform vec3 wind_vector = vec3(0.0);

varying float sway_w;
varying float glow_pick;
varying vec3 world_pos;

void vertex() {
	float sway = COLOR.a;
	float speed = length(wind_vector);
	vec3 dir = speed > 0.01 ? wind_vector / speed : vec3(0.0);
	float phase = float(INSTANCE_ID) * 1.37;
	float gust = 0.65 + 0.35 * sin(TIME * (1.1 + speed * 0.06) + phase);
	float lean = clamp(speed * 0.04, 0.0, 0.8) * gust;
	float flutter = sin(TIME * 3.3 + phase * 2.1) * 0.05 * clamp(speed * 0.12, 0.0, 1.0);
	VERTEX += dir * (lean + flutter) * sway;
	sway_w = sway;
	glow_pick = step(0.5, fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453));
	world_pos = VERTEX;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	// Specular is disabled, so roughness only shapes the rim: Godot's rim
	// falloff exponent is (1 - roughness) * 16, and at 1.0 the "rim" would
	// cover the whole surface.
	ROUGHNESS = 0.75;
	float glow = look_site_glow(world_pos, 0.25) * glow_pick * smoothstep(0.3, 0.9, sway_w);
	RIM = 0.45;
	RIM_TINT = 0.4;
	EMISSION = look_glow_emission(world_pos, glow * 2.2) + look_rim(NORMAL, VIEW, 0.3);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

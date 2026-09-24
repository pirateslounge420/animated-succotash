// Vegetation placeholders (DESIGN.md "Weather System > Physical
// expression": local wind drives foliage animation). Meshes carry their
// color in vertex RGB and how much each vertex may sway in vertex alpha
// (0 at the roots, 1 at the crown), so trunks stay put and crowns move.
// Wind comes from the live weather: `wind_vector` is set each frame on the
// one material every plant shares (PlantMeshes.material()); its direction
// sets which way crowns lean and its strength how far and how fast.
//
// Textured (Look, 64 px nearest): bark streaks on trunks, a leafy surface
// on crowns, and alpha-cutout leaf-cluster cards around the crowns so
// silhouettes are ragged and dappled instead of round. The material
// comes from UV2.x (0 bark, 1 leaves, 2 card); card UVs are in UV.
//
// Lit flat (Lambert, no specular) like the terrain, with a rim light on
// silhouettes (lit by sun and moon, plus a moonlit edge after dark). Near
// magical sites, about half the plants glow at their tips at night.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform vec3 wind_vector = vec3(0.0);
uniform sampler2D look_tex_bark : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_leaves : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_leaf_card : filter_nearest_mipmap, repeat_enable;

varying float sway_w;
varying float glow_pick;
varying vec3 world_pos;
varying vec3 obj_pos; // meters, in the plant's own frame
varying vec3 obj_normal;
varying float mat_id;

void vertex() {
	// Texture space: the plant's own frame (so textures ride with it),
	// scaled to meters by the instance's height.
	mat4 inv = inverse(MODEL_MATRIX);
	float scale = length(MODEL_MATRIX[1].xyz);
	obj_pos = (inv * vec4(VERTEX, 1.0)).xyz * scale;
	obj_normal = normalize((inv * vec4(NORMAL, 0.0)).xyz);
	mat_id = UV2.x;
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
	vec3 an = abs(obj_normal);
	vec4 tex;
	if (mat_id > 1.5) {
		tex = texture(look_tex_leaf_card, UV);
	} else if (mat_id > 0.5) {
		vec2 uv = an.y > 0.55 ? obj_pos.xz : (an.x > an.z ? obj_pos.zy : obj_pos.xy);
		tex = texture(look_tex_leaves, uv * 0.9);
	} else {
		vec2 uv = an.x > an.z ? obj_pos.zy : obj_pos.xy;
		tex = texture(look_tex_bark, vec2(uv.x * 1.6, uv.y * 0.5));
	}
	ALBEDO = COLOR.rgb * tex.rgb * 2.0;
	ALPHA = mat_id > 1.5 ? tex.a : 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Specular is disabled, so roughness only shapes the rim: Godot's rim
	// falloff exponent is (1 - roughness) * 16, and at 1.0 the "rim" would
	// cover the whole surface.
	ROUGHNESS = 0.75;
	float glow = look_site_glow(world_pos, 0.25) * glow_pick * smoothstep(0.3, 0.9, sway_w);
	RIM = 0.45;
	RIM_TINT = 0.4;
	EMISSION = look_glow_emission(world_pos, glow * 1.0) + look_rim(NORMAL, VIEW, 0.3);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

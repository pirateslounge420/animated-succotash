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
// comes from UV2.x (0 bark, 1 leaves, 2 card, 3 vine); card UVs are in UV.
//
// Wet places (per plant, from the MultiMesh's custom data: r = moss,
// g = vines): moss creeps over the bark, thickest low down and on upward
// faces, and vines hang from the crown. Each vine strand has a 0-1 key in
// UV2.y and shows only where the plant's vine amount is above it.
//
// Lit like the terrain (Lambert with colored shadows, no specular), with a
// rim light on silhouettes (lit by sun and moon, plus a moonlit edge after
// dark) and leaf translucency. Near
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
varying float moss;

void vertex() {
	// Texture space: the plant's own frame (so textures ride with it),
	// scaled to meters by the instance's height.
	mat4 inv = inverse(MODEL_MATRIX);
	float scale = length(MODEL_MATRIX[1].xyz);
	obj_pos = (inv * vec4(VERTEX, 1.0)).xyz * scale;
	obj_normal = normalize((inv * vec4(NORMAL, 0.0)).xyz);
	mat_id = UV2.x;
	moss = INSTANCE_CUSTOM.r;
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
	// Vine strands above this plant's vine amount collapse to a point.
	if (mat_id > 2.5 && UV2.y >= INSTANCE_CUSTOM.g) {
		VERTEX = MODEL_MATRIX[3].xyz;
	}
}

void fragment() {
	vec3 an = abs(obj_normal);
	vec4 tex;
	if (mat_id > 2.5) {
		// Vines: the leafy texture running down the strand.
		tex = texture(look_tex_leaves, vec2(obj_pos.x + obj_pos.z, obj_pos.y) * 2.0);
	} else if (mat_id > 1.5) {
		tex = texture(look_tex_leaf_card, UV);
	} else if (mat_id > 0.5) {
		vec2 uv = an.y > 0.55 ? obj_pos.xz : (an.x > an.z ? obj_pos.zy : obj_pos.xy);
		tex = texture(look_tex_leaves, uv * 0.9);
	} else {
		vec2 uv = an.x > an.z ? obj_pos.zy : obj_pos.xy;
		tex = texture(look_tex_bark, vec2(uv.x * 1.6, uv.y * 0.5));
	}
	ALBEDO = COLOR.rgb * tex.rgb * 2.0;
	if (mat_id < 0.5 && moss > 0.01) {
		// Moss on the bark: patchy, low down, on faces turned up and to one
		// side (the damp side).
		float n = texture(look_tex_leaves, vec2(obj_pos.x + obj_pos.z, obj_pos.y) * 0.7).g;
		float lowness = 1.0 - clamp(obj_pos.y / 5.0, 0.0, 1.0);
		float m = smoothstep(0.45, 0.7, n * 0.9 + 0.3 * lowness + 0.25 * obj_normal.y + 0.15 * obj_normal.z + 0.4 * moss - 0.25);
		vec3 moss_col = vec3(0.2, 0.38, 0.12) * texture(look_tex_leaves, vec2(obj_pos.x + obj_pos.z, obj_pos.y) * 1.3).rgb * 2.0;
		ALBEDO = mix(ALBEDO, moss_col, m * moss);
	}
	ALPHA = (mat_id > 1.5 && mat_id < 2.5) ? tex.a : 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Leaves are translucent: light shining through from behind lights
	// them too, so crowns seen from below stay green instead of black.
	float leafy = step(0.5, mat_id);
	BACKLIGHT = ALBEDO * 0.6 * leafy;
	// Specular is disabled, so roughness only shapes the rim (light()):
	// the rim falloff exponent is (1 - roughness) * 16, and at 1.0 the
	// "rim" would cover the whole surface.
	ROUGHNESS = 0.75;
	float glow = look_site_glow(world_pos, 0.25) * glow_pick * smoothstep(0.3, 0.9, sway_w);
	EMISSION = look_glow_emission(world_pos, glow * 1.0) + look_rim(NORMAL, VIEW, 0.45);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

// Lambert with colored shadows, plus the rim and leaf translucency that a
// custom light() has to supply itself (RIM 0.45, tint 0.4).
void light() {
	DIFFUSE_LIGHT += look_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL);
	DIFFUSE_LIGHT += look_rim_light(NORMAL, VIEW, LIGHT_COLOR, ROUGHNESS, 0.45, 0.4, ALBEDO);
	DIFFUSE_LIGHT += look_backlight(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, BACKLIGHT);
}

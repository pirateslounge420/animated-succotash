// Vegetation placeholders (DESIGN.md "Weather System > Physical
// expression": local wind drives foliage animation). Meshes carry their
// color in vertex RGB and how much each vertex may sway in vertex alpha
// (0 at the roots, 1 at the crown), so trunks stay put and crowns move.
// Wind comes from the live weather: `wind_vector` is set each frame on the
// one material every plant shares (PlantMeshes.material()); its direction
// sets which way crowns lean and its strength how far and how fast.
//
// Textured (Look, painted, linear-filtered): bark streaks on trunks,
// a leafy surface on crowns, and alpha-cutout leaf-cluster cards around
// the crowns so silhouettes are ragged and dappled instead of round. The material
// comes from UV2.x (0 bark, 1 leaves, 2 card, 3 vine, 4 bamboo culm,
// 5 a branchy tree's leaf-cluster card); card UVs are in UV.
//
// Branchy trees' leaf clusters (PlantMeshes.leaf_clusters) thin and shrink
// per tree: the MultiMesh custom data's alpha is how bare the tree is (0
// full leaf; PlantMeshes.leaf_amount(): growth and a dry site), times
// `leaf_season` (1 until seasons exist). A cluster whose key (CUSTOM0.w)
// is above the leaf amount is hidden; the rest scale about their center
// (CUSTOM0.xyz), smaller on a sparse tree. Their cut-out edges are broken
// up with noise so no two read alike.
//
// Dead trees (custom data alpha 1, DeadWood) lose every leaf and their
// bark goes grey; dead bamboo culms go dry straw.
//
// Wet places (per plant, from the MultiMesh's custom data: r = moss,
// g = vines): moss creeps over the bark, thickest low down and on upward
// faces, and vines hang from the crown. Each vine strand has a 0-1 key in
// UV2.y and shows only where the plant's vine amount is above it.
//
// Colors follow the R1a palette (palette.gdshaderinc): green leaves are
// pulled part of the way toward the grass target (species keep their own
// shade; flowers and autumn colors, not being green, are left alone), bark
// toward the warm dirt/bark brown, moss toward the moss green, and all of
// them cool toward their night targets after dark.
//
// Vertex-lit like the terrain (Lambert, no specular, Look), with Godot's
// own leaf translucency (BACKLIGHT). Hard sun shadows: in the shadow pass
// closed shapes cast from their far faces only (no self-shadow acne). Near magical sites, about half the
// plants glow at their tips at night.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"
#include "res://shaders/palette.gdshaderinc"

uniform vec3 wind_vector = vec3(0.0);
// The eye (the active camera, scene space) and how far from it leaves
// still cast shadows (design §W, look.json light.leaf_shadow_m): beyond
// that, in the shadow pass, leaves and leaf cards collapse to nothing
// (they still receive shadows); trunks and limbs always cast.
global uniform vec3 look_eye;
global uniform float look_leaf_shadow_m;
// Ground cover and shrubs are drawn only this near the eye (0: always;
// design §W, look.json "ranges", set per node by VegetationPlacer): each
// plant shrinks away into its root over the last tenth.
instance uniform float draw_range_m = 0.0;
// Leaf left on the trees for the season, 0-1 (Phase 5 sets it; 1 = full).
uniform float leaf_season = 1.0;
uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_bark : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_leaves : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_leaf_card : filter_linear_mipmap, repeat_enable;

varying float sway_w;
varying float glow_pick;
varying vec3 world_pos;
varying vec3 obj_pos; // meters, in the plant's own frame
varying vec3 obj_normal;
varying float mat_id;
varying float moss;
varying float cluster_key;
varying float dead_v;

void vertex() {
	// Texture space: the plant's own frame (so textures ride with it),
	// scaled to meters by the instance's height.
	mat4 inv = inverse(MODEL_MATRIX);
	float scale = length(MODEL_MATRIX[1].xyz);
	obj_pos = (inv * vec4(VERTEX, 1.0)).xyz * scale;
	obj_normal = normalize((inv * vec4(NORMAL, 0.0)).xyz);
	mat_id = UV2.x;
	moss = INSTANCE_CUSTOM.r;
	cluster_key = CUSTOM0.w;
	float leaf = (1.0 - INSTANCE_CUSTOM.a) * leaf_season;
	if (mat_id > 4.5) {
		// A leaf cluster, smaller on a sparse tree.
		vec3 c = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
		VERTEX = c + (VERTEX - c) * mix(0.6, 1.0, smoothstep(0.1, 0.8, leaf));
	}
	if (draw_range_m > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float fade = 1.0 - smoothstep(draw_range_m * 0.9, draw_range_m, distance(root, look_eye));
		VERTEX = root + (VERTEX - root) * fade;
	}
	float sway = COLOR.a;
	float speed = length(wind_vector);
	vec3 dir = speed > 0.01 ? wind_vector / speed : vec3(0.0);
	float phase = float(INSTANCE_ID) * 1.37;
	float gust = 0.65 + 0.35 * sin(TIME * (1.1 + speed * 0.06) + phase);
	float lean = clamp(speed * 0.04, 0.0, 0.8) * gust;
	float flutter = sin(TIME * 3.3 + phase * 2.1) * 0.05 * clamp(speed * 0.12, 0.0, 1.0);
	VERTEX += dir * (lean + flutter) * sway;
	// Rustled (brushed through or bumped, TreeContact): a quick shiver of
	// the whole crown, a few tens of centimeters on a big tree.
	float rustle = INSTANCE_CUSTOM.b;
	if (rustle > 0.001) {
		vec3 sx = normalize(MODEL_MATRIX[0].xyz);
		vec3 sz = normalize(MODEL_MATRIX[2].xyz);
		float amp = 0.012 * length(MODEL_MATRIX[1].xyz) * rustle * sway;
		VERTEX += (sx * sin(TIME * 23.0 + phase) + sz * cos(TIME * 19.0 + phase * 1.3)) * amp;
	}
	sway_w = sway;
	glow_pick = step(0.5, fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453));
	world_pos = VERTEX;
	// Vine strands above this plant's vine amount collapse to a point.
	if (mat_id > 2.5 && mat_id < 3.5 && UV2.y >= INSTANCE_CUSTOM.g) {
		VERTEX = MODEL_MATRIX[3].xyz;
	}
	// So do the leaf clusters this tree has shed.
	if (mat_id > 4.5 && CUSTOM0.w >= leaf) {
		VERTEX = MODEL_MATRIX[3].xyz;
	}
	// A dead tree (bare 1: DeadWood): no leaves at all, a snag; dead
	// bamboo keeps only its dry culms.
	dead_v = step(0.975, INSTANCE_CUSTOM.a);
	if (dead_v > 0.5 && ((mat_id > 0.5 && mat_id < 2.5) || mat_id > 4.5)) {
		VERTEX = MODEL_MATRIX[3].xyz;
	}
	// The shadow pass (a directional light's is orthographic): leaves
	// cast only near the eye.
	if (PROJECTION_MATRIX[3][3] == 1.0 && ((mat_id > 0.5 && mat_id < 2.5) || mat_id > 4.5)
			&& distance(world_pos, look_eye) > look_leaf_shadow_m) {
		VERTEX = MODEL_MATRIX[3].xyz;
	}
}

void fragment() {
	// The sun's and moon's shadow maps are drawn with an orthographic
	// projection (the game camera is perspective). There, closed shapes
	// (bark, crowns, bamboo culms) cast from their far faces only, so a
	// lit face never shadows itself (the material is double-sided for the
	// leaf cards, which still cast from both sides).
	if (PROJECTION_MATRIX[3][3] == 1.0 && FRONT_FACING && (mat_id < 1.5 || (mat_id > 3.5 && mat_id < 4.5))) {
		discard;
	}
	vec3 an = abs(obj_normal);
	vec4 tex;
	if (mat_id > 4.5) {
		// Leaf-cluster card: the ragged leaf cluster, its cut-out edge
		// pushed in and out by noise (per cluster), so the clusters are
		// noisy and each one different.
		tex = texture(look_tex_leaf_card, UV);
		float nz = texture(look_grain_soft, UV * 0.9 + vec2(cluster_key * 7.31, cluster_key * 3.17)).r;
		tex.a *= 0.7 + 0.6 * nz;
	} else if (mat_id > 3.5) {
		// Bamboo culm: smooth, faintly streaked, ringed with a node every
		// ~35 cm (a dark ridge with a pale band under it).
		vec2 uv = an.x > an.z ? obj_pos.zy : obj_pos.xy;
		tex = texture(look_tex_bark, vec2(uv.x * 3.0, uv.y * 0.15)) * 0.35 + 0.33;
		float node = fract(obj_pos.y / 0.35);
		tex.rgb *= 1.0 - 0.45 * step(0.94, node) + 0.18 * step(0.86, node) * step(node, 0.94);
	} else if (mat_id > 2.5) {
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
	// R1a palette: leaves toward grass green, bark toward the warm brown.
	vec3 base = COLOR.rgb;
	float gw = pal_greenness(base);
	float nk = look_night;
	if (mat_id < 0.5) {
		base = pal_pull(base, pal_dirt, 0.7 * (1.0 - gw));
		base = pal_pull(base, pal_bark_night, 0.6 * nk * (1.0 - gw));
	}
	base = pal_pull(base, pal_grass, 0.45 * gw);
	base = pal_pull(base, pal_grass_night, 0.7 * nk * gw);
	if (dead_v > 0.5) {
		// Dead wood: grey weathered bark; dry straw-colored bamboo.
		base = mat_id > 3.5 && mat_id < 4.5 ? mix(base, vec3(0.72, 0.62, 0.40), 0.85) : mix(base, vec3(0.46, 0.44, 0.41), 0.75);
	}
	ALBEDO = base * tex.rgb * 2.0;
	if (mat_id < 0.5 && moss > 0.01) {
		// Moss on the bark: patchy, low down, on faces turned up and to one
		// side (the damp side).
		float n = texture(look_tex_leaves, vec2(obj_pos.x + obj_pos.z, obj_pos.y) * 0.7).g;
		float lowness = 1.0 - clamp(obj_pos.y / 5.0, 0.0, 1.0);
		float m = smoothstep(0.45, 0.7, n * 0.9 + 0.3 * lowness + 0.25 * obj_normal.y + 0.15 * obj_normal.z + 0.4 * moss - 0.25);
		vec3 moss_col = pal_pull(pal_moss, pal_grass_night, 0.7 * nk) * texture(look_tex_leaves, vec2(obj_pos.x + obj_pos.z, obj_pos.y) * 1.3).rgb * 2.0;
		ALBEDO = mix(ALBEDO, moss_col, m * moss);
	}
	ALPHA = ((mat_id > 1.5 && mat_id < 2.5) || mat_id > 4.5) ? tex.a : 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Leaves are translucent: light shining through from behind lights
	// them too, so crowns seen from below stay green instead of black.
	float leafy = max(step(0.5, mat_id) * step(mat_id, 3.5), step(4.5, mat_id));
	BACKLIGHT = ALBEDO * 0.6 * leafy;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float glow = look_site_glow(world_pos, 0.25) * glow_pick * smoothstep(0.3, 0.9, sway_w);
	EMISSION = look_glow_emission(world_pos, glow * 1.0);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

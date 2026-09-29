// Vegetation placeholders (DESIGN.md "Weather System > Physical
// expression": local wind drives foliage animation). Meshes carry their
// color in vertex RGB and how much each vertex may sway in vertex alpha
// (0 at the roots, 1 at the crown), so trunks stay put and crowns move.
// Wind comes from the live weather: the global `plant_wind`, set each frame
// by WeatherFX (every plant material reads it); its direction
// sets which way crowns lean and its strength how far and how fast.
//
// Textured with Look's tiny detail tiles (§AG), nearest-filtered with at
// most two mip levels (retro_tex): bark every look_tile_m2.x metres on
// trunks, a leafy speckle every look_tile_m2.y on crowns, and noisy 32 px
// alpha-cutout leaf-cluster cards around the crowns so silhouettes are
// ragged and dappled instead of round.
//
// A species with its own tiles (design §AH, PlantMeshes.material_for)
// draws those instead, times white and the plant's genes jitter (not
// times its colour: the tiles carry it): its bark every sp_bark_tile_m
// (0.4 m), its foliage mass on the crowns, and on the cards its leaf
// cutout at the leaf's own size near (SP_NEAR_M), the mass for clumps and
// far cards, inside the ragged cluster outline. sp_autumn blends the leaf
// toward its autumn leaf and the mass by the same share (§AI). The material
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
// pulled part of the way toward the canopy target (species keep their own
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

global uniform vec3 plant_wind;
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
// Leaf left on the trees for the season, 0-1 (LeafSeason sets it on the
// deciduous species' materials; 1 = full).
uniform float leaf_season = 1.0;
uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_bark : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_leaves : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_leaf_card : filter_nearest_mipmap, repeat_enable;
// A species with its own tiles (design §AH; PlantMeshes.material_for):
// its leaf cutout (and autumn leaf), foliage mass and bark, which carry
// its colour, so they are drawn times white and the plant's genes jitter,
// never times the species colour. Species without tiles keep the class
// textures above and the palette pulls.
// Their values are taken as they are, like the vertex colours every other
// plant and surface is drawn with (no sRGB decode), so a tile's green
// lands where a species' own colour green would.
uniform bool sp_tiled = false;
uniform bool sp_has_bark = true; // (mosses, air plants, conks: no bark tile)
uniform sampler2D sp_leaf : filter_nearest_mipmap, repeat_disable;
uniform sampler2D sp_leaf_autumn : filter_nearest_mipmap, repeat_disable;
uniform sampler2D sp_leaves : filter_nearest_mipmap, repeat_enable;
uniform sampler2D sp_bark : filter_nearest_mipmap, repeat_enable;
uniform vec3 sp_leaf_color = vec3(0.24, 0.51, 0.2);
uniform vec3 sp_autumn_color = vec3(0.69, 0.54, 0.23);
uniform float sp_bark_tile_m = 0.4; // the bark tile's square, m
uniform float sp_leaf_m = 0.12; // one leaf cell on the near cards, m
// How far into its autumn colour the species is, 0-1 (the season; §AI).
uniform float sp_autumn = 0.0;
// Cards nearer than this show the leaf cutout, farther the foliage mass.
const float SP_NEAR_M = 25.0;

varying float sway_w;
varying float glow_pick;
varying vec3 world_pos;
varying vec3 obj_pos; // meters, in the plant's own frame
varying vec3 obj_normal;
varying float mat_id;
varying float moss;
varying float cluster_key;
varying float dead_v;
varying float wood_dead; // a dead limb of a living tree (TreeArch: UV2.y 1 on bark)
varying vec3 genes; // this plant's jitter: a warm/cool and value roll
varying float inst;

void vertex() {
	// Texture space: the plant's own frame (so textures ride with it),
	// scaled to meters by the instance's height.
	mat4 inv = inverse(MODEL_MATRIX);
	float scale = length(MODEL_MATRIX[1].xyz);
	obj_pos = (inv * vec4(VERTEX, 1.0)).xyz * scale;
	obj_normal = normalize((inv * vec4(NORMAL, 0.0)).xyz);
	mat_id = UV2.x;
	wood_dead = (UV2.x < 0.5 && UV2.y > 0.5) ? 1.0 : 0.0;
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
	float speed = length(plant_wind);
	vec3 dir = speed > 0.01 ? plant_wind / speed : vec3(0.0);
	float phase = float(INSTANCE_ID) * 1.37;
	float gust = 0.65 + 0.35 * sin(TIME * (1.1 + speed * 0.06) + phase);
	float lean = clamp(speed * 0.04, 0.0, 0.8) * gust;
	float flutter = sin(TIME * 3.3 + phase * 2.1) * 0.05 * clamp(speed * 0.12, 0.0, 1.0);
	VERTEX += dir * (lean + flutter) * sway;
	// A branchy tree's twigs each sway on their own phase, and the
	// clusters they carry with them, so the gaps in the crown open and
	// close (§AJ 5): the phase in CUSTOM0.w on the twig's wood, in UV2.y on
	// its clusters.
	float tw = mat_id > 4.5 ? UV2.y : (mat_id < 0.5 ? CUSTOM0.w : -1.0);
	if (tw >= 0.0 && sway > 0.0) {
		float size_k = clamp(length(MODEL_MATRIX[1].xyz) / 15.0, 0.5, 1.5);
		float amp = (0.06 + 0.12 * clamp(speed * 0.1, 0.0, 1.0)) * size_k * sway / 0.45;
		vec3 side_w = speed > 0.01 ? normalize(cross(dir, normalize(MODEL_MATRIX[1].xyz)) + vec3(1e-4)) : normalize(MODEL_MATRIX[0].xyz);
		float t1 = TIME * (1.6 + tw * 0.9) + tw * 6.2832 + phase;
		VERTEX += (side_w * sin(t1) + dir * 0.6 * sin(t1 * 1.37 + 1.1) + normalize(MODEL_MATRIX[1].xyz) * 0.3 * sin(t1 * 0.73 + 2.0)) * amp;
	}
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
	// Genes (PLANT_SCHEMA §4c: kin, not twins): each plant a little warmer
	// or cooler and lighter or darker than its species, by its instance.
	float g1 = fract(sin(float(INSTANCE_ID) * 78.233 + 1.7) * 43758.5453);
	float g2 = fract(sin(float(INSTANCE_ID) * 39.425 + 5.1) * 24634.6345);
	genes = vec3(1.0 + 0.12 * (g2 - 0.5), 1.0, 1.0 - 0.12 * (g2 - 0.5)) * (0.9 + 0.2 * g1);
	inst = float(INSTANCE_ID);
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

float sp_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// One cell of leaves on a near card (§AH: the leaf cutout is the card at
// this range): `g` card coordinates in leaf lengths; each cell holds one
// leaf, flipped or turned at random, some left empty. The mip comes from
// the continuous coordinates, so the cell seams don't pick a blurry one.
vec4 sp_leaf_cell(vec2 g, float seed) {
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float h = sp_hash(cell + seed);
	if (h < 0.22) {
		return vec4(0.0);
	}
	if (fract(h * 7.31) > 0.5) {
		f.x = 1.0 - f.x;
	}
	if (fract(h * 13.7) > 0.5) {
		f = f.yx;
	}
	vec2 dg = max(abs(dFdx(g)), abs(dFdy(g)));
	float lod = clamp(log2(max(max(dg.x, dg.y) * 48.0, 1e-4)), 0.0, look_max_mips);
	vec4 c = textureLod(sp_leaf, f, lod);
	vec4 a = textureLod(sp_leaf_autumn, f, lod);
	return vec4(mix(c.rgb, a.rgb, sp_autumn), c.a);
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
	// The season (LeafSeason, design §AI): a thinning crown loses its
	// leaves in leaf-sized cells, a hash picking which go first, until at
	// leaf_season 0 it is bare. (Branchy trees' clusters thin by their own
	// keys in vertex().)
	if (leaf_season < 0.999 && mat_id > 0.5 && mat_id < 2.5) {
		vec3 cell = floor(obj_pos / max(sp_leaf_m * 2.0, 0.25));
		if (sp_hash(cell.xy + cell.z * 17.13) >= leaf_season) {
			discard;
		}
	}
	vec3 an = abs(obj_normal);
	vec4 tex;
	if (mat_id > 4.5) {
		// Leaf-cluster card: the noisy leaf cluster, mirrored and turned
		// per cluster so neighbours don't match.
		vec2 cuv = fract(cluster_key * 5.3) > 0.5 ? vec2(1.0 - UV.x, UV.y) : UV;
		cuv = fract(cluster_key * 9.7) > 0.5 ? cuv.yx : cuv;
		tex = retro_tex(look_tex_leaf_card, cuv);
	} else if (mat_id > 3.5) {
		// Bamboo culm: smooth, faintly streaked, ringed with a node every
		// ~35 cm (a dark ridge with a pale band under it).
		vec2 uv = an.x > an.z ? obj_pos.zy : obj_pos.xy;
		tex = retro_tex(look_tex_bark, vec2(uv.x * 3.0, uv.y * 0.15)) * 0.35 + 0.33;
		float node = fract(obj_pos.y / 0.35);
		tex.rgb *= 1.0 - 0.45 * step(0.94, node) + 0.18 * step(0.86, node) * step(node, 0.94);
	} else if (mat_id > 2.5) {
		// Vines: the leafy texture running down the strand.
		tex = retro_tex(look_tex_leaves, vec2(obj_pos.x + obj_pos.z, obj_pos.y) / look_tile_m2.y);
	} else if (mat_id > 1.5) {
		tex = retro_tex(look_tex_leaf_card, UV);
	} else if (mat_id > 0.5) {
		vec2 uv = an.y > 0.55 ? obj_pos.xz : (an.x > an.z ? obj_pos.zy : obj_pos.xy);
		tex = retro_tex(look_tex_leaves, uv / look_tile_m2.y);
	} else {
		vec2 uv = an.x > an.z ? obj_pos.zy : obj_pos.xy;
		tex = retro_tex(look_tex_bark, uv / look_tile_m2.x);
	}
	// Palette: leaves toward the canopy green (§AG), bark toward the warm
	// brown.
	vec3 base = COLOR.rgb;
	float gw = pal_greenness(base);
	float nk = look_night;
	if (mat_id < 0.5) {
		base = pal_pull(base, pal_bark, 0.7 * (1.0 - gw));
		base = pal_pull(base, pal_bark_night, 0.6 * nk * (1.0 - gw));
	}
	base = pal_pull(base, pal_canopy, 0.55 * gw);
	base = pal_pull(base, pal_grass_night, 0.7 * nk * gw);
	if (dead_v > 0.5 || wood_dead > 0.5) {
		// Dead wood: grey weathered bark; dry straw-colored bamboo.
		base = mat_id > 3.5 && mat_id < 4.5 ? mix(base, vec3(0.72, 0.62, 0.40), 0.85) : mix(base, vec3(0.46, 0.44, 0.41), 0.75);
	}
	ALBEDO = base * tex.rgb * 2.0;
	if (sp_tiled && ((mat_id < 0.5 && sp_has_bark) || (mat_id > 0.5 && mat_id < 2.5) || mat_id > 4.5)) {
		// The species' own tiles (§AH), times white and the genes jitter.
		// The foliage mass takes the autumn colour by the same share as the
		// leaf cutout (autumn / leaf colour).
		vec3 autumn_tint = mix(vec3(1.0), clamp(sp_autumn_color / max(sp_leaf_color, vec3(0.01)), 0.0, 4.0), sp_autumn);
		// The mass tile holds a few leaves across.
		float mass_m = clamp(sp_leaf_m * 2.5, 0.3, 3.0);
		vec4 t;
		if (mat_id < 0.5) {
			// Bark, tiled every sp_bark_tile_m.
			vec2 uv = an.x > an.z ? obj_pos.zy : obj_pos.xy;
			t = retro_tex(sp_bark, uv / sp_bark_tile_m);
		} else if (mat_id < 1.5) {
			// A crown's surface: the foliage mass over its own shade.
			vec2 uv = an.y > 0.55 ? obj_pos.xz : (an.x > an.z ? obj_pos.zy : obj_pos.xy);
			vec4 m = retro_tex(sp_leaves, uv / mass_m);
			t = vec4(mix(sp_leaf_color * 0.45, m.rgb, m.a) * autumn_tint, 1.0);
		} else {
			// Cards: the ragged cluster outline; inside it, near, the leaf
			// cutout at the leaf's own size; for clumps and far cards, the
			// foliage mass over its own shade.
			vec2 cuv = UV;
			if (mat_id > 4.5) {
				cuv = fract(cluster_key * 5.3) > 0.5 ? vec2(1.0 - UV.x, UV.y) : UV;
				cuv = fract(cluster_key * 9.7) > 0.5 ? cuv.yx : cuv;
			}
			float edge = retro_tex(look_tex_leaf_card, cuv).a;
			float card_m = (length(dFdx(world_pos)) + length(dFdy(world_pos))) / max(length(dFdx(UV)) + length(dFdy(UV)), 1e-6);
			card_m = floor(card_m * 10.0 + 0.5) / 10.0;
			if (distance(world_pos, CAMERA_POSITION_WORLD) < SP_NEAR_M) {
				vec4 l = sp_leaf_cell(cuv * card_m / sp_leaf_m, inst * 3.1 + cluster_key * 17.0);
				t = vec4(l.rgb, l.a * edge);
			} else {
				vec4 m = retro_tex(sp_leaves, cuv * card_m / mass_m);
				// A branchy tree's cluster keeps the mass tile's holes
				// (cut out to canopy.gap, §AJ 2): sky through every card.
				float a = mat_id > 4.5 ? edge * step(0.5, m.a) : edge;
				t = vec4(mix(sp_leaf_color * 0.45, m.rgb, m.a) * autumn_tint, a);
			}
		}
		vec3 c = t.rgb * genes;
		float cg = pal_greenness(c);
		c = pal_pull(c, mat_id < 0.5 ? pal_bark_night : pal_grass_night, (mat_id < 0.5 ? 0.6 : 0.7 * cg) * nk);
		if (dead_v > 0.5 || wood_dead > 0.5) {
			c = mix(c, vec3(0.46, 0.44, 0.41), 0.75);
		}
		ALBEDO = c;
		tex.a = t.a;
	}
	if (mat_id < 0.5 && moss > 0.01) {
		// Moss on the bark: patchy, low down, on faces turned up and to one
		// side (the damp side).
		float n = retro_tex(look_tex_leaves, vec2(obj_pos.x + obj_pos.z, obj_pos.y) * 0.7).g;
		float lowness = 1.0 - clamp(obj_pos.y / 5.0, 0.0, 1.0);
		float m = smoothstep(0.45, 0.7, n * 0.9 + 0.3 * lowness + 0.25 * obj_normal.y + 0.15 * obj_normal.z + 0.4 * moss - 0.25);
		vec3 moss_col = pal_pull(pal_moss, pal_grass_night, 0.7 * nk) * retro_tex(look_tex_leaves, vec2(obj_pos.x + obj_pos.z, obj_pos.y) * 1.3).rgb * 2.0;
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

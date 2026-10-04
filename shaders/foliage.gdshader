// Vegetation placeholders (DESIGN.md "Weather System > Physical
// expression": local wind drives foliage animation). Meshes carry their
// color in vertex RGB and how much each vertex may sway in vertex alpha
// (0 at the roots, 1 at the crown), so trunks stay put and crowns move.
// Wind comes from the live weather: the global `plant_wind`, set each frame
// by WeatherFX, with the travelling gust field on top (design §DA,
// wind.gdshaderinc, data/wind.json): each plant samples the field at its
// root, is sheltered below the crowns by its spot's sky visibility, and
// moves by the Beaufort table (grass bows; leaves, twigs, branches and
// trunks start at their own wind speeds; each trunk sways at its period
// by height; Populus and the sacred fig flutter in any air).
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
// 5 a branchy tree's leaf-cluster card, 6 a far tree's picture); card UVs
// are in UV.
//
// Far trees as 2D (from play; PlantMeshes._build_impostor, UV2.x 6): one
// quad per tree, turned to face the camera round the tree's own up; the
// fragment cuts the far model's outline from it (CUSTOM0: the crown's
// half-width at four heights; UV2.y: crown base + 10 x trunk half-width in
// hundredths) and paints it the leaf colour with the season, the palette
// and the fog of every other plant. They never cast shadows.
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
// Shade leaves (design §AR, PlantGrowth.leaf_scale): the custom data's
// green carries the plant's leaf size with its vines (vines 0-1 + 2 x a
// code 1-16: 0.8x .. 1.55x; 0 none): bigger in the shade, smaller in full
// sun. Leaf clusters and cards grow about their middles by it, the leaf
// cells on the near cards and the foliage mass are drawn that much
// larger, and big shade leaves are a little darker.
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
#include "res://shaders/wind.gdshaderinc"

global uniform vec3 plant_wind;
// The eye (the active camera, scene space) and how far from it leaves
// still cast shadows (design §W, look.json light.leaf_shadow_m): beyond
// that, in the shadow pass, leaves and leaf cards collapse to nothing
// (they still receive shadows); trunks and limbs always cast.
global uniform vec3 look_eye;
global uniform float look_leaf_shadow_m;
// The sun's shadow map's reach and the stand-in shade past it (x wood,
// y leaves; SkySystem, look.json light.plant_far_shade).
global uniform float look_shadow_reach_m;
global uniform vec2 look_plant_far_shade;
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
// The vines on this tree (material 3 strands; design 1 Oct §CE): the vine
// species' own leafy tile and leaf colour (PlantMeshes.material_for).
uniform bool sp_vine_on = false;
uniform sampler2D sp_vine_leaves : filter_nearest_mipmap, repeat_enable;
uniform vec3 sp_vine_color = vec3(0.24, 0.42, 0.18);
uniform vec3 sp_leaf_color = vec3(0.24, 0.51, 0.2);
uniform vec3 sp_autumn_color = vec3(0.69, 0.54, 0.23);
uniform float sp_bark_tile_m = 0.4; // the bark tile's square, m
uniform float sp_leaf_m = 0.12; // one leaf cell on the near cards, m
// How far into its autumn colour the species is, 0-1 (the season; §AI);
// a deciduous species (sp_deciduous) runs the clock below instead.
uniform float sp_autumn = 0.0;
// The staged autumn and spring (design §AI.1 revised; data/seasons.json
// autumn_colour; LeafSeason sets the globals): each deciduous tree runs
// the clock itself, offset by its own seeded day (± jitter_days), and its
// top and outer clusters by cluster_lead_days more, so a hillside turns
// over weeks and a tree from the outside in. leaf_clock.x: days since the
// winter -> spring transition began; .y: days since the summer -> autumn
// transition began. ac_start: the four stages' start days (from the
// latter); ac_blend / ac_hue / ac_sat / ac_val: each stage's colour blend,
// hue drift toward the autumn colour, saturation and value, eased from one
// stage start to the next; ac_fall: (fall day, share lost a day, fall
// days, end of the last stage); ac_tree: (jitter days, cluster lead days,
// spring days, 0); spring_a: (bud end, young end as shares of spring
// days, bud saturation, bud value); spring_b: (young value, young hue
// shift toward yellow in degrees, 0, 0).
uniform bool sp_deciduous = false;
global uniform vec2 leaf_clock;
global uniform vec4 ac_start;
global uniform vec4 ac_blend;
global uniform vec4 ac_hue;
global uniform vec4 ac_sat;
global uniform vec4 ac_val;
global uniform vec4 ac_fall;
global uniform vec4 ac_tree;
global uniform vec4 spring_a;
global uniform vec4 spring_b;
// Cards nearer than this show the leaf cutout, farther the foliage mass.
const float SP_NEAR_M = 25.0;

// What reaches the fragment stage, packed into 8 varying slots (Godot 4.4
// and later keep 14-15 slots for the Forward+ scene shader and reject a
// shader past the GPU's limit, 31 on a Mac: 19 slots here made every
// plant draw grey there; tools/shader_varying_check.py, house limit 12).
// The names below are kept as #defines so the code reads as before.
// Flat (the same on every corner of a triangle: per plant, per piece, per
// leaf cluster or far picture):
//   f_season  the season on this tree / cluster: (autumn blend, hue drift
//             toward the autumn colour, saturation, value)
//   f_a       hue shift toward yellow (spring, 0-1 of a turn), the leaf
//             left, the plant's leaf size (shade leaves bigger), glow pick
//   f_b       material id, moss, a rare sport's code (PlantGenetics,
//             data/sports.json: packed into the custom data's red with the
//             moss, moss 0-1 + 2 x code; colour sports are drawn here,
//             sport_tint(), size ones are in the transform), cluster key
//   f_c       genes (this plant's jitter: a warm/cool and value roll), the
//             instance
//   f_d       dead (bare 1), a dead limb of a living tree (TreeArch: UV2.y
//             1 on bark), a far picture's crown base and trunk half-width
//             (z on every other plant: the gust's sheen on grass, §DA)
//   f_imp     a far picture's crown profile (CUSTOM0)
// Smooth (across a triangle):
//   s_pos     position in the plant's own frame (meters), the sway weight
//   s_nrm     the normal in the plant's own frame
// world_pos is rebuilt in fragment() from VERTEX and INV_VIEW_MATRIX.
varying flat vec4 f_season;
varying flat vec4 f_a;
varying flat vec4 f_b;
varying flat vec4 f_c;
varying flat vec4 f_d;
varying flat vec4 f_imp;
varying vec4 s_pos;
varying vec4 s_nrm;
#define v_season f_season
#define v_hshift f_a.x
#define v_leaf f_a.y
#define v_leafs f_a.z
#define glow_pick f_a.w
#define mat_id f_b.x
#define moss f_b.y
#define v_sport f_b.z
#define cluster_key f_b.w
#define genes f_c.xyz
#define inst f_c.w
#define dead_v f_d.x
#define wood_dead f_d.y
#define v_imp2 f_d.zw
#define v_imp f_imp
#define obj_pos s_pos.xyz
#define sway_w s_pos.w
#define obj_normal s_nrm.xyz

// A value eased through the stages: `v` at each stage's start day `st`,
// held after the last.
float stage_ease(float t, vec4 st, vec4 v) {
	if (t <= st.x) return v.x;
	if (t < st.y) return mix(v.x, v.y, (t - st.x) / max(st.y - st.x, 1e-3));
	if (t < st.z) return mix(v.y, v.z, (t - st.y) / max(st.z - st.y, 1e-3));
	if (t < st.w) return mix(v.z, v.w, (t - st.z) / max(st.w - st.z, 1e-3));
	return v.w;
}

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	// Texture space: the plant's own frame (so textures ride with it),
	// scaled to meters by the instance's height.
	mat4 inv = inverse(MODEL_MATRIX);
	float scale = length(MODEL_MATRIX[1].xyz);
	obj_pos = (inv * vec4(VERTEX, 1.0)).xyz * scale;
	obj_normal = normalize((inv * vec4(NORMAL, 0.0)).xyz);
	// Which way the normal faces the camera (in the shadow pass, the
	// light): the far-face rule below reads it, so a mirrored tree (its
	// faces wound the other way) casts the same.
	s_nrm.w = dot(NORMAL, INV_VIEW_MATRIX[2].xyz);
	mat_id = UV2.x;
	wood_dead = (UV2.x < 0.5 && UV2.y > 0.5) ? 1.0 : 0.0;
	v_sport = floor(INSTANCE_CUSTOM.r * 0.5 + 1e-4);
	moss = INSTANCE_CUSTOM.r - 2.0 * v_sport;
	cluster_key = CUSTOM0.w;
	float lcode = floor(INSTANCE_CUSTOM.g * 0.5 + 1e-4);
	float vines_v = INSTANCE_CUSTOM.g - 2.0 * lcode;
	v_leafs = lcode < 0.5 ? 1.0 : 0.8 + 0.05 * (lcode - 1.0);
	float leaf = (1.0 - INSTANCE_CUSTOM.a) * leaf_season;
	v_season = vec4(sp_autumn, 0.0, 1.0, 1.0);
	v_hshift = 0.0;
	if (sp_deciduous) {
		// This tree's own day (± jitter_days), its top and outer clusters
		// ahead by up to cluster_lead_days.
		// (Seeded by the tree's own turn and lean, which the floating
		// origin never changes; instance ids repeat from chunk to chunk.)
		vec3 bx = normalize(MODEL_MATRIX[0].xyz);
		float h1 = fract(sin(dot(bx, vec3(127.1, 311.7, 74.7))) * 43758.5453) * 2.0 - 1.0;
		float h2 = fract(sin(dot(bx, vec3(269.5, 183.3, 246.1))) * 24634.6345) * 2.0 - 1.0;
		float lead = 0.0;
		if (mat_id > 4.5 && mat_id < 5.5) {
			vec3 cc = CUSTOM0.xyz;
			lead = ac_tree.y * clamp(0.5 * smoothstep(0.35, 0.95, cc.y) + 0.5 * smoothstep(0.05, 0.3, length(cc.xz)), 0.0, 1.0);
		}
		float t = leaf_clock.y + h1 * ac_tree.x + lead;
		float sd = max(leaf_clock.x + h2 * ac_tree.x * 0.5 + lead * 0.25, 0.0);
		// Autumn: colour by stage; the leaves fall from the dull stage.
		float fall = t - ac_fall.x;
		float leaf_a = fall <= 0.0 ? 1.0 : pow(1.0 - ac_fall.y, fall) * (1.0 - smoothstep(0.75 * ac_fall.z, ac_fall.z, fall));
		// Spring: buds, young pale leaves, full; the clusters grow in
		// through the bud and young stages.
		float sp_days = max(ac_tree.z, 1.0);
		float u = sd / sp_days;
		float leaf_s = smoothstep(0.0, spring_a.y, u);
		float bud = 1.0 - smoothstep(spring_a.x * 0.6, spring_a.x, u);
		float young = smoothstep(spring_a.x * 0.6, spring_a.x, u) * (1.0 - smoothstep(spring_a.y, 1.0, u));
		float in_spring = step(u, 1.0) * step(t, ac_start.x);
		v_season = vec4(stage_ease(t, ac_start, ac_blend), stage_ease(t, ac_start, ac_hue),
			stage_ease(t, ac_start, ac_sat), stage_ease(t, ac_start, ac_val));
		v_season.z *= mix(1.0, mix(1.0, spring_a.z, bud), in_spring);
		v_season.w *= mix(1.0, mix(1.0, spring_a.w, bud) * mix(1.0, spring_b.x, young), in_spring);
		v_hshift = spring_b.y / 360.0 * young * in_spring;
		leaf *= min(leaf_a, leaf_s);
	}
	v_leaf = leaf;
	if (mat_id > 4.5 && mat_id < 5.5) {
		// A leaf cluster, smaller on a sparse tree, bigger in the shade.
		vec3 c = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
		VERTEX = c + (VERTEX - c) * mix(0.6, 1.0, smoothstep(0.1, 0.8, leaf)) * v_leafs;
	} else if (mat_id > 1.5 && mat_id < 2.5 && abs(v_leafs - 1.0) > 0.01) {
		// A leaf card, about its middle.
		vec3 c = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
		VERTEX = c + (VERTEX - c) * v_leafs;
	}
	if (draw_range_m > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float fade = 1.0 - smoothstep(draw_range_m * 0.9, draw_range_m, distance(root, look_eye));
		VERTEX = root + (VERTEX - root) * fade;
	}
	// The wind (design 3 Oct §DA, wind.gdshaderinc; Wind I). Every plant
	// samples the one gust field at its root, so a gust is a patch that
	// runs across a meadow and through a wood, not each plant on its own
	// sine. Its instance custom blue carries its rustle (TreeContact) and
	// Wind.stamp's code: its cover (1 - sky visibility, §BD) in
	// 31sts, its flutter flag, and its kind (0 sheltered below the
	// crowns, 1 grass and herbs, 2 a canopy crown in the full wind).
	float sway = COLOR.a;
	vec3 root_w = MODEL_MATRIX[3].xyz;
	vec3 up_p = normalize(MODEL_MATRIX[1].xyz);
	float tall = length(MODEL_MATRIX[1].xyz);
	float wcode = floor(INSTANCE_CUSTOM.b * 0.5 + 1e-4);
	float rustle = INSTANCE_CUSTOM.b - 2.0 * wcode;
	float sky = 1.0 - mod(wcode, 32.0) / 31.0;
	float flut = mod(floor(wcode / 32.0), 2.0);
	float wkind = floor(wcode / 64.0);
	vec4 gv = wind_gust_vec(root_w, plant_wind, up_p);
	float u10 = length(gv.xyz);
	vec3 dir = u10 > 0.01 ? gv.xyz / u10 : vec3(0.0);
	// The wind it feels, as the open 10 m wind the Beaufort table is
	// written against: the crowns the full gust, everything below them
	// sheltered by its spot's sky visibility; how far it moves goes with
	// the wind at its own height (the log profile).
	float ug = u10 * (wkind > 1.5 ? 1.0 : wind_shelter(sky));
	float prof = wind_profile(max(tall * 0.8, 0.05));
	float phase = float(INSTANCE_ID) * 1.37;
	bool leafy = (mat_id > 0.5 && mat_id < 2.5) || (mat_id > 4.5 && mat_id < 5.5);
	bool blade_v = abs(mat_id - 2.25) < 0.1;
	f_d.z = 0.0;
	if (wkind > 0.5 && wkind < 1.5) {
		// Grass, reeds and herbs (wind.json grass): bow from lean_from_mps
		// to lean_max of their height, nearly flat by flatten_mps; a gust
		// is a bowed patch, its cards tipping their lit side away, so a
		// paler sheen runs over the meadow ahead of it.
		float bow = wind_crowns2.w * smoothstep(wind_grass.x, wind_grass.y, ug);
		float shiver = 0.08 * bow * sin(TIME * 3.1 + phase);
		VERTEX += dir * (bow + shiver) * tall * sway - up_p * tall * sway * bow * bow * 0.45;
		f_d.z = wind_grass.z * smoothstep(wind_grass.x, wind_grass.y * 0.6, ug) * clamp(gv.w - 0.85, 0.0, 0.75) * 0.35;
	} else {
		// Trees and shrubs by force (wind.json crowns): leaves from
		// leaves_mps, twigs from twigs_mps, small branches from
		// small_branches_mps, small trees swaying from small_trees_mps,
		// large branches from large_branches_mps, whole trees from
		// whole_trees_mps. Nothing breaks (§BS).
		float leaves = wind_gate(ug, wind_crowns.x);
		float twigs = wind_gate(ug, wind_crowns.y);
		float smallb = wind_gate(ug, wind_crowns.z);
		float largeb = wind_gate(ug, wind_crowns2.x);
		// The steady push: the crown leans downwind, more in a gust.
		float push = min(0.022 * ug * prof * leaves, min(0.9, 0.06 * tall));
		// The trunk's own sway, at its period by height, so a stand of one
		// height sways together; the gust field's own value shifts its
		// phase, so the sway rolls through the stand with the gust.
		float thr = mix(wind_crowns.w, wind_crowns2.y, smoothstep(6.0, 15.0, tall));
		float whole = wind_gate(ug, thr) * clamp(ug / thr, 1.0, 1.6);
		float per = wind_sway_period(tall);
		float osc = sin(6.2832 * TIME / per + 2.5 * (gv.w - 1.0));
		float sway_m = 0.012 * tall * prof * whole;
		vec3 side_s = normalize(cross(up_p, dir) + vec3(1e-4));
		VERTEX += (dir * (push + sway_m * osc) + side_s * sway_m * 0.3 * osc) * sway;
		// A branchy tree's twigs each sway on their own phase, and the
		// clusters they carry with them, so the gaps in the crown open and
		// close (§AJ 5): the phase in CUSTOM0.w on the twig's wood, in UV2.y
		// on its clusters; a whole leaf (2.25) on its stalk's, in UV2.y.
		// Still below twigs_mps, more with the small and large branches.
		float tw = mat_id > 5.5 ? -1.0 : ((mat_id > 4.5 || blade_v) ? UV2.y : (mat_id < 0.5 ? CUSTOM0.w : -1.0));
		if (tw >= 0.0 && sway > 0.0) {
			float size_k = clamp(tall / 15.0, 0.5, 1.5);
			float amp = (0.05 * twigs + 0.06 * smallb + 0.08 * largeb) * prof * size_k * sway / 0.45;
			vec3 side_w = u10 > 0.01 ? side_s : normalize(MODEL_MATRIX[0].xyz);
			float t1 = TIME * (1.6 + tw * 0.9) + tw * 6.2832 + phase;
			VERTEX += (side_w * sin(t1) + dir * 0.6 * sin(t1 * 1.37 + 1.1) + up_p * 0.3 * sin(t1 * 0.73 + 2.0)) * amp;
		}
		// The leaves stir from leaves_mps: a small quick shimmer of the
		// leaf clusters and cards.
		if (leafy && sway > 0.0) {
			float lp = (tw >= 0.0 ? tw : 0.0) * 6.2832 + phase;
			float lamp = 0.02 * leaves * clamp(ug / wind_crowns.x, 1.0, 3.0) * sway;
			VERTEX += (side_s * sin(TIME * 5.3 + lp) + up_p * 0.5 * sin(TIME * 4.1 + lp * 1.7)) * lamp;
		}
	}
	// Flutter (wind.json flutter): leaves on long or flattened stalks
	// (Populus, Ficus religiosa; §CL) tremble in any air, from from_mps,
	// by amount on top of the crown's sway.
	if (flut > 0.5 && leafy) {
		float lp = (blade_v || mat_id > 4.5 ? UV2.y : 0.0) * 6.2832 + phase;
		float famp = wind_prof.w * smoothstep(wind_crowns2.z, wind_crowns2.z + 1.5, ug) * sway;
		VERTEX += (normalize(cross(up_p, dir + vec3(1e-3, 0.0, 0.0))) * sin(TIME * 9.0 + lp) + up_p * 0.4 * sin(TIME * 7.3 + lp * 2.3)) * famp;
	}
	// Rustled (brushed through or bumped, TreeContact): a quick shiver of
	// the whole crown, a few tens of centimeters on a big tree.
	if (rustle > 0.001) {
		vec3 sx = normalize(MODEL_MATRIX[0].xyz);
		vec3 sz = normalize(MODEL_MATRIX[2].xyz);
		float amp = 0.012 * tall * rustle * sway;
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
	if (mat_id > 5.5) {
		// A far tree's picture: upright on the tree's own up, turned round
		// it to face the camera, lit as a crown's top is (its face leant
		// mostly up: facing the camera, a picture looked at away from the
		// sun was lit from behind, a dark band against the haze).
		vec3 root = MODEL_MATRIX[3].xyz;
		vec3 upv = MODEL_MATRIX[1].xyz;
		vec3 upn = normalize(upv);
		vec3 to_cam = CAMERA_POSITION_WORLD - root;
		vec3 flat_c = to_cam - upn * dot(to_cam, upn);
		vec3 fwd = length(flat_c) > 1e-3 ? normalize(flat_c) : normalize(MODEL_MATRIX[2].xyz);
		vec3 side = normalize(cross(upn, fwd));
		vec3 lp = (inv * vec4(VERTEX, 1.0)).xyz;
		VERTEX = root + upv * lp.y + side * lp.x * length(MODEL_MATRIX[0].xyz);
		NORMAL = normalize(upn + fwd * 0.35);
		v_imp = CUSTOM0;
		v_imp2 = vec2(mod(UV2.y, 10.0), floor(UV2.y / 10.0) / 100.0);
		// Never in the shadow pass.
		if (PROJECTION_MATRIX[3][3] == 1.0) {
			VERTEX = root;
		}
	}
	vec3 world_pos = VERTEX;
	// Vine strands above this plant's vine amount collapse to a point.
	if (mat_id > 2.5 && mat_id < 3.5 && UV2.y >= vines_v) {
		VERTEX = MODEL_MATRIX[3].xyz;
	}
	// So do the leaf clusters (and whole leaves) this tree has shed.
	if (((mat_id > 4.5 && mat_id < 5.5) || blade_v) && CUSTOM0.w >= leaf) {
		VERTEX = MODEL_MATRIX[3].xyz;
	}
	// A dead tree (bare 1: DeadWood): no leaves at all, a snag; dead
	// bamboo keeps only its dry culms.
	dead_v = step(0.975, INSTANCE_CUSTOM.a);
	if (dead_v > 0.5 && ((mat_id > 0.5 && mat_id < 2.5) || (mat_id > 4.5 && mat_id < 5.5))) {
		VERTEX = MODEL_MATRIX[3].xyz;
	}
	// The shadow pass (a directional light's is orthographic): leaves
	// cast only near the eye.
	if (PROJECTION_MATRIX[3][3] == 1.0 && ((mat_id > 0.5 && mat_id < 2.5) || (mat_id > 4.5 && mat_id < 5.5))
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
	return vec4(mix(c.rgb, a.rgb, v_season.x), c.a);
}

// A far picture's crown half-width (share of its widest) at `t` up the
// crown (0 its base, 1 its top): the four samples, eased between, closing
// to a point at the top and a little in at the base.
float imp_profile(float t, vec4 p) {
	float x = t * 4.0 - 0.5;
	if (x < 0.0) return mix(p.x * 0.7, p.x, x + 1.0);
	if (x < 1.0) return mix(p.x, p.y, smoothstep(0.0, 1.0, x));
	if (x < 2.0) return mix(p.y, p.z, smoothstep(0.0, 1.0, x - 1.0));
	if (x < 3.0) return mix(p.z, p.w, smoothstep(0.0, 1.0, x - 2.0));
	return mix(p.w, 0.0, smoothstep(0.0, 1.0, x - 3.0));
}

// A colour sport on a surface of colour `c` (leafy: leaves, cards, crown;
// else bark, stems, petioles): 1 tetraploid (deeper, darker green), 2
// variegated (cream sectors and margins, from the plant's own frame so
// they stay put), 3 golden, 4 green form (no dark pigment: stems and
// petioles plain green), 5 dark form (purple-black / copper), 6 blue form
// (glaucous). The rest are form sports, drawn by the mesh builders.
vec3 sport_tint(vec3 c, bool leafy) {
	if (v_sport < 0.5) {
		return c;
	}
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	if (v_sport < 1.5) {
		return leafy ? c * vec3(0.82, 0.92, 0.8) : c;
	} else if (v_sport < 2.5) {
		if (!leafy) {
			return c;
		}
		float n = retro_tile(look_tex_leaves, obj_pos.xz * 1.7 + obj_pos.y * 0.6).g;
		float edge = retro_tile(look_tex_leaves, obj_pos.zy * 3.1).r;
		float white = smoothstep(0.52, 0.6, n * 0.8 + edge * 0.35);
		return mix(c, vec3(0.93, 0.9, 0.74) * (0.55 + lum * 1.2), white);
	} else if (v_sport < 3.5) {
		return leafy ? mix(c, vec3(1.25, 1.05, 0.35) * (0.35 + lum * 1.3), 0.7) : c;
	} else if (v_sport < 4.5) {
		return leafy ? c : mix(c, vec3(0.42, 0.6, 0.3) * (0.4 + lum * 1.3), 0.8);
	} else if (v_sport < 5.5) {
		return mix(c, vec3(0.42, 0.16, 0.3) * (0.25 + lum * 0.9), leafy ? 0.75 : 0.5);
	} else if (v_sport < 6.5) {
		return leafy ? mix(c, vec3(0.62, 0.78, 0.86) * (0.35 + lum * 1.2), 0.6) : c;
	}
	return c;
}

void fragment() {
	// World position, rebuilt here (not a varying: see the slots above).
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The sun's and moon's shadow maps are drawn with an orthographic
	// projection (the game camera is perspective). There, closed shapes
	// (bark, crowns, bamboo culms) cast from their far faces only, so a
	// lit face never shadows itself (the material is double-sided for the
	// leaf cards, which still cast from both sides). Since Mike's 3 Oct
	// play the far faces are told by the normal (s_nrm.w), not FRONT_FACING.
	// The near faces are told by the normal, not the winding (mirrored
	// trees): wood's normals point out (bark, culms; Mike's 3 Oct play),
	// a crown lobe's still point in.
	if (PROJECTION_MATRIX[3][3] == 1.0) {
		bool wood = mat_id < 0.5 || (mat_id > 3.5 && mat_id < 4.5);
		if ((wood && s_nrm.w > 0.0) || (mat_id > 0.5 && mat_id < 1.5 && s_nrm.w < 0.0)) {
			discard;
		}
	}
	if (mat_id > 5.5) {
		// A far tree's picture: the crown's outline, ragged by the leafy
		// speckle; the trunk under it; the season's leaf left in coarse
		// cells (a bare winter crown shows a grey haze of twigs); a dead
		// tree only its trunk.
		float x = abs(UV.x - 0.5) * 2.0 * 1.08;
		float cb = v_imp2.x;
		float t = (UV.y - cb) / max(1.0 - cb, 1e-3);
		float n = retro_tile(look_tex_leaves, UV * vec2(3.0, 5.0)).g;
		float r = imp_profile(clamp(t, 0.0, 1.0), v_imp);
		float rim = r * (0.78 + 0.44 * n);
		bool crown = t > 0.0 && x < rim;
		// A ragged rim with sky through it (1 Oct, bug 1: a smooth-edged
		// picture read as a flat dark shard at dusk): the outer half of the
		// crown keeps only what the leaf-card cutout keeps, in cells that
		// turn with the tree so neighbours differ.
		if (crown && x > rim * 0.45) {
			float holes = retro_tex(look_tex_leaf_card, UV * vec2(2.0, 3.0) + vec2(fract(inst * 0.37), fract(inst * 0.61))).a;
			if (holes < 0.5) {
				crown = false;
			}
		}
		bool trunk = UV.y < cb + 0.08 && x < max(v_imp2.y, 0.04);
		bool twigs = false;
		if (crown && (v_leaf < 0.999 || dead_v > 0.5)) {
			if (sp_hash(floor(UV * vec2(14.0, 20.0)) + inst) >= v_leaf * (1.0 - dead_v)) {
				crown = false;
				twigs = dead_v < 0.5 && n > 0.55 && t < 0.85;
			}
		}
		if (!crown && !trunk && !twigs) {
			discard;
		}
		float nk_i = look_night;
		vec3 c;
		if (crown) {
			c = sp_tiled ? mix(sp_leaf_color, sp_autumn_color, v_season.x) : COLOR.rgb;
			c *= genes * (0.7 + 0.45 * n) * mix(0.72, 1.08, clamp(t, 0.0, 1.0));
			if (sp_deciduous) {
				vec3 hsv = rgb_to_hsv(c);
				float ha = rgb_to_hsv(sp_autumn_color).x;
				float dh = fract(ha - hsv.x + 0.5) - 0.5;
				hsv.x = fract(hsv.x + dh * v_season.y - v_hshift);
				hsv.y = clamp(hsv.y * v_season.z, 0.0, 1.0);
				hsv.z = clamp(hsv.z * v_season.w, 0.0, 1.0);
				c = hsv_to_rgb(hsv);
			}
			float g = pal_greenness(c);
			c = pal_pull(c, pal_canopy, 0.55 * g);
			c = pal_pull(c, pal_grass_night, 0.7 * nk_i * g);
			c = sport_tint(c, true);
		} else {
			c = pal_bark * 0.5 * (0.75 + 0.3 * n) * (twigs ? 1.15 : 1.0);
			c = pal_pull(c, pal_bark_night, 0.6 * nk_i);
		}
		// Always past the shadow map: the plants' stand-in shade (below),
		// and no back-lit glow, so it matches the near trees it replaces.
		c *= mix(1.0, crown ? look_plant_far_shade.y : look_plant_far_shade.x, (look_shadow_reach_m > 0.0 ? 1.0 : 0.0) * (1.0 - 0.6 * look_night));
		ALBEDO = c;
		ALPHA = 1.0;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		BACKLIGHT = c * (crown && look_shadow_reach_m <= 0.0 ? 0.6 : 0.0);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
	} else {
	// The season (LeafSeason, design §AI): a thinning crown loses its
	// leaves in leaf-sized cells, a hash picking which go first, until at
	// leaf_season 0 it is bare. (Branchy trees' clusters thin by their own
	// keys in vertex().)
	// A whole leaf (2.25, PlantMeshes.leaf_blade) goes whole, by its key,
	// in vertex().
	bool blade = abs(mat_id - 2.25) < 0.1;
	if (v_leaf < 0.999 && mat_id > 0.5 && mat_id < 2.5 && !blade) {
		vec3 cell = floor(obj_pos / max(sp_leaf_m * v_leafs * 2.0, 0.25));
		if (sp_hash(cell.xy + cell.z * 17.13) >= v_leaf) {
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
		tex = retro_tile(look_tex_bark, vec2(uv.x * 3.0, uv.y * 0.15)) * 0.35 + 0.33;
		float node = fract(obj_pos.y / 0.35);
		tex.rgb *= 1.0 - 0.45 * step(0.94, node) + 0.18 * step(0.86, node) * step(node, 0.94);
	} else if (mat_id > 2.5) {
		// Vines: the leafy texture running down the strand (the vine
		// species' own tile when the tree has one, §CE).
		vec2 vuv = vec2(obj_pos.x + obj_pos.z, obj_pos.y) / look_tile_m2.y;
		tex = sp_vine_on ? texture(sp_vine_leaves, vuv) : retro_tile(look_tex_leaves, vuv);
	} else if (blade) {
		// A whole leaf with no tile of its own: a plain blade, the oval
		// inside the leaf's box (the card spans the box).
		vec2 e = (UV - vec2(0.5)) * 2.0;
		tex = vec4(vec3(0.5), step(dot(e, e), 0.95));
	} else if (mat_id > 1.5) {
		tex = retro_tex(look_tex_leaf_card, UV);
	} else if (mat_id > 0.5) {
		vec2 uv = an.y > 0.55 ? obj_pos.xz : (an.x > an.z ? obj_pos.zy : obj_pos.xy);
		tex = retro_tile(look_tex_leaves, uv / (look_tile_m2.y * v_leafs));
	} else {
		vec2 uv = an.x > an.z ? obj_pos.zy : obj_pos.xy;
		tex = retro_tile(look_tex_bark, uv / look_tile_m2.x);
	}
	// Palette: leaves toward the canopy green (§AG), bark toward the warm
	// brown.
	vec3 base = COLOR.rgb;
	if (sp_vine_on && mat_id > 2.5 && mat_id < 3.5) {
		base = sp_vine_color;
	}
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
		vec3 autumn_tint = mix(vec3(1.0), clamp(sp_autumn_color / max(sp_leaf_color, vec3(0.01)), 0.0, 4.0), v_season.x);
		// The mass tile holds a few leaves across (bigger in the shade).
		float mass_m = clamp(sp_leaf_m * v_leafs * 2.5, 0.3, 3.0);
		vec4 t;
		if (mat_id < 0.5) {
			// Bark, tiled every sp_bark_tile_m.
			vec2 uv = an.x > an.z ? obj_pos.zy : obj_pos.xy;
			t = retro_tex(sp_bark, uv / sp_bark_tile_m);
		} else if (mat_id < 1.5) {
			// A crown's surface (the hull of a tree with no branch layout:
			// the understory tiers, palms, herbs): the foliage mass over
			// its own shade, CUT like the cards (1 Oct, bug 1: a solid hull
			// read as a flat dark shard at dusk): near, the leaf cutout at
			// the leaf's own size; far, the mass tile's holes, so the hull
			// is a ragged leafy shell with sky through it.
			vec2 uv = an.y > 0.55 ? obj_pos.xz : (an.x > an.z ? obj_pos.zy : obj_pos.xy);
			vec4 m = retro_tex(sp_leaves, uv / mass_m);
			if (distance(world_pos, CAMERA_POSITION_WORLD) < SP_NEAR_M) {
				vec4 l = sp_leaf_cell(uv / (sp_leaf_m * v_leafs), inst * 3.1 + floor(uv.x / mass_m) * 7.0);
				t = vec4(l.rgb, l.a);
			} else {
				t = vec4(mix(sp_leaf_color * 0.45, m.rgb, m.a) * autumn_tint, step(0.5, m.a));
			}
		} else if (blade) {
			// A whole leaf (Mike's 3 Oct play): the leaf tile once across
			// the card, near and far; no grid, flips, blanked cells or
			// cluster outline. The mip from the tile's own texel size.
			vec2 dg = max(abs(dFdx(UV)), abs(dFdy(UV)));
			float lod = clamp(log2(max(max(dg.x, dg.y) * 48.0, 1e-4)), 0.0, look_max_mips);
			vec4 l = textureLod(sp_leaf, UV, lod);
			vec4 la = textureLod(sp_leaf_autumn, UV, lod);
			t = vec4(mix(l.rgb, la.rgb, v_season.x), l.a);
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
				vec4 l = sp_leaf_cell(cuv * card_m / (sp_leaf_m * v_leafs), inst * 3.1 + cluster_key * 17.0);
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
		if (sp_deciduous && mat_id > 0.5) {
			// The season's hue drift toward the autumn colour (yellow-green),
			// the dull stage's saturation and value, spring's buds and
			// young pale leaves.
			vec3 hsv = rgb_to_hsv(c);
			float ha = rgb_to_hsv(sp_autumn_color).x;
			float dh = fract(ha - hsv.x + 0.5) - 0.5;
			hsv.x = fract(hsv.x + dh * v_season.y - v_hshift);
			hsv.y = clamp(hsv.y * v_season.z, 0.0, 1.0);
			hsv.z = clamp(hsv.z * v_season.w, 0.0, 1.0);
			c = hsv_to_rgb(hsv);
		}
		float cg = pal_greenness(c);
		c = pal_pull(c, mat_id < 0.5 ? pal_bark_night : pal_grass_night, (mat_id < 0.5 ? 0.6 : 0.7 * cg) * nk);
		if (dead_v > 0.5 || wood_dead > 0.5) {
			c = mix(c, vec3(0.46, 0.44, 0.41), 0.75);
		}
		ALBEDO = c;
		tex.a = t.a;
	}
	ALBEDO = sport_tint(ALBEDO, (mat_id > 0.5 && mat_id < 3.5) || mat_id > 4.5);
	if (v_leafs > 1.01 && ((mat_id > 0.5 && mat_id < 2.5) || mat_id > 4.5)) {
		// Shade leaves: more chlorophyll to a leaf, a little darker.
		ALBEDO *= mix(1.0, 0.86, clamp((v_leafs - 1.0) / 0.45, 0.0, 1.0));
	}
	if (mat_id < 5.5 && f_d.z > 0.0) {
		// The gust's sheen on grass (§DA, wind.json grass.sheen): bowed
		// blades tip their lit side away, paler toward the tips.
		ALBEDO *= 1.0 + f_d.z * smoothstep(0.2, 1.0, sway_w);
	}
	if (mat_id < 0.5 && moss > 0.01) {
		// Moss on the bark: patchy, low down, on faces turned up and to one
		// side (the damp side).
		float n = retro_tile(look_tex_leaves, vec2(obj_pos.x + obj_pos.z, obj_pos.y) * 0.7).g;
		float lowness = 1.0 - clamp(obj_pos.y / 5.0, 0.0, 1.0);
		float m = smoothstep(0.45, 0.7, n * 0.9 + 0.3 * lowness + 0.25 * obj_normal.y + 0.15 * obj_normal.z + 0.4 * moss - 0.25);
		vec3 moss_col = pal_pull(pal_moss, pal_grass_night, 0.7 * nk) * retro_tile(look_tex_leaves, vec2(obj_pos.x + obj_pos.z, obj_pos.y) * 1.3).rgb * 2.0;
		ALBEDO = mix(ALBEDO, moss_col, m * moss);
	}
	// Cards, cluster cards and a tiled crown hull cut by their alpha.
	ALPHA = ((mat_id > 1.5 && mat_id < 2.5) || mat_id > 4.5 || (sp_tiled && mat_id > 0.5 && mat_id < 1.5)) ? tex.a : 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Leaves are translucent: light shining through from behind lights
	// them too, so crowns seen from below stay green instead of black.
	float leafy = max(step(0.5, mat_id) * step(mat_id, 3.5), step(4.5, mat_id));
	// Past the shadow map's reach nothing shades a plant (Mike's 3 Oct
	// play: far wood glowed, then turned navy as he walked up): a stand-in
	// shade like the ground's, eased in over the shadow map's last fifth so
	// the swap doesn't show, and back-lit leaves stop glowing there, so a
	// stand against the sun stays a dark silhouette at every distance.
	float far_k = look_shadow_reach_m > 0.0 ? smoothstep(look_shadow_reach_m * 0.8, look_shadow_reach_m, distance(world_pos, CAMERA_POSITION_WORLD)) : 0.0;
	bool wood_k = mat_id < 0.5 || (mat_id > 3.5 && mat_id < 4.5);
	ALBEDO *= mix(1.0, wood_k ? look_plant_far_shade.x : look_plant_far_shade.y, far_k * (1.0 - 0.6 * look_night));
	BACKLIGHT = ALBEDO * 0.6 * leafy * (1.0 - far_k);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float glow = look_site_glow(world_pos, 0.25) * glow_pick * smoothstep(0.3, 0.9, sway_w);
	// The ambient floor (§BD): leaves see the sky the player does.
	EMISSION = look_glow_emission(world_pos, glow * 1.0) + ALBEDO * look_floor;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
	}
}

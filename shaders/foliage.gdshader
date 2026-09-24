// Vegetation placeholders (DESIGN.md "Weather System > Physical
// expression": local wind drives foliage animation). Meshes carry their
// color in vertex RGB and how much each vertex may sway in vertex alpha
// (0 at the roots, 1 at the crown), so trunks stay put and crowns move.
// Wind comes from the live weather: `wind_vector` is set each frame on the
// one material every plant shares (PlantMeshes.material()).
shader_type spatial;
render_mode world_vertex_coords, cull_disabled;

uniform vec3 wind_vector = vec3(0.0);

void vertex() {
	float sway = COLOR.a;
	float speed = length(wind_vector);
	vec3 dir = speed > 0.01 ? wind_vector / speed : vec3(0.0);
	float phase = float(INSTANCE_ID) * 1.37;
	float gust = 0.65 + 0.35 * sin(TIME * (1.1 + speed * 0.06) + phase);
	float lean = clamp(speed * 0.04, 0.0, 0.8) * gust;
	float flutter = sin(TIME * 3.3 + phase * 2.1) * 0.05 * clamp(speed * 0.12, 0.0, 1.0);
	VERTEX += dir * (lean + flutter) * sway;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.85;
}

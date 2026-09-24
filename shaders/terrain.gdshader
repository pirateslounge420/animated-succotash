// Ground. Flat-shaded low-poly faces colored per face (vertex colors from
// TerrainChunk). `wetness` rises at night so surfaces pick up the glossy,
// wet sheen of the spec's moonlit look; by day the ground is matte.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform float wetness = 0.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = mix(0.92, 0.42, wetness);
	SPECULAR = mix(0.25, 0.6, wetness);
}

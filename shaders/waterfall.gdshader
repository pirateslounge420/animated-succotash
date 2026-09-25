// Waterfalls (TerrainChunk, from RiverNetwork's drops): a falling sheet of
// water. UV.x runs across the fall in meters, UV.y down it in meters from
// the lip; UV2 carries the fall's (height, width), so every fall shares one
// material. Streaks of white water slide down over a deep blue sheet, foam
// thickens toward the plunge pool, and the edges fray. At night the water
// glows from within like the rest (brighter than still water: the
// bioluminescent waterfalls of the references), and bright enough to bloom.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform vec3 water_color : source_color = vec3(0.1, 0.42, 0.78);
uniform vec3 foam_color : source_color = vec3(0.86, 0.94, 1.0);
varying vec3 world_pos;
varying float height;
varying float width;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	height = UV2.x;
	width = UV2.y;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// Streaks: stretched noise sliding down, faster lower down (falling).
	float speed = 2.2;
	float y = UV.y - TIME * speed;
	float streak = noise(vec2(UV.x * 2.2, y * 0.35)) * 0.6 + noise(vec2(UV.x * 5.0, y * 0.9)) * 0.4;
	float depth01 = clamp(UV.y / max(height, 0.1), 0.0, 1.0);
	float foam = smoothstep(0.52, 0.8, streak) + smoothstep(0.55, 1.0, depth01) * 0.7;
	foam = clamp(foam, 0.0, 1.0);
	ALBEDO = mix(water_color, foam_color, foam);
	ROUGHNESS = 0.4;
	// Frayed edges and a thinning lip.
	float edge = min(UV.x, width - UV.x);
	ALPHA = clamp(0.78 + 0.2 * foam, 0.0, 1.0) * smoothstep(0.0, 0.8, edge + streak * 0.6);
	// Glows from within at night (teal-cobalt, pulsing with the streaks);
	// a little by day, as the references' falls do.
	vec3 glow = mix(vec3(0.1, 0.45, 1.0), vec3(0.5, 0.85, 1.0), foam);
	EMISSION = glow * (0.08 + 1.6 * look_night) * (0.6 + 0.6 * streak);
	EMISSION += look_glow_emission(world_pos, look_site_glow(world_pos, 1.0) * 1.2);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

void light() {
	DIFFUSE_LIGHT += look_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL);
}

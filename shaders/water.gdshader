// Oceans, lakes and rivers (DESIGN.md: water is reflective, fresnel-based,
// not emissive). Looking straight down you see into the water; toward the
// horizon it turns into a mirror of the sky and whichever light dominates:
// warm sun glare by day, cool moon glint at night. That reflection of the
// cobalt night sky is what makes water read as lit from within.
//
// Day colors are pushed saturated (Frutiger Aero: shiny turquoise
// shallows, ultramarine depths). At glow ponds and other magical sites the
// water itself emits a teal/cobalt glow at night, bright enough to light
// the banks (Landmarks adds lights there too).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

#include "res://shaders/look.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

uniform vec3 deep_color : source_color = vec3(0.01, 0.14, 0.5);
uniform vec3 shallow_color : source_color = vec3(0.0, 0.62, 0.72);
uniform float wave_scale = 0.08;
uniform float wave_speed = 0.35;
uniform float wave_strength = 0.35;
uniform vec2 flow = vec2(0.0); // rivers drift along their current

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float waves(vec2 p, float t) {
	return noise(p + vec2(t, t * 0.7) + flow * t) * 0.6 + noise(p * 2.3 - vec2(t * 0.8, -t * 0.5) + flow * t) * 0.4;
}

void fragment() {
	vec2 p = UV * wave_scale; // UV is in meters
	float t = TIME * wave_speed;
	float e = 0.05;
	float h = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hy = waves(p + vec2(0.0, e), t);
	NORMAL_MAP = normalize(vec3((h - hx) / e * wave_strength, (h - hy) / e * wave_strength, 1.0)) * 0.5 + 0.5;

	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	ALBEDO = mix(shallow_color, deep_color, 0.55 + 0.45 * fresnel);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	ALPHA = mix(0.72, 0.97, fresnel);
	float glow = look_site_glow(world_pos, 1.0);
	// Lit from within: brightest looking down into it, rippling with the waves.
	EMISSION = look_glow_emission(world_pos, glow * (1.1 + 1.0 * h) * (1.0 - 0.4 * fresnel));
	ALPHA = mix(ALPHA, 0.9, glow * look_glow);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

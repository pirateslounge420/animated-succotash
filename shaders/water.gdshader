// Oceans, lakes and rivers (DESIGN.md: water is reflective, fresnel-based,
// not emissive). Looking straight down you see into the water; toward the
// horizon it turns into a mirror of the sky and whichever light dominates:
// warm sun glare by day, cool moon glint at night. That reflection of the
// cobalt night sky is what makes water read as lit from within.
//
// Day colors are pushed saturated (Frutiger Aero: shiny turquoise
// shallows, ultramarine depths). The body is painted, like old-console
// water: two copies of Look's water texture (caustic lines over a
// mottled base) drift across each other at different speeds and angles,
// with the current on rivers, so the surface shimmers with chunky
// darker mottles and bright cyan flecks where the lines cross. At glow ponds and other magical sites the
// water itself emits a teal/cobalt glow at night, bright enough to light
// the banks (Landmarks adds lights there too).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

#include "res://shaders/look.gdshaderinc"

varying vec3 world_pos;
// How far fresh water has risen in heavy rain, m (StormFX).
uniform float water_rise = 0.0;

void vertex() {
	// Water meshes are flat with their normal up; heavy rain lifts them.
	VERTEX += NORMAL * water_rise;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

uniform vec3 deep_color : source_color = vec3(0.01, 0.14, 0.5);
uniform vec3 shallow_color : source_color = vec3(0.0, 0.62, 0.72);
uniform float wave_scale = 0.08;
uniform float wave_speed = 0.35;
uniform float wave_strength = 0.35;
uniform vec2 flow = vec2(0.0); // rivers drift along their current
// Storms (StormFX): how soaked the land is (0-1: rivers and waves run
// faster) and rain falling on the surface now (0-1: drops pock it).
uniform float storm_flow = 0.0;
uniform float rain_drops = 0.0;
uniform sampler2D look_tex_water : filter_nearest_mipmap_anisotropic, repeat_enable;

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
	float t = TIME * wave_speed * (1.0 + 1.5 * storm_flow);
	float e = 0.05;
	float h = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hy = waves(p + vec2(0.0, e), t);
	vec2 slope = vec2(h - hx, h - hy) / e * wave_strength;
	if (rain_drops > 0.01) {
		// Raindrops: small pocks flickering over the surface.
		vec2 q = UV * 2.5;
		float cell = floor(TIME * 9.0);
		float d = noise(q + vec2(cell * 1.7, cell * 2.3)) - noise(q + vec2(0.13, 0.0) + vec2(cell * 1.7, cell * 2.3));
		float d2 = noise(q + vec2(cell * 1.7, cell * 2.3)) - noise(q + vec2(0.0, 0.13) + vec2(cell * 1.7, cell * 2.3));
		slope += vec2(d, d2) * 3.0 * rain_drops;
	}
	NORMAL_MAP = normalize(vec3(slope, 1.0)) * 0.5 + 0.5;

	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	ALBEDO = mix(shallow_color, deep_color, 0.55 + 0.45 * fresnel);
	// The painted body: two drifting layers of caustics, the wave height
	// nudging them so they wobble.
	vec2 drift = flow * t * 0.6;
	vec2 wob = slope * 0.05;
	float ta = texture(look_tex_water, UV * 0.3 + drift + vec2(t * 0.06, t * 0.02) + wob).r;
	float tb = texture(look_tex_water, mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * UV * 0.23 + drift * 0.8 - vec2(t * 0.03, t * 0.05) - wob).r;
	float paint = 1.0 - fresnel * 0.8; // calm toward the horizon, where it mirrors the sky
	ALBEDO *= mix(1.0, 0.72 + 0.56 * (ta + tb) * 0.5, paint);
	float fleck = smoothstep(0.62, 0.78, min(ta, tb) + 0.5 * max(ta, tb) - 0.25);
	ALBEDO = mix(ALBEDO, vec3(0.45, 0.95, 1.0), fleck * 0.55 * paint);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	ALPHA = mix(0.72, 0.97, fresnel);
	float glow = look_site_glow(world_pos, 1.0);
	// Lit from within: brightest looking down into it, rippling with the waves.
	EMISSION = look_glow_emission(world_pos, glow * (1.1 + 1.0 * h) * (1.0 - 0.4 * fresnel));
	ALPHA = mix(ALPHA, 0.9, glow * look_glow);
	// White water (rivers: UV2.x): rapids and the churn below falls. Foam
	// streaks race downstream (UV.y runs along the river, in meters) and
	// glow a little at night.
	float white = UV2.x;
	if (white > 0.01) {
		float y = UV.y * 0.45 - TIME * (2.5 + 3.5 * white) * (1.0 + storm_flow);
		float streak = noise(vec2(UV.x * 1.2, y * 0.5)) * 0.6 + noise(vec2(UV.x * 3.0, y * 1.6)) * 0.4;
		float foam = smoothstep(0.66 - 0.32 * white, 0.82, streak) * smoothstep(0.0, 0.3, white);
		ALBEDO = mix(ALBEDO, vec3(0.88, 0.95, 1.0), foam);
		ALPHA = mix(ALPHA, 0.98, foam);
		ROUGHNESS = mix(ROUGHNESS, 0.45, foam);
		EMISSION += vec3(0.3, 0.65, 1.0) * foam * look_night * 0.8;
	}
	// At night the caustic lines glow as white-blue veins (strongest
	// looking down into the water).
	float veins = smoothstep(0.62, 0.8, max(ta, tb)) + fleck;
	EMISSION += vec3(0.35, 0.65, 1.0) * veins * look_night * 0.55 * paint;
	// All water glows faintly cobalt at night, lit from within.
	EMISSION += vec3(0.06, 0.2, 0.75) * look_night * (0.45 + 0.35 * h) * (1.0 - 0.4 * fresnel);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

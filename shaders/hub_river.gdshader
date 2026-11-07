// The hub camp's river (Mike, 6 Nov: the "blue ribbon"): water that takes
// its light from the hour. It holds the sky's own colour (look_fog_low) and
// a mirror's shine, so firelight and torches glint on it after dark, and it
// runs dark with the night instead of glowing. By day it
// is still the brightest thing in view (§GB.1.3). Ripples drift downstream
// and the ground's own banks draw its shore.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

global uniform vec3 look_fog_low;
global uniform float look_night;

uniform vec3 deep_color : source_color = vec3(0.02, 0.05, 0.09);
uniform vec3 day_color : source_color = vec3(0.16, 0.50, 0.72);
// How much of the sky's colour it holds by day and at full night.
uniform float sky_day = 0.42;
uniform float sky_night = 0.09;
uniform vec2 flow = vec2(0.0, 1.0);
uniform float flow_mps = 0.5;
uniform float ripple_m = 1.6;
uniform float ripple_tilt = 0.09;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Two layers, stretched across the flow and running down it.
float ripples(vec2 p) {
	vec2 side = vec2(-flow.y, flow.x);
	vec2 q = vec2(dot(p, side), dot(p, flow) - TIME * flow_mps) / ripple_m;
	return noise(q * vec2(1.0, 2.2)) * 0.6 + noise(q * vec2(2.3, 4.1) + 7.3 - vec2(0.0, TIME * 0.2)) * 0.4;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float h = ripples(p);
	float e = 0.15;
	vec3 up = normalize(vec3((h - ripples(p + vec2(e, 0.0))) / e * ripple_tilt, 1.0, (h - ripples(p + vec2(0.0, e))) / e * ripple_tilt));
	NORMAL = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz);
	float day = 1.0 - look_night;
	ALBEDO = mix(deep_color, day_color, day);
	ROUGHNESS = 0.14;
	SPECULAR = 0.6;
	float glint = smoothstep(0.55, 0.8, h);
	EMISSION = look_fog_low * mix(sky_night, sky_day, day) * (0.35 + 0.9 * h + 1.6 * glint);
	ALPHA = 0.94;
}

// The Amorphophallus' parts that come and go with its life (AroidGarden,
// docs/design/AROID_LIFE.md): the shoot spike, the inflorescence bud, the
// peduncle, the spathe, the spadix's appendix, the pollen, the berries.
// One MultiMesh per part per species per chunk; each instance carries its
// colours: COLOR (linear) the main one; INSTANCE_CUSTOM.rgb a second one
// and .a what to do with them:
//   0 plain                  the main colour
//   1 mottled, 2 spotted,    the cataphylls' or peduncle's pattern (the
//   3 streaked, 4 lichen,    species' petiole grammar): the second colour
//   5 warty                  laid over the main by pattern, in the part's
//                            own frame so it stays put
//   10 two-sided             the spathe: main outside, second inside (the
//                            mesh's UV.x is 1 on the inner surface)
//   11 berries               the main colour, each berry shaded round
//   12 pollen                the main colour, a little bright
// Vertex-lit like the creatures and props (Lambert, no specular, Look),
// cooled toward the night palette after dark, fogged like everything else.
// The tall parts lean with the wind by their height (plant_wind).
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_disabled;

#include "res://shaders/look.gdshaderinc"
#include "res://shaders/palette.gdshaderinc"

global uniform vec3 plant_wind;

varying vec3 world_pos;
varying vec3 v_obj;
varying vec4 v_c2;
varying flat float v_mode;

float ap_hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float ap_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(ap_hash(i), ap_hash(i + vec3(1, 0, 0)), f.x), mix(ap_hash(i + vec3(0, 1, 0)), ap_hash(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(ap_hash(i + vec3(0, 0, 1)), ap_hash(i + vec3(1, 0, 1)), f.x), mix(ap_hash(i + vec3(0, 1, 1)), ap_hash(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	v_obj = VERTEX;
	v_c2 = INSTANCE_CUSTOM;
	v_mode = INSTANCE_CUSTOM.a;
	// Lean with the wind by the square of the height up the part.
	float speed = length(plant_wind);
	vec3 up = MODEL_MATRIX[1].xyz;
	float h = length(up);
	float k = clamp(VERTEX.y, 0.0, 1.2);
	vec3 bend = speed > 0.01 ? plant_wind / speed * clamp(speed * 0.01, 0.0, 0.12) * h * k * k : vec3(0.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + bend * (0.8 + 0.2 * sin(TIME * 1.7 + float(INSTANCE_ID)));
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec3 c2 = v_c2.rgb;
	float mode = v_mode;
	// The pattern, in the part's own (unit) frame, stretched along its
	// height like the petiole's blotches.
	vec3 q = v_obj * vec3(6.0, 2.5, 6.0);
	if (mode > 0.5 && mode < 1.5) {
		float n = ap_noise(q) * 0.7 + ap_noise(q * 2.3) * 0.3;
		c = mix(c, c2, smoothstep(0.52, 0.6, n));
	} else if (mode > 1.5 && mode < 2.5) {
		float n = ap_noise(q * 2.2);
		c = mix(c, c2, smoothstep(0.68, 0.72, n));
	} else if (mode > 2.5 && mode < 3.5) {
		float s = ap_noise(vec3(atan(v_obj.z, v_obj.x) * 5.0, v_obj.y * 0.6, 0.0));
		c = mix(c, c2, smoothstep(0.55, 0.62, s));
	} else if (mode > 3.5 && mode < 4.5) {
		float n = ap_noise(q * 1.4);
		float rim = smoothstep(0.58, 0.61, n) - smoothstep(0.61, 0.66, n);
		c = mix(c, c2, smoothstep(0.6, 0.64, n));
		c = mix(c, c * 0.45, rim);
	} else if (mode > 4.5 && mode < 5.5) {
		float n = ap_noise(q * 3.0);
		c = mix(c, c2, smoothstep(0.7, 0.74, n));
		c *= 0.85 + 0.3 * n;
	} else if (mode > 9.5 && mode < 10.5) {
		c = UV.x > 0.5 ? c2 : c;
	} else if (mode > 10.5 && mode < 11.5) {
		c *= 0.7 + 0.5 * clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	}
	c = pal_pull(c, pal_bark_night, 0.45 * look_night);
	ALBEDO = c;
	if (mode > 11.5 && mode < 12.5) {
		EMISSION = c * 0.25;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

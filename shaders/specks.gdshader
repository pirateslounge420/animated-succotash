// Specks thrown up from a fire (design 3 Oct §CZ, look.json fire.specks):
// they replace the embers' steady loop on the campfires (the torch keeps
// its own, §CP). A MultiMesh of unit quads, every transform identity,
// sitting at the fire's foot; Campfire throws them on a random clock and on
// every pop of the fire's sound, writing each speck's slot:
// INSTANCE_CUSTOM r its birth (on `now`, the fire's clock, set each frame),
// g and b seeds, a its kind (0-0.5 a spark, 1-1.5 ash) plus a seed. The
// vertex stage flies it from those: out at its own speed inside cone_deg
// of straight up, slowing as it climbs (drag a second), curling sideways
// (curl_m), drifting with the gusted wind at the fire (plant_wind and the
// gust field, wind.gdshaderinc; x wind_share),
// never above height_max_m, gone after its life. Drawn a camera-facing
// square `px` internal pixels across at any distance. A spark is the
// flame's orange (spark_col, pushed past 1 so it glints in the bloom)
// cooling to red (spark_cool), then gone; ash is a pale blue-grey flake
// (the hearth smoke's, ash_col, never a neutral grey) that does not glow,
// lives longer and flutters.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

global uniform vec3 plant_wind;
#include "res://shaders/wind.gdshaderinc"
uniform float now = 0.0;
uniform float px = 1.0;
uniform vec2 speed_mps = vec2(0.5, 2.2);
uniform float cone_deg = 35.0;
uniform float drag = 0.9;
uniform float curl_m = 0.15;
uniform float wind_share = 1.0;
uniform vec2 life_s = vec2(0.8, 3.5);
uniform float height_max_m = 3.0;
uniform float ash_life_scale = 1.6;
uniform float spread_m = 0.2;
uniform vec3 spark_col = vec3(2.0, 0.5, 0.02);
uniform vec3 spark_cool = vec3(0.8, 0.09, 0.02);
uniform vec3 ash_col = vec3(0.27, 0.35, 0.58);

varying float v_t;
varying float v_ash;

float h(float x) {
	return fract(sin(x * 91.345) * 47453.5453);
}

void vertex() {
	vec4 s = INSTANCE_CUSTOM;
	float ash = s.a >= 0.75 ? 1.0 : 0.0;
	float s3 = fract(s.a) * 2.0;
	float age = now - s.r;
	float life = mix(life_s.x, life_s.y, s.b) * (ash > 0.5 ? ash_life_scale : 1.0);
	v_t = age / life;
	v_ash = ash;
	// Out inside the cone at its own speed (ash a little slower).
	float az = s.g * 6.2832;
	float tilt = radians(cone_deg) * sqrt(h(s.g + s.b));
	vec3 dir = vec3(sin(tilt) * cos(az), cos(tilt), sin(tilt) * sin(az));
	float v0 = mix(speed_mps.x, speed_mps.y, h(s.b + 3.7)) * (ash > 0.5 ? 0.7 : 1.0);
	float a = max(age, 0.0);
	float k = max(drag, 0.01);
	vec3 p = dir * v0 * (1.0 - exp(-k * a)) / k;
	p.y = min(p.y, height_max_m);
	// Where it left the bed, the curl that grows as it climbs, and ash's
	// flutter.
	p.xz += vec2(cos(az * 1.7), sin(az * 1.7)) * spread_m * s3;
	float w = a * (2.0 + 2.0 * s.b) + az;
	p.x += sin(w) * curl_m * min(a, 1.5);
	p.z += cos(w * 0.8) * curl_m * min(a, 1.5);
	if (ash > 0.5) {
		p.x += sin(a * 7.0 + az) * 0.05;
		p.y -= 0.04 * abs(sin(a * 5.0 + az));
	}
	// The gust field at the fire, not just the mean (design §DA, wind.json
	// specks.read_gust_field): a gust carries the specks off harder.
	vec3 gust_w = wind_gust_vec(MODEL_MATRIX[3].xyz, plant_wind, normalize(MODEL_MATRIX[1].xyz)).xyz;
	vec3 world = (MODEL_MATRIX * vec4(p, 1.0)).xyz + gust_w * wind_share * a;
	vec4 v = VIEW_MATRIX * vec4(world, 1.0);
	float size = px * 2.0 * max(-v.z, 0.01) / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	v.xy += VERTEX.xy * size;
	POSITION = PROJECTION_MATRIX * v;
	// Not born yet, or spent: off screen.
	if (age < 0.0 || v_t > 1.0) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	}
}

void fragment() {
	if (v_ash > 0.5) {
		ALBEDO = ash_col;
	} else {
		// The flame's orange cooling to red over its life, and gone.
		ALBEDO = mix(spark_col, spark_cool, smoothstep(0.3, 0.9, v_t));
	}
	ALPHA = v_t < 0.97 ? 1.0 : 0.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

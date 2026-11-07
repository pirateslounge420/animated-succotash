// The rolling ground fog (Mike, 6 Nov: "i want it more rolling on the ground
// level"). One full-screen pass over the opaque world. Each pixel walks its
// view ray through a low layer above the ground and adds up the fog it
// crosses. Two drifting noise fields set how high the layer stands at each
// spot and where it thins, so banks swell and roll past at knee to chest
// height, pool in low ground and leave the tree tops clear.
// Numbers: look.json dream_sky.fog.ground (Surface).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

global uniform vec3 look_fog_color;
global uniform vec3 look_fog_low;
global uniform float look_night;
global uniform float look_ground_m;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float top_m = 2.6;
uniform float density = 0.16;
uniform float near_m = 2.0;
uniform float reach_m = 70.0;
uniform float scale_m = 26.0;
uniform float drift_mps = 0.5;
uniform vec2 wind = vec2(0.8, 0.6);
uniform float amount = 1.0;
uniform float sky_share = 0.45;
uniform float night_sky_share = 0.1;

const int STEPS = 10;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 hit = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 dir = normalize(hit - cam);
	float t0 = near_m;
	float t1 = min(length(hit - cam), reach_m);
	// Only the stretch of the ray inside the layer.
	float ceil_y = look_ground_m + top_m * 1.5;
	if (abs(dir.y) > 1e-4) {
		float at_ceil = (ceil_y - cam.y) / dir.y;
		if (cam.y > ceil_y) {
			t0 = max(t0, at_ceil);
		} else if (dir.y > 0.0) {
			t1 = min(t1, at_ceil);
		}
	}
	float tau = 0.0;
	if (t1 > t0) {
		float step_m = (t1 - t0) / float(STEPS);
		// A different start per pixel, so the steps don't show as bands.
		float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		vec2 drift = wind * drift_mps * TIME;
		for (int i = 0; i < STEPS; i++) {
			vec3 p = cam + dir * (t0 + (float(i) + dither) * step_m);
			float big = texture(noise_tex, (p.xz - drift) / (scale_m * 2.3)).r;
			float roll = texture(noise_tex, (p.xz - drift * 1.7 + big * 9.0) / scale_m + vec2(0.37, 0.11)).r;
			float high = top_m * (0.15 + 2.0 * big * big + 0.6 * roll);
			float h = (p.y - look_ground_m) / max(high, 0.05);
			float body = 1.0 - smoothstep(0.15, 1.0, h);
			tau += body * smoothstep(0.38, 0.68, roll * 0.55 + big * 0.55) * step_m;
		}
	}
	vec3 lit = mix(look_fog_color, look_fog_low, mix(sky_share, night_sky_share, look_night));
	ALBEDO = lit;
	ALPHA = (1.0 - exp(-tau * density * amount)) * 0.94;
	FOG = vec4(0.0);
}

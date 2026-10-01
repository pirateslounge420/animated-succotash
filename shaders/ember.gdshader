// Embers (design §BZ): single-pixel sparks drifting up from the coals.
// For a MultiMeshInstance3D of unit quads (1x1, centred, every transform
// identity, use_custom_data on) sitting at the coals; INSTANCE_CUSTOM holds
// four random seeds in 0..1 per ember. The vertex stage does all the work
// from TIME and the seeds, so nothing runs on the CPU per frame: each
// ember loops through a life of its own length, starts somewhere round the
// coals, climbs, wobbles, and is drawn as a camera-facing square exactly
// `px` internal pixels across whatever the distance. The fragment is a
// flat colour, on for most of the life, off at the end, with one blink.
// The colour is a linear scene colour (Campfire.emissive: look.json
// fire.flame.embers.color on screen, its full channels pushed past 1.0 by
// embers.hdr so a spark glints in the bloom).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color = vec3(2.22, 0.48, 0.016); // #FFB020 on screen, red pushed x2
uniform float px = 1.0;          // size in internal screen pixels
uniform float rise_mps = 0.6;    // climb speed
uniform float life_min = 1.0;    // seconds alive, per ember from its seed
uniform float life_max = 2.5;
uniform float spread_m = 0.25;   // radius round the coals they start in
uniform float wobble_m = 0.08;   // sideways drift as they climb
uniform float phase = 0.0;

varying float v_t;     // 0..1 of this ember's life
varying float v_blink; // the moment (in life) it blinks off

void vertex() {
	vec4 s = INSTANCE_CUSTOM;
	float life = mix(life_min, life_max, s.r);
	float t = fract(TIME / life + s.g + phase);
	// Where it starts round the coals, and how far it has climbed.
	float ang = s.b * 6.2832;
	vec3 p = vec3(cos(ang), 0.0, sin(ang)) * spread_m * s.a;
	p.y = t * life * rise_mps;
	// Sideways wobble that grows as it climbs.
	float w = TIME * (1.5 + s.r) + s.b * 6.2832;
	p.x += sin(w) * wobble_m * t;
	p.z += cos(w * 0.7 + s.a * 6.2832) * wobble_m * t;
	// To view space, then grow the quad's corners by px pixels at this depth
	// and project ourselves (writing POSITION skips the built-in projection).
	vec4 v = MODELVIEW_MATRIX * vec4(p, 1.0);
	float size = px * 2.0 * max(-v.z, 0.01) / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	v.xy += VERTEX.xy * size;
	POSITION = PROJECTION_MATRIX * v;
	v_t = t;
	v_blink = 0.1 + s.a * 0.7;
}

void fragment() {
	ALBEDO = color;
	// On, then off for the last part of its life, and a short blink off
	// around its own moment so the embers twinkle. Nothing soft.
	float on = v_t < 0.85 ? 1.0 : 0.0;
	float blink = abs(v_t - v_blink) < 0.03 ? 0.0 : 1.0;
	ALPHA = on * blink;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

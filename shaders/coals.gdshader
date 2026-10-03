// The bed of coals at the foot of a fire (design 3 Oct §CZ, look.json
// fire.coals): a low mound drawn on a coarse texel grid (texels_m a metre),
// char crust with hot patches in the flame's own colour bands. The whole
// bed breathes slowly (`breath`, set each frame by Campfire.flicker so the
// fire's light can breathe with it), each patch of coals brightens and
// dims on its own clock (patch_hz, patch_amount), out of step with its
// neighbours, and the hot cracks crawl (crawl). `air` (0-1) is a gust of
// wind, a poke or a fresh piece laid on: the bed flares by air_brighten
// and settles (Campfire). `heat` is the burn (FireStore: 1 flames, less
// low, less again at embers, 0 out: all char). Unshaded: coals give off
// light; the char doesn't glow (it is near black). For a PlaneMesh of
// bed_width_m, subdivided, lying flat at the fire's foot.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 band0 = vec3(2.0, 1.9, 0.3); // the flame's bands, linear on-screen colours (Campfire.emissive)
uniform vec3 band1 = vec3(1.6, 0.6, 0.05);
uniform vec3 band2 = vec3(0.8, 0.1, 0.02);
uniform vec3 band3 = vec3(0.1, 0.004, 0.0);
uniform vec3 char_col = vec3(0.01, 0.004, 0.002);
uniform float texels_m = 32.0;
uniform float width_m = 0.6;
uniform float dome_m = 0.06;
uniform vec2 patch_hz = vec2(0.6, 1.4);
uniform float patch_amount = 0.35;
uniform float crawl = 0.06;
uniform float air_brighten = 0.25;
uniform float breath = 1.0;
uniform float air = 0.0;
uniform float heat = 1.0;
uniform float phase = 0.0;

varying vec2 v_m; // position on the bed, metres from its middle

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_m = VERTEX.xz;
	float r = length(VERTEX.xz) / (width_m * 0.5);
	VERTEX.y += dome_m * max(1.0 - r * r, 0.0);
}

void fragment() {
	// The texel this pixel falls in.
	vec2 cell = floor(v_m * texels_m);
	vec2 c = (cell + 0.5) / texels_m;
	float half_w = width_m * 0.5;
	// A ragged round edge, texel by texel.
	float r = length(c) / half_w;
	if (r > 0.82 + 0.18 * h21(cell + 7.0)) {
		discard;
	}
	// The hot cracks: a noise that crawls slowly over the bed.
	vec2 drift = vec2(TIME * crawl, TIME * crawl * 0.6) * texels_m;
	float crack = vnoise((cell + drift) * 0.35 + phase);
	float base = smoothstep(0.35, 0.85, crack) * (1.0 - 0.35 * r);
	// Each patch of coals (4 texels) on its own clock.
	vec2 pc = floor(cell / 4.0);
	float hz = mix(patch_hz.x, patch_hz.y, h21(pc + 3.1));
	float pk = 1.0 + patch_amount * sin(6.2832 * (hz * TIME + h21(pc + 9.7)) + phase);
	float t = base * pk * breath * (1.0 + air_brighten * air) * heat;
	t += 0.06 * h21(cell) * heat;
	vec3 col = char_col;
	if (t > 0.78) {
		col = band0;
	} else if (t > 0.58) {
		col = band1;
	} else if (t > 0.36) {
		col = band2;
	} else if (t > 0.18) {
		col = band3;
	}
	ALBEDO = col;
}

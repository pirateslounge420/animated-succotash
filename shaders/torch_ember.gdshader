// The torch's head: the burnt end of the stick, smouldering (Mike, 3 Oct:
// "more of a glowing ember"; then "less like a ball on the end and more
// like a burned end of a stick: it shouldn't be rounded"). The mesh is the
// stick's own last few centimetres (Torch._burnt_end_mesh: six-sided, a
// little thinner toward a jagged, broken tip), in metres in its own frame,
// y up from where it meets the wood. Black char along it, grey ash flecks,
// heat showing through its cracks and growing toward the torn tip, the tip
// itself glowing most; all of it breathing with the torch's light
// (Torch.ember_glow sets `glow` from the same pulse it gives the light).
// Nothing is soft, like the fire (§BZ): read on a coarse texel grid and
// posterised to the fire's flat bands (look.json fire.flame.bands, set by
// Campfire.emissive: ON-SCREEN colours, the core and the gold pushed past
// 1.0 so they bloom); the char and ash unlit and dark.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D look_grain_soft : filter_nearest, repeat_enable; // Look.grain(): 64x64 grey noise
uniform float texels_m = 150.0; // texels a metre on the burnt end
uniform float length_m = 0.07;  // how long the burnt end is
uniform float crawl = 0.06;     // how fast the heat crawls (noise units a second)
uniform float glow = 1.0;       // 0 cold .. 1 full .. more when the air feeds it (Torch)
uniform float phase = 0.0;      // per-torch offset so no two crawl alike
uniform vec3 band0 = vec3(1.97, 1.93, 0.099); // core, #FEFC54 on screen
uniform vec3 band1 = vec3(1.5, 0.435, 0.028); // gold, #FCA82C
uniform vec3 band2 = vec3(0.879, 0.101, 0.026); // orange, #E6552A
uniform vec3 band3 = vec3(0.113, 0.004, 0.0); // deep red, #5A0A00
uniform vec3 char_col = vec3(0.012, 0.008, 0.006); // the char
uniform vec3 ash_col = vec3(0.045, 0.042, 0.04);   // grey ash flecks

varying vec3 v_obj;
varying float v_cap; // 1 on the broken tip's faces

void vertex() {
	v_obj = VERTEX;
	v_cap = NORMAL.y > 0.5 ? 1.0 : 0.0;
}

void fragment() {
	// On whole texels, in metres along the stick.
	vec3 g = floor(v_obj * texels_m) / texels_m;
	float t = TIME * crawl + phase;
	float along = clamp(v_obj.y / max(length_m, 1e-3), 0.0, 1.0);
	float n1 = texture(look_grain_soft, g.xz * 9.0 + vec2(g.y * 7.0, t)).r;
	float n2 = texture(look_grain_soft, vec2(g.x + g.z, g.y) * 8.0 + vec2(t * -0.7, 0.5)).r;
	// Cracks: where the two noises cross the middle, the heat shows,
	// more of them toward the tip.
	float crack = (1.0 - smoothstep(0.0, 0.14, abs(n1 - n2))) * smoothstep(0.15, 0.75, along);
	float tip = smoothstep(0.55, 1.0, along);
	float heat = (crack * 0.7 + tip * 0.55 + v_cap * 0.45 + n1 * 0.2) * glow;
	vec3 col = n2 > 0.72 ? ash_col : char_col;
	if (heat > 0.98) {
		col = band0;
	} else if (heat > 0.82) {
		col = band1;
	} else if (heat > 0.64) {
		col = band2;
	} else if (heat > 0.47) {
		col = band3;
	}
	ALBEDO = col;
}

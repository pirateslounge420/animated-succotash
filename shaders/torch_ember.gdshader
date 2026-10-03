// The torch's head as a glowing ember (Mike, 3 Oct: "instead of the
// current fire animation, more of a glowing ember"). A small lumpy coal
// at the stick's head: a dark char crust with heat showing through its
// cracks, crawling slowly over it, the whole coal breathing brighter and
// dimmer with the torch's light (Torch.ember_glow: the code sets `glow`
// from the same pulse it gives the light, so the coal and the light on
// the world breathe together). Nothing is soft, like the fire (§BZ): the
// heat is read on a coarse texel grid in the head's own frame and
// posterised to the fire's flat bands (look.json fire.flame.bands, set by
// Campfire.emissive: ON-SCREEN colours, the core and the gold pushed past
// 1.0 so they bloom), the char under them dark and unlit.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D look_grain_soft : filter_nearest, repeat_enable; // Look.grain(): 64x64 grey noise
uniform float texels = 7.0;    // texels across the head's radius
uniform float crawl = 0.06;    // how fast the heat crawls over it (noise units a second)
uniform float glow = 1.0;      // 0 cold .. 1 full .. more when the air feeds it (Torch)
uniform float phase = 0.0;     // per-torch offset so no two crawl alike
uniform vec3 band0 = vec3(1.97, 1.93, 0.099); // core, #FEFC54 on screen
uniform vec3 band1 = vec3(1.5, 0.435, 0.028); // gold, #FCA82C
uniform vec3 band2 = vec3(0.879, 0.101, 0.026); // orange, #E6552A
uniform vec3 band3 = vec3(0.113, 0.004, 0.0); // deep red, #5A0A00
uniform vec3 char_col = vec3(0.012, 0.007, 0.005); // the crust

varying vec3 v_obj;

void vertex() {
	v_obj = VERTEX;
}

void fragment() {
	// The head's own frame on a coarse grid: every step on whole texels.
	vec3 g = floor(v_obj * texels) / texels;
	float t = TIME * crawl + phase;
	float n1 = texture(look_grain_soft, g.xz * 0.61 + vec2(g.y * 0.37, t)).r;
	float n2 = texture(look_grain_soft, g.zy * 0.43 + vec2(t * -0.7, g.x * 0.29) + 0.5).r;
	// Cracks: where the two noises cross the middle, the heat shows.
	float crack = 1.0 - smoothstep(0.0, 0.16, abs(n1 - n2));
	// Hotter toward the tip, where the air reaches it.
	float tip = clamp(v_obj.y * 0.8 + 0.5, 0.0, 1.0);
	float heat = (crack * 0.75 + n1 * 0.35 + tip * 0.2) * glow;
	vec3 col = char_col;
	if (heat > 0.95) {
		col = band0;
	} else if (heat > 0.8) {
		col = band1;
	} else if (heat > 0.62) {
		col = band2;
	} else if (heat > 0.45) {
		col = band3;
	}
	ALBEDO = col;
}

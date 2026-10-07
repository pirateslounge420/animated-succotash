// The pitch torch's wrap (design 6 Oct §EZ.2, PitchTorch; torch.json
// pitch_head): the stick's top wound in bands of fibre or bark and soaked
// in pine pitch or birch tar (§EH: no metal). The mesh is PitchTorch's:
// six flat sides, in metres in its own frame, y up the stick from where
// the wrap starts (0) to its flat top (length_m), each band a strip whose
// lower edge stands proud; below y 0, the drips running down the stick.
//
// Painted, not lit (the R-rules: no shine, no specular, no normal map):
// the colours are the tar's own, on whole texels (texels_m a metre) like
// every surface. Each band's rows (`rows` texels tall): its proud lower
// edge a shade lighter (edge_col, the strip's edge), the rest near-black
// pitch with a few tar flecks. Lit (`heat` 1, PitchTorch.set_lit) the top
// band thins toward the coal: a row half-way, then dark amber (thin_col)
// bubbling under the coal (the bubbles crawl). Unlit, the top band is
// pitch like the rest. The colours arrive as scene colours that land on
// the screen as torch.json pitch_head.colors (Campfire.emissive).
//
// Light only shows the paint (light() below): the same on every face (no
// shading across the head, no specular), and never brighter than the
// paint, so by its own flame or a hearth the head is its painted colours
// (a firelit tint at the edge of a light), and in the dark it is dark like
// everything that gives off no light (R8).
//
// It draws after a hearth's pool of firelight on the floor (Campfire's
// ground decals, fire_glow_warm and fire_glow, drawn toward the camera so
// they paint over whatever lies low by the fire): ALPHA 1 puts it in the
// transparent pass, PitchTorch gives it a later render_priority, and it
// still writes depth. So the bundle lying by the hearth shows its pitch,
// not the decal's orange.
shader_type spatial;
render_mode cull_back, shadows_disabled, specular_disabled, depth_draw_always;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain_soft : filter_nearest, repeat_enable; // Look.grain(): 64x64 grey noise
uniform float texels_m = 150.0; // texels a metre (pitch_head.head.texels_m)
uniform float length_m = 0.12;  // the wrap's length (pitch_head.head.length_m)
uniform float bands = 4.0;      // how many strips (pitch_head.head.bands)
uniform float rows = 5.0;       // texel rows a band (PitchTorch: its height on the texel grid)
uniform float heat = 0.0;       // 0 unlit .. 1 lit: the top band thins under the coal
uniform float phase = 0.0;      // per-torch offset so no two wraps fleck alike
uniform vec3 pitch_col = vec3(0.0068, 0.0049, 0.0032); // #17110C on screen
uniform vec3 thin_col = vec3(0.098, 0.029, 0.0049);    // #5C3010
uniform vec3 edge_col = vec3(0.022, 0.012, 0.0062);    // #2A1C12

varying vec3 v_obj;
varying vec3 v_world;

void vertex() {
	v_obj = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// On whole texels: the flecks and bubbles are read off the grid.
	vec3 g = floor(v_obj * texels_m) / texels_m;
	float n = texture(look_grain_soft, g.xz * 7.0 + vec2(g.y * 5.0 + phase, phase * 0.37)).r;
	vec3 col = pitch_col;
	if (v_obj.y < -0.0005) {
		// A drip of pitch down the stick: the same tar, a fleck here and there.
		col = n > 0.82 ? edge_col : pitch_col;
	} else {
		float bh = length_m / max(bands, 1.0);
		float band = min(floor(v_obj.y / bh), bands - 1.0);
		float f = clamp((v_obj.y - band * bh) / bh, 0.0, 0.9999);
		float row = floor(f * rows);
		// The strip's proud lower edge (and the ledge under it), then pitch.
		col = row < 0.5 ? edge_col : (n > 0.8 ? edge_col : pitch_col);
		if (band > bands - 1.5 && heat > 0.5) {
			// Lit, the top band thins toward the coal: half-way, then dark
			// amber, bubbling (dark flecks crawl through it).
			float b = texture(look_grain_soft, g.xz * 9.0 + vec2(g.y * 3.0 - phase, TIME * 0.15)).r;
			if (row >= rows - 3.0) {
				col = b > 0.8 ? pitch_col : thin_col;
			} else if (row >= 1.0) {
				col = mix(pitch_col, thin_col, 0.45);
			}
		}
	}
	ALBEDO = col;
	ALPHA = 1.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(v_world, CAMERA_POSITION_WORLD);
}

void light() {
	// However the face is turned, up to the paint itself (1/PI undoes
	// LIGHT_COLOR's PI, as Lambert does).
	DIFFUSE_LIGHT = min(DIFFUSE_LIGHT + LIGHT_COLOR * ATTENUATION / PI, vec3(1.0));
}

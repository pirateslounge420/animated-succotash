// The fire: one pixel flame (design §BZ). One camera-facing card per fire
// (it turns only about its own up axis, the fire's up on the planet). Grey
// noise scrolls up through a teardrop mask, round at the base and drawn to
// a point, licked sideways and torn at the tip. Nothing is soft: the heat
// is posterised to four flat bands, the alpha is a hard cut, and every
// step happens on a 32x48 texel grid (the UV is snapped to it first and
// the scroll moves in whole texel rows), so the card is crunchy at any
// distance; the 480p frame does the rest. With `low` the bands collapse to
// reds and the mask shrinks raggedly: a low fire is a red flicker.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D look_grain_soft : filter_nearest, repeat_enable; // Look.grain(): 64x64 grey noise
uniform vec2 texels = vec2(32.0, 48.0);   // the card's texel grid (look.json fire.flame.texels)
uniform float scroll = 1.6;               // noise scroll, card heights per second (noise_scroll_per_s, x torch scroll_scale)
uniform float phase = 0.0;                // per-fire offset so fires don't move together
uniform vec3 band0 : source_color = vec3(1.0, 0.914, 0.627); // core  #FFE9A0
uniform vec3 band1 : source_color = vec3(1.0, 0.69, 0.125);  // #FFB020
uniform vec3 band2 : source_color = vec3(1.0, 0.29, 0.0);    // #FF4A00
uniform vec3 band3 : source_color = vec3(0.353, 0.039, 0.0); // edge #5A0A00
uniform vec3 low0 : source_color = vec3(1.0, 0.29, 0.0);     // the collapsed (low fire) bands: #FF4A00
uniform vec3 low1 : source_color = vec3(0.541, 0.102, 0.0);  // #8A1A00
uniform vec3 low2 : source_color = vec3(0.227, 0.031, 0.0);  // #3A0800
uniform float low = 0.0;                  // 0 = full fire, 1 = collapsed to a red flicker

void vertex() {
	// Billboard about the card's own up axis only: the card stays standing
	// on its bottom edge and swings to face the camera.
	vec3 up = MODEL_MATRIX[1].xyz;
	float h = length(up);
	up /= h;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	vec3 right = cross(up, to_cam);
	right = length(right) > 1e-4 ? normalize(right) : normalize(MODEL_MATRIX[0].xyz);
	vec3 fwd = cross(right, up);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0), vec4(up * h, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	// Snap to the texel grid first; everything below reads from q, so the
	// card is made of texels.x by texels.y flat squares.
	vec2 q = (floor(UV * texels) + 0.5) / texels;
	float x = q.x * 2.0 - 1.0; // -1 left edge, 1 right edge
	float y = 1.0 - q.y;       // 0 at the base, 1 at the tip
	// The scroll climbs in whole texel rows, so the fire steps instead of
	// sliding: one slow, large octave and one faster, smaller one.
	float raw = TIME * scroll + phase;
	float t1 = floor(raw * texels.y) / texels.y;
	float t2 = floor(raw * 1.9 * texels.y) / texels.y;
	float n1 = texture(look_grain_soft, vec2(q.x * 0.6 + phase, (y - t1) * 0.55)).r - 0.5;
	float n2 = texture(look_grain_soft, vec2(q.x * 1.3 - phase, (y - t2) * 1.2)).r - 0.5;
	// Licked sideways, more toward the tip and wilder when low; the height
	// breathes, and a low fire's mask shrinks raggedly.
	x += (n1 * 0.9 + n2 * 0.35) * y * (1.0 + low * 0.8);
	y += n2 * 0.12 * y;
	y *= 1.0 + low * (0.3 + 0.4 * n2);
	// Teardrop: round at the base, drawn to a point.
	float width = sqrt(clamp(y / 0.16, 0.0, 1.0)) * pow(clamp(1.0 - y, 0.0, 1.0), 0.85);
	float d = abs(x) / max(width, 1e-3); // 0 on the spine, 1 at the edge
	// Hard body, and a torn tip: flecks break off where the noise says so.
	float body = step(d, 1.0) * step(0.12, width + n2 * 0.3);
	// Heat: how deep inside the mask, hotter low and in the centre.
	float heat = clamp((1.0 - d) * (1.1 - y * 0.8), 0.0, 1.0);
	// Posterised: four flat bands with hard cuts. A small pale heart, most
	// of the flame gold and orange, a thin dark edge; low fires go red.
	vec3 c0 = mix(band0, low0, low);
	vec3 c1 = mix(band1, low1, low);
	vec3 c2 = mix(band2, low2, low);
	vec3 c3 = mix(band3, low2, low);
	ALBEDO = heat > 0.72 ? c0 : (heat > 0.45 ? c1 : (heat > 0.2 ? c2 : c3));
	ALPHA = body;
	ALPHA_SCISSOR_THRESHOLD = 0.5; // a hard cut, so the card writes depth
}

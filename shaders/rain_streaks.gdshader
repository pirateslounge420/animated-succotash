// Rain as long straight vertical streaks in the internal 480-line frame
// (design §BU, 1 Oct, Mike's reference frames): a canvas overlay under the
// post grade, so the streaks take the grade and the dither like everything
// else. Each screen column rolls its own streaks down at its own pace;
// more columns light up as the rain thickens (dense in a storm), and the
// wind leans them a little. Nothing else: no splashes, no blur.
shader_type canvas_item;

uniform float intensity = 0.0; // 0-1, from the local rain and storm
uniform float lean = 0.0; // px of sideways drift per px of fall (the wind)
uniform vec3 streak_color : source_color = vec3(0.78, 0.86, 1.0);
uniform float lines = 480.0; // the internal frame's lines
uniform float speed = 2.2; // screens per second
uniform float sheltered = 0.0; // 0-1: under cover the rain thins

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	// Work in internal pixels so a streak is one pixel wide whatever the
	// window.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = vec2(UV.x * lines * aspect, UV.y * lines);
	float a = 0.0;
	// Two layers of columns: a far, finer, slower one and a near one.
	for (int layer = 0; layer < 2; layer++) {
		float fl = float(layer);
		float spacing = mix(3.0, 5.0, fl);
		float sp = speed * mix(0.7, 1.0, fl);
		float x = p.x - p.y * lean * mix(0.5, 1.0, fl);
		float col = floor(x / spacing);
		float h = hash(col + fl * 77.0);
		// Which columns rain: more of them as the rain thickens.
		float on = step(h, intensity * (1.0 - 0.7 * sheltered));
		// Along the column: a streak of len px every period px, rolling down.
		float period = mix(70.0, 140.0, hash(col * 3.1 + fl));
		float len = period * mix(0.35, 0.6, hash(col * 5.7 + fl));
		float y = p.y + TIME * sp * lines + h * period * 10.0;
		float t = mod(y, period);
		float streak = step(t, len) * step(fract(x / spacing), 1.0 / spacing + 0.001);
		// Fade in at the head, out at the tail.
		float along = t / max(len, 1.0);
		streak *= smoothstep(0.0, 0.15, along) * (1.0 - smoothstep(0.7, 1.0, along));
		a = max(a, on * streak * mix(0.35, 0.55, fl));
	}
	COLOR = vec4(streak_color, a * clamp(intensity * 1.5, 0.0, 1.0));
}

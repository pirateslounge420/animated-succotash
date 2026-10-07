shader_type canvas_item;
render_mode unshaded;
// The red ring round the edge of the view (design 6 Oct §FD, §FJ.3;
// HarmRing, Harm in the crawler). Drawn on a canvas layer at the internal
// frame (480 lines by default, §EU.1), so every pixel of it is one of the
// frame's and it scales up nearest with the rest of the HUD (§Y).
//
// Its inner edge is a rounded box `width_frac` of the frame's short side
// in from the middle of each edge, its corners rounded (`corner`, a share
// of the box's smaller half-size), so it reads as a ring round the view
// and reaches deeper into the corners. Its alpha is `alpha` at the rim,
// stepping down toward the inner edge in `bands` (§EC's flash steps the
// same way: four bands, the era's flat fills, no smooth gradient).

uniform vec4 ring_color = vec4(0.69, 0.094, 0.094, 1.0);
uniform float alpha = 0.0;
uniform float width_frac = 0.1;
uniform float corner = 0.6;
uniform float bands = 4.0;
uniform vec2 frame_px = vec2(854.0, 480.0);

void fragment() {
	// The pixel's centre, in the frame's pixels.
	vec2 p = floor(UV * frame_px) + 0.5;
	vec2 c = frame_px * 0.5;
	float depth = max(width_frac * min(frame_px.x, frame_px.y), 1e-3);
	vec2 h = max(c - vec2(depth), vec2(1.0));
	float r = min(h.x, h.y) * clamp(corner, 0.0, 1.0);
	vec2 q = abs(p - c) - (h - vec2(r));
	// Outside the inner box (> 0): how far, in pixels.
	float out_px = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	float t = clamp(out_px / depth, 0.0, 1.0);
	float stepped = ceil(t * bands) / bands;
	COLOR = vec4(ring_color.rgb, alpha * stepped);
}

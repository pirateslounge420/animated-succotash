// Mist at a waterfall's foot (TerrainChunk._build_falls, look.json
// water.waterfall.mist): a few soft camera-facing cards over the plunge
// pool, each rising rise_m and fading in and out over period_s, staggered
// so the spray never pulses as one. Low-res: px texels across a card,
// the alpha a soft round puff broken up by the water's glint noise
// (WaterLook.glint_texture, nearest with mipmaps). Unshaded, faint, and
// gone within near_fade_m of the eye, so it never stands as a wall.
// One mesh holds every card of a chunk: VERTEX is a card's centre, NORMAL
// the local up, UV its corner, UV2 (size m, phase 0-1).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/look.gdshaderinc"

uniform vec3 mist_color : source_color = vec3(0.43, 0.72, 1.0); // #B0DCFF
uniform float mist_alpha = 0.32;
uniform float rise_m = 2.5;
uniform float period_s = 7.0;
uniform float px = 12.0;
uniform float near_fade_m = 5.0;
uniform sampler2D glint_tex : filter_nearest_mipmap, repeat_enable;

varying vec3 world_pos;
varying float life;
varying float near;
varying float phase;

void vertex() {
	float size = UV2.x;
	phase = UV2.y;
	life = fract(TIME / period_s + phase);
	vec3 center = VERTEX + normalize(NORMAL) * rise_m * life;
	world_pos = (MODEL_MATRIX * vec4(center, 1.0)).xyz;
	vec4 v = MODELVIEW_MATRIX * vec4(center, 1.0);
	// Facing the camera, swelling a little as it rises.
	v.xy += (UV - 0.5) * size * mix(0.8, 1.3, life);
	near = smoothstep(near_fade_m * 0.5, near_fade_m, -v.z);
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	// Low-res: the card is px texels across, each one flat.
	vec2 q = (floor(UV * px) + 0.5) / px;
	float puff = 1.0 - smoothstep(0.2, 1.0, length(q - 0.5) * 2.0);
	float n = textureLod(glint_tex, q * 0.5 + vec2(phase * 0.37, phase * 0.61 + life * 0.2), 1.0).r;
	float fade = sin(life * PI);
	ALPHA = mist_alpha * puff * mix(0.35, 1.0, n) * fade * near;
	ALBEDO = mist_color * mix(1.0, 0.35, look_night);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

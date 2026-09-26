// Ground. Low-poly faces colored per vertex (TerrainChunk), vertex-lit:
// Lambert diffuse and no specular, like GameCube-era terrain. The
// surface is texture-led, like the hand-painted ground of GameCube-era
// games: Look's 256 px textures, crisp (nearest-filtered) but dense (grass
// texels about 0.7 cm), picked by the vertex color: streaky grass on green ground,
// rippled sand on bright warm ground, pebbly dirt on soil, mottled stone
// on grey rock faces, just a faint grain on snow. Each is sampled twice (a second, turned and
// rescaled copy) and blended by a slow noise so the tiling doesn't show,
// and smooth, painterly light and dark patches plus a slight hue drift
// run over meters to tens of meters, like sun-dappled grass.
//
// Near magical sites, patches of moss glow at night.
shader_type spatial;
render_mode cull_back, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
// Anisotropic: stays chunky up close without ring-shaped moire where the
// ground is seen at a grazing angle.
uniform sampler2D look_tex_grass : filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D look_tex_dirt : filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D look_tex_sand : filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D look_tex_stone : filter_nearest_mipmap_anisotropic, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The texture at `uv`, plus a turned, rescaled copy blended in by `mixer`
// (0-1, slow): breaks up the tiling.
vec3 untiled(sampler2D tex, vec2 uv, float mixer) {
	vec2 uv2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.71 + vec2(0.37, 0.61);
	return mix(texture(tex, uv).rgb, texture(tex, uv2).rgb, smoothstep(0.35, 0.65, mixer));
}

void fragment() {
	// Slow, smooth noise: which copy of the textures shows, and big soft
	// patches of light and dark (a few meters and a few tens of meters).
	float mixer = texture(look_grain_soft, UV * 0.043).r;
	float patch_s = texture(look_grain_soft, UV * 0.09 + 0.3).r;
	float patch_l = texture(look_grain_soft, UV * 0.011 + 0.7).r;
	vec3 c = COLOR.rgb;
	float hi = max(c.r, max(c.g, c.b));
	float sat = hi - min(c.r, min(c.g, c.b));
	float green = smoothstep(0.0, 0.07, c.g - max(c.r, c.b) * 0.92);
	float rocky = (1.0 - smoothstep(0.03, 0.09, sat)) * (1.0 - smoothstep(0.72, 0.88, hi));
	float snow = (1.0 - smoothstep(0.03, 0.09, sat)) * smoothstep(0.72, 0.88, hi);
	float sandy = smoothstep(0.05, 0.14, c.r - c.b) * smoothstep(0.45, 0.62, hi) * (1.0 - green);
	// UV is in meters: grass tiles every ~1.8 m, dirt ~1.4 m, sand ~2.5 m,
	// stone ~3.3 m.
	vec3 t = mix(untiled(look_tex_dirt, UV * 0.7, mixer), untiled(look_tex_sand, UV * 0.4, mixer), sandy);
	t = mix(t, untiled(look_tex_grass, UV * 0.55, mixer), green);
	t = mix(t, untiled(look_tex_stone, UV * 0.3, mixer), rocky);
	// Snow: just under white, with a faint crag grain so it reads as snow
	// on rock, not blank white.
	vec3 snow_t = mix(vec3(0.4), texture(look_tex_stone, UV * 0.15).rgb * 0.8, 0.35);
	t = mix(t, snow_t, snow * 0.85);
	// Texture contrast eases off far away, so fine detail doesn't shimmer
	// toward the horizon, but the ground stays textured well into the
	// middle distance.
	float dist = distance(world_pos, CAMERA_POSITION_WORLD);
	float far = smoothstep(60.0, 450.0, dist);
	t = mix(t, vec3(0.5), far * 0.55);
	// Far off, rock turns to crags meters across (as on the far shell), so
	// distant cliffs read crunchy instead of flat.
	vec3 crags = texture(look_tex_stone, UV / 90.0).rgb * 0.65 + texture(look_tex_stone, UV / 380.0 + 0.3).rgb * 0.35;
	t = mix(t, crags, rocky * smoothstep(200.0, 900.0, dist) * 0.9);
	// Painterly light and dark: grass drifts a little warmer in the light
	// patches and cooler in the dark ones.
	float dapple = (patch_s - 0.5) * 0.5 + (patch_l - 0.5) * 0.6;
	vec3 tint = mix(vec3(0.94, 0.98, 1.08), vec3(1.07, 1.03, 0.9), smoothstep(-0.2, 0.2, dapple));
	c *= mix(vec3(1.0), tint, green * 0.8);
	ALBEDO = c * t * 2.0 * (1.0 + dapple * 0.35);
	ROUGHNESS = 1.0;
	// Glowing moss creeps over the ground at magical places, in patches a
	// few meters across.
	float patch = texture(look_grain_soft, UV * 0.03).r;
	float glow = look_site_glow(world_pos, 0.3) * smoothstep(0.6, 0.75, patch);
	EMISSION = look_glow_emission(world_pos, glow * 0.55);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

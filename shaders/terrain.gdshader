// Ground. Low-poly faces colored per vertex (TerrainChunk), vertex-lit:
// Lambert diffuse and no specular, like GameCube-era terrain. The
// surface is texture-led, like the hand-painted ground of GameCube-era
// games (§AG): tiny detail tiles (Look: 64 px, stone 128) drawn
// nearest-filtered with at most two mip levels (retro_tex) and tiled hard
// every look_tile_m metres (grass 1.5, dirt 2, sand 2, stone 3), so the
// ground is a busy speckle of texels right to the fog. Picked by the vertex
// color: grass on green ground, sand on bright warm ground, dirt on soil,
// stone on grey rock faces, just a faint grain on snow. Smooth, painterly
// light and dark patches plus a slight hue drift run over meters to tens
// of meters, like sun-dappled grass.
//
// Colors follow the R1a palette (palette.gdshaderinc): grass, dirt, stone
// and snow are pulled toward their targets by day and cooled toward their
// night targets as night falls.
//
// Under trees (vertex alpha: 1 - how much canopy is overhead, baked by
// TerrainChunk.bake_canopy_shade) the ground is in dappled shade: patches
// of shadow with sun flecks between them, the light coming through the
// gaps between the leaf clusters, a meter or two across; faint by night.
//
// Near magical sites, patches of moss glow at night.
shader_type spatial;
render_mode cull_back, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"
#include "res://shaders/palette.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_grass : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_dirt : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_sand : filter_nearest_mipmap, repeat_enable;
uniform sampler2D look_tex_stone : filter_nearest_mipmap, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Slow, smooth noise: big soft patches of light and dark (a few meters
	// and a few tens of meters).
	float patch_s = texture(look_grain_soft, UV * 0.09 + 0.3).r;
	float patch_l = texture(look_grain_soft, UV * 0.011 + 0.7).r;
	vec3 c = COLOR.rgb;
	float hi = max(c.r, max(c.g, c.b));
	float sat = hi - min(c.r, min(c.g, c.b));
	float green = smoothstep(0.0, 0.07, c.g - max(c.r, c.b) * 0.92);
	float rocky = (1.0 - smoothstep(0.03, 0.09, sat)) * (1.0 - smoothstep(0.72, 0.88, hi));
	float snow = (1.0 - smoothstep(0.03, 0.09, sat)) * smoothstep(0.72, 0.88, hi);
	float sandy = smoothstep(0.05, 0.14, c.r - c.b) * smoothstep(0.45, 0.62, hi) * (1.0 - green);
	// UV is in meters: each tile repeats every look_tile_m.
	vec3 t = mix(retro_tex(look_tex_dirt, UV / look_tile_m.y).rgb, retro_tex(look_tex_sand, UV / look_tile_m.z).rgb, sandy);
	t = mix(t, retro_tex(look_tex_grass, UV / look_tile_m.x).rgb, green);
	t = mix(t, retro_tex(look_tex_stone, UV / look_tile_m.w).rgb, rocky);
	// Snow: just under white, with a faint crag grain so it reads as snow
	// on rock, not blank white.
	vec3 snow_t = mix(vec3(0.4), retro_tex(look_tex_stone, UV / (look_tile_m.w * 2.0)).rgb * 0.8, 0.35);
	t = mix(t, snow_t, snow * 0.85);
	// Texture contrast eases off only a little far away: the far ground
	// is meant to sparkle (§AG), and the fog has it by ~400 m.
	float dist = distance(world_pos, CAMERA_POSITION_WORLD);
	float far = smoothstep(60.0, 450.0, dist);
	t = mix(t, vec3(0.5), far * 0.2);
	// Far off, rock turns to crags meters across (as on the far shell), so
	// distant cliffs read crunchy instead of flat.
	vec3 crags = retro_tex(look_tex_stone, UV / 90.0).rgb * 0.65 + retro_tex(look_tex_stone, UV / 380.0 + 0.3).rgb * 0.35;
	t = mix(t, crags, rocky * smoothstep(200.0, 900.0, dist) * 0.9);
	// Painterly light and dark: grass drifts a little warmer in the light
	// patches and cooler in the dark ones.
	float dapple = (patch_s - 0.5) * 0.5 + (patch_l - 0.5) * 0.6;
	vec3 tint = mix(vec3(0.94, 0.98, 1.08), vec3(1.07, 1.03, 0.9), smoothstep(-0.2, 0.2, dapple));
	c *= mix(vec3(1.0), tint, green * 0.8);
	// R1a palette: pull each kind of ground toward its target (the
	// classification above reads the raw vertex color, so footsteps and
	// textures don't change), then cool it toward its night target.
	float dirt_w = (1.0 - green) * (1.0 - rocky) * (1.0 - snow) * (1.0 - sandy);
	c = pal_pull(c, pal_grass, 0.75 * green);
	c = pal_pull(c, pal_dirt, 0.55 * dirt_w);
	c = pal_pull(c, pal_stone, 0.85 * rocky);
	c = pal_pull(c, pal_snow, 0.9 * snow);
	float nk = look_night;
	c = pal_pull(c, pal_grass_night, 0.8 * nk * green);
	c = pal_pull(c, pal_bark_night, 0.6 * nk * dirt_w);
	c = pal_pull(c, pal_stone_night, 0.75 * nk * rocky);
	ALBEDO = c * t * 2.0 * (1.0 + dapple * 0.35);
	// Dappled canopy shade: shadow, broken by sun flecks.
	float canopy = 1.0 - COLOR.a;
	if (canopy > 0.002) {
		float fn = texture(look_grain_soft, UV * 0.37 + vec2(0.13, 0.71)).r * 0.65
			+ texture(look_grain_soft, UV * 0.9 + vec2(0.52, 0.27)).r * 0.35;
		float fleck = smoothstep(0.54, 0.6, fn);
		float sun = 1.0 - 0.75 * nk;
		ALBEDO *= mix(1.0, mix(0.66, 0.66 + 0.5 * sun, fleck), canopy);
	}
	ROUGHNESS = 1.0;
	// Glowing moss creeps over the ground at magical places, in patches a
	// few meters across.
	float patch = texture(look_grain_soft, UV * 0.03).r;
	float glow = look_site_glow(world_pos, 0.3) * smoothstep(0.6, 0.75, patch);
	EMISSION = look_glow_emission(world_pos, glow * 0.55);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

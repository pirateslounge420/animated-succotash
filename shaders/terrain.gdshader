// Ground. Flat-shaded low-poly faces colored per face (vertex colors from
// TerrainChunk), lit flat: Lambert diffuse on face normals and no PBR
// specular, so each triangle reads as one solid color like GameCube-era
// terrain. Chunky 64 px nearest-filtered textures (Look) give it a hand-
// painted PS2-era surface, picked by the vertex color: streaky grass on
// green ground, pebbly dirt on sand and soil, mottled stone on grey rock
// faces, just a faint grain on snow.
//
// `wetness` rises at night: a hard-edged toon highlight gives the spec's
// wet, over-sharpened moonlit sheen without smooth PBR shading. Near
// magical sites, patches of moss glow at night.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_toon;
// light() below: Lambert with colored shadows (Look), plus the toon wet
// highlight.

#include "res://shaders/look.gdshaderinc"

uniform float wetness = 0.0;
uniform sampler2D look_grain : filter_nearest, repeat_enable;
// Anisotropic: stays chunky up close without ring-shaped moire where the
// ground is seen at a grazing angle.
uniform sampler2D look_tex_grass : filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D look_tex_dirt : filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D look_tex_stone : filter_nearest_mipmap_anisotropic, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float g = texture(look_grain, UV * 0.25).r;
	vec3 c = COLOR.rgb;
	float hi = max(c.r, max(c.g, c.b));
	float sat = hi - min(c.r, min(c.g, c.b));
	float green = smoothstep(0.0, 0.07, c.g - max(c.r, c.b) * 0.92);
	float rocky = (1.0 - smoothstep(0.03, 0.09, sat)) * (1.0 - smoothstep(0.72, 0.88, hi));
	float snow = (1.0 - smoothstep(0.03, 0.09, sat)) * smoothstep(0.72, 0.88, hi);
	// UV is in meters: grass tiles every ~2.2 m, dirt ~1.7 m, stone ~5 m.
	vec3 t = mix(texture(look_tex_dirt, UV * 0.6).rgb, texture(look_tex_grass, UV * 0.45).rgb, green);
	t = mix(t, texture(look_tex_stone, UV * 0.2).rgb, rocky);
	t = mix(t, vec3(0.5), snow * 0.7);
	// Texture contrast fades with distance: chunky up close, calm far off,
	// so fine detail never shimmers or rings (moire) toward the horizon.
	float far = smoothstep(25.0, 140.0, distance(world_pos, CAMERA_POSITION_WORLD));
	t = mix(t, vec3(0.5), far * 0.75);
	ALBEDO = c * t * 2.0 * mix(0.92, 1.08, g);
	ROUGHNESS = mix(1.0, 0.55, wetness);
	SPECULAR = 0.35 * wetness;
	// Glowing moss creeps over the ground at magical places, in patches.
	// Moss patches a few meters across (the grain sampled coarsely).
	float patch = texture(look_grain, UV * 0.03).r;
	float glow = look_site_glow(world_pos, 0.3) * smoothstep(0.6, 0.75, patch);
	EMISSION = look_glow_emission(world_pos, glow * 0.55);
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

void light() {
	DIFFUSE_LIGHT += look_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL);
	// Hard-edged toon highlight (wet ground at night).
	float rv = dot(reflect(-LIGHT, NORMAL), VIEW);
	SPECULAR_LIGHT += LIGHT_COLOR / PI * ATTENUATION * smoothstep(0.985, 0.99, rv) * SPECULAR_AMOUNT * 0.35;
}

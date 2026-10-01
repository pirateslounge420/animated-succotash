// Shared look for every world material (terrain, far terrain, plants,
// water, ruins). SkySystem sets these uniforms each frame through Look.
//
// Lighting is Godot's own, not here: every lit world shader is plain
// Lambert with no specular under one hard-shadowed sun (or moon) over a
// low, deep-blue ambient (SkySystem, data/look.json: dark and moody,
// bright only where the light hits). No custom light(), rim, sheen or
// gloss; the blue of the shadows is the ambient's, and the grade's.
//
// Fog is done here rather than by the Environment: smooth distance haze
// that thins with altitude, and valleys and low ground fill with extra
// mist, most of all at night. Writing FOG replaces the Environment's fog for the material.
//
// Glow is the bioluminescent night palette: at magical places (ruins,
// glow ponds, mythical territories) water, moss and plant tips emit a
// saturated teal/cobalt light at night. The nearest sites arrive as
// look_sites (scene position, radius) with look_site_kind (1 = ruins and
// mythical ground, where moss and plants glow too; lower = glow ponds,
// mostly the water itself); look_glow scales everything with darkness.

// Shared per-frame values are global shader uniforms (project settings,
// [shader_globals]): Look sets each once a frame, however many materials
// use them. Colors arrive already linear (Look converts them).
global uniform vec3 look_fog_color;
global uniform float look_fog_density; // per meter
const float look_fog_max = 0.96;
global uniform vec3 look_up; // viewer's local up
// Haze thins with altitude (an exponential atmosphere): planet center in
// scene space, radius, and the haze's scale height.
global uniform vec3 look_planet_center;
global uniform float look_planet_radius;
const float look_haze_height = 150.0; // 1.5 km times PlanetConst.HEIGHT_SCALE
global uniform float look_mist; // 0-1 extra ground mist
// Valley fog (§AG, look.json retro.fog): below the local ground mean
// (look_ground_m, its height above the planet radius) the air thickens,
// reaching look_height_density per metre look_height_m below it.
global uniform float look_ground_m;
global uniform float look_height_density;
global uniform float look_height_m;
// Detail tiles (§AG, look.json retro): the tiny tiles are drawn nearest,
// tiled hard every look_tile_m metres (x grass, y dirt, z sand, w stone;
// look_tile_m2 x bark, y leaves), and use at most look_max_mips mip levels
// (retro_tex) so far ground still sparkles with texel noise.
global uniform vec4 look_tile_m;
global uniform vec2 look_tile_m2;
global uniform float look_max_mips;
// Ground darkening under canopy when the sun casts no shadow map by day
// (§AG 6, retro.canopy_dark; 0 while it does: SkySystem.day_shadows()).
global uniform float look_canopy_dark;
global uniform float look_night;
// §AG tile contrast (data/look.json retro.tile_contrast): the detail tiles'
// light and dark pushed apart about their mid grey (0 = as painted).
global uniform float look_tile_contrast;
// §BU step 5b: within this of the eye the grass tile gains finer blade
// flecks (look.json ranges.grass_m), fading to the plain tile beyond.
global uniform float look_grass_m;
// The ambient floor (design 30 Sept §BD, look.json ambient_floor): the
// hour's floor colour times its energy times the sky visibility where the
// player stands (0 inside a tomb or cave), linear, added under everything
// as ambient after the darkening stack, so day shade is navy and night is
// a blue-grey lift, never black while any sky shows. look_floor_min: the
// least share a point in the open keeps under its own canopy shade.
global uniform vec3 look_floor;
global uniform float look_floor_min;
// Teal and cobalt (sRGB (0.05, 1.0, 0.85) and (0.15, 0.35, 1.0)), linear.
const vec3 look_glow_color = vec3(0.00394, 1.0, 0.69207);
const vec3 look_glow_color_b = vec3(0.01961, 0.10048, 1.0);
global uniform float look_glow; // 0 by day, 1 at night
// The nearest glowing sites: xyz scene position, w radius; their kinds
// packed four to a vec4.
global uniform vec4 look_site_0;
global uniform vec4 look_site_1;
global uniform vec4 look_site_2;
global uniform vec4 look_site_3;
global uniform vec4 look_site_4;
global uniform vec4 look_site_5;
global uniform vec4 look_site_6;
global uniform vec4 look_site_7;
global uniform vec4 look_site_kind_a;
global uniform vec4 look_site_kind_b;
global uniform int look_site_count;

// Haze thickens smoothly with distance (it used to step in flat bands).
float look_band(float f) {
	return f;
}

vec4 look_fog(vec3 world_pos, vec3 cam_pos) {
	vec3 rel = world_pos - cam_pos;
	float dist = length(rel);
	// Ground below eye level sits in mist; peaks rise out of it.
	float height = dot(rel, look_up);
	float mist = look_mist * exp(-max(height + 4.0, 0.0) / 14.0);
	// Haze along the ray through air that thins with height: sea-level
	// density times the mean of exp(-altitude / H) between the two ends.
	float hc = max(length(cam_pos - look_planet_center) - look_planet_radius, 0.0);
	float hp = length(world_pos - look_planet_center) - look_planet_radius;
	float k = (hp - hc) / look_haze_height;
	float thin = exp(-hc / look_haze_height) * (abs(k) < 1e-3 ? 1.0 : (1.0 - exp(-k)) / k);
	// Valley fog: how deep the ray's two ends lie below the local ground
	// mean, averaged, as a share of look_height_m.
	float below = clamp((look_ground_m - (hc + hp) * 0.5) / max(look_height_m, 1.0), 0.0, 1.0);
	float f = 1.0 - exp(-dist * (look_fog_density * min(thin, 1.5) * (1.0 + 2.5 * mist) + look_height_density * below));
	f = min(look_band(f), look_fog_max);
	return vec4(look_fog_color, f);
}

// Glow color drifts between teal and cobalt across space and time.
vec3 look_glow_emission(vec3 world_pos, float amount) {
	float drift = 0.5 + 0.5 * sin(dot(world_pos, vec3(0.07, 0.05, 0.06)) + TIME * 0.4);
	float pulse = 0.8 + 0.2 * sin(TIME * 1.3 + dot(world_pos, vec3(0.3, 0.2, 0.25)));
	return mix(look_glow_color, look_glow_color_b, drift) * amount * look_glow * pulse;
}

// 0-1 closeness to the nearest glowing site; `kind_weight` 1 counts every
// site fully, 0 counts only ruins/mythical sites (kind 1).
float look_site_glow(vec3 world_pos, float kind_weight) {
	if (look_site_count <= 0) {
		return 0.0;
	}
	vec4 sites[8] = vec4[8](look_site_0, look_site_1, look_site_2, look_site_3, look_site_4, look_site_5, look_site_6, look_site_7);
	float kinds[8] = float[8](look_site_kind_a.x, look_site_kind_a.y, look_site_kind_a.z, look_site_kind_a.w,
		look_site_kind_b.x, look_site_kind_b.y, look_site_kind_b.z, look_site_kind_b.w);
	float g = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= look_site_count) {
			break;
		}
		vec4 s = sites[i];
		float k = mix(step(0.99, kinds[i]), 1.0, kind_weight);
		g = max(g, smoothstep(s.w, s.w * 0.35, distance(world_pos, s.xyz)) * k);
	}
	return g;
}

// A nearest-filtered detail tile at `uv`, its mip level picked as the
// hardware would but never past look_max_mips (fragment only).
vec4 retro_tex(sampler2D tex, vec2 uv) {
	vec2 st = uv * vec2(textureSize(tex, 0));
	vec2 dx = dFdx(st);
	vec2 dy = dFdy(st);
	float lod = 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-8));
	return textureLod(tex, uv, clamp(lod, 0.0, look_max_mips));
}

// One of Look's mid-grey modulation tiles (grass, dirt, sand, stone, bark,
// leaves, water: 0.5 = unchanged), nearest-filtered with at most
// look_max_mips mips, its contrast pushed by look_tile_contrast (§AG 1).
vec4 retro_tile(sampler2D tex, vec2 uv) {
	vec4 c = retro_tex(tex, uv);
	c.rgb = 0.5 + (c.rgb - 0.5) * (1.0 + look_tile_contrast);
	return c;
}

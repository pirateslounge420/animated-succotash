// Shared look for every world material (terrain, far terrain, plants,
// water, ruins). SkySystem sets these uniforms each frame through Look.
//
// Fog is done here rather than by the Environment: N64/PS1-style fog comes
// in flat bands (a few hard-edged steps of haze instead of a smooth PBR
// gradient), and valleys and low ground fill with extra mist, most of all
// at night. Writing FOG replaces the Environment's fog for the material.
//
// Glow is the bioluminescent night palette: at magical places (ruins,
// glow ponds, mythical territories) water, moss and plant tips emit a
// saturated teal/cobalt light at night. The nearest sites arrive as
// look_sites (scene position, radius) with look_site_kind (1 = ruins and
// mythical ground, where moss and plants glow too; lower = glow ponds,
// mostly the water itself); look_glow scales everything with darkness.

uniform vec3 look_fog_color : source_color = vec3(0.55, 0.8, 1.0);
uniform float look_fog_density = 0.0004; // per meter
uniform float look_fog_bands = 6.0;
uniform float look_fog_max = 0.96;
uniform vec3 look_up = vec3(0.0, 1.0, 0.0); // viewer's local up
uniform float look_mist = 0.0; // 0-1 extra ground mist
uniform float look_night = 0.0;
uniform vec3 look_glow_color : source_color = vec3(0.05, 1.0, 0.85);
uniform vec3 look_glow_color_b : source_color = vec3(0.15, 0.35, 1.0);
uniform float look_glow = 0.0; // 0 by day, 1 at night
uniform vec3 look_rim_color : source_color = vec3(0.45, 0.55, 1.0); // moonlit edge
uniform vec4 look_sites[8];
uniform float look_site_kind[8];
uniform int look_site_count = 0;

// Stepped haze: flat bands with a narrow soft edge between them.
float look_band(float f) {
	float x = f * look_fog_bands;
	float fl = floor(x);
	return (fl + smoothstep(0.47, 0.53, x - fl)) / look_fog_bands;
}

vec4 look_fog(vec3 world_pos, vec3 cam_pos) {
	vec3 rel = world_pos - cam_pos;
	float dist = length(rel);
	// Ground below eye level sits in mist; peaks rise out of it.
	float height = dot(rel, look_up);
	float mist = look_mist * exp(-max(height + 4.0, 0.0) / 14.0);
	float f = 1.0 - exp(-dist * look_fog_density * (1.0 + 2.5 * mist));
	f = min(look_band(f), look_fog_max);
	return vec4(look_fog_color, f);
}

// Glow color drifts between teal and cobalt across space and time.
vec3 look_glow_emission(vec3 world_pos, float amount) {
	float drift = 0.5 + 0.5 * sin(dot(world_pos, vec3(0.07, 0.05, 0.06)) + TIME * 0.4);
	float pulse = 0.8 + 0.2 * sin(TIME * 1.3 + dot(world_pos, vec3(0.3, 0.2, 0.25)));
	return mix(look_glow_color, look_glow_color_b, drift) * amount * look_glow * pulse;
}

// Night edge light: silhouettes pick up a cool moonlit rim facing away
// from the camera, the crunchy PS2-era edge definition. Daytime rim comes
// from the lights themselves (RIM), so this only fades in after dark.
vec3 look_rim(vec3 normal, vec3 view, float amount) {
	float rim = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 3.0);
	return look_rim_color * rim * amount * look_night;
}

// 0-1 closeness to the nearest glowing site; `kind_weight` 1 counts every
// site fully, 0 counts only ruins/mythical sites (kind 1).
float look_site_glow(vec3 world_pos, float kind_weight) {
	float g = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= look_site_count) {
			break;
		}
		vec4 s = look_sites[i];
		float k = mix(step(0.99, look_site_kind[i]), 1.0, kind_weight);
		g = max(g, smoothstep(s.w, s.w * 0.35, distance(world_pos, s.xyz)) * k);
	}
	return g;
}

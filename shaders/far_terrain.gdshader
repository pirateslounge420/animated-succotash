// Distant planet shell (FarShell): coarse terrain or sea far beyond the
// streamed chunks, for long views of distant mountains. Cut away near the
// camera, where detailed chunks take over. Vertex-lit and fogged like the
// near terrain, so the two meet without a visible change.
//
// Mountains read crunchy, not as flat color: rock (grey, or anything
// steep) carries Look's stone texture at the scale of crags, meters per
// texel, plus big strata, and snow a faint glittering grain. It's mapped
// in the planet's own frame (the shell sits at the planet center), so it
// doesn't slide when the floating origin moves.
shader_type spatial;
render_mode cull_back, vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"

uniform float hide_radius = 700.0;
uniform bool is_sea = false;
uniform vec3 sea_color : source_color = vec3(0.02, 0.3, 0.62);
uniform sampler2D look_grain : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_stone : filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 world_pos;
varying vec3 planet_pos;
varying vec3 planet_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	planet_pos = VERTEX;
	planet_normal = NORMAL;
}

// Stone at `scale` (per meter), projected from the side the slope faces.
vec3 crag(float scale) {
	vec3 n = abs(planet_normal);
	vec3 p = planet_pos * scale;
	vec3 a = texture(look_tex_stone, p.yz).rgb;
	vec3 b = texture(look_tex_stone, p.xz).rgb;
	vec3 c = texture(look_tex_stone, p.xy).rgb;
	return (a * n.x + b * n.y + c * n.z) / (n.x + n.y + n.z);
}

void fragment() {
	if (distance(world_pos, CAMERA_POSITION_WORLD) < hide_radius) {
		discard;
	}
	if (is_sea) {
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
		ALBEDO = mix(sea_color, sea_color * 0.55, fresnel);
		EMISSION = look_glow_emission(world_pos, look_site_glow(world_pos, 1.0) * 0.6);
	} else {
		vec3 c = COLOR.rgb;
		float hi = max(c.r, max(c.g, c.b));
		float sat = hi - min(c.r, min(c.g, c.b));
		float steep = 1.0 - dot(normalize(planet_normal), normalize(planet_pos));
		float rock = max(1.0 - smoothstep(0.04, 0.12, sat), smoothstep(0.12, 0.3, steep));
		float snow = (1.0 - smoothstep(0.03, 0.09, sat)) * smoothstep(0.72, 0.88, hi);
		// Crags a few meters per texel, over strata tens of meters apart.
		vec3 t = crag(1.0 / 90.0) * 0.65 + crag(1.0 / 380.0) * 0.35;
		float strata = texture(look_grain_soft, vec2(length(planet_pos) / 55.0, dot(planet_pos, vec3(0.3, 0.5, 0.8)) / 900.0)).r;
		t *= 0.85 + 0.3 * strata;
		t = mix(vec3(0.5), t, rock * (1.0 - snow * 0.6));
		t *= 1.0 - 0.1 * snow; // snow just under white, so it keeps its shape
		// Everything else gets soft patches of light and dark.
		float patches = texture(look_grain_soft, planet_pos.xz / 700.0 + planet_pos.y / 900.0).r;
		ALBEDO = c * t * 2.0 * mix(1.0, 0.85 + 0.3 * patches, 1.0 - rock);
	}
	ROUGHNESS = 1.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

// The gibbon's body (GibbonBody): SculptedBodies' look, vertex-lit like
// the rest of the world (Lambert, no specular, Look's fog), with creases
// baked into the vertex colors and Look's fur strokes over a coarse
// grain, the crunchy texture on a rounded shape of R1. UV.x is the
// surface: 0 bare skin (a faint grain), 1 fur.
//
// Two things differ from creature_sculpt.gdshader:
//  - Texture space is the REST pose. Skinning moves VERTEX and NORMAL,
//    so texturing in those would slide the fur over the arms as they
//    swing; the mesh carries every vertex's rest position and normal in
//    CUSTOM0 and CUSTOM1 instead, and the triplanar fur reads those.
//  - Night (R1a: bodies tinted into the night ultramarine, nothing
//    black). The coat and the pale face ring, hands and feet are tint
//    channels (their weights in UV2, occlusion baked in) with a day and a
//    night color each, eased by look_night. The night colors are cool,
//    near-neutral slates rather than blues: the night light and grade
//    tint them into the ultramarine with the fur still showing, where a
//    saturated blue would come out flat violet (as the Pond Crawler
//    found). Fixed colors (the face skin) ease toward a dark slate. A
//    floor, day and night, keeps the darkest creases and the eyes off
//    black.
//
// The face is drawn here, per pixel, rather than painted on vertices:
// a bare dark face inside the lar gibbon's pale ring, an ellipsoid in
// rest-pose space, so it stays crisp on the coarse mesh.
//
// `rigid` parts (the eyes) are small separate meshes with no rest
// channels: one flat color, their own position as texture space.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled;

#include "res://shaders/look.gdshaderinc"
#include "res://shaders/prelit.gdshaderinc"

uniform sampler2D look_grain_soft : filter_linear_mipmap, repeat_enable;
uniform sampler2D look_tex_fur : filter_nearest_mipmap, repeat_enable;
// Linear colors. The night ones are albedos tuned by rendering at night
// (the moon, the ultramarine ambient and the night grade shift them).
uniform vec3 coat_color = vec3(0.07, 0.035, 0.02);
uniform vec3 pale_color = vec3(0.85, 0.77, 0.6);
uniform vec3 coat_night = vec3(0.18, 0.2, 0.29);
uniform vec3 pale_night = vec3(0.5, 0.55, 0.7);
uniform vec3 fixed_night = vec3(0.1, 0.11, 0.15);
// The darkest albedo by day and at night (creases and eyes stay a dark
// warm brown by day, deep blue at night, never black).
uniform vec3 day_floor = vec3(0.03, 0.022, 0.018);
uniform vec3 night_floor = vec3(0.08, 0.09, 0.13);
// Fur strokes per meter of rest-pose space.
uniform float fur_scale = 13.0;
// The bare face (rest-pose ellipsoid) and the pale ring round it, out to
// `ring_outer` times the face's size.
uniform vec3 face_color = vec3(0.1, 0.065, 0.055);
uniform vec3 face_center = vec3(0.0, 0.276, -0.062);
uniform vec3 face_radii = vec3(0.037, 0.044, 0.031);
uniform float ring_outer = 1.33;
uniform bool rigid = false;
uniform vec3 flat_color = vec3(0.03, 0.02, 0.015);

varying vec3 rest_pos;
varying vec3 rest_nrm;
varying vec3 world_pos;

void vertex() {
	if (rigid) {
		rest_pos = VERTEX;
		rest_nrm = NORMAL;
	} else {
		rest_pos = CUSTOM0.xyz;
		rest_nrm = CUSTOM1.xyz;
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 fur(float scale) {
	vec3 n = abs(normalize(rest_nrm));
	n = n * n;
	vec3 a = texture(look_tex_fur, rest_pos.xy * scale).rgb;
	vec3 b = texture(look_tex_fur, rest_pos.zy * scale).rgb;
	vec3 c = texture(look_tex_fur, rest_pos.xz * scale).rgb;
	return (a * n.z + b * n.x + c * n.y) / (n.x + n.y + n.z);
}

void fragment() {
	float nk = look_night;
	vec3 t = vec3(0.5);
	float k = 0.0;
	vec3 base;
	if (rigid) {
		base = mix(flat_color, fixed_night * 0.6, nk * 0.85);
	} else {
		// The face: 1 on the bare face, the ring between it and
		// ring_outer, on the front of the head only.
		float fd = length((rest_pos - face_center) / face_radii);
		float front = smoothstep(0.17, 0.2, rest_pos.y) * (1.0 - smoothstep(-0.03, -0.012, rest_pos.z));
		float face = (1.0 - smoothstep(0.9, 1.0, fd)) * front;
		float ring = smoothstep(0.9, 1.0, fd) * (1.0 - smoothstep(ring_outer - 0.1, ring_outer, fd)) * front;
		int kind = int(round(UV.x));
		if (kind == 1 && face < 0.5) {
			t = fur(fur_scale);
			k = 0.9;
		} else {
			t = vec3(texture(look_grain_soft, (rest_pos.xy + rest_pos.zy) * 18.0).r);
			k = 0.4;
		}
		// Fixed colors (vertex COLOR) and the two tint channels, each
		// eased toward its night color. The vertex weights carry the baked
		// creases; the face and ring take the occlusion of what's there.
		float occ = clamp(UV2.x + UV2.y + max(max(COLOR.r, COLOR.g), COLOR.b) * 3.0, 0.45, 1.0);
		vec3 fixed_col = mix(COLOR.rgb, fixed_night * clamp(max(max(COLOR.r, COLOR.g), COLOR.b) * 3.0, 0.4, 1.0), nk * 0.8);
		vec3 coat = mix(coat_color, coat_night, nk);
		vec3 pale = mix(pale_color, pale_night, nk);
		base = fixed_col + UV2.x * coat + UV2.y * pale;
		base = mix(base, pale * occ, ring);
		base = mix(base, mix(face_color, fixed_night * 0.8, nk * 0.8) * occ, face);
		// Crunch: broad soft mottling in rest-pose space.
		float g = texture(look_grain_soft, (rest_pos.xy * 1.3 + rest_pos.zy * 1.7) * 2.2).r;
		base *= 0.82 + 0.36 * g;
	}
	vec3 albedo = base * mix(vec3(1.0), t * 2.0, k);
	ALBEDO = max(albedo, mix(day_floor, night_floor, nk));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
	// Pre-lit (design §ES.2): the painted light, from the sky above.
	ALBEDO = prelit_paint(ALBEDO, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

#include "res://shaders/prelit_light.gdshaderinc"

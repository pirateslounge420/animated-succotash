// A figure as a sprite (design 6 Oct §ET.8, FigureSprite): the Doom way.
// The shared rig, painted per §ES, was rendered once to a sheet of frames
// (`atlas`: `grid` columns x rows, each column an angle around the figure
// for an animation frame, each row a viewing height); this quad stands
// upright where the figure stands, turns about its own up to face the
// camera, and shows the one frame FigureSprite picked (`cell`). Lit like a
// pre-lit model (prelit_light.gdshaderinc: the fire lights it), fogged
// like everything (Look), cut out by the frame's alpha (no blending: the
// silhouette stays crisp at 270 lines).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, depth_prepass_alpha;

#include "res://shaders/look.gdshaderinc"
#include "res://shaders/prelit.gdshaderinc"

uniform sampler2D atlas : filter_nearest, source_color;
uniform vec2 grid = vec2(8.0, 3.0);
uniform vec2 cell = vec2(0.0, 1.0);

varying vec3 world_pos;

void vertex() {
	// Upright, turned about its own up to face the camera.
	vec3 up = normalize(MODEL_MATRIX[1].xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz;
	vec3 fwd = normalize(to_cam - up * dot(to_cam, up) + vec3(1e-5, 0.0, 0.0));
	vec3 right = normalize(cross(up, fwd));
	mat4 bb = mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0), vec4(up * length(MODEL_MATRIX[1].xyz), 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	world_pos = (bb * vec4(VERTEX, 1.0)).xyz;
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = (cell + vec2(UV.x, UV.y)) / grid;
	vec4 t = texture(atlas, uv);
	ALBEDO = t.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	FOG = look_fog(world_pos, CAMERA_POSITION_WORLD);
}

#include "res://shaders/prelit_light.gdshaderinc"

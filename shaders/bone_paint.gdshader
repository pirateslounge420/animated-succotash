// The skeleton's paint for its sprite bake (design §ES: the light is in
// the paint; §ET.8: creatures are sprites baked from a model). Bone lit
// from above and falling to navy underneath (the R-rules' shade: navy,
// never grey), the same from every side so all eight views of the sheet
// match; the fire lights the sprite in play (figure_sprite.gdshader).
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 albedo : source_color = vec4(0.82, 0.78, 0.66, 1.0);
uniform vec4 shade : source_color = vec4(0.17, 0.19, 0.36, 1.0);
uniform float floor_light = 0.22;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float k = clamp(0.5 + 0.5 * world_normal.y, 0.0, 1.0);
	k = floor_light + (1.0 - floor_light) * smoothstep(0.05, 0.95, k);
	ALBEDO = mix(shade.rgb, albedo.rgb, k);
}

// The live light for a pre-lit model (design 6 Oct §ES.2; prelit.gdshaderinc
// first): the sun and the moon tint (their colour, their strength, their
// cast shadow) but don't model the form, which is painted; the fire and
// the torches light round what they reach (a soft N.L). With look_prelit 0,
// plain Lambert, as before.
void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	if (look_prelit < 0.5) {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * ndl * ATTENUATION;
	} else if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * look_prelit_sun * ATTENUATION;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * (0.35 + 0.65 * ndl) * ATTENUATION;
	}
}

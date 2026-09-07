shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Toy-plastic shading for the small character parts - mittens, ears, snouts,
// hats, uniform bits. Same two-step band ramp, plum shadows and warm rim as
// the slime body shader, minus the wobble vertex channel: static parts stay
// put. The raised light_floor variant (toon_face) keeps dark face details
// readable when the head sits in shadow.
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shadow_color : source_color = vec4(0.36, 0.30, 0.52, 1.0);
uniform float band_softness = 0.12;
uniform float rim_strength = 0.32;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float light_floor = 0.07;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = albedo.rgb;
	EMISSION = rim_color.rgb * rim * rim_strength;
	ROUGHNESS = 0.5;
}
void light() {
	float nl = max(dot(NORMAL, LIGHT), 0.0);
	// Two soft steps make the classic three-band cartoon ramp.
	float band = smoothstep(0.32 - band_softness, 0.32 + band_softness, nl) * 0.58
		+ smoothstep(0.72 - band_softness, 0.72 + band_softness, nl) * 0.42;
	band = max(band, light_floor);
	vec3 shadow = ALBEDO * shadow_color.rgb * 1.35;
	DIFFUSE_LIGHT += mix(shadow, ALBEDO, band) * LIGHT_COLOR * ATTENUATION;
	// Small hard specular dot keeps the gooey wet look.
	DIFFUSE_LIGHT += pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 40.0) * 0.45 * LIGHT_COLOR * ATTENUATION;
}
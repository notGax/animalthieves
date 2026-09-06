shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Toy-plastic character shading: banded ramp diffuse with plum shadows, a
// warm rim light and a flash/wobble channel the animation code can drive.
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shadow_color : source_color = vec4(0.36, 0.30, 0.52, 1.0);
uniform float band_softness = 0.12;
uniform float rim_strength = 0.32;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wobble : hint_range(0.0, 0.2) = 0.0;
uniform float wobble_speed = 9.0;
void vertex() {
	if (wobble > 0.0) {
		VERTEX += NORMAL * sin(TIME * wobble_speed + VERTEX.y * 6.0 + VERTEX.x * 4.0) * wobble;
	}
}
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(albedo.rgb, flash_color.rgb, flash);
	EMISSION = rim_color.rgb * rim * rim_strength + flash_color.rgb * flash * 0.55;
	ROUGHNESS = 0.5;
}
void light() {
	float nl = max(dot(NORMAL, LIGHT), 0.0);
	// Two soft steps make the classic three-band cartoon ramp.
	float band = smoothstep(0.32 - band_softness, 0.32 + band_softness, nl) * 0.58
		+ smoothstep(0.72 - band_softness, 0.72 + band_softness, nl) * 0.42;
	band = max(band, 0.07);
	vec3 shadow = ALBEDO * shadow_color.rgb * 1.35;
	DIFFUSE_LIGHT += mix(shadow, ALBEDO, band) * LIGHT_COLOR * ATTENUATION;
	// Small hard specular dot keeps the gooey wet look.
	DIFFUSE_LIGHT += pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 40.0) * 0.45 * LIGHT_COLOR * ATTENUATION;
}
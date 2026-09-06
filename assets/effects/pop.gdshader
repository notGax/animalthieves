shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// Soft additive burst material for pops, rings and sparks.
uniform vec4 color : source_color = vec4(1.0);
uniform float intensity = 2.0;
uniform float softness = 1.6;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), softness);
	ALBEDO = color.rgb * intensity;
	ALPHA = clamp(color.a * mix(0.35, 1.0, fres), 0.0, 1.0);
}
shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int surface_kind = 0;
uniform float tile_size = 4.0;
uniform vec4 tint : source_color = vec4(1.0);
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
vec3 sample_surface(vec2 p) {
 vec2 offset = vec2(float(surface_kind % 2), float(surface_kind / 2)) * 0.5;
 return texture(atlas, offset + clamp(fract(p / tile_size), vec2(0.003), vec2(0.997)) * 0.5).rgb;
}
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 vec3 weights = pow(abs(world_normal), vec3(8.0));
 weights /= max(dot(weights, vec3(1.0)), 0.001);
 vec3 c = sample_surface(world_pos.zy) * weights.x + sample_surface(world_pos.xz) * weights.y + sample_surface(world_pos.xy) * weights.z;
 if (surface_kind == 4) {
  float n = hash(floor(world_pos.xz * 4.0));
  c = vec3(0.28,0.34,0.35) + n * 0.012;
 }
 ALBEDO = c * tint.rgb;
 ROUGHNESS = clamp(0.75 + (1.0 - c.r) * 0.2,0.0,1.0);
 METALLIC = 0.0;
}

shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int surface_kind = 0;
uniform float tile_size = 4.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation = 1.18;
uniform float value_lift = 0.03;
uniform float rim_strength = 0.22;
uniform float wall_gradient = 0.55;
uniform float grime_strength = 0.14;
uniform float roughness_bias = 0.0;
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
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
 // Saturate + lift so the painted atlas reads toy-bright, then apply the per-kind tint.
 float luma = dot(c, vec3(0.299,0.587,0.114));
 c = mix(vec3(luma), c, saturation) + value_lift;
 c *= tint.rgb;
 float wallness = 1.0 - clamp(abs(world_normal.y), 0.0, 1.0);
 if (surface_kind != 4 && wallness > 0.2) {
  // Grime: vertical streaks that pool where the wall meets a floor (y=0 street level, y=-12 basements).
  float streak = noise(vec2(dot(world_pos.xz, vec2(1.0, 0.31)), floor(world_pos.y * 2.0))) * 0.7 + noise(vec2(dot(world_pos.xz, vec2(0.53, 1.0)), floor(world_pos.y * 2.0))) * 0.3;
  c *= 1.0 - grime_strength * streak * wallness;
  float junction = min(abs(world_pos.y), abs(world_pos.y + 12.0));
  c *= mix(1.0 - wall_gradient, 1.0, smoothstep(0.0, 1.6, junction));
 }
 ALBEDO = c;
 ROUGHNESS = clamp(0.75 + (1.0 - c.r) * 0.2 + roughness_bias, 0.0, 1.0);
 METALLIC = 0.0;
 // Faint top-down sheen so sunlit floors and roofs pop without a specular overhaul.
 vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
 float rim = pow(max(dot(world_normal, view_dir), 0.0), 2.0);
 EMISSION = c * rim * rim_strength * clamp(world_normal.y, 0.0, 1.0);
}
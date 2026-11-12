// Chapter V: a portal between games — a swirling vortex with a white-hot
// core and a bright rim, like the passage at the end of chapter IV but tinted.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 color_a : source_color = vec3(0.55, 0.2, 1.0);
uniform vec3 color_b : source_color = vec3(0.15, 0.9, 1.0);
uniform float open = 1.0;
// Gameplay provides its paused clock; TIME keeps moving during pause.
uniform float sim_time = 0.0;
uniform float spin = 2.5;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float radius = 0.92 * open;
	if (r > radius + 0.06 || open <= 0.001) discard;
	float sw = a + 3.2 / (r + 0.18) - sim_time * spin;
	float bands = 0.5 + 0.5 * sin(sw * 5.0);
	float n = noise(vec2(sw * 1.7, r * 9.0 - sim_time * 3.0));
	vec3 col = mix(color_a, color_b, clamp(bands * 0.65 + n * 0.45, 0.0, 1.0));
	float core = smoothstep(0.38 * open, 0.0, r);
	float rim = smoothstep(radius - 0.14, radius, r) * (1.0 - smoothstep(radius, radius + 0.06, r));
	float fade = 1.0 - smoothstep(radius, radius + 0.06, r);
	col = col * (0.45 + bands * 0.7) * fade + vec3(1.0) * core * 1.6 + mix(color_b, vec3(1.0), 0.4) * rim * 2.2;
	ALBEDO = col;
}

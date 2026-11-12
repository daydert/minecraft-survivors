// Chapter V: a passage between games torn into the world's code. A ragged,
// pixel-quantized rift: a near-black throat that slowly churns, a burning
// cracked edge in the destination colour and torn scanlines. No cartoon swirl.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
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
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void fragment() {
	// Same pixel grid as the blocks around it.
	vec2 uv = floor(UV * 48.0) / 48.0 + 0.5 / 48.0;
	float t = floor(sim_time * 12.0) / 12.0;
	// Torn scanlines: a few rows jump sideways for a frame.
	float row = floor(uv.y * 24.0);
	float tear = step(0.86, hash(vec2(row, floor(t * 6.0)))) * (hash(vec2(row + 3.0, t)) - 0.5) * 0.12 * open;
	vec2 p = (uv + vec2(tear, 0.0)) * 2.0 - 1.0;
	p.x *= 1.35; // taller than wide: a wound, not a disc
	float a = atan(p.y, p.x);
	float edge_noise = fbm(vec2(a * 2.2 + 7.0, t * 0.6)) * 0.34 + fbm(vec2(a * 6.0, t * 1.7)) * 0.12;
	float radius = (0.62 + edge_noise) * open;
	float r = length(p);
	if (r > radius + 0.09 || open <= 0.001) discard;
	// The throat: dark, slowly churning, with faint colour deep inside.
	float churn = fbm(vec2(a * 1.5 - t * spin * 0.25, log(r + 0.05) * 3.0 - t * 1.4));
	vec3 deep = mix(vec3(0.005, 0.0, 0.01), color_a * 0.22, smoothstep(0.45, 0.95, churn));
	deep += color_b * 0.18 * smoothstep(0.82, 1.0, churn) * smoothstep(radius, 0.0, r);
	// Burning cracked rim with veins reaching inward.
	float rim = smoothstep(radius - 0.12, radius, r) * (1.0 - smoothstep(radius, radius + 0.09, r));
	float veins = step(0.8, fbm(vec2(a * 9.0, r * 7.0 - t * 2.0))) * smoothstep(radius * 0.4, radius, r);
	vec3 burn = mix(color_a, color_b, hash(vec2(floor(a * 12.0), t)) * 0.5);
	vec3 col = deep + burn * (rim * 2.4 + veins * 1.1);
	// Occasional dead pixels of code: bright single cells inside the dark.
	float cell = step(0.985, hash(floor(uv * 48.0) + floor(t * 4.0)));
	col += color_b * cell * 0.9 * smoothstep(radius, radius * 0.5, r);
	ALBEDO = col;
	ALPHA = clamp(1.0 - smoothstep(radius, radius + 0.09, r) + rim, 0.0, 1.0);
}

// Chapter V, 2Fort: a warm painted sky — gradient, soft drifting clouds, sun.
shader_type sky;
uniform float sim_time = 0.0;
uniform vec3 top_color : source_color = vec3(0.27, 0.5, 0.82);
uniform vec3 horizon_color : source_color = vec3(0.74, 0.83, 0.9);
uniform vec3 ground_color : source_color = vec3(0.66, 0.58, 0.46);
uniform vec3 cloud_color : source_color = vec3(0.98, 0.96, 0.92);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(y, 0.0, 1.0), 0.5));
	if (y < 0.0) col = mix(horizon_color, ground_color, clamp(-y * 5.0, 0.0, 1.0));
	if (y > 0.01) {
		vec2 uv = d.xz / (y + 0.12) * 0.9 + vec2(sim_time * 0.006, sim_time * 0.002);
		float c = smoothstep(0.5, 0.8, fbm(uv));
		float shade = smoothstep(0.55, 0.9, fbm(uv + vec2(0.08, 0.05)));
		vec3 cc = mix(cloud_color, cloud_color * vec3(0.82, 0.85, 0.92), shade);
		col = mix(col, cc, c * 0.85 * clamp(y * 6.0, 0.0, 1.0));
	}
	float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += LIGHT0_COLOR * (pow(s, 900.0) * 6.0 + pow(s, 12.0) * 0.18);
	COLOR = col;
}

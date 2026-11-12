// Chapter V, 2Fort canal: moving water — rippled normals, sun glints,
// a fresnel sky sheen and soft transparency instead of a stretched texture.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
uniform vec3 deep_color : source_color = vec3(0.1, 0.24, 0.23);
uniform vec3 shallow_color : source_color = vec3(0.3, 0.46, 0.38);
uniform vec3 sky_color : source_color = vec3(0.62, 0.76, 0.9);
uniform float sim_time = 0.0;
uniform float scale = 0.45;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float waves(vec2 p, float t) {
	return noise(p * scale + vec2(t * 0.35, t * 0.22)) + 0.5 * noise(p * scale * 2.7 - vec2(t * 0.3, -t * 0.4)) + 0.25 * noise(p * scale * 6.1 + vec2(-t * 0.5, t * 0.3));
}
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(world_pos.x * 1.1 + sim_time * 1.3) + sin(world_pos.z * 1.6 + sim_time * 0.9)) * 0.025;
}
void fragment() {
	vec2 p = world_pos.xz;
	float t = sim_time;
	float e = 0.12;
	float h = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t);
	float fade = clamp(1.0 - length(VERTEX) / 60.0, 0.15, 1.0);
	vec3 n = normalize(vec3((h - hx) * 2.2 * fade, 1.0, (h - hz) * 2.2 * fade));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 base = mix(deep_color, shallow_color, smoothstep(0.6, 1.4, h));
	ALBEDO = mix(base, sky_color * 0.8, fres * 0.35);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = sky_color * fres * 0.08;
	ALPHA = mix(0.82, 0.97, fres);
}

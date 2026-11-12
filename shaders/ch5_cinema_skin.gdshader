shader_type spatial;
render_mode cull_disabled;
uniform sampler2D skin_texture : source_color, filter_nearest, repeat_disable;
uniform float blood_amount = 0.0;
uniform float erase_amount = 0.0;
uniform bool clip_enabled = false;
uniform vec3 gate_origin = vec3(3.6, 1.9, -0.6);
uniform vec3 gate_normal = vec3(-0.4794255, 0.0, 0.8775826);
uniform vec3 gate_color : source_color = vec3(.5, .8, 1.0);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 texel = texture(skin_texture, UV);
	if (texel.a < .5) discard;
	float side = dot(world_position - gate_origin, gate_normal);
	if (clip_enabled && side < 0.0) discard;
	vec2 px = floor(UV * 64.0);
	float grain = fract(sin(dot(px,vec2(12.9898,78.233)))*43758.5453);
	if (grain < erase_amount) discard;
	float cluster = fract(sin(dot(floor(px/3.0),vec2(31.17,43.71)))*15437.71);
	float stain = step(cluster*.65+grain*.35, blood_amount*.62);
	ALBEDO = mix(texel.rgb,vec3(.25+grain*.12,.012,.018),stain);
	ROUGHNESS = .9;
	EMISSION = clip_enabled ? gate_color * (1.0 - smoothstep(.0, .035, abs(side))) * .8 : vec3(0.0);
}

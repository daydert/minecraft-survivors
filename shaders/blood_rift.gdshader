shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 center = vec2(0.5);
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform float wipe = 0.0;
void fragment() {
	vec2 resolution=vec2(640.0,360.0);
	vec2 p=(SCREEN_UV-center)*resolution;
	// At full expansion the field passes every corner of the visible world.
	float reach=length(max(center,vec2(1.0)-center)*resolution*vec2(1.0,1.3))+120.0;
	float radius=mix(14.0,reach*2.2,smoothstep(0.08,1.0,progress));
	float distance_to_center=length(p*vec2(1.0,1.3));
	float cleared=(1.0-smoothstep(wipe*(reach+110.0)-80.0,wipe*(reach+110.0),distance_to_center))*step(0.001,wipe);
	float field=(1.0-smoothstep(radius*0.12,radius,distance_to_center))*(1.0-cleared);
	float angle=field*field*progress*6.5;
	float c=cos(angle);float s=sin(angle);
	vec2 warped=mat2(vec2(c,s),vec2(-s,c))*p*(1.0+field*progress*0.65);
	vec2 uv=clamp(center+warped/resolution,vec2(0.5)/resolution,vec2(1.0)-vec2(0.5)/resolution);
	vec3 background=texture(screen_texture,(floor(uv*resolution)+0.5)/resolution).rgb;
	float spiral=pow(max(0.0,sin(atan(p.y,p.x)*5.0-distance_to_center*0.16+phase*3.0)),8.0)*field;
	vec3 blood=mix(background,vec3(0.19,0.002,0.018),field*progress*0.65);
	blood+=vec3(0.30,0.003,0.022)*spiral*progress;
	float core=(1.0-smoothstep(radius*0.18,radius*0.36,distance_to_center))*(1.0-cleared);
	vec3 result=mix(blood,vec3(0.016,0.0,0.003),core*progress);
	vec3 original=texture(screen_texture,SCREEN_UV).rgb;
	// The second, black wave restores the unwarped scene under a dark veil.
	COLOR=vec4(mix(result,original*0.06,cleared),1.0);
}

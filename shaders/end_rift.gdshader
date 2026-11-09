shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 center=vec2(.5);
uniform float power=0.0;
uniform float phase=0.0;
void fragment(){
	vec2 res=vec2(640.0,360.0);
	vec2 p=(SCREEN_UV-center)*res;
	float radius=length(p);
	float ring=sin(radius*.09-phase*7.0)*exp(-radius*.008)*power;
	vec2 delta=normalize(p+vec2(.001))*ring*2.3;
	float band=step(.94,fract(sin(floor(SCREEN_UV.y*90.0)+floor(phase*12.0)*13.0)*43758.5453));
	delta.x+=band*sin(phase*33.0)*power*5.0;
	vec2 uv=(floor(clamp(SCREEN_UV+delta/res,vec2(.001),vec2(.999))*res)+.5)/res;
	float split=power*(.6+band*2.0)/640.0;
	vec3 c=texture(screen_texture,uv).rgb;
	c.r=texture(screen_texture,clamp(uv+vec2(split,0.0),vec2(.001),vec2(.999))).r;
	c.b=texture(screen_texture,clamp(uv-vec2(split,0.0),vec2(.001),vec2(.999))).b;
	float edge=smoothstep(.16,.75,length((SCREEN_UV-center)*vec2(1.0,.7)));
	c=mix(c,c*vec3(.55,.35,.68),edge*power*.65);
	c+=vec3(.12,.01,.18)*max(0.0,ring)*.17;
	COLOR=vec4(c,1.0);
}

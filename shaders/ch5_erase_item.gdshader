shader_type spatial;
render_mode cull_disabled;
uniform float erase_amount=0.0;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float grain=fract(sin(dot(floor(world_position*32.0),vec3(12.9898,78.233,23.71)))*43758.5453);
 if(grain<erase_amount) discard;
 ALBEDO=COLOR.rgb;ROUGHNESS=.85;
}

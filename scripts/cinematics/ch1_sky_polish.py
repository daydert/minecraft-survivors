"""Connected branching lightning at the single sky event; MCP scene edit."""
import bpy
from mathutils import Vector
sc=bpy.data.scenes['CH1_Garden_Prologue'];bpy.context.window.scene=sc
points=[(-2.7,4,8.7),(-1.4,4,7.55),(-1.9,4,6.95),(-.15,4,6.25),(-.8,4,5.65),(1.15,4,5.05)]
segments=list(zip(points,points[1:]))+[(points[2],(-3.0,4,6.45)),(points[3],(1.45,4,6.65))]
objects=sorted([o for o in sc.objects if o.name.startswith('CH1_sky_fracture')],key=lambda o:o.name)
for i,(ob,(a,b)) in enumerate(zip(objects,segments)):
 a,b=Vector(a),Vector(b);v=b-a;ob.location=(a+b)/2;ob.rotation_mode='QUATERNION';ob.rotation_quaternion=Vector((1,0,0)).rotation_difference(v.normalized());w=.032 if i<5 else .018;ob.scale=(v.length/1.4,w/.04,w/.04)
sc.frame_set(254)
bpy.data.libraries.write('/home/daydert/MinecraftSurvivors2/assets/art_source/ch1_intro/ch1_intro.blend',{sc},fake_user=True,compress=True)
print('CONNECTED_SKY_EVENT')

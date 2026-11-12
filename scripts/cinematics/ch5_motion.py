"""Godot-space shot/acting source, authored and inspected in Blender MCP.
Pure deterministic sampling. Rigid blocks, articulated elbows/knees for the
cinematic only; no gameplay rig, clocks, hitboxes or RNG are altered.
"""
import math
from mathutils import Vector,Matrix,Quaternion
PI=math.pi
PARTS=['root','hips','torso','head','ra','la','rl','ll','re','le','rk','lk','grip']
def clamp(x,a=0,b=1):return max(a,min(b,x))
def ease(a,b,t):
 x=clamp((t-a)/(b-a));return x*x*(3-2*x)
def mix(a,b,k):return a+(b-a)*k
def pulse(t,at,width=.4):return math.sin(PI*clamp((t-at)/width)) if at<t<at+width else 0

def actor(p=(0,0,0),yaw=0):
 return {'root':{'p':list(p),'r':[0,yaw,0]},'hips':{'p':[0,.75,0],'r':[0,0,0]}, **{k:{'r':[0,0,0]} for k in PARTS if k not in ['root','hips']}}
def r(a,k,x=0,y=0,z=0):
 a[k].pop('q',None);a[k]['r']=[x,y,z]
def camera(p,to,fov=40):return {'p':p,'to':to,'fov':fov}
def rotation(e):return Matrix.Rotation(e[1],3,'Y')@Matrix.Rotation(e[0],3,'X')@Matrix.Rotation(e[2],3,'Z')
REST={'hips':(0,.75,0),'torso':(0,0,0),'head':(0,.75,0),'ra':(-.3125,.625,0),'la':(.3125,.625,0),'rl':(-.11875,0,0),'ll':(.11875,0,0),'re':(0,-.25,0),'le':(0,-.25,0),'rk':(0,-.375,0),'lk':(0,-.375,0),'grip':(-.0625,-.375,0)}
PARENT={'hips':'root','torso':'hips','head':'torso','ra':'torso','la':'torso','rl':'hips','ll':'hips','re':'ra','le':'la','rk':'rl','lk':'ll','grip':'re'}
def matrices(a):
 out={}
 for k in PARTS:
  d=a[k];p=d.get('p',REST.get(k,(0,0,0)));q=d.get('q');rot=Quaternion((q[3],*q[:3])).to_matrix() if q else rotation(d['r']);m=Matrix.Translation(Vector(p))@rot.to_4x4()
  out[k]=out[PARENT[k]]@m if k in PARENT else m
 return out

def aim_head(a,target,weight=1):
 m=matrices(a);local=m['torso'].inverted()@Vector(target)-Vector(REST['head'])
 yaw=math.atan2(local.x,local.z);pitch=-math.atan2(local.y-.23,math.hypot(local.x,local.z))
 r(a,'head',clamp(pitch,-.55,.65)*weight,clamp(yaw,-1.15,1.15)*weight)

def walk(a,t,start,end,p0,p1):
 k=clamp((t-start)/(end-start));p=Vector(p0).lerp(Vector(p1),k)
 a['root']['p']=list(p)
 if k<=0 or k>=1:return
 # Short strides with a held support foot, followed by toe clearance.
 phase=k*PI*4;stride=math.sin(phase)*.48
 r(a,'rl',stride);r(a,'ll',-stride)
 r(a,'rk',max(0,-math.sin(phase))*.7);r(a,'lk',max(0,math.sin(phase))*.7)
 a['hips']['p'][1]=.75-abs(math.sin(phase))*.025
 r(a,'ra',-stride*.3,0,-.08);r(a,'la',stride*.3,0,.08)
 plant_legs(a,t,start,end,p0,p1)

def plant_legs(a,t,start,end,p0,p1):
 duration=end-start;cycle=duration/2;root=Vector(a['root']['p']);R=rotation(a['root']['r'])
 a['hips']['p'][1]=.71
 for leg,knee,x,offset in [('rl','rk',-.11875,0),('ll','lk',.11875,.5)]:
  u=(t-start)/cycle+offset;period=math.floor(u);phase=u-period
  at0=start+(period-offset)*cycle+cycle*.3;at1=at0+cycle
  point=lambda tt:Vector(p0).lerp(Vector(p1),clamp((tt-start)/duration))+R@Vector((x,0,0))
  foot=point(at0) if phase<.6 else point(at0).lerp(point(at1),ease(.6,1,phase))
  foot.y=max(0,math.sin(PI*clamp((phase-.6)/.4))*.09 if phase>.6 else 0)
  local=R.inverted()@(foot-root)-Vector((x,a['hips']['p'][1],0))
  length=min(.748,local.length);direction=local.normalized();pole=Vector((0,0,1));pole=(pole-direction*pole.dot(direction)).normalized()
  mid=direction*(length/2)+pole*math.sqrt(max(0,.375**2-(length/2)**2))
  top=Vector((0,-1,0)).rotation_difference(mid.normalized());bottom=Vector((0,-1,0)).rotation_difference((local-mid).normalized())
  lower=top.inverted()@bottom
  a[leg]['q']=[top.x,top.y,top.z,top.w];a[knee]['q']=[lower.x,lower.y,lower.z,lower.w]

def brace(a,weight,hip):
 a['hips']['p'][1]=hip
 R=rotation(a['root']['r']);root=Vector(a['root']['p'])
 for leg,knee,x,z in [('rl','rk',-.11875,1.20),('ll','lk',.11875,1.36)]:
  foot=root+R@Vector((x,0,0));foot.y=0;foot.z=z
  local=R.inverted()@(foot-root)-Vector((x,hip,0))
  length=min(.748,local.length);direction=local.normalized();pole=Vector((0,0,1));pole=(pole-direction*pole.dot(direction)).normalized()
  mid=direction*(length/2)+pole*math.sqrt(max(0,.375**2-(length/2)**2))
  top=Vector((0,-1,0)).rotation_difference(mid.normalized());bottom=Vector((0,-1,0)).rotation_difference((local-mid).normalized())
  for key,q in [(leg,top),(knee,top.inverted()@bottom)]:
   q=Quaternion().slerp(q,weight);a[key]['q']=[q.x,q.y,q.z,q.w]

def aim_blade(s,target):
 fore=matrices(s)['re'];hand=fore@Vector(REST['grip']);direction=Vector(target)-hand
 desired=(-direction.normalized()).to_track_quat('Y','Z').to_matrix()
 q=(fore.to_3x3().inverted()@desired).to_quaternion();s['grip']['q']=[q.x,q.y,q.z,q.w]

def chair(t):
 n=actor((0,0,.05));n['hips']['p']=[0,.64,0]
 for leg,knee in [('rl','rk'),('ll','lk')]:r(n,leg,-.85);r(n,knee,.85)
 r(n,'ra',.16,0,-.12);r(n,'la',.16,0,.12);r(n,'re',-.55);r(n,'le',-.55)
 s=actor((-1.7,0,1.65),2.35)
 r(s,'ra',.08,0,-.07);r(s,'la',.03,0,.07)
 # Steve listens and checks the console, then returns his attention to Notch.
 if 9.2<t<11.8:r(s,'head',.08,-.55*math.sin(PI*(t-9.2)/2.6))
 else:aim_head(s,(0,1.56,.05))
 breathing=math.sin(t*2.1)*.012
 r(s,'torso',breathing)
 # Small, finite attempts to free the wrists, at meaningful changes of intent.
 strain=pulse(t,1.0,.65)*.11+pulse(t,2.3,.55)*.08+pulse(t,21.5,.55)*.17+pulse(t,23.0,.65)*.12+pulse(t,26.0,.55)*.1
 lean=.05
 if t<3.4:lean=.12*ease(.3,1,t)-.07*ease(2.5,3.3,t)
 elif t<8:lean=.13*ease(4,4.6,t)
 elif t<12.6:lean=.09
 elif t<16.8:lean=.03
 elif t<21.4:lean=.18*ease(16.8,17.5,t)
 elif t<25.6:lean=.22
 elif t<30:lean=.10
 else:lean=-.12*ease(30,30.5,t)
 r(n,'torso',lean+strain,0,math.sin(t*1.6)*.009)
 r(n,'ra',.16+strain,0,-.12);r(n,'la',.16+strain,0,.12)
 # Hands reach for the hanging blade; wrist remains the owner of the prop.
 if t>29.6:
  d=ease(29.6,30.4,t)
  r(s,'ra',mix(.08,-.45,d),0,-.18*d);r(s,'re',-.85*d)
  r(s,'head',.25*d,-.25*d)
 if t>30.55:
  walk(s,t,30.55,31.85,(-1.7,0,1.65),(.04,0,1.32))
  s['root']['r'][1]=mix(2.35,PI,ease(30.55,31.85,t))
  r(s,'ra',-.55,0,-.17);r(s,'re',-.65)
  aim_head(s,(0,1.52,.05))
 # Heel settles, elbow retracts, torso winds. The thrust is straight, no overhead chop.
 if t>31.85:
  w=ease(31.9,32.65,t);hit=ease(32.76,33,t)
  s['root']['p']=[.04,0,mix(1.32,1.08,hit)]
  s['hips']['p']=[0,mix(.75,.72,w),0]
  r(s,'rl',-.10*w);r(s,'ll',.10*w);r(s,'rk',.10*w);r(s,'lk',-.10*w)
  r(s,'torso',mix(-.09*w,.16,hit),mix(.20*w,-.06,hit),0)
  r(s,'ra',mix(mix(-.55,.25,w),-1.22,hit),mix(-.1,-.25,hit),mix(-.25,-.03,hit))
  r(s,'re',mix(mix(-.65,-1.7,w),0,hit));r(s,'la',mix(-.2,-.55,hit),0,.15);r(s,'le',-.25)
  r(s,'head',mix(.1,.22,hit),.04,0)
  brace(s,w,mix(.72,.69,hit))
  # Aim blade from the forearm through the wound, using an actual wrist joint.
  world=matrices(s);fore=world['re'];hand=fore@Vector(REST['grip'])
  direction=Vector((.06,1.12,.0))-hand
  desired=(-direction.normalized()).to_track_quat('Y','Z').to_matrix() # blade local -Y
  local=fore.to_3x3().inverted()@desired
  q=Quaternion().slerp(local.to_quaternion(),max(w,hit));s['grip']['q']=[q.x,q.y,q.z,q.w]
  # The wrist keeps the blade aimed through the target while the elbow retracts.
 if t>33:
  shock=ease(33,33.10,t);settle=ease(34.1,37.4,t)
  r(n,'torso',mix(-.20*shock,.28,settle),0,.025*settle)
  r(n,'head',mix(-.42*shock,.65,settle),-.05,.12*settle)
  for k in ['ra','la']:n[k]['r'][0]=mix(.06,.32,settle)
  for k in ['re','le']:n[k]['r'][0]=mix(-.55,-.25,settle)
  if t<33.35:n['torso']['r'][0]+=math.sin((t-33)*PI*14)*.025*(1-(t-33)/.35)
 if 33.2<t<38.5:
  # Hold the contact; only the head follows his final words.
  r(s,'head',.18+ease(34.4,35.0,t)*.09,0,0)
 if t>38.5:
  pull=ease(38.5,39.1,t)
  s['root']['p'][2]=mix(1.08,1.45,pull)
  r(s,'ra',mix(-1.22,-.12,pull),0,-.08);r(s,'re',mix(0,-.15,pull));r(s,'grip')
  s['grip'].pop('q',None)
  r(s,'torso',mix(.16,0,pull));s['hips']['p'][1]=mix(.72,.75,pull)
  for k in ['rl','ll','rk','lk']:r(s,k)
 if t>40:
  s['root']['r'][1]=mix(PI,PI*1.64,ease(40,41.0,t));r(s,'head',.05,-.3*(1-ease(40,41.2,t)))
  walk(s,t,41.1,44,(.04,0,1.45),(-1.4,0,2.3));s['root']['r'][1]=PI*1.64
 # Follow attention through the body hierarchy, not a fixed sine-wave head.
 if t<33:
  aim_head(n,Vector(s['root']['p'])+Vector((0,1.7,0)))
  if t<2.5:r(n,'head',.45, mix(-.4,.4,ease(.8,1.7,t)),.07)
  if 13<t<16.2:r(n,'head',.16,-.65,.08)
  if 16.8<t<21.4:n['head']['r'][2]=-.10*ease(16.8,17.4,t)
  if 21.4<t<25.6:n['head']['r'][0]-=.12
  if 30<t<31.3:r(n,'head',.28,-.45,0)
 # The same side of the action axis throughout; contact is seen in profile.
 shots=[(0,camera([3.6,2.5,4.4],[-.6,1.0,.5],41)),
  (3.4,camera([3.1,2.1,4.0],[-.6,1.1,.5],39)),
  (4,camera([-1.3,1.7,2.65],[0,1.48,.12],35)),
  (12.5,camera([-1.05,1.65,2.35],[0,1.48,.12],33)),
  (12.6,camera([-.6,1.7,2.6],[-.15,1.4,.3],38)),
  (21.3,camera([-.5,1.65,2.5],[-.1,1.4,.3],35)),
  (21.4,camera([-.65,1.15,2.65],[0,1.43,.12],37)),
  (29.5,camera([-.55,1.2,2.45],[0,1.43,.12],35)),
  (29.6,camera([3.2,1.65,3.5],[-.55,1.1,.7],41)),
  (32.6,camera([3.0,1.55,3.2],[-.4,1.15,.65],40)),
  (32.7,camera([3.2,1.35,1.65],[.08,1.18,.6],36)),
  (34.25,camera([3.0,1.36,1.6],[.08,1.18,.6],35)),
  (34.3,camera([2.4,1.65,1.5],[0,1.47,.12],34)),
  (38.45,camera([2.5,1.62,1.6],[0,1.42,.12],35)),
  (38.5,camera([3.1,1.55,2.5],[.0,1.0,.65],40)),
  (40.0,camera([3.2,1.6,2.8],[.0,1.0,.65],40)),
  (40.05,camera([3.8,2.5,4.5],[-.4,.95,.65],44)),
  (44,camera([4.0,2.65,4.7],[-.4,.95,.65],44))]
 return {'steve':s,'notch':n,'cam':sample_camera(shots,t)}

def sample_camera(keys,t):
 a=keys[0];b=keys[-1]
 for idx in range(len(keys)-1):
  if keys[idx][0]<=t<=keys[idx+1][0]:a,b=keys[idx],keys[idx+1];break
 k=clamp((t-a[0])/max(.0001,b[0]-a[0]))
 # Boundaries < .11s are cuts, without a one-frame swoop through scenery.
 if b[0]-a[0]<.11:k=0 if t<b[0] else 1
 return {key:list(Vector(a[1][key]).lerp(Vector(b[1][key]),k)) if key!='fov' else mix(a[1][key],b[1][key],k) for key in ['p','to','fov']}

GATE=(3.6,1.9,-.6)
def portal(index,t):
 # One contact owner for each gate, with a distinct attack trajectory.
 p=actor((-1.7,0,.5),PI/2);v=actor((.5,0,.4),-PI/2)
 approach=ease(.55,1.60,t);impact=ease(1.60,1.76,t);cross=clamp((t-1.76)/.95)
 p['root']['p']=[mix(-1.7,-.35,approach),0,.5]
 gait=math.sin(approach*PI*3)*.45*math.sin(approach*PI)
 r(p,'rl',gait);r(p,'ll',-gait);r(p,'rk',max(0,-gait));r(p,'lk',max(0,gait))
 r(p,'torso',.1+.22*approach)
 r(p,'ra',mix(-.25,-1.55,impact),0,-.1);r(p,'la',mix(-.15,-1.35,impact),0,.12)
 r(p,'re',-.30*(1-impact));r(p,'le',-.45*(1-impact))
 if index in [1,3]:
  # Shoulder check: braced leading arm and body, rather than identical palm shoves.
  r(p,'la',-.65,0,.35);r(p,'le',-1.0);r(p,'torso',.3,.22*approach)
 if index==4:
  # Notch catches Steve's arm, turns his own weight and releases him.
  r(p,'ra',-1.4,0,-.3);r(p,'re',-.65*(1-impact));r(v,'la',-1.1,0,.4)
 resistance=pulse(t,.85,.55)
 r(v,'torso',-.10*resistance);r(v,'ra',-.6*resistance,0,-.2);r(v,'re',-.8*resistance)
 aim_head(v,p['root']['p'][:1]+[1.7,p['root']['p'][2]])
 if t>=1.76:
  # Full-size bodies cross the physical portal plane; they are never shrunk.
  target=Vector(GATE)+Vector((.65,-1.35,-.35))
  vv=Vector((.5,0,.4)).lerp(target,cross)
  vv.y+=math.sin(cross*PI)*(.28 if index%2 else .5)
  v['root']['p']=list(vv);v['root']['r']=[-.23*math.sin(PI*cross),mix(-PI/2,PI/2,cross),-.1*cross]
  r(v,'ra',-1.5,0,-.55);r(v,'la',-1.2,0,.65);r(v,'re',-.3);r(v,'le',-.4)
  r(v,'rl',-.45);r(v,'ll',.3);r(v,'rk',.65);r(v,'lk',.25)
 if t>2.8:
  jump=clamp((t-2.8)/.85);pp=Vector((-.35,0,.5)).lerp(Vector(GATE)+Vector((.7,-1.35,-.35)),jump);pp.y+=math.sin(jump*PI)*.55
  p['root']['p']=list(pp);r(p,'torso',.25);r(p,'ra',-.8,0,-.15);r(p,'la',-.5,0,.1);r(p,'rk',.45);r(p,'lk',.65)
 if index in [0,2,4]:s,n=v,p
 else:s,n=p,v
 # A single moving camera preserves geography through the shove and entry.
 c=camera([mix(-.4,.7,ease(0,3.8,t)),2.15,mix(6.6,5.2,ease(0,3.8,t))],[1.1,1.25,.0],47)
 return {'steve':s,'notch':n,'cam':c,'visible_s':t<(2.72 if s is v else 3.68),'visible_n':t<(2.72 if n is v else 3.68)}

def door(t):
 s=actor((.5,0,-1.0),PI)
 walk(s,t,0,2.7,(.5,0,-1.0),(.5,0,-5.26))
 r(s,'head',-.02,-.12*math.sin(PI*ease(2.7,3.2,t)))
 if 2.8<t<4.2:
  reach=ease(2.85,3.25,t)*(1-ease(3.35,3.65,t))
  r(s,'la',-1.25*reach,0,.08);r(s,'le',-.30*reach)
 if t>4.0:walk(s,t,4.0,5.0,(.5,0,-5.26),(.5,0,-6.5))
 c=sample_camera([(0,camera([2.9,1.55,1.1],[.5,1.1,-4.0],44)),(2.7,camera([2.6,1.55,.3],[.5,1.1,-4.9],42)),(2.8,camera([2.1,1.5,-2.8],[.5,1.0,-5.6],48)),(5,camera([1.8,1.45,-3.4],[.5,1.0,-6],48))],t)
 return {'steve':s,'cam':c}

def arrival(t):
 s=actor((9,0,-16),PI*.95)
 fall=1-ease(0,.72,t);s['root']['p'][1]=fall*2.7
 compress=pulse(t,.72,.5)*.12
 s['hips']['p'][1]=.75-compress;r(s,'rk',compress*3);r(s,'lk',compress*3)
 r(s,'ra',.08+fall*.5,0,-.15);r(s,'la',.1+fall*.3,0,.15)
 turn=ease(1.15,2.1,t);r(s,'head',-.08-turn*.16,turn*.6,0)
 s['root']['r'][1]=mix(PI*.95,PI*.8,ease(1.6,3.2,t))
 c=sample_camera([(0,camera([12,2.35,-18.3],[9,1,-16],47)),(1.5,camera([12.2,2.3,-18.5],[9,1,-16],47)),(1.6,camera([14,2.6,-19],[1,6,20],61)),(5,camera([13.4,3.3,-18.7],[0,7,22],60))],t)
 return {'steve':s,'cam':c}

def erase_throw(t):
 s=actor((-1.6,0,1.2),PI*.75);n=actor((1.3,0,-1.4),-.6)
 launch=ease(0,.16,t)
 r(s,'ra',mix(-2.2,-1.4,launch),.1,-.12);r(s,'re',mix(-.8,-.12,launch));r(s,'torso',mix(-.1,.12,launch),mix(.25,-.15,launch),0)
 aim_head(s,(.3,2.5,-2.7));aim_head(n,(-1.6,1.6,1.2))
 reaction=ease(.6,.82,t);r(n,'torso',-.18*reaction);r(n,'ra',-.3,0,-.4*reaction);r(n,'la',-.3,0,.5*reaction)
 n['root']['p'][0]+=reaction*.4
 if t>.6:r(n,'head',-.3, -.7*reaction,0)
 aim_blade(s,(.3,2.5,-2.7))
 c=sample_camera([(0,camera([2.5,1.8,3.4],[-.2,1.5,-.7],48)),(.58,camera([2.3,1.8,3.1],[-.2,1.5,-.7],48)),(.6,camera([1.8,2.15,-.1],[.1,2.4,-3],49)),(1.45,camera([1.8,2.15,-.1],[.1,2.4,-3],49)),(1.5,camera([3.3,2,3.2],[.3,1.2,-.5],45)),(3.6,camera([3.3,2,3.2],[.3,1.2,-.5],45))],t)
 return {'steve':s,'notch':n,'cam':c}

def wire(t):
 s=actor((-1,0,0),PI/2);n=actor((1,0,0),-PI/2)
 drive=ease(0,.20,t);release=ease(1.6,2.8,t)
 r(s,'torso',.1+drive*.14,0,0);r(s,'ra',mix(-1.1,-1.5,drive),0,-.1);r(s,'re',mix(-.7,-.05,drive));r(s,'la',-1.2,0,.15);r(s,'le',-.5)
 r(s,'rl',-.14);r(s,'rk',.14);r(s,'ll',.14);r(s,'lk',-.14)
 n['hips']['p'][1]=.55;r(n,'rl',-.8);r(n,'ll',-.8);r(n,'rk',1.5);r(n,'lk',1.5)
 shock=pulse(t,.2,.45)
 r(n,'torso',mix(.32,-.17,drive)+release*.15);r(n,'head',-.3*drive+release*.45)
 r(n,'ra',-.25-shock*.5,0,-.35);r(n,'la',-.25-shock*.35,0,.4);r(n,'re',-.45);r(n,'le',-.4)
 aim_head(s,(1,1.1,0))
 return {'steve':s,'notch':n,'cam':camera([.6,1.55,5.0],[0,1,0],42)}

# Arm solve in world space. The palm, rather than the root, owns contact.
def fist(a, target, side='r', weight=1):
 upper=side+'a';lower=side+'e';world=matrices(a)
 parent=world['torso'];shoulder=parent@Vector(REST[upper]);delta=parent.to_3x3().inverted()@(Vector(target)-shoulder)
 length=min(.619,delta.length);direction=delta.normalized();pole=Vector((0,0,-1));pole=(pole-direction*pole.dot(direction)).normalized()
 along=(.25**2-.375**2+length**2)/(2*length);mid=direction*along+pole*math.sqrt(max(0,.25**2-along**2))
 top=Vector((0,-1,0)).rotation_difference(mid.normalized());bottom=Vector((0,-1,0)).rotation_difference((delta-mid).normalized())
 for key,q in [(upper,top),(lower,top.inverted()@bottom)]:
  base=rotation(a[key]['r']).to_quaternion();q=base.slerp(q,weight);a[key]['q']=[q.x,q.y,q.z,q.w]

portal_before=portal
def portal(index,t):
 # Opponent lands first; the counter transfers whole-body weight into the gate.
 d=portal_before(index,t);p=d['notch'] if index%2==0 else d['steve'];v=d['steve'] if index%2==0 else d['notch']
 p['root']['p']=[mix(-1.7,-.18,ease(.15,.7,t)),0,.5]
 first=ease(.64,.89,t)*(1-ease(1.02,1.30,t))
 counter=ease(1.45,1.79,t)*(1-ease(1.88,2.16,t))
 r(v,'torso',-.10,.38*first,0);r(v,'ra',-.9,0,-.2);r(v,'re',-1.1)
 r(p,'torso',.12,-.45*counter,0);r(p,'ra',.25,0,-.3);r(p,'re',-1.5)
 if t<1.80:
  target=matrices(p)['head']@Vector((0,.23,.22));fist(v,target,weight=first)
  target=matrices(v)['head']@Vector((0,.23,.20));fist(p,target,weight=counter)
  r(p,'head',-.2*pulse(t,.89,.4),-.45*pulse(t,.89,.4),-.12*pulse(t,.89,.4))
  r(v,'head',0,.0,0)
 if t>=1.80:
  cross=clamp((t-1.8)/1.02);target=Vector(GATE)+Vector((.8,-1.35,-.4))
  v['root']['p']=list(Vector((.5,0,.4)).lerp(target,ease(0,1,cross))+Vector((0,math.sin(cross*PI)*.65,0)))
  v['root']['r']=[-.35*math.sin(cross*PI),mix(-PI/2,PI*.7,cross),-.22*math.sin(cross*PI)]
  r(v,'head',-.32,.4,.2);r(v,'ra',-1.3,0,-.6);r(v,'la',-.8,0,.7);r(v,'rk',.8);r(v,'lk',.4)
 if t>2.9:
  jump=ease(2.9,3.8,t);p['root']['p']=list(Vector((-.18,0,.5)).lerp(Vector(GATE)+Vector((.8,-1.35,-.4)),jump)+Vector((0,math.sin(jump*PI)*.5,0)))
  r(p,'torso',.25);r(p,'ra',-.8);r(p,'re',-.3);r(p,'rk',.45);r(p,'lk',.55)
 d['cam']=camera([mix(-.5,.75,ease(0,3.9,t)),1.95,mix(5.9,5.2,ease(0,3.9,t))],[1.0,1.2,0],47)
 return d

chair_before=chair
def chair(t):
 d=chair_before(t);s=d['steve'];n=d['notch']
 # The last 22 cm comes from the hip and shoulder. The elbow opens along
 # one blade axis; the hand stops at the body while the torso settles.
 if 32.2<t<38.5:
  hit=ease(32.79,33.0,t);wind=ease(32.2,32.72,t)
  r(s,'torso',mix(-.10,.18,hit),mix(.16,-.10,hit),0)
  target=Vector((.08,1.13,mix(1.01,.56,hit)))
  fist(s,target,weight=wind);aim_blade(s,(.08,1.13,-.2))
  # Follow-through stays in the same contact; Notch reacts after frame 990.
  settle=ease(33.04,33.22,t)
  s['hips']['p'][1]-=.012*math.sin(settle*PI)
 return d

def qte(t,kind='hit'):
 s=actor((-.60,0,.25),PI/2);n=actor((.60,0,.25),-PI/2)
 for a in [s,n]:
  r(a,'ra',-.9,0,-.25);r(a,'re',-1.0);r(a,'la',-.9,0,.3);r(a,'le',-1.15);r(a,'rl',-.14);r(a,'rk',.14);r(a,'ll',.1);r(a,'lk',-.1)
 impact=ease(.82,1.0,t)*(1-ease(1.16,1.65,t));recoil=pulse(t,1.0,.55)
 if kind=='hit':
  r(n,'la',-.2,0,.35);r(n,'le',-.4);r(n,'ra',.1,0,-.2);r(n,'re',-.5)
  s['root']['p'][0]+=.65*impact;r(s,'rl',-.32*impact);r(s,'rk',.32*impact);r(s,'ll',.16*impact);r(s,'lk',-.16*impact)
  r(s,'torso',.16,-.5*impact,0);fist(s,matrices(n)['head']@Vector((0,.2,.18)),weight=impact)
  r(n,'head',-.35*recoil,.5*recoil,.18*recoil);r(n,'torso',-.22*recoil)
 elif kind=='block':
  n['root']['p'][0]-=.58*impact
  r(s,'la',-1.7,0,.4);r(s,'le',-1.2);r(s,'torso',-.1)
  fist(n,matrices(s)['head']@Vector((0,.16,.28)),weight=impact);r(s,'head',-.12*recoil);r(n,'torso',.14,-.3*impact)
 elif kind=='dodge':
  n['root']['p'][0]-=.58*impact
  s['hips']['p'][1]=.75-.28*impact;r(s,'rk',.6*impact);r(s,'lk',.6*impact);r(s,'torso',.3*impact)
  fist(n,(-.6,1.7,.25),weight=impact);r(n,'torso',.18,.4*impact)
 elif kind=='miss':
  n['root']['p'][0]-=.65*impact
  fist(n,matrices(s)['head']@Vector((0,.20,.15)),weight=impact);r(s,'head',-.4*recoil,-.5*recoil,-.2*recoil);r(s,'torso',-.22*recoil)
 cam=camera([.25,1.5,3.6],[0,1.2,.25],44)
 return {'steve':s,'notch':n,'cam':cam}
def qte_hit(t):return qte(t,'hit')
def qte_block(t):return qte(t,'block')
def qte_dodge(t):return qte(t,'dodge')
def qte_miss(t):return qte(t,'miss')

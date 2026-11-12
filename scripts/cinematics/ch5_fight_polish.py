"""Final acting pass; imported by the Blender MCP scene builder.
All coordinates are Godot Y-up. Contacts and props own their world targets.
"""
import math
from mathutils import Vector,Quaternion
import ch5_motion as M
PI=math.pi

def plant(a,base_x,step=0,hip=.68):
 a['hips']['p'][1]=hip
 R=M.rotation(a['root']['r']);root=Vector(a['root']['p'])
 forward=1 if a['root']['r'][1]>0 else -1
 for leg,knee,x,lead in [('rl','rk',-.11875,True),('ll','lk',.11875,False)]:
  foot=Vector((base_x+forward*(.10+step if lead else -.14),0,root.z))+R@Vector((x,0,0))
  local=R.inverted()@(foot-root)-Vector((x,hip,0))
  length=min(.748,local.length);direction=local.normalized();pole=Vector((0,0,1));pole=(pole-direction*pole.dot(direction)).normalized()
  mid=direction*length/2+pole*math.sqrt(max(0,.375**2-(length/2)**2))
  top=Vector((0,-1,0)).rotation_difference(mid.normalized());bottom=Vector((0,-1,0)).rotation_difference((local-mid).normalized())
  for key,q in [(leg,top),(knee,top.inverted()@bottom)]:a[key]['q']=[q.x,q.y,q.z,q.w]

def headpoint(a):return M.matrices(a)['head']@Vector((0,.13,.22))
def guard(a):
 for side in ['r','l']:
  M.r(a,side+'a',-.9,0,-.20 if side=='r' else .22);M.r(a,side+'e',-1.2)

def envelope(t,start=.78,hit=1.0,end=1.8):
 return M.ease(start,hit,t)*(1-M.ease(1.12,end,t))

def recoil(a,t,at=1.0,sign=1,heavy=False):
 # Sharp jaw/neck snap, then shoulders, pelvis and recovery; no idle sine.
 j=M.ease(at,at+.06,t)*(1-M.ease(at+.18,at+.65,t))
 b=M.ease(at+.035,at+.16,t)*(1-M.ease(at+.30,at+.85,t))
 M.r(a,'head',-.36*j,sign*.57*j,sign*.16*j)
 M.r(a,'torso',-.22*b,sign*.16*b,sign*.06*b)
 a['root']['p'][0]+=sign*.10*b*(1.4 if heavy else 1)
 return j

def exchange(t,kind):
 s=M.actor((-.50,0,.25),PI/2);n=M.actor((.50,0,.25),-PI/2)
 guard(s);guard(n);strike=envelope(t);recover=M.ease(1.75,2.4,t)
 counter=envelope(t,1.17,1.40,2.0)
 offensive=kind in ['jab','cross','hook','uppercut']
 if offensive:
  s['root']['p'][0]+=.28*strike
  M.r(s,'torso',.10+strike*.09,(-.36 if kind!='hook' else -.68)*strike,0)
  M.r(n,'la',-.2,0,.35);M.r(n,'le',-.45);M.r(n,'ra',.0,0,-.2);M.r(n,'re',-.55)
  side='l' if kind in ['jab','hook'] else 'r'
  M.r(s,side+'a',.10 if kind!='uppercut' else -.4,0,-.3 if side=='r' else .3);M.r(s,side+'e',-1.45)
  point=headpoint(n)
  # A hook sweeps an arc in depth; an uppercut rises under the chin.
  arc=math.sin(PI*M.ease(.78,1.0,t))
  if kind=='hook':point.z+=arc*.32;point.x-=arc*.12
  if kind=='uppercut':point.y-=arc*.46;point.x-=arc*.15
  M.fist(s,point,side,strike)
  recoil(n,t,heavy=kind in ['hook','uppercut'])
 elif kind in ['slip','roll']:
  n['root']['p'][0]-=.24*strike;M.r(n,'torso',.14,-.32*strike,0)
  M.fist(n,(-.47,1.64,.25),weight=strike)
  # Slip changes the head's line in depth; the roll also lowers the hips.
  s['root']['p'][2]+=(.25 if kind=='slip' else -.12)*strike
  M.r(s,'torso',.10,.12*strike,-.24*strike)
  M.r(s,'head',.1*strike,0,.12*strike)
 elif kind=='parry':
  n['root']['p'][0]-=.22*strike;M.r(n,'torso',.12,-.3*strike,0)
  M.fist(n,(-.40,1.65,.25+.32*strike),weight=strike)
  M.fist(s,(-.25,1.55,.53),'l',strike)
  s['root']['p'][0]+=.26*counter;M.r(s,'torso',.1,-.42*counter)
  M.fist(s,headpoint(n),'r',counter);recoil(n,t,1.4)
 elif kind=='guard':
  n['root']['p'][0]-=.22*strike
  M.r(s,'la',-1.7,0,.40);M.r(s,'le',-1.55);M.r(s,'ra',-1.65,0,-.40);M.r(s,'re',-1.55)
  M.fist(n,(-.35,1.68,.43),weight=strike)
  M.r(s,'torso',-.10*strike);M.r(s,'head',-.10*M.pulse(t,1,.25))
  # A compact elbow/cross follows the held guard.
  s['root']['p'][0]+=.26*counter;M.r(s,'torso',.08,-.35*counter)
  M.fist(s,headpoint(n),'r',counter);recoil(n,t,1.4)
 elif kind=='miss':
  n['root']['p'][0]-=.28*strike;M.r(n,'torso',.12,.28*strike)
  M.fist(n,headpoint(s),weight=strike);recoil(s,t,sign=-1,heavy=True)
 hip=.68-(.23*strike if kind=='roll' else 0)
 plant(s,-.5,0,hip);plant(n,.5)
 # Orbit remains on the same side of the action axis, with a small contact push.
 bias={'jab':-.55,'cross':.35,'hook':-.35,'uppercut':.45,'slip':-.6,'roll':.5,'parry':-.2,'guard':.6,'miss':.1}[kind]
 c=M.camera([bias+M.mix(-.15,.20,M.ease(0,2.4,t)),M.mix(1.52,1.68,M.ease(0,2.4,t)),M.mix(3.65,3.25,M.ease(.4,1.3,t))],[0,1.55,.25],46)
 impact=M.pulse(t,1,.20);c['p'][2]-=.055*impact;c['p'][1]+=.02*impact
 return {'steve':s,'notch':n,'cam':c}

def qte_jab(t):return exchange(t,'jab')
def qte_cross(t):return exchange(t,'cross')
def qte_hook(t):return exchange(t,'hook')
def qte_uppercut(t):return exchange(t,'uppercut')
def qte_slip(t):return exchange(t,'slip')
def qte_parry(t):return exchange(t,'parry')
def qte_guard(t):return exchange(t,'guard')
def qte_roll(t):return exchange(t,'roll')
def qte_miss(t):return exchange(t,'miss')

def finisher(t):
 s=M.actor((-.50,0,.25),PI/2);n=M.actor((.50,0,.25),-PI/2);guard(s);guard(n)
 hit=M.ease(.35,.65,t);hold=hit*(1-M.ease(.83,1.25,t))
 s['root']['p'][0]+=.28*hold;M.r(s,'torso',.14,-.55*hold)
 M.fist(s,headpoint(n),'r',hold)
 recoil(n,t,.65,heavy=True)
 fall=M.ease(.78,1.12,t);down=M.ease(1.12,1.3,t)
 # The jaw reaches the table at y=.96, z=1.18, after a quarter turn. The body then settles.
 n['root']['p']=[M.mix(.5,.75,fall),0,M.mix(.25,.45,fall)]
 M.r(n,'torso',M.mix(0,.89,fall),0,M.mix(0,-.10,down))
 M.r(n,'head',M.mix(0,.10,fall),0,M.mix(0,.08,down))
 n['hips']['p'][1]=M.mix(.68,.70,fall)
 M.r(n,'ra',.6*fall,0,-.2);M.r(n,'la',.45*fall,0,.3);M.r(n,'re',-.25);M.r(n,'le',-.35)
 # Turning the root toward the table makes forward flexion carry the jaw down.
 n['root']['r'][1]=M.mix(-PI/2,0,fall)
 plant(s,-.5);plant(n,.75,hip=n['hips']['p'][1])
 c=M.sample_camera([(0,M.camera([.2,1.55,3.8],[.1,1.2,.25],42)),(.60,M.camera([.35,1.55,3.6],[.15,1.2,.25],42)),(.65,M.camera([2.0,1.7,3.6],[.65,1.1,.75],43)),(1.4,M.camera([2.1,1.7,3.5],[.7,1.05,.75],43)),(3.6,M.camera([2.2,1.8,3.7],[.65,1,.75],44))],t)
 return {'steve':s,'notch':n,'cam':c}

CAN_AT=Vector((.90,1.10,-1.85))
CAN_OFFSET=Vector((0,.015,.15))
BAD_LENGTH=18.2
BRIDGE_LENGTH=4.2

def grip_at(a,target,rotation,weight=1):
 # Solve the real off-axis palm, including its 1 px lateral offset. The old
 # fist solver aimed a forearm endpoint and left props floating beside it.
 mats=M.matrices(a);parent=mats['torso'];shoulder=parent@Vector(M.REST['ra'])
 delta=parent.to_3x3().inverted()@(Vector(target)-shoulder)
 v=Vector(M.REST['grip']);l1=.25;l2=v.length
 length=min(l1+l2-.002,max(.14,delta.length));direction=delta.normalized()
 pole=Vector((0,0,-1));pole=(pole-direction*pole.dot(direction)).normalized()
 along=(l1*l1-l2*l2+length*length)/(2*length)
 mid=direction*along+pole*math.sqrt(max(0,l1*l1-along*along))
 top=Vector((0,-1,0)).rotation_difference(mid.normalized())
 bottom=v.normalized().rotation_difference((direction*length-mid).normalized())
 for key,q in [('ra',top),('re',top.inverted()@bottom)]:
  q=M.rotation(a[key]['r']).to_quaternion().slerp(q,weight);a[key]['q']=[q.x,q.y,q.z,q.w]
 fore=M.matrices(a)['re'];q=(fore.to_3x3().inverted()@rotation).to_quaternion()
 q=Quaternion().slerp(q,weight);a['grip']['q']=[q.x,q.y,q.z,q.w]

def can_matrix(pose,t):
 from mathutils import Matrix
 return M.matrices(pose['notch'])['grip']@Matrix.Translation(CAN_OFFSET) if t>=5.1 else Matrix.Translation(CAN_AT)

def support(a,feet):
 root=Vector(a['root']['p']);R=M.rotation(a['root']['r']);hip=a['hips']['p'][1]
 for side,x,target in [('r',-.11875,feet[0]),('l',.11875,feet[1])]:
  local=R.inverted()@(Vector(target)-root)-Vector((x,hip,0))
  length=min(.748,local.length);direction=local.normalized()
  pole=Vector((0,0,1));pole=(pole-direction*pole.dot(direction)).normalized()
  mid=direction*length/2+pole*math.sqrt(max(0,.375**2-(length/2)**2))
  top=Vector((0,-1,0)).rotation_difference(mid.normalized());bottom=Vector((0,-1,0)).rotation_difference((direction*length-mid).normalized())
  for key,q in [(side+'l',top),(side+'k',top.inverted()@bottom)]:a[key]['q']=[q.x,q.y,q.z,q.w]

def bad_end(t):
 s=M.actor((-1.6,0,1.2),PI*.75);n=M.actor((1.3,0,-1.4),-.6)
 # A measured draw to the hip, rear-foot drive, torso rotation, then the
 # straight elbow extension. Deletion catches the hand before its target.
 wind=M.ease(.3,1.02,t);drive=M.ease(1.08,1.48,t)
 s['root']['p']=list(Vector((-1.6,0,1.2)).lerp(Vector((-1.38,0,1.01)),wind).lerp(Vector((-.25,0,.06)),drive))
 s['hips']['p'][1]=M.mix(.74,.61,wind)+.05*drive
 M.r(s,'torso',M.mix(-.06,.20,drive),M.mix(.26,-.16,drive),-.035*drive)
 M.r(s,'ra',-.3,0,-.2);M.r(s,'re',-1.4)
 target=Vector((1.3,1.2,-1.4));root=Vector(s['root']['p']);R=M.rotation(s['root']['r'])
 hip_hand=root+R@Vector((-.27,1.03,.08))
 extension=root+(target-root).normalized()*.69+Vector((0,1.05,0))
 # World-space palm travels on one straight thrust line, never an overhead cut.
 hand=hip_hand.lerp(extension,drive)
 M.fist(s,hand,weight=1);M.aim_blade(s,target);M.aim_head(s,(1.3,1.65,-1.4))
 M.r(s,'la',-.6-drive*.35,0,.25);M.r(s,'le',-1.1+.6*drive)
 rear=Vector((-1.82,0,1.24));front=Vector((-1.23,0,.93)).lerp(Vector((.0,0,-.10)),drive)
 support(s,[rear.lerp(Vector((-.68,0,.45)),drive),front])
 M.aim_head(n,Vector(s['root']['p'])+Vector((0,1.6,0)))
 M.r(n,'ra',-.28,0,-.12);M.r(n,'re',-.85);M.r(n,'la',-.1,0,.1);M.r(n,'le',-.25)
 if 2.5<t<4.2:M.r(n,'head',M.mix(.18,.05,M.ease(2.8,3.5,t)),-.28,0)
 # The table is left of the exit aisle. The can stays on its support until
 # the palm reaches it. Its rim, rather than its centre, meets the mouth.
 reach=M.ease(4.3,5.1,t);lift=M.ease(5.4,6.3,t);lower=M.ease(8.0,8.85,t)
 if 4.3<t<9.25:
  drink=M.ease(6.3,6.8,t)*(1-lower)
  M.r(n,'head',-.12*drink,0,0);M.r(n,'torso',-.025*drink)
  R=M.rotation((-.98*drink,-.6,0))
  mouth=M.matrices(n)['head']@Vector((0,.18,.275))
  drinking=mouth-R@Vector((0,.174,0))
  carried=Vector((1.03,1.06,-.96))
  centre=CAN_AT.lerp(drinking,lift).lerp(carried,lower)
  grip_at(n,centre-R@CAN_OFFSET,R,reach)
 if t>=9.25:
  # Two straight, clear legs around the table, then a stop at the handle.
  yaw0=-.6;yaw1=math.atan2(1.25,-.65);yaw2=math.atan2(.95,-1.73)
  n['root']['r'][1]=M.mix(yaw0,yaw1,M.ease(9.25,9.65,t))
  if t>=9.65:M.walk(n,t,9.65,11.15,(1.3,0,-1.4),(2.55,0,-2.05));n['root']['r'][1]=yaw1
  if t>=11.15:
   M.walk(n,t,11.15,13.25,(2.55,0,-2.05),(3.5,0,-3.78));n['root']['r'][1]=M.mix(yaw1,yaw2,M.ease(11.15,11.5,t))
  if t>=13.25:n['root']['p']=[3.5,0,-3.78];n['root']['r'][1]=M.mix(yaw2,PI,M.ease(13.1,13.4,t))
  if t>=14.2:M.walk(n,t,14.2,16.5,(3.5,0,-3.78),(3.5,0,-5.65));n['root']['r'][1]=PI
  M.r(n,'head',.04,0,0);M.r(n,'ra',-.15,0,-.18);M.r(n,'re',-.9)
  # Carried upright alongside the torso. Independent wrist orientation keeps
  # the can from spinning when the body rounds the corner.
  fore=M.matrices(n)['re'];R=M.rotation((0,n['root']['r'][1],0));q=(fore.to_3x3().inverted()@R).to_quaternion();n['grip']['q']=[q.x,q.y,q.z,q.w]
  if 12.95<t<14.2:
   k=M.ease(12.95,13.45,t)*(1-M.ease(13.75,14.2,t));M.fist(n,(3.2,1.15,-4.38),'l',k)
 c=M.sample_camera([(0,M.camera([2.9,1.85,3.2],[-.1,1.18,-.35],47)),(1.05,M.camera([2.6,1.72,2.9],[.0,1.25,-.40],45)),(2.55,M.camera([2.4,1.72,2.5],[.5,1.3,-.8],44)),(2.8,M.camera([2.7,1.72,.8],[1.2,1.43,-1.4],37)),(4.15,M.camera([2.6,1.75,.8],[1.20,1.40,-1.4],39)),(4.3,M.camera([2.5,1.70,.55],[1.06,1.3,-1.4],43)),(8.95,M.camera([2.4,1.75,.6],[1.15,1.4,-1.3],43)),(9.1,M.camera([-.2,2.6,2.8],[2.3,1.05,-2.5],51)),(18.2,M.camera([.1,2.4,2.2],[2.7,1.0,-3.3],48))],t)
 return {'steve':s,'notch':n,'cam':c}

def bad_qte(t):
 if t>=BRIDGE_LENGTH:return bad_end(t-BRIDGE_LENGTH)
 # Match the evaluated final failed exchange exactly; recover with feet still
 # on this floor. Notch steps clear, raises delete(), Steve draws at his hip.
 d=exchange(2.4,'miss');s=d['steve'];n=d['notch']
 k=M.ease(.15,3.4,t)
 M.walk(s,t,.15,3.4,(-.5,0,.25),(-1.6,0,1.2));M.walk(n,t,.15,3.4,(.5,0,.25),(1.3,0,-1.4))
 s['root']['r'][1]=M.mix(PI/2,PI*.75,k);n['root']['r'][1]=M.mix(-PI/2,-.6,k)
 M.r(s,'torso',.12*(1-k));M.r(s,'head',.15*(1-k),0,0)
 M.r(s,'ra',M.mix(-.9,.12,k),0,-.18);M.r(s,'re',M.mix(-1.2,-.9,k))
 M.r(s,'la',-.5,0,.15);M.r(s,'le',-.8)
 gesture=M.ease(.65,1.4,t)*(1-M.ease(2.4,3.5,t))
 M.r(n,'ra',-.28-gesture*.7,0,-.15);M.r(n,'re',-.85-gesture*.3)
 M.aim_head(s,headpoint(n));M.aim_head(n,headpoint(s));M.aim_blade(s,(1.3,1.2,-1.4))
 if t<.15:return exchange(2.4,'miss')
 # Blend into the final attack's actual start pose, without a reset frame.
 target=bad_end(0);blend=M.ease(3.4,4.2,t)
 for who in ['steve','notch']:
  a=d[who];dest=target[who]
  for key in M.PARTS:
   qa=a[key].get('q');qa=Quaternion((qa[3],*qa[:3])) if qa else M.rotation(a[key]['r']).to_quaternion()
   qb=dest[key].get('q');qb=Quaternion((qb[3],*qb[:3])) if qb else M.rotation(dest[key]['r']).to_quaternion()
   q=qa.slerp(qb,blend);a[key]['q']=[q.x,q.y,q.z,q.w]
   a[key]['p']=list(Vector(a[key].get('p',M.REST.get(key,(0,0,0)))).lerp(Vector(dest[key].get('p',M.REST.get(key,(0,0,0)))),blend))
 c0=exchange(2.4,'miss')['cam'];c1=target['cam'];camk=M.ease(.15,4.2,t)
 d['cam']=M.camera(list(Vector(c0['p']).lerp(Vector(c1['p']),camk)),list(Vector(c0['to']).lerp(Vector(c1['to']),camk)),M.mix(c0['fov'],c1['fov'],camk))
 return d

portal_previous=M.portal
def portal(index,t):
 d=portal_previous(index,t);p=d['notch'] if index%2==0 else d['steve'];v=d['steve'] if index%2==0 else d['notch']
 if .89<=t<1.45:
  # First hit now snaps the jaw, folds the neck into the shoulders and forces
  # one support correction before the counter. The root never teleports away.
  j=M.ease(.89,.94,t)*(1-M.ease(1.02,1.35,t));b=M.ease(.92,1.05,t)*(1-M.ease(1.12,1.43,t))
  M.r(p,'head',-.48*j,-.72*j,-.18*j);M.r(p,'torso',-.20*b,-.16*b,-.08*b)
  p['root']['p'][0]-=.12*b;p['hips']['p'][1]=.75-.06*b;M.r(p,'rk',.18*b);M.r(p,'lk',.13*b)
  M.r(p,'la',-1.45*j,0,.3);M.r(p,'le',-1.1)
 c=d['cam'];j=M.pulse(t,.89,.18);c['p'][0]-=.045*j;c['p'][2]-=.08*j
 return d

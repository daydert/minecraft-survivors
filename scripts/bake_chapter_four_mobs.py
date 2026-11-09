"""Chapter IV mobs: vanilla UVs on connected, deformed cuboid hierarchies.

Own atlases/metadata/provenance. Existing chapter atlases are never written.
"""
from pathlib import Path
import json, math
import numpy as np
from PIL import Image
from import_minecraft_assets import ROOT, Importer, bake, box, find_client, tinted
from bake_minecraft_characters import part, transform, action_pose, DIRECTIONS, humanoid, creeper
from bake_v2_assets import witch, actor_atlas, block


def flesh(imp, origin, size):
    return block(imp, 'red_concrete_powder', origin, size, tint=(255,200,190))


def bone(imp, origin, size):
    return block(imp, 'bone_block_side', origin, size)


def tissue(imp, origin, size):
    return block(imp,'mushroom_stem',origin,size,tint=(245,180,172))


def beam(imp, start, end, width=.8, meat=False):
    a,b=np.array(start,float),np.array(end,float);d=b-a;length=float(np.linalg.norm(d))
    mesh=(tissue if meat else bone)(imp,(-width/2,-width/2,0),(width,width,length))
    return transform(mesh,(-math.asin(d[1]/length),math.atan2(d[0],d[2]),0),offset=a)


def open_ribs(imp,y=14,z=-3,width=8,height=9):
    # A deep dark cavity, pale membranes, exposed organs and outward rib arches.
    mesh=block(imp,'coal_block',(-width/2,y,z-.8),(width,height,1.6))
    mesh+=tissue(imp,(-width*.42,y+.3,z-.9),(width*.84,height*.78,.8))
    mesh+=flesh(imp,(-width*.25,y+.5,z-1.5),(width*.5,height*.75,1.5))
    for row in range(3):
        yy=y+height*.3+row*height*.28
        for sign in [-1,1]:
            path=[(sign*.8,yy,z-1.5),(sign*width*.6,yy+1,z-4),(sign*width*.85,yy+2.5,z-2)]
            mesh+=beam(imp,path[0],path[1],1)
            mesh+=beam(imp,path[1],path[2],1)
    # Two attached loops of exposed intestine hang below the rib cage.
    path=[(-2,y+3,z-2),(-3,y-1,z-3),(0,y-3,z-3),(3,y-1,z-3),(2,y+2,z-2)]
    for a,b in zip(path,path[1:]):mesh+=beam(imp,a,b,1.8,True)
    return mesh


def split_head(imp,tex,y=24,height=8):
    upper=part(tex,(-4,y+3,-4),(8,height-3,8),(0,0))
    jaw=part(tex,(-4,y,-4),(8,3,8),(0,height-3))
    jaw+=tissue(imp,(-3,y+2.7,-4),(6,.8,7))
    jaw+=flesh(imp,(-1,y+3,-6),(2,.8,5))
    for x in [-2.5,0,2.5]:jaw+=bone(imp,(x-.6,y+3,-4.4),(1.2,1.4,1))
    upper+=block(imp,'coal_block',(-3.5,y+2,-4.5),(7,2,5))
    for x in [-2.5,0,2.5]:upper+=bone(imp,(x-.5,y+3,-4.7),(1,1.8,1))
    upper+=transform(jaw,(-.68,0,.08),pivot=(0,y+3,3))
    for sign in [-1,1]:upper+=beam(imp,(sign*3,y+4,2),(sign*3,y,0),1.1,True)
    return upper


def item(imp, name, grip, angle=0, scale=1):
    tex=imp.tex('item/'+name)
    # Handle is the lower-right end of the vanilla tool sprite.
    points=np.array([[-13,13,0],[3,13,0],[3,-3,0],[-13,-3,0]],float)*scale
    return transform([(points,tex,(0,0,16,16),1)],(0,0,angle),offset=grip)


def flayed(imp,state,i,n,large=False):
    gait,lift,action,hurt,breath=action_pose(state,i,n)
    tex=imp.tex('entity/zombie/zombie')
    mesh=transform(split_head(imp,tex),(.08,0,-.14),pivot=(0,24,0))
    torso=part(tex,(-4,12,-2),(8,12,4),(16,16))
    mesh+=torso[1:]  # Remove the front skin surface; the chest is physically open.
    mesh+=open_ribs(imp,14,-2.3,8,9)
    for sign in [-1,1]:
        flap=part(tex,(-1.8,11,-2),(3.6,11,1),(16,17))
        mesh+=transform(flap,(.12,sign*.8,sign*.15),pivot=(0,22,0),offset=(sign*5,0,-3))
    for sign in [-1,1]:
        mesh+=part(tex,(sign*2-2,0,-2),(4,12,4),(0,16),pivot=(sign*2,12,0),angles=(gait*.48*sign,0,0))
        shoulder=(sign*5,22,0)
        if sign<0:
            arm=part(tex,(-2,12,-2),(4,10,4),(40,16))
            arm+=flesh(imp,(-1,11,-1),(2,2,2))
            arm+=part(tex,(-1.5,4,-1.5),(3,7,3),(40,21),pivot=(0,11,0),angles=(-.75+gait*.14,0,.35))
            mesh+=transform(arm,(.12+action*.6,0,.12),pivot=(0,22,0),offset=(sign*5,0,0))
        else:
            arm=part(tex,(-2,10,-2),(4,12,4),(40,16))
            if large:arm+=item(imp,'iron_shovel',(0,10,-2),-.35,1.6)
            mesh+=transform(arm,(.8+action*1.2,0,-.12),pivot=(0,22,0),offset=(sign*5,0,0))
    if large:
        mesh+=tissue(imp,(-6,16,1),(12,12,7))
        for yy in [19,23,27]:mesh+=bone(imp,(-1,yy,7),(2,1.4,3))
    return transform(mesh,(hurt*.3,0,0),pivot=(0,12,0),offset=(0,lift+breath,0))


def skeleton(imp,state,i,n):
    gait,lift,action,hurt,breath=action_pose(state,i,n)
    tex=imp.tex('entity/skeleton/skeleton')
    mesh=split_head(imp,tex)
    mesh+=part(tex,(-4,12,-2),(8,12,4),(16,16))[1:]
    mesh+=open_ribs(imp,14,-2,7,8)
    mesh+=tissue(imp,(2,15,0),(5,10,6))
    for sign in [-1,1]:
        mesh+=part(tex,(sign*2-1,0,-1),(2,12,2),(0,16),pivot=(sign*2,12,0),angles=(gait*.5*sign,0,0))
        arm=part(tex,(-1,10,-1),(2,12,2),(40,16))
        if sign>0:
            arm+=item(imp,'bow',(0,10,-2),-.3,1.0)
            arm+=flesh(imp,(-1.5,10,-1.5),(3,4,3))
        mesh+=transform(arm,(.25+action*(1.1 if sign>0 else .9),0,sign*.1),pivot=(0,22,0),offset=(sign*5,0,0))
    return transform(mesh,offset=(0,lift+breath,0))


def spider(imp,state,i,n):
    gait,lift,action,hurt,breath=action_pose(state,i,n)
    tex=imp.tex('entity/spider/spider')
    mesh=part(tex,(-4,5,-11),(8,7,8),(32,4))
    mesh+=part(tex,(-3,5,-3),(6,6,6),(0,0))
    # Split abdomen remains connected by exposed tissue and three ribs.
    for sign in [-1,1]:
        half=part(tex,(sign*3-2,4,2),(4,8,12),(0,12))
        mesh+=transform(half,(0,0,sign*(.62+action*.2)),pivot=(sign*2,8,2))
    mesh+=tissue(imp,(-3,4,2),(6,9,12))
    mesh+=flesh(imp,(-2,9,3),(4,6,9))
    for z in [3,7,11]:
        for sign in [-1,1]:
            mesh+=beam(imp,(0,10,z),(sign*6,14,z),1)
            mesh+=beam(imp,(sign*6,14,z),(sign*8,12,z+1),1)
    mesh+=block(imp,'coal_block',(-3,5,-11.3),(6,4,1))
    for x in [-2,0,2]:mesh+=bone(imp,(x-.6,5,-12),(1.2,3,1.5))
    for sign in [-1,1]:
        for leg in range(4):
            phase=i/8*math.tau+leg*1.8+sign*.8
            yaw=(leg-1.5)*.42+(.25*math.sin(phase) if state=='walk' else action*.1)
            roll=-sign*(.35+leg*.08+(.22*math.cos(phase) if state=='walk' else -action*.12))
            limb=part(tex,(0,-1,-1),(14 if sign<0 and leg==1 else 16,2,2),(18,0))
            if sign<0:limb=transform(limb,scale=(-1,1,1))
            mesh+=transform(limb,(0,yaw,roll),offset=(sign*3,7,3-leg*2))
    return transform(mesh,offset=(0,lift*.3+breath,0))


def bloated(imp,state,i,n):
    mesh=creeper(imp,state,i,n)
    # Keep the four feet and recognizable green head. The torso is peeled open.
    head=split_head(imp,imp.tex('entity/creeper/creeper'),18)
    feet=mesh[12:]
    pulse=1+.07*math.sin(i*2) if state=='windup' else 1+.025*math.sin(i*1.3)
    core=open_ribs(imp,7,-3.0,10,10)
    core+=tissue(imp,(-5,6,-2),(10,13,7))
    core+=flesh(imp,(-4,8,-4),(8,9,4))
    tex=imp.tex('entity/creeper/creeper')
    for sign in [-1,1]:
        panel=part(tex,(-2.5,6,-2),(5,12,3),(16,16))
        core+=transform(panel,(0,sign*.8,sign*.15),pivot=(0,18,0),offset=(sign*5,0,0))
    return head+feet+transform(core,pivot=(0,12,0),scale=(pulse,1,pulse))


def villager(imp,state,i,n,arms=True,bell=False):
    gait,lift,action,hurt,breath=action_pose(state,i,n)
    tex=imp.tex('entity/villager/villager')
    mesh=[]
    head=part(tex,(-4,24,-4),(4,10,8),(0,0)) if bell else split_head(imp,tex,24,10)
    head+=part(tex,(-2 if bell else -1,25,-6),(2,4,2),(24,0))
    if bell:
        head+=block(imp,'gold_block',(0,24,-4),(7,8,8))
        head+=block(imp,'gold_block',(-1,23,-5),(9,2,10))
        head+=bone(imp,(2,20,-1),(2,4,2))
        head+=tissue(imp,(-2,22,-4),(4,5,6))
        head+=beam(imp,(-4,27,-3),(1,23,-6),1.5,True)
    mesh+=transform(head,(-action*.2,0,hurt),pivot=(0,24,0),offset=(0,action*1.2 if bell else 0,0))
    mesh+=part(tex,(-4,12,-3),(8,12,6),(16,20))[1:]
    mesh+=part(tex,(-4,4,-3),(8,20,6),(0,38))[1:]
    mesh+=open_ribs(imp,12,-3.2,7,10)
    for sign in [-1,1]:
        mesh+=part(tex,(sign*2-2,0,-2),(4,12,4),(0,22),pivot=(sign*2,12,0),angles=(gait*.5*sign,0,0))
        if arms:mesh+=part(tex,(sign*6-2,10,-2),(4,12,4),(44,22),pivot=(sign*5,22,0),angles=(gait*.2+action*1.6,0,sign*.12))
    mesh+=flesh(imp,(-4.2,14,-3.2),(3,6,1))
    return transform(mesh,offset=(0,lift+breath,0))


def crawler(imp,state,i,n):
    mesh=transform(villager(imp,state,i,n,arms=False),(math.pi/2,0,0),pivot=(0,12,0),offset=(0,-6,0))
    tex=imp.tex('entity/villager/villager')
    gait=math.sin(i/8*math.tau) if state=='walk' else 0
    for sign in [-1,1]:
        limb=part(tex,(-1.5,3,-11),(3,3,12),(44,22))
        limb+=part(tex,(-1.5,0,-13),(3,4,3),(44,22))
        mesh+=transform(limb,(0,gait*.16*sign,0),pivot=(0,4,0),offset=(sign*5,0,0))
    return mesh


def fused(imp,state,i,n,lower=False):
    mesh=villager(imp,state,i,n)
    if not lower:
        upper=transform(villager(imp,state,i,n),(.25,.5,-.4),pivot=(0,12,0),scale=(.75,.75,.75),offset=(2,22,3))
        mesh+=upper
        mesh+=tissue(imp,(-5,20,-2),(12,15,10))
        mesh+=flesh(imp,(-3,22,-3),(7,11,3))
        for yy in [24,28,32]:mesh+=beam(imp,(-5,yy,-3),(7,yy+2,-4),1.2)
    else:mesh+=flesh(imp,(-3,25,-2),(6,3,5))
    return mesh


def quadruped(imp,kind,state,i,n,sheared=False):
    gait,lift,action,hurt,breath=action_pose(state,i,n)
    cow=kind=='cow';wolf=kind=='wolf'
    path='entity/cow/temperate_cow' if cow else 'entity/wolf/wolf' if wolf else 'entity/sheep/sheep'
    tex=imp.tex(path)
    mesh=[]
    if wolf:
        torso=part(tex,(-3,0,-3),(6,9,6),(18,14))
        mesh+=transform(torso,(math.pi/2,0,0),offset=(0,11,-1))
        mesh+=part(tex,(-4,8,-6),(8,7,7),(21,0))
        head=part(tex,(-4,9,-12),(8,8,6),(0,0))
        head+=part(tex,(-3,11,-18),(6,3,7),(0,10))
        head+=block(imp,'coal_block',(-3,7,-18.2),(6,4,7))
        jaw=part(tex,(-3.5,5,-18),(7,2,8),(0,10))
        jaw+=tissue(imp,(-3,7,-18),(6,.7,7))
        for x in [-2,0,2]:
            jaw+=bone(imp,(x-.6,7,-18),(1.2,2.5,1))
            head+=bone(imp,(x-.5,9,-18.1),(1,3,1))
        jaw+=flesh(imp,(-1,7.5,-20),(2,.8,5))
        head+=transform(jaw,(-.45-action*.3,0,.1),pivot=(0,9,-10))
        for sign in [-1,1]:head+=beam(imp,(sign*3,12,-11),(sign*3.5,6,-14),1,True)
        for sign in [-1,1]:head+=part(tex,(sign*3-1,16,-10),(2,3,1),(16,14))
        mesh+=transform(head,(-action*.2,0,0),pivot=(0,12,-6))
        for x in [-2.5,2.5]:
            for z in [-4,5]:mesh+=part(tex,(x-1,0,z-1),(2,9,2),(0,18),pivot=(x,9,z),angles=(gait*.8*(1 if x*z>0 else -1),0,0))
        mesh+=tissue(imp,(-3.3,5,-1),(6.6,10,8))
        mesh+=flesh(imp,(-2,9,0),(4,6,7))
        for z in [-1,2,5]:
            for sign in [-1,1]:
                mesh+=beam(imp,(0,13,z),(sign*5,15,z),1)
                mesh+=beam(imp,(sign*5,15,z),(sign*6,10,z+1),1)
        for z in [0,3,6]:mesh+=bone(imp,(-.7,15,z),(1.4,2,2))
        mesh+=part(tex,(-1,10,8),(2,2,8),(9,18),pivot=(0,11,8),angles=(-.35,0,0))
    else:
        dims=(12,18,10) if cow else (8,16,6)
        torso=part(tex,(-dims[0]/2,0,-dims[2]/2),dims,(18,4) if cow else (28,8))
        mesh+=transform(torso[:-1],(math.pi/2,0,0),offset=(0,17 if cow else 14,-8))
        if cow:
            head=part(tex,(-4,20,-16),(8,4,8),(0,0))
            head+=block(imp,'coal_block',(-3.7,16,-16.3),(7.4,5,6))
            jaw=part(tex,(-4,14,-16),(8,3,8),(0,5))
            jaw+=tissue(imp,(-3,17,-16),(6,1,7))
            for x in [-2.5,0,2.5]:
                jaw+=bone(imp,(x-.6,17,-16),(1.2,2,1))
                head+=bone(imp,(x-.5,18,-16.5),(1,2.5,1.5))
            head+=transform(jaw,(-.35-action*.25,0,0),pivot=(0,19,-8))
            for sign in [-1,1]:head+=beam(imp,(sign*3,21,-10),(sign*3,16,-12),1.2,True)
        else:
            head=part(tex,(-3,16,-14),(6,3,8),(0,0))
            head+=block(imp,'coal_block',(-2.8,12,-14.2),(5.6,4,5))
            head+=part(tex,(-3,11,-15),(6,2,8),(0,4))
            for x in [-2,0,2]:head+=bone(imp,(x-.5,13,-15),(1,2,1))
            head+=tissue(imp,(-2,13,-15.5),(4,1,4))
        if cow:
            for sign in [-1,1]:head+=part(tex,(sign*4-1,22,-13),(2,3,2),(22,0))
        mesh+=transform(head,(action*.32,0,0),pivot=(0,18,-8))
        for x in [-4 if cow else -2.5,4 if cow else 2.5]:
            for z in [-6,6]:mesh+=part(tex,(x-1.8,0,z-1.8),(3.6,12 if cow else 11,3.6),(0,16),pivot=(x,12,z),angles=(gait*.7*(1 if x*z>0 else -1),0,0))
        if cow:
            mesh+=open_ribs(imp,11,-8.5,10,11)
            mesh+=tissue(imp,(-5,10,-5),(10,10,8))
            mesh+=tissue(imp,(-4,6,-1),(8,7,10))
            mesh+=flesh(imp,(-3,5,0),(6,5,7))
            for sign in [-1,1]:mesh+=beam(imp,(sign*5,16,2),(sign*4,7,3),1.2,True)
            for sign in [-1,1]:
                flap=part(tex,(-2,12,-9),(4,9,1),(28,14))
                mesh+=transform(flap,(0,sign*(.55+action*.75),0),pivot=(-sign*2,17,-8),offset=(sign*2,0,0))
            for z in [-4,1,6]:
                for sign in [-1,1]:mesh+=beam(imp,(sign*5,16,z),(sign*8,19,z+2),1.2)
        elif not sheared:
            wool=imp.tex('entity/sheep/sheep_wool')
            woolmesh=part(wool,(-4,0,-3),(8,16,6),(28,8))
            shell=transform(woolmesh,(math.pi/2,0,0),offset=(0,14,-8),scale=(1.45,1.04,1.6))
            # Sparse tufts and two peeled wool flaps expose the body underneath.
            mesh+=shell[2:4]
            for sign in [-1,1]:
                tuft=part(wool,(-2,7,-3),(4,9,5),(28,8))
                mesh+=transform(tuft,(0,sign*.4,sign*.5),pivot=(0,16,0),offset=(sign*5,0,-2))
            mesh+=open_ribs(imp,7,-9.2,8,9)
            mesh+=flesh(imp,(-4,8,-4),(8,8,6))
            mesh+=tissue(imp,(-2.5,4,-1),(5,8,7))
        else:
            mesh+=tissue(imp,(-4,7,-5),(8,9,9))
            mesh+=open_ribs(imp,6,-9.2,7,8)
    return transform(mesh,(hurt*.15,0,0),offset=(0,lift*.4+breath,0))


def infected_witch(imp,state,i,n):
    base=witch(imp,state,i,n)
    tex=imp.tex('entity/witch')
    # Replace the head with an articulated jaw and open both torso/robe fronts.
    # Preserve the actual hat, nose, arms and palm-bound potion hierarchy.
    mesh=split_head(imp,tex,24,10)
    mesh += [face for index,face in enumerate(base) if index not in {0,1,2,3,4,5,36,42}]
    mesh+=open_ribs(imp,11,-4.1,8,11)
    mesh+=tissue(imp,(-7,11,3),(15,17,9))
    mesh+=flesh(imp,(-5,14,9),(11,11,5))
    mesh+=tissue(imp,(-5,9,-4),(3,7,4))
    mesh+=flesh(imp,(-4,10,-5),(3,5,3))
    for yy in [16,21,26]:
        mesh+=beam(imp,(-6,yy,9),(-9,yy+2,10),1.4)
        mesh+=beam(imp,(6,yy,9),(9,yy+2,10),1.4)
    mesh+=block(imp,'iron_block',(-5,12,8),(10,8,6),tint=(96,88,90))
    mesh+=block(imp,'slime_block',(-4,19,9),(8,2,4))
    for x in [-3,2]:
        mesh+=block(imp,'glass',(x,18,8),(3,6,3))
        mesh+=block(imp,'slime_block',(x+.5,18.5,8.5),(2,3,2))
    return mesh


def horse(imp,state,i,n):
    gait,lift,action,hurt,breath=action_pose(state,i,n)
    tex=imp.tex('entity/horse/horse_skeleton')
    mesh=part(tex,(-5,12,-9),(10,10,22),(0,32))
    neck=part(tex,(-3,19,-11),(6,14,6),(0,0),pivot=(0,20,-7),angles=(-.3-action*.14,0,0))
    head=part(tex,(-2.5,29,-18),(5,6,10),(0,13))
    neck+=head
    mesh+=neck
    for x in [-3.5,3.5]:
        for z in [-6,10]:mesh+=part(tex,(x-1.5,0,z-1.5),(3,13,3),(48,21),pivot=(x,13,z),angles=(gait*.9*(1 if x*z>0 else -1),0,0))
    rider=transform(humanoid(imp,'skeleton',state,i,n),scale=(.7,.7,.7),offset=(0,21,2))
    mesh+=rider
    mesh+=tissue(imp,(-5,18,-2),(10,13,9))
    mesh+=flesh(imp,(-4,9,-1),(8,13,8))
    for z in [-5,0,5,10]:
        for sign in [-1,1]:mesh+=beam(imp,(sign*4,17,z),(sign*7,12,z+1),1.3)
    mesh+=block(imp,'coal_block',(-2.5,27,-18.3),(5,4,3))
    for x in [-1.8,0,1.8]:mesh+=bone(imp,(x-.4,25.5,-18.5),(.8,3,1))
    return transform(mesh,offset=(0,lift+breath,0))


def parasite(imp,state,i,n):
    gait,lift,action,hurt,breath=action_pose(state,i,n)
    tex=imp.tex('entity/silverfish')
    mesh=bone(imp,(-3,1,-4),(6,4,9))
    mesh+=flesh(imp,(-1,3,-2),(2,2,5))
    for sign in [-1,1]:
        for z in [-2,1,4]:mesh+=bone(imp,(sign*3-1,0,z),(3,1,1))
    return transform(mesh,offset=(0,lift*.3,0))


def chicken(imp,state,i,n):
    gait,lift,action,hurt,breath=action_pose(state,i,n)
    tex=imp.tex('entity/chicken/temperate_chicken')
    mesh=part(tex,(-3,3,-3),(6,6,6),(0,9))
    mesh+=part(tex,(-2,10,-7),(4,6,3),(0,0))
    mesh+=tissue(imp,(-1,7,-5),(2,5,2))
    mesh+=bone(imp,(-.5,6,-4),(1,5,1))
    mesh+=part(tex,(-2,8,-10),(4,2,3),(14,0))
    mesh+=part(tex,(-1,6,-8),(2,2,2),(14,4))
    for sign in [-1,1]:
        mesh+=part(tex,(sign*2-1,0,-1),(2,3,2),(26,0),pivot=(sign*2,3,0),angles=(gait*sign,0,0))
        mesh+=part(tex,(sign*4-1,3,-2),(2,5,5),(24,13),pivot=(sign*3,8,0),angles=(0,0,gait*.4*sign))
    return mesh


def generate(only=None):
    version,client,_=find_client(Path.home()/'.local/share/PrismLauncher');imp=Importer(client)
    base=json.loads((ROOT/'data/animations.json').read_text())['actors']['zombie']
    definitions={
      'flayed_zombie':(flayed,(40,44),.87,(20,39)),
      'growth_skeleton':(skeleton,(48,44),.9,(24,39)),
      'torn_spider':(spider,(64,40),1.0,(32,26)),
      'bloated_creeper':(bloated,(40,40),.98,(20,35)),
      'hungry_wolf':(lambda *a:quadruped(*a[:1],'wolf',*a[1:]),(48,40),1.0,(24,32)),
      'crawler':(crawler,(56,40),.86,(28,27)),
      'open_cow':(lambda *a:quadruped(*a[:1],'cow',*a[1:]),(64,48),.98,(32,40)),
      'matted_sheep':(lambda *a:quadruped(*a[:1],'sheep',*a[1:]),(48,40),1.0,(24,33)),
      'sheared_sheep':(lambda *a:quadruped(*a[:1],'sheep',*a[1:],sheared=True),(48,40),1.0,(24,33)),
      'infected_witch':(infected_witch,(48,52),.8,(24,46)),
      'fused_villagers':(fused,(48,64),.82,(24,58)),
      'fused_lower':(lambda *a:fused(*a,lower=True),(48,64),.82,(24,58)),
      'gravedigger':(lambda *a:flayed(*a,large=True),(80,72),1.45,(40,61)),
      'bellringer':(lambda *a:villager(*a,bell=True),(48,48),.95,(24,42)),
      'bone_rider':(horse,(80,72),1.0,(40,62)),
      'parasite':(parasite,(24,20),1.0,(12,14)),
      'chicken':(chicken,(24,24),.85,(12,20)),
    }
    previous=json.loads((ROOT/'data/chapter_four_mobs.json').read_text()) if only else {}
    previous_manifest=json.loads((ROOT/'docs/CHAPTER_FOUR_MOBS_MANIFEST.json').read_text()) if only else {}
    sprites=previous.get('sprites',[]);actors=previous.get('actors',{})
    for name,(builder,frame,scale,anchor) in definitions.items():
        if only and name not in only:continue
        spec=json.loads(json.dumps(base));spec['states']['death']={'start':22,'durations':[.1,.12,.14,.2],'loop':False};spec['columns']=26;spec['frame_size']=list(frame);spec['anchor']=list(anchor);spec['pivot']=list(anchor)
        spec['shadow_size']=[15,4] if name in ['gravedigger','bone_rider'] else [12,3] if name in ['open_cow','torn_spider'] else [7,2]
        # Action clips use normalized encounter progress; arbitrary attack lengths
        # remain synchronized with the same warning/effect/collision clock.
        def animated(imp,state,i,n,builder=builder):
            mesh=builder(imp,state,i,n)
            if state=='death':
                fall=(i+1)/n
                mesh=transform(mesh,(-fall*math.pi/2,0,fall*.1),pivot=(0,0,0),offset=(0,fall*5,0))
            return mesh
        # Render with overscan and crop a common union across every pose/direction.
        # This preserves the ground anchor and never truncates a falling body.
        pad=40;large=(frame[0]+pad*2,frame[1]+pad*2)
        large_anchor=(anchor[0]+pad,anchor[1]+pad)
        raw=actor_atlas(imp,name,animated,large,scale,large_anchor,spec)
        frames=[];bounds=[]
        for row in range(3):
            for col in range(spec['columns']):
                f=raw.crop((col*large[0],row*large[1],(col+1)*large[0],(row+1)*large[1]))
                frames.append(f);bounds.append(f.getbbox())
        union=(min(b[0] for b in bounds)-2,min(b[1] for b in bounds)-2,max(b[2] for b in bounds)+2,max(b[3] for b in bounds)+2)
        frame=(union[2]-union[0],union[3]-union[1]);new_anchor=(large_anchor[0]-union[0],large_anchor[1]-union[1])
        spec['frame_size']=list(frame);spec['anchor']=list(new_anchor);spec['pivot']=list(new_anchor)
        atlas=Image.new('RGBA',(frame[0]*spec['columns'],frame[1]*3))
        for j,f in enumerate(frames):atlas.paste(f.crop(union),((j%spec['columns'])*frame[0],(j//spec['columns'])*frame[1]))
        imp.save(atlas,'ch4_'+name+'_atlas',['vanilla entity/item/block textures; connected custom hierarchy'])
        if 'ch4_'+name+'_atlas' not in sprites:sprites.append('ch4_'+name+'_atlas')
        actors['ch4_'+name]=spec
        print('BAKED',name,flush=True)
    imp.save(bake(block(imp,'coarse_dirt',(-10,0,-6),(20,18,12)),(24,28),1,(12,22),yaw=0,elevation=20),'ch4_earth_wall',['block/coarse_dirt'])
    if 'ch4_earth_wall' not in sprites:sprites.append('ch4_earth_wall')
    (ROOT/'data/chapter_four_mobs.json').write_text(json.dumps(dict(sprites=sprites,actors=actors),indent=2)+'\n')
    previous_manifest.setdefault('raw_files',{}).update(imp.files);previous_manifest.setdefault('derived',{}).update(imp.derived)
    previous_manifest.update(version=version,client_jar=str(client))
    (ROOT/'docs/CHAPTER_FOUR_MOBS_MANIFEST.json').write_text(json.dumps(previous_manifest,indent=2)+'\n')

if __name__=='__main__':generate()

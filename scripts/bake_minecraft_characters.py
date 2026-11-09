"""Bake textured Minecraft cuboids into the game's animated orthographic atlases.

No image generation or painted character parts: every face samples the local
vanilla texture. Herobrine is the Steve skin with white eyes and a custom pose.
The CPU rasterizer is shared with the original-item importer.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageChops

from import_minecraft_assets import ROOT, Importer, bake, box, find_client

OUT=ROOT/"assets/sprites"
SOURCES={"steve":"entity/player/wide/steve", "zombie":"entity/zombie/zombie",
         "skeleton":"entity/skeleton/skeleton", "creeper":"entity/creeper/creeper",
         "spider":"entity/spider/spider", "slime":"entity/slime/slime",
         "ravager":"entity/illager/ravager", "vindicator":"entity/illager/vindicator",
         "elite":"entity/zombie/zombie"}
# Models face -Z. Negative yaw projects that front toward screen RIGHT;
# main.gd mirrors this canonical side row only when travelling left.
# A slight three-quarter view retains the original face pixels at 32px.
DIRECTIONS={"down":0,"up":180,"side":-55}
STEVE_PIXEL_PHASE={"down":(0,.75),"up":(0,0),"side":(.5,.9)}


def rotation(x=0,y=0,z=0):
    cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    return np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]]) @ np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]]) @ np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]])


def transform(mesh,angles=(0,0,0),pivot=(0,0,0),offset=(0,0,0),scale=(1,1,1)):
    matrix=rotation(*angles)
    pivot=np.array(pivot); offset=np.array(offset)
    return [(((v-pivot)*scale)@matrix.T+pivot+offset,t,r,s) for v,t,r,s in mesh]


def part(tex,origin,size,uv,pivot=None,angles=(0,0,0),inflate=0):
    mesh=box(tex,origin,size,uv)
    if inflate:
        center=np.array(origin)+np.array(size)/2
        mesh=[(center+(v-center)*(1+2*inflate/np.array(size)),t,r,s) for v,t,r,s in mesh]
    return transform(mesh,angles,pivot or origin)


def java_part(tex,origin,size,uv,pivot=(0,0,0),angles=(0,0,0)):
    x,y,z=origin;w,h,d=size
    mesh=box(tex,(x,-y-h,z),size,uv)
    rx,ry,rz=angles
    return transform(mesh,(-rx,ry,-rz),offset=(pivot[0],24-pivot[1],pivot[2]))


def action_pose(state,index,count):
    t=index/max(1,count-1)
    gait=math.sin(index/8*math.tau) if state=="walk" else 0
    lift=abs(math.sin(index/8*math.tau))*0.55 if state=="walk" else 0
    action=(0.2+t*0.8) if state=="windup" else (1.3-t*0.3) if state=="attack" else (1-t)*0.7 if state=="recover" else 0
    hurt=math.sin(t*math.pi+0.5)*0.12 if state=="hurt" else 0
    breath=math.sin(index/max(1,count)*math.tau)*0.25 if state=="idle" else 0
    return gait,lift,action,hurt,breath


def humanoid(imp,name,state,index,count,seated=False):
    tex=imp.tex(SOURCES.get(name,SOURCES["steve"]))
    if name=="herobrine":
        tex=tex.copy()
        d=ImageDraw.Draw(tex)
        d.rectangle((9,12,10,12),fill="white")
        d.rectangle((13,12,14,12),fill="white")
    gait,lift,action,hurt,breath=action_pose(state,index,count)
    illager=name=="vindicator"; skeleton=name=="skeleton"
    zombie=name in ["zombie","elite"]
    mesh=[]
    if illager:
        mesh+=part(tex,(-4,24,-4),(8,10,8),(0,0),pivot=(0,24,0),angles=(hurt,0,0))
        mesh+=part(tex,(-1,19,-6),(2,4,2),(24,0))
        mesh+=part(tex,(-4,12,-3),(8,12,6),(16,20))
        mesh+=part(tex,(-4,4,-3),(8,20,6),(0,38),inflate=.25)
    else:
        mesh+=part(tex,(-4,24,-4),(8,8,8),(0,0),pivot=(0,24,0),angles=(hurt,0,breath*.01))
        mesh+=part(tex,(-4,12,-2),(8,12,4),(16,16))
        if name in ["steve","herobrine"]:
            mesh+=part(tex,(-4,24,-4),(8,8,8),(32,0),inflate=.25)
            mesh+=part(tex,(-4,12,-2),(8,12,4),(16,32),inflate=.25)
    upper=[]
    upper_body_face_count=len(mesh)
    # Head/body may lean during hurt; legs retain a fixed ground-space origin.
    for sign in [-1,1]:
        leg_w=2 if skeleton else 4
        lx=sign*1.9-leg_w/2
        uv=(0,16) if skeleton else ((0,16) if sign<0 or name not in ["steve","herobrine"] else (16,48))
        angles=(gait*.68*sign,0,0)
        leg=part(tex,(lx,0,-leg_w/2),(leg_w,12,leg_w),uv,pivot=(sign*1.9,12,0),angles=angles)
        if name in ["steve","herobrine"]:
            leg+=part(tex,(lx,0,-2),(4,12,4),(0,32) if sign<0 else (0,48),pivot=(sign*1.9,12,0),angles=angles,inflate=.20)
        if seated:
            # Riding pose, with the nearer leg crossing the other as in the
            # supplied seated reference. All original skin UVs are retained.
            leg=part(tex,(lx,0,-2),(4,12,4),uv,pivot=(sign*1.9,12,0),
                     angles=(1.18 if sign<0 else 1.48,sign*.16,0.05 if sign<0 else -.42))
            leg=transform(leg,offset=(0,6,-1))
        mesh+=leg
        arm_w=2 if skeleton else 4
        ax=sign*6-arm_w/2
        arm_uv=(40,16) if not illager else (40,46)
        if name in ["steve","herobrine"] and sign>0:arm_uv=(32,48)
        if zombie:arm_angle=1.38+gait*.12+action*.18
        elif skeleton:arm_angle=.1+action*1.1
        elif illager:arm_angle=.2+action*1.8 if sign<0 else gait*.35
        else:arm_angle=-gait*.6+(action*1.7 if sign<0 else action*.25)
        arm_rot=(arm_angle,0,-sign*.06)
        if seated:arm_rot=(.48,sign*.12,sign*.5)
        arm=part(tex,(ax,12,-arm_w/2),(arm_w,12,arm_w),arm_uv,pivot=(sign*5,22,0),angles=arm_rot)
        if name in ["steve","herobrine"]:
            arm+=part(tex,(ax,12,-2),(4,12,4),(40,32) if sign<0 else (48,48),pivot=(sign*5,22,0),angles=arm_rot,inflate=.25)
        if illager and sign<0:
            axe=imp.tex("item/iron_axe")
            # A generated-item plane with original transparent item pixels.
            quad=np.array([[ax-4,14,-1.5],[ax+8,14,-1.5],[ax+8,2,-1.5],[ax-4,2,-1.5]],dtype=float)
            arm+=transform([(quad,axe,(0,0,16,16),1.0)],arm_rot,(sign*5,22,0))
        if seated:
            arm=part(tex,(sign*6-2,24,-2),(4,6,4),arm_uv,pivot=(sign*5,28,0),angles=(.12,0,sign*.35))
            lower_uv=(40,22) if sign<0 else (32,54)
            arm+=part(tex,(sign*9-2,20,-3),(4,6,4),lower_uv,pivot=(sign*9,26,-1),angles=(math.pi/2,sign*.1,0))
        upper+=arm
    if seated:
        # Seated hips at y=18, shoulders at y=28, head at y=30..38.
        # Legs were already raised above; raise only original head/body parts.
        # A cuboid contributes six faces, not one mesh entry. Move the complete
        # head and torso together; moving just four entries hid the chest.
        mesh[:upper_body_face_count]=transform(mesh[:upper_body_face_count],offset=(0,6,0))
    mesh+=upper
    if name=="elite":
        armor=imp.tex("entity/equipment/humanoid/iron")
        mesh+=part(armor,(-4,24,-4),(8,8,8),(0,0),inflate=.7)
        mesh+=part(armor,(-4,12,-2),(8,12,4),(16,16),inflate=.55)
        for sign in [-1,1]:
            mesh+=part(armor,(sign*6-2,12,-2),(4,12,4),(40,16),pivot=(sign*5,22,0),angles=(1.38+gait*.12+action*.18,0,-sign*.06),inflate=.4)
    if not seated:mesh=transform(mesh,(hurt*.4,0,hurt*.3),pivot=(0,12,0),offset=(0,lift+breath,0))
    return mesh


def creeper(imp,state,index,count):
    tex=imp.tex(SOURCES["creeper"])
    gait,lift,action,hurt,breath=action_pose(state,index,count)
    mesh=part(tex,(-4,18,-4),(8,8,8),(0,0),pivot=(0,18,0),angles=(hurt,0,0))
    mesh+=part(tex,(-4,6,-2),(8,12,4),(16,16))
    for x in [-2,2]:
        for z in [-4,4]:
            mesh+=part(tex,(x-2,0,z-2),(4,6,4),(0,16),pivot=(x,6,z),angles=(gait*.65*(1 if x*z>0 else -1),0,0))
    scale=1+(.035*math.sin(index*2.2) if state=="windup" else 0)
    return transform(mesh,offset=(0,breath+lift*.2,0),scale=(scale,scale,scale))


def spider(imp,state,index,count):
    tex=imp.tex(SOURCES["spider"])
    gait,lift,action,hurt,breath=action_pose(state,index,count)
    mesh=java_part(tex,(-4,-4,-8),(8,8,8),(32,4),(0,15,-3))
    mesh+=java_part(tex,(-3,-3,-3),(6,6,6),(0,0),(0,15,0))
    mesh+=java_part(tex,(-5,-4,-6),(10,8,12),(0,12),(0,15,9))
    for sign in [-1,1]:
        for leg in range(4):
            phase=index/8*math.tau+leg*math.pi*.5+(math.pi if sign<0 else 0)
            yaw=(leg-1.5)*.4+(.24*math.sin(phase) if state=="walk" else action*.08)
            roll=-sign*(.55+(.2*math.cos(phase) if state=="walk" else 0))
            legmesh=part(tex,(0,-1,-1),(16,2,2),(18,0))
            if sign<0:legmesh=transform(legmesh,scale=(-1,1,1))
            mesh+=transform(legmesh,(0,yaw,roll),offset=(sign*3,9,3-leg*2))
    return transform(mesh,(hurt,0,0),offset=(0,lift*.3+breath,0))


def ravager(imp,state,index,count):
    tex=imp.tex(SOURCES["ravager"])
    gait,lift,action,hurt,breath=action_pose(state,index,count)
    # Cuboids, UV origins and hierarchy transcribed from 1.21.11 hez.class.
    mesh=java_part(tex,(-7,-10,-7),(14,16,20),(0,55),(0,1,2),(math.pi/2,0,0))
    mesh+=java_part(tex,(-6,6,-7),(12,13,18),(0,91),(0,1,2),(math.pi/2,0,0))
    mesh+=java_part(tex,(-5,-1,-18),(10,10,18),(68,73),(0,-7,5.5))
    head=java_part(tex,(-8,-20,-14),(16,20,16),(0,0),(0,9,-11.5))
    head+=java_part(tex,(-2,-6,-18),(4,8,4),(0,0),(0,9,-11.5))
    head+=java_part(tex,(-8,0,-16),(16,3,16),(0,36),(0,7,-9.5),(action*.22,0,0))
    for sign in [-1,1]:
        head+=java_part(tex,(0,-14,-2),(2,14,4),(74,55),(-10 if sign<0 else 8,-5,-19.5),(1.0995574,0,0))
    mesh+=transform(head,(action*.12+hurt,0,0),pivot=(0,20,-12))
    for x in [-8,8]:
        for z in [-5,18]:
            mesh+=java_part(tex,(-4,0,-4),(8,37,8),(64,0) if z<0 else (96,0),(x,-13,z),
                            (gait*.48*(1 if x*z>0 else -1),0,0))
    return transform(mesh,offset=(0,breath+lift*.6,-6.5))


def actor_frame(imp,name,state,index,count,row):
    size=(48,32) if name=="spider" else (64,64) if name=="ravager" else (32,32)
    yaw=DIRECTIONS[row]
    if name=="slime":
        tex=imp.tex(SOURCES[name]);gait,lift,action,hurt,breath=action_pose(state,index,count)
        squash=.80+index/max(1,count-1)*.1 if state=="windup" else 1.18 if state=="attack" else .88+index/max(1,count-1)*.12 if state=="recover" else .84+index*.08 if state=="hurt" else 1+breath*.04
        hop=3+2*math.sin(index/max(1,count-1)*math.pi/2) if state=="attack" else max(0,2-index) if state=="recover" else 0
        inner=box(tex,(-3,1,-3),(6,6,6),(0,16))
        inner+=box(tex,(-3.25,3.5,-4.1),(2,2,2),(32,0))+box(tex,(1.25,3.5,-4.1),(2,2,2),(32,4))
        inner+=box(tex,(0,2,-4.2),(1,1,1),(32,8))
        inner=transform(inner,scale=(1/squash,squash,1/squash),offset=(0,hop+breath,0))
        shell=tex.copy();shell.putalpha(shell.getchannel("A").point(lambda a:int(a*.38)))
        outer=transform(box(shell,(-4,0,-4),(8,8,8),(0,0)),scale=(1/squash,squash,1/squash),offset=(0,hop+breath,0))
        im=bake(inner,size,2.0,(16,27),yaw=yaw,elevation=22)
        im.alpha_composite(bake(outer,size,2.0,(16,27),yaw=yaw,elevation=22))
        return im
    mesh=(creeper(imp,state,index,count) if name=="creeper" else spider(imp,state,index,count) if name=="spider" else
          ravager(imp,state,index,count) if name=="ravager" else humanoid(imp,name,state,index,count))
    scale=.86 if name in ["steve","zombie","elite","skeleton"] else .81 if name=="vindicator" else .98 if name=="creeper" else .95 if name=="ravager" else .95
    center=(size[0]/2,53 if name=="ravager" else 23 if name=="spider" else 28)
    if name=="steve":
        # A one-texel eye row must survive every pose. Snap the subpixel root
        # bob to the output grid and keep a fixed sampling phase per view.
        # This samples the untouched skin; it does not paint or blink eyes.
        _,lift,_,_,breath=action_pose(state,index,count)
        bob=scale*(lift+breath)*math.cos(math.radians(20))
        dx,dy=STEVE_PIXEL_PHASE[row]
        center=(center[0]+dx,center[1]+dy+bob-round(bob))
    return bake(mesh,size,scale,center,yaw=yaw,elevation=20)


def block(imp,source,origin,size,top=None):
    tex=imp.tex("block/"+source);toptex=imp.tex("block/"+top) if top else tex
    faces={face:(toptex if face in ["up","down"] else tex,(0,0,16,16)) for face in ["north","south","east","west","up","down"]}
    return box(tex,origin,size,faces=faces)


def ending_assets(imp):
    mesh=block(imp,"stone_bricks",(-24,0,-17),(48,4,36))
    mesh+=block(imp,"stone_bricks",(-16,4,-10),(32,10,23))
    mesh+=block(imp,"polished_blackstone_bricks",(-16,14,8),(32,36,7))
    mesh+=block(imp,"stone_bricks",(-18,14,-11),(6,10,26))
    mesh+=block(imp,"stone_bricks",(12,14,-11),(6,10,26))
    mesh+=block(imp,"stone_bricks",(-19,48,7),(38,5,10))
    skin=imp.tex(SOURCES["steve"])
    for x,y,z in [(-15,24,-7),(15,24,-7),(-13,53,8),(13,53,8)]:
        mesh+=part(skin,(x-4,y,z-4),(8,8,8),(0,0))
    mesh+=transform(humanoid(imp,"herobrine","idle",0,4,seated=True),pivot=(0,18,0),scale=(1.35,1.35,1.35))
    for sign in [-1,1]:
        mesh+=block(imp,"netherrack",(sign*41-5,4,-2),(10,43,10))
        mesh+=block(imp,"nether_bricks",(sign*41-7,0,-4),(14,4,14))
    imp.save(bake(mesh,(192,176),1.55,(96,150),yaw=0,elevation=23),"herobrine_throne",
             [SOURCES["steve"],"block/stone_bricks","block/polished_blackstone_bricks","block/netherrack","block/nether_bricks"])
    # Fire sockets are projected from the same camera as the baked stage.
    sockets=[]
    for sign in [-1,1]:
        point=np.array([sign*41,47,3]);sockets.append([96+point[0]*1.55,150-(point[1]*math.cos(math.radians(23))+point[2]*math.sin(math.radians(23)))*1.55])
    for variant in range(3):
        dead=block(imp,"oak_log",(-3,0,-3),(6,42,6),"oak_log_top")
        imp.save(bake(dead,(64,72),1.28,(32,65),yaw=25+variant*5,elevation=22),f"tree_dead_{variant}",["block/oak_log","block/oak_log_top"])
    ground=Image.open(OUT/"ground.png").convert("RGB")
    burned=ImageChops.multiply(ground,Image.new("RGB",ground.size,(74,60,44)))
    imp.save(burned,"ground_scorched",["ground (derived vanilla block textures)"])
    imp.native_strip("nether_portal","block/nether_portal")
    imp.save(imp.tex("block/netherrack"),"nether_backdrop",["block/netherrack"])
    imp.save(imp.tex("block/obsidian"),"portal_frame",["block/obsidian"])
    return {"size":[192,176],"pivot":[96,150],"fire_sockets":sockets,
            "reference":"User-supplied seated Herobrine reference: relaxed throne pose, crossed legs, white eyes; four Steve heads and two netherrack braziers"}


def generate(names=None):
    version,client,_=find_client(Path.home()/".local/share/PrismLauncher")
    imp=Importer(client)
    data=json.loads((ROOT/"data/animations.json").read_text())
    if "vindicator" not in data["actors"]:
        data["actors"]["vindicator"]=json.loads(json.dumps(data["actors"]["zombie"]))
        data["actors"]["vindicator"]["states"]["windup"]["durations"]=[.25,.15,.1]
    selected=names or list(SOURCES)
    for name in selected:
        spec=data["actors"][name]
        spec.pop("generated_anchor",None)
        spec["source_texture"]="assets/minecraft/textures/"+SOURCES[name]+".png"
        spec["source_model"]="Minecraft textured cuboids; animated orthographic projection"
        spec["alpha_mode"]="translucent" if name=="slime" else "binary"
        spec["side_facing"]="right"
        spec["projection_yaw"]=DIRECTIONS
        w,h=spec["frame_size"]
        atlas=Image.new("RGBA",(w*spec["columns"],h*3))
        for row_i,row in enumerate(DIRECTIONS):
            for state,clip in spec["states"].items():
                for i in range(len(clip["durations"])):
                    atlas.paste(actor_frame(imp,name,state,i,len(clip["durations"]),row),((clip["start"]+i)*w,row_i*h))
        sources=[SOURCES[name]]
        if name=="elite":sources.append("entity/equipment/humanoid/iron")
        if name=="vindicator":sources.append("item/iron_axe")
        origin=(f"Origin: Minecraft Java {version}, local client {client}; vanilla textures {sources}. "
                f"Cuboid UV bake by scripts/bake_minecraft_characters.py; orthographic views {DIRECTIONS}; "
                "canonical side faces right and is mirrored by the runtime for left movement. "
                "Steve keeps original eye texels through pixel-snapped root motion and fixed camera sampling phases. "
                "Custom poses; no image generation or painted face pixels.")
        imp.save(atlas,name+"_atlas",sources,origin=origin)
        print("Baked",name,atlas.size)
    stage=ending_assets(imp) if names is None else None
    (ROOT/"data/animations.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
    (ROOT/"docs/ASSET_MANIFEST.json").write_text(json.dumps(data["actors"],ensure_ascii=False,indent=2)+"\n")
    manifest={"version":version,"client_jar":str(client),"raw_files":imp.files,"derived":imp.derived,
              "throne":stage,"notes":"All character faces sample original vanilla UV textures. Herobrine's white eyes and seated pose are custom. No imagegen assets are used by these atlases."}
    if names is None:
        (ROOT/"data/chapter_assets.json").write_text(json.dumps({"clips":imp.clips,"throne":stage},indent=2)+"\n")
        (ROOT/"docs/MINECRAFT_CHARACTER_MANIFEST.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    sheet=Image.new("RGBA",(1120,460),(26,26,26,255));draw=ImageDraw.Draw(sheet)
    font=ImageFont.truetype(str(ROOT/"assets/fonts/DejaVuSans.ttf"),11)
    for i,name in enumerate(SOURCES):
        spec=data["actors"][name];w,h=spec["frame_size"]
        im=Image.open(OUT/(name+"_atlas.png")).crop((0,0,w,h)).resize((w*3,h*3),Image.Resampling.NEAREST)
        x=(i%5)*224;y=(i//5)*230
        sheet.alpha_composite(im,(x+max(0,(224-im.width)//2),y+8))
        draw.text((x+8,y+210),name,font=font,fill="white")
    sheet.save(ROOT/"qa/minecraft_characters.png")
    print("Vanilla character baking complete",version)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--only",nargs="+");args=p.parse_args()
    generate(args.only)
    if args.only is None:
        from bake_nether_assets import generate as generate_nether
        generate_nether()
        from bake_herobrine_duel import generate as generate_duel
        generate_duel()

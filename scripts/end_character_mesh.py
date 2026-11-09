"""Shared original-skin rig with real shoulder/palm attachments for End equipment."""
import math
import numpy as np
from PIL import ImageDraw
from bake_minecraft_characters import part,transform

def held_item(imp,source,grip,scale=.8,anchor=(4.5,12),rotation=0):
 tex=imp.tex('item/'+source);w,h=tex.size;verts=[]
 for u,v in [(0,0),(w,0),(w,h),(0,h)]:
  x=(u-anchor[0])*scale;y=(anchor[1]-v)*scale
  verts.append(np.array(grip)+np.array([x*math.cos(rotation)-y*math.sin(rotation),x*math.sin(rotation)+y*math.cos(rotation),0]))
 return [(np.array(verts),tex,(0,0,w,h),1)]

def corruption(imp,final=False):
 skin=imp.tex('entity/player/wide/steve').copy();stone=imp.tex('block/obsidian')
 for y in range(64):
  for x in range(64):
   r,g,b,a=skin.getpixel((x,y))
   if not a:continue
   mask=(12<=x<16 and 8<=y<16) or (40<=x<56 and 16<=y<28) or (24<=x<30 and 20<=y<32) or (4<=x<8 and 20<=y<28)
   if mask:
    c=stone.getpixel((x%16,y%16));crack=(x*2+y)%11==0
    skin.putpixel((x,y),(142 if crack else c[0]+9,49 if crack else c[1],210 if crack else c[2]+18,a))
   elif final:
    skin.putpixel((x,y),(int(r*.64),int(g*.63),min(255,int(b*.8+12)),a))
 d=ImageDraw.Draw(skin)
 for x in [9,13]:d.rectangle((x,12,x+1,12),fill=(225,133,255,255))
 return skin

def rig(imp,tex,gear='idle',progress=0,phase='idle',gait=0,guard=False,final=False):
 wind=progress if phase=='windup' else 1-progress*.25 if phase=='attack' else (1-progress)*.7 if phase=='recover' else 0
 flight=gear in ['elytra','rocket']
 m=part(tex,(-4,24,-4),(8,8,8),(0,0))+part(tex,(-4,24,-4),(8,8,8),(32,0),inflate=.25)
 m+=part(tex,(-4,12,-2),(8,12,4),(16,16))+part(tex,(-4,12,-2),(8,12,4),(16,32),inflate=.25)
 for sign in [-1,1]:
  angle=gait*.65*sign
  if final and phase=='windup':angle=-sign*.18*progress
  elif final and phase=='attack':angle=-sign*.18+sign*.53*progress
  elif final and phase=='recover':angle=sign*.35*(1-progress)
  leg=part(tex,(sign*2-2,0,-2),(4,12,4),(0,16) if sign<0 else (16,48),angles=(angle,0,0),pivot=(sign*2,12,0))
  leg+=part(tex,(sign*2-2,0,-2),(4,12,4),(0,32) if sign<0 else (0,48),angles=(angle,0,0),pivot=(sign*2,12,0),inflate=.2)
  m+=leg
  shoulder=(sign*5,22,0);arm_rot=(-gait*.5*sign,0,-sign*.06)
  if sign<0 and gear not in ['idle','elytra']:
   if gear=='rocket':arm_rot=(.05,0,-.08)
   elif gear.startswith('spear'):arm_rot=(1.2+wind*.22,0,-.08)
   elif gear in ['mace','sword']:
    swing=2.4-progress*2.3 if phase=='attack' else .2+wind*2.2 if phase=='windup' else .2
    arm_rot=(swing,-.2+wind*.2,-.08)
   elif gear in ['dragon_breath','end_crystal','hand']:arm_rot=(1.05+wind*.25,0,-.08)
   else:arm_rot=(1.7-progress*1.6 if phase=='attack' else .2+wind*1.5,0,-.08)
  if sign>0 and guard:arm_rot=(.05 if flight else 1.0,0,-.16)
  arm=part(tex,(sign*6-2,12,-2),(4,12,4),(40,16) if sign<0 else (32,48))
  arm+=part(tex,(sign*6-2,12,-2),(4,12,4),(40,32) if sign<0 else (48,48),inflate=.2)
  grip=(sign*6,13,-2.4)
  if sign<0:
   if gear.startswith('spear') or gear=='rocket':
    tier=gear.removeprefix('spear_') if gear.startswith('spear_') else 'netherite'
    item=held_item(imp,tier+'_spear_in_hand',grip,1.05,(20,20),-.75)
    desired=0 if gear=='rocket' else -1.4
    arm+=transform(item,(desired-arm_rot[0],0,0),pivot=grip)
   elif gear in ['mace','knockback_stick','sword']:
    item=held_item(imp,{'mace':'mace','knockback_stick':'stick','sword':'netherite_sword'}[gear],grip,.9 if gear=='mace' else .82,(4.5,12),.8)
    desired=-.8-progress*1.7 if phase=='attack' else -.2 if phase=='windup' else -2.5*(1-progress) if phase=='recover' else 0
    arm+=transform(item,(desired-arm_rot[0],0,0),pivot=grip)
   elif gear=='dragon_breath':arm+=held_item(imp,'dragon_breath',grip,.64,(8,10))
   elif gear=='end_crystal':
    crystal=imp.tex('entity/end_crystal/end_crystal');core=part(crystal,(-4,-4,-4),(8,8,8),(32,0))
    core=[(v,t,tuple(c*2 for c in rect),shade) for v,t,rect,shade in core]
    arm+=transform(core,scale=(.65,.65,.65),offset=grip)
   elif gear=='hand':arm+=part(corruption(imp),(-8,12,-4),(4,10,4),(40,18))
  if sign>0 and guard:
   shield=imp.tex('entity/shield_base_nopattern')
   board=part(shield,(-6,-11,-.5),(12,22,1),(0,0))
   arm+=transform(board,scale=(.72,.72,.72),offset=(sign*6,15,-4))
  m+=transform(arm,arm_rot,shoulder)
 if flight:
  wings=imp.tex('entity/equipment/wings/elytra')
  for sign in [-1,1]:
   wing=part(wings,(-10,0,0),(10,20,2),(22,0))
   wing=transform(wing,(0,sign*.15,sign*(.55+math.sin(progress*math.tau)*.08)),pivot=(0,20,0))
   m+=transform(wing,scale=(-sign,1,1),offset=(sign*2,7,3))
  m=transform(m,(-1.08,0,0),pivot=(0,16,0),offset=(0,7,0))
 if final:
  # Whole-body counterrotation makes the blade windup a connected pose.
  twist=-.5+progress if phase=='attack' else -.5*progress if phase=='windup' else .5*(1-progress) if phase=='recover' else 0
  lean=.1*progress if phase=='windup' else .2*(1-progress) if phase=='attack' else 0
  m=transform(m,(lean,twist,0),pivot=(0,12,0))
 return m

"""Godot Y-up motion source. Contacts before effects; owns no simulation/RNG."""
import math
from mathutils import Vector
import ch5_motion as M
from ch5_fight_polish import support,grip_at

def spiral_raise(t):
 a=M.actor();k=M.ease(.12,1.05,t);hold=M.ease(2.05,2.6,t)
 a['hips']['p'][1]=.73-.05*math.sin(k*math.pi)
 M.r(a,'torso',-.05*math.sin(k*math.pi),.08*math.sin(k*math.pi))
 M.r(a,'head',.18*(1-k)-.10*k)
 for side,sign in [('r',-1),('l',1)]:
  M.r(a,side+'a',-.12-1.58*k+.18*hold,0,sign*(.10+.38*k))
  M.r(a,side+'e',-.18-.32*math.sin(k*math.pi))
 support(a,[(-.16,0,.07),(.16,0,-.07)])
 return a

def ground_smash(t):
 a=M.actor();wind=M.ease(.0,.88,t);hit=M.ease(.90,1.10,t);recover=M.ease(2.38,3.3,t)
 a['root']['p'][2]=.15*hit*(1-recover)
 a['hips']['p'][1]=M.mix(M.mix(.75,.68,wind),.38,hit)*(1-recover)+.75*recover
 M.r(a,'torso',M.mix(-.16*wind,1.15,hit)*(1-recover),-.25*wind*(1-hit)*(1-recover),0)
 M.r(a,'head',-.15*wind*(1-hit)-1.05*hit*(1-recover),.12*wind*(1-hit))
 M.r(a,'ra',M.mix(M.mix(-.05,-2.55,wind),-.25,recover),0,-.23*wind*(1-recover));M.r(a,'re',M.mix(-.70*wind,-.4,recover))
 M.r(a,'la',-.35-1.65*hit*(1-recover),0,.25);M.r(a,'le',-.95)
 grip_at(a,(-.15,.055,.85),M.rotation((0,0,0)),hit*(1-recover))
 support(a,[(-.20,0,.20),(.20,0,-.16)])
 return a

def cast_step(t):
 a=M.actor();k=M.clamp(t);z=.55*M.ease(0,1,k);a['root']['p'][2]=z;a['hips']['p'][1]=.71
 # Lead foot advances while the rear supports, then the rear catches up.
 left=.55*M.ease(.05,.48,k);right=.55*M.ease(.53,.96,k)
 lift_l=.085*math.sin(math.pi*M.clamp((k-.05)/.43)) if .05<k<.48 else 0
 lift_r=.065*math.sin(math.pi*M.clamp((k-.53)/.43)) if .53<k<.96 else 0
 support(a,[(-.13,lift_r,right),(.13,lift_l,left)])
 M.r(a,'torso',.035,.025*math.sin(k*math.pi*2));M.r(a,'head',.02)
 M.r(a,'ra',-1.05,0,-.20);M.r(a,'re',-.30);M.r(a,'la',-1.05,0,.20);M.r(a,'le',-.30)
 return a
TRACKS={'spiral_raise':(2.6,spiral_raise),'ground_smash':(3.4,ground_smash),'cast_step':(1.0,cast_step)}

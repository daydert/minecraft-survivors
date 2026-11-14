extends RefCounted
## The race for the last iron sword (chapter III ending). Three beats on scene time:
## mash to outrun him, dodge his low cut, grab the hilt in the window. Two failures lose.
const MASH_TIME:=1.8
const MASH_NEED:=11
const DODGE_LEAD:=.35
const DODGE_WINDOW:=.6
const GRAB_TIME:=1.0
const GRAB_FROM:=.82
const BEAT_GAP:=.45
var beat:=0
var age:=0.0
var fails:=0
var presses:=0
var result:=""
var dir:="left"
var resolved:=false
var success:=false
var events: Array=[]
var outcomes: Array=[]
## Input counts only after the scene's short intro (set by the encounter).
var started:=false
## Bars frozen at the moment a beat resolves, so nobody runs backwards in the gap.
var held_foe:=0.0
var held_ring:=0.0

func reset(seed_value: int):
	beat=0;age=0.0;fails=0;presses=0;result="";resolved=false;success=false;events.clear();outcomes.clear();started=false;held_foe=0.0;held_ring=0.0
	dir="left" if posmod(seed_value,2)==0 else "right"

## Player progress on the sprint (0..1) and his, which fills on its own.
func bar() -> float:return clampf(float(presses)/MASH_NEED,0,1)
func foe_bar() -> float:
	if beat>0:return 1.0
	return held_foe if resolved else clampf(age/MASH_TIME,0,1)
## How far the grab ring has closed (1 = on the hilt).
func ring() -> float:return held_ring if resolved and beat==2 else clampf(age/GRAB_TIME,0,1)
func live() -> bool:return started and result.is_empty() and not resolved

func press(action: String):
	if not live():return
	match beat:
		0:
			if action=="attack":
				presses+=1;events.append("step")
				if presses>=MASH_NEED:finish(true)
		1:
			if action not in ["left","right"]:return
			# Before the prompt a guess counts as a flinch: spamming both keys does not pass.
			finish(age>=DODGE_LEAD and action==dir and age<=DODGE_LEAD+DODGE_WINDOW)
		2:
			if action=="attack":finish(age>=GRAB_FROM*GRAB_TIME and age<=GRAB_TIME)

func finish(ok: bool):
	held_foe=foe_bar();held_ring=ring()
	resolved=true;success=ok;outcomes.append(ok)
	if not ok:fails+=1
	events.append(["mash_won","dodged","grabbed"][beat] if ok else ["mash_lost","cut","fumbled"][beat])
	age=0.0

## Events pile up from press() and step() until the encounter reads and clears them.
func step(dt: float):
	if not result.is_empty() or not started:return
	age+=dt
	if not resolved:
		if beat==0 and age>=MASH_TIME:finish(false)
		elif beat==1 and age>DODGE_LEAD+DODGE_WINDOW:finish(false)
		elif beat==2 and age>GRAB_TIME+.05:finish(false)
		return
	if age>=BEAT_GAP:
		if fails>=2:result="lost";events.append("lost");return
		if beat>=2:result="won";events.append(result);return
		beat+=1;age=0.0;resolved=false;success=false

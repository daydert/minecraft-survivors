extends RefCounted
## Authored close combat; inputs, deadlines and consequences share scene time.
const ACTIONS := ["left","accept","right","accept","up","accept","down","accept"]
const TRACKS := ["slip","jab","parry","cross","guard","hook","roll","uppercut"]
const FINISH_LENGTH := 3.6
const LENGTH := 2.4
var beat := 0
var age := 0.0
var mistakes := 0
var resolved := false
var resolved_age := -1.0
var success := false
var result := ""
var finishing := false
var finish_age := 0.0
var events: Array=[]
func reset():beat=0;age=0;mistakes=0;resolved=false;resolved_age=-1.0;success=false;result="";finishing=false;finish_age=0;events.clear()
func expected() -> String:return ACTIONS[mini(beat,ACTIONS.size()-1)]
func press(action: String):
 if finishing or resolved or age<.25 or age>.90 or not result.is_empty():return
 resolved=true;resolved_age=age;success=action==expected()
 if not success:mistakes+=1
func step(dt: float):
 events.clear()
 if not result.is_empty():return
 if finishing:
  var previous: float=finish_age;finish_age+=dt
  if previous<.65 and finish_age>=.65:events.append("ko_punch")
  if previous<1.12 and finish_age>=1.12:events.append("table_hit")
  if finish_age>=FINISH_LENGTH:result="won"
  return
 var before: float=age;age+=dt
 if not resolved and age>.90:resolved=true;resolved_age=age;success=false;mistakes+=1
 if before<1.0 and age>=1.0:events.append(("block" if beat in [2,4] else "dodge" if beat in [0,6] else "hit") if success else "hurt")
 if success and beat in [2,4] and before<1.4 and age>=1.4:events.append("counter")
 if age>=LENGTH:
  if mistakes>=3:result="lost";return
  beat+=1;age=0;resolved=false;resolved_age=-1;success=false
  if beat>=ACTIONS.size():finishing=true;finish_age=0

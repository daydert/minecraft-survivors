extends RefCounted
## EnderSteve, the last duel of chapter III. One body, many loops: he is fast, he
## blinks, he reads the hero. State lives on the mob dictionary `m` (string phases,
## like every boss in the project); what survives between his deaths lives in `w.duel`.
## Every blow of his goes through w.boss_strike(): the air is no shelter from him.

## Phases where he takes full damage. Everything he does between them is guarded.
const OPENINGS:=["walk","recover","pose","winded","clock_broken"]
## Pattern ids (numbers kept for the poses/renderer): his ordinary moves and the big ones.
const DASH:=0
const FAN:=1
const RING:=2
const CUTS:=4
const LEAP:=5
const PURSUIT:=6
const BOLTS:=7
const CROSS:=8
const BLINKS:=9
const ECHOES:=10
const SKYFALL:=11
const PROJECTION:=12
const LOOP:=13
const ORDINARY:=[DASH,FAN,RING,CUTS,LEAP,PURSUIT,BOLTS,CROSS]
## Projection is his signature: every other big move. Fight two adds the Loop.
const BIG:=[PROJECTION,BLINKS,ECHOES,PROJECTION,SKYFALL]
const BIG_TWO:=[PROJECTION,LOOP,BLINKS,PROJECTION,ECHOES,LOOP,SKYFALL]
## What he says when he comes back, by what killed him the first time.
const REBIRTH_LINES:={"mace":"Прыгай сколько хочешь. Я буду ждать там, где ты приземлишься","spear":"Твой рывок всегда прямой","knockback_stick":"Больше ты меня не столкнёшь","end_crystal":"Свои кристаллы получишь обратно","dragon_breath":"Твой туман меня не задержит","shield":"Щит тебя не спасёт","distance":"Не убежишь","other":"Я запомнил каждый твой удар"}
## Projection: three laps, each faster, each with a shorter look at the path.
const LAP_SPEED:=[320.0,480.0,700.0]
const LAP_PREVIEW:=[.40,.30,.22]
const FRAME_REACH:=14.0
## Intercept: he waits where a leap peaks or a glide comes down.
const INTERCEPT_RANGE:=160.0
const INTERCEPT_REACH:=24.0
const LEAP_PEAK:=.475
const CRUSH:=10.0
## The clock: hit him hard while it runs and he rewinds and learns; wait it out and it breaks.
const CLOCK_TIME:=9.0
const REWIND_TIME:=1.4
const REWIND_SHARE:=.12
const BROKEN_TIME:=2.5
const BAIT:=[DASH,CUTS,CROSS,FAN]
const TAUNTS=["Слишком медленно","Я это уже видел","Ещё раз","Не так"]
## Damage of his blows (the hero has 20).
const HIT:=5.0
const BLADE:=4.0
const SKYFALL_HIT:=7.0

## The hero's lasting speed bonus he answers with (sugar etc.; not slows or the glide).
static func pace(w) -> float:return w.speed_scale()

## His windups and warnings shrink with the hero's speed, but only by its square root.
static func tempo(w, seconds: float) -> float:
	return seconds/sqrt(pace(w))*(.85 if int(w.duel.get("fight",1))==2 else 1.0)

static func second(w) -> bool:return int(w.duel.get("fight",1))==2
static func learned(w) -> String:return String(w.duel.get("learned","")) if second(w) else ""

func rebirth_line(w) -> String:return REBIRTH_LINES.get(String(w.duel.get("learned","other")),REBIRTH_LINES.other)

func shot(w, p: Vector2, dir: Vector2, speed: float, turn: float=0.0):
	var before: int=w.projectiles.size()
	w.fire_projectile("end_blade",p,dir,{"speed":speed*pace(w),"damage":BLADE,"range":760,"radius":3,"life":8,"turn":turn},false)
	if w.projectiles.size()>before:w.projectiles.back().steve=true

func cut(w, start: Vector2, end: Vector2, wait: float, width: float=11.0, echo: bool=true):
	w.hazards.append({"kind":"end_cut","p":start,"end":end,"wait":wait,"total":wait,"radius":width,"damage":HIT,"remaining":.2,"echo":echo,"steve":true})

func bolt(w, p: Vector2, wait: float):
	w.hazards.append({"kind":"end_bolt","p":p,"wait":wait,"total":wait,"radius":22.0,"damage":HIT,"remaining":.15,"steve":true})

func arena(w, p: Vector2, margin: float=40.0) -> Vector2:
	return p.clamp(w.END_ARENA.position+Vector2.ONE*margin,w.END_ARENA.end-Vector2.ONE*margin)

func recover(m: Dictionary, seconds: float=1.0):
	m.phase="recover";m.timer=seconds;m.altitude=0.0
	# While his clock runs he lowers the blade on purpose: bait.
	if m.get("clock",{}).get("state","")=="running":m.phase="pose";m.timer=.9;return
	# After a clean hit he stops and lets you see it.
	if m.get("taunt",false):m.taunt=false;m.phase="pose";m.timer=.9

func taunt(w, m: Dictionary):
	m.taunt=true
	if w.clock>=float(m.get("taunt_at",0.0)):
		m.taunt_at=w.clock+11.0;w.say(TAUNTS[int(m.get("taunts",0))%TAUNTS.size()],1.6);m.taunts=int(m.get("taunts",0))+1

func hit(w, m: Dictionary, source: Vector2, damage: float, unblockable: bool=false) -> bool:
	var landed: bool=w.boss_strike(source,damage,unblockable)
	if landed:taunt(w,m)
	return landed

## He never stands still: circles the hero, flips direction, blinks to the other side.
func strafe(w, m: Dictionary, dt: float, keep: float=115.0):
	var to: Vector2=m.p.direction_to(w.player);var dist: float=m.p.distance_to(w.player)
	if w.clock>=float(m.get("strafe_flip",0.0)):m.strafe_flip=w.clock+w.rng.randf_range(1.4,2.4);m.strafe_dir=-float(m.get("strafe_dir",1.0))
	var radial: float=clampf((dist-keep)/50.0,-1,1)
	var v: Vector2=(to*radial+to.orthogonal()*float(m.get("strafe_dir",1.0))).normalized()*(150.0 if second(w) else 125.0)*pace(w)
	m.p=w.move_actor(m.p,v*dt,m.radius);m.moving=true
	if w.clock>=float(m.get("hop_at",0.0)):
		m.hop_at=w.clock+(1.0 if second(w) else 1.4)
		if dist<70 or w.rng.randf()<.45:w.teleport_mob(m,arena(w,w.player+Vector2.from_angle(w.rng.randf()*TAU)*keep))

## The next move: ordinary ones without repeats, and every third a big one.
func choose(w, m: Dictionary) -> int:
	if second(w):return choose_two(w,m)
	if m.get("clock",{}).get("state","")=="running":
		var bait: Array=BAIT.duplicate();bait.erase(int(m.get("pattern",-1)))
		return bait[w.rng.randi_range(0,bait.size()-1)]
	m.count=int(m.get("count",0))+1
	if m.count%3==0:
		m.big=int(m.get("big",-1))+1
		return BIG[m.big%BIG.size()]
	var pool: Array=ORDINARY.duplicate();pool.erase(int(m.get("pattern",-1)))
	return pool[w.rng.randi_range(0,pool.size()-1)]

static func lap_speed(w, lap: int) -> float:return LAP_SPEED[clampi(lap,0,2)]*pace(w)
static func lap_preview(w, lap: int) -> float:return tempo(w,LAP_PREVIEW[clampi(lap,0,2)])

## The 24 frames of the next lap: from where he stands, past the hero, through the
## spot the hero is heading to, and out the far side.
func plan_lap(w, m: Dictionary):
	var center: Vector2=arena(w,w.player+w.tracked_velocity*.3,30)
	var a: float=m.p.direction_to(center).angle()+w.rng.randf_range(-.6,.6)
	var side: float=1.0 if w.rng.randf()<.5 else -1.0
	m.path=[m.p,arena(w,center+Vector2.from_angle(a+side*1.9)*80,24),center,arena(w,center+Vector2.from_angle(a)*95,24),arena(w,center+Vector2.from_angle(a-side*1.4)*70,24)]
	m.seg=1;m.preview=lap_preview(w,int(m.lap));m.phase="projection_preview";m.timer=m.preview

## The hero was touched: frozen in a frame until the crushing blow lands.
func frame_hero(w, m: Dictionary):
	var hold: float=tempo(w,.55)+.35
	# Caught above the void (glide, leap): the frame holds him over the last safe ground.
	if not w.supported_at(w.player,6):w.player=w.last_safe
	w.framed=hold+.1;w.frame_pos=w.player;w.flight=0.0;w.rocket=false;w.dash_left=0.0;w.jump_age=-1.0;w.jump_height=0.0
	w.levitation=0.0;w.levitation_height=0.0;w.levitation_velocity=0.0;w.player_push=Vector2.ZERO
	w.hitstop=maxf(w.hitstop,.08);w.sound("ch4_hb_freeze");w.shake=maxf(w.shake,.3)
	w.duel.framed=int(w.duel.get("framed",0))+1
	var behind: Vector2=arena(w,w.player+m.p.direction_to(w.player)*22,24)
	w.add_effect("end_afterimage",m.p,.4,{"actor":m.kind,"direction":m.visual_dir,"pose":m.visual.duplicate()})
	m.p=behind;m.charge=m.p.direction_to(w.player);m.phase="framed_strike";m.timer=hold;m.windup_total=hold

func intercept_chance(w) -> float:
	if learned(w) in ["mace","distance"] or (second(w) and int(w.duel.style.get("glides",0))>=4):return 1.0
	return .6

## A leap or the end of a glide close to him: he is already there.
func watch_air(w, m: Dictionary) -> bool:
	if int(m.get("air_seen",0))==w.air_serial or m.p.distance_to(w.player)>INTERCEPT_RANGE*pace(w):return false
	var wait:=-1.0;var lead:=.5
	if w.jump_age>=0 and w.jump_age<LEAP_PEAK-.15:wait=LEAP_PEAK-w.jump_age
	elif w.flight>0 and w.flight<.75 and not w.rocket:wait=w.flight;lead=1.0
	if wait<0:return false
	m.air_seen=w.air_serial
	if w.rng.randf()>=intercept_chance(w):return false
	m.mark=arena(w,w.player+w.tracked_velocity*wait*lead,24)
	w.teleport_mob(m,m.mark+Vector2(0,2))
	m.p=m.mark;m.phase="intercept";m.timer=wait;m.windup_total=wait;m.charge=Vector2.UP
	w.sound("ch4_hb_charge",.1)
	# He knows the mace: the spot it comes down on is cut a moment later too.
	if learned(w)=="mace" and lead<1.0:
		for j in range(4):bolt(w,arena(w,m.mark+Vector2.from_angle(j*PI/2+.4)*30,24),wait+.5)
	return true

## Fight two: he answers what the hero did to him the first time.
func read_hero(w, m: Dictionary) -> bool:
	if not second(w):return false
	var what: String=learned(w)
	if what=="spear" and w.dash_left>0 and int(m.get("dash_seen",0))!=w.dash_serial:
		m.dash_seen=w.dash_serial
		if w.dash_direction.dot(w.player.direction_to(m.p))>.6 and m.p.distance_to(w.player)<220:
			var side: Vector2=w.dash_direction.orthogonal()*(1.0 if w.rng.randf()<.5 else -1.0)
			w.teleport_mob(m,arena(w,m.p+side*70))
			cut(w,w.player,arena(w,w.player+w.dash_direction*170,20),w.dash_left+tempo(w,.45),10,false)
			return true
	if what=="end_crystal":
		for e in w.effects:
			if e.kind=="placed_end_crystal" and not e.get("kicked",false) and not e.triggered and e.p.distance_to(m.p)<110:
				e.kicked=true;e.p=w.player;e.age=.05;w.sound("swing",.05);w.fx.ring(e.p,float(e.stats.radius),.6,"thorns")
				return false
	if what=="dragon_breath" and w.clock>=float(m.get("breath_cd",0.0)):
		for e in w.effects:
			if e.kind=="friendly_breath" and e.p.distance_to(m.p)<float(e.radius):
				m.breath_cd=w.clock+1.0;w.teleport_mob(m,arena(w,w.player+Vector2.from_angle(w.rng.randf()*TAU)*110));return true
	if int(w.duel.style.get("pearls",0))>0 and int(m.get("pearl_seen",0))!=w.pearl_serial:
		for e in w.effects:
			if e.kind=="end_pearl" and e.age<.15:
				m.pearl_seen=w.pearl_serial
				if w.rng.randf()<.5:
					w.teleport_mob(m,arena(w,e.end+e.start.direction_to(e.end)*36))
					m.phase="counter";m.timer=maxf(0,e.total-e.age)+maxf(tempo(w,.3),.34);m.windup_total=m.timer;m.charge=m.p.direction_to(e.end)
					return true
	return false

## The Loop: three reflections of his other loops replay his last moves at once.
## They are only light and warnings; the hits are his cuts and bolts.
func loop(w, m: Dictionary):
	var past: Array=m.get("history",[]).filter(func(p):return p not in [PROJECTION,LOOP])
	while past.size()<3:past.push_front(ORDINARY[past.size()])
	past=past.slice(past.size()-3)
	if not m.get("loop_spoken",false):m.loop_spoken=true;w.say("Каждую из них",1.6)
	for j in range(3):
		var a: float=w.rng.randf()*TAU*.2+j*TAU/3
		var from: Vector2=arena(w,w.player+Vector2.from_angle(a)*120,30)
		var wait: float=tempo(w,.9)+j*.35
		w.add_effect("steve_loop_ghost",from,wait+.35,{"pattern":past[j],"target":w.player,"wait":wait})
		match past[j]:
			DASH,PURSUIT,FAN,RING:cut(w,from,arena(w,from+from.direction_to(w.player)*260,20),wait,11,true)
			CUTS,CROSS:
				var d:=Vector2.from_angle(a+PI/4)
				cut(w,w.player-d*90,w.player+d*90,wait);cut(w,w.player-d.orthogonal()*90,w.player+d.orthogonal()*90,wait)
			LEAP,SKYFALL,BOLTS:
				for k in range(3):bolt(w,arena(w,w.player+w.tracked_velocity*.3+Vector2.from_angle(k*TAU/3+a)*(0 if k==0 else 40),24),wait)
			_:cut(w,from,arena(w,from+Vector2.from_angle(a).orthogonal()*240,20),wait,10,true)
	w.sound("end_teleport");w.fx.ring(m.p,110.0,.7,"evolve")

func can_frame(w) -> bool:
	return w.fall_age<0 and w.dash_left<=0 and w.blink_grace<=0 and w.hit_grace<=0 and w.hp>0

## Fight two leans on what he saw: distance draws his dashes, close play his falls.
func choose_two(w, m: Dictionary) -> int:
	if m.get("clock",{}).get("state","")=="running":
		var bait: Array=BAIT.duplicate();bait.erase(int(m.get("pattern",-1)))
		return bait[w.rng.randi_range(0,bait.size()-1)]
	m.count=int(m.get("count",0))+1
	var style: Dictionary=w.duel.style
	var dist: float=float(style.get("dist_sum",0.0))/maxf(.01,float(style.get("time",0.0)))
	if m.count%2==0:
		var big: Array=BIG_TWO.duplicate()
		if int(w.duel.get("framed",0))>=2:big.append(PROJECTION)
		if dist<70:big.append_array([SKYFALL,ECHOES])
		if dist>110 or learned(w)=="distance":big.append(PROJECTION)
		big.erase(int(m.get("pattern",-1)))
		return big[w.rng.randi_range(0,big.size()-1)]
	var pool: Array=ORDINARY.duplicate()
	if dist>110 or learned(w)=="distance":pool.append_array([DASH,PURSUIT])
	pool=pool.filter(func(p):return p!=int(m.get("pattern",-1)))
	return pool[w.rng.randi_range(0,pool.size()-1)]

## Damage that reaches him, after his guard, his dodge and what he has learned.
func on_hurt(w, m: Dictionary, amount: float) -> float:
	if m.hp<=0:return amount
	if m.phase=="rewind":return 0.0
	var reads: bool=learned(w)=="knockback_stick" and w.damage_owner=="knockback_stick" and m.phase not in OPENINGS
	if w.damage_source!="status" and (m.phase in ["walk","cast","echoes"] or reads) and m.phase not in ["framed_strike","rewind"] and w.clock>=float(m.get("dodge_cd",0.0)) and (reads or w.rng.randf()<(.75 if second(w) else .55)):
		m.dodge_cd=w.clock+(1.2 if second(w) else 1.7)
		var side: Vector2=w.player.direction_to(m.p).orthogonal()*(1.0 if w.rng.randf()<.5 else -1.0)
		w.teleport_mob(m,arena(w,m.p+side*72.0*pace(w)-m.p.direction_to(w.player)*20.0))
		w.fx.flash(m.p,60.0,Color(.8,.5,1),.12)
		if m.p.distance_to(w.player)<90:
			m.phase="counter";m.timer=tempo(w,.35);m.windup_total=m.timer;m.charge=m.p.direction_to(w.player)
		return 0.0
	var share: float=1.0 if m.phase in OPENINGS else .4
	if m.phase=="clock_broken":share=1.5
	share*=float(w.duel.get("adapt",{}).get(w.damage_owner,1.0))
	var c: Dictionary=m.get("clock",{})
	if c.get("state","")=="running":c.dealt[w.damage_owner]=float(c.dealt.get(w.damage_owner,0.0))+amount*share
	if share<1.0 and w.clock>=float(m.get("guard_fx",0.0)):
		m.guard_fx=w.clock+.15;w.fx.ring(m.p-Vector2(0,10),12.0,.18,"thorns");w.sound("shield_block",.1)
	return amount*share

static func clock_marks(w) -> Array:return [.7,.35] if second(w) else [.6]

func start_clock(w, m: Dictionary):
	m.clock={"state":"running","age":0.0,"hp0":m.hp,"p0":m.p,"trail":[m.p],"tick":0.0,"dealt":{}}
	m.clocks=int(m.get("clocks",0))+1
	m.phase="clock_wind";m.timer=1.0;m.windup_total=1.0;m.altitude=0.0
	w.sound("ch4_hb_charge",.05);w.sound("ch4_bell_warn",.05);w.fx.ring(m.p,80.0,.8,"evolve");w.shake=maxf(w.shake,.25)

## Runs alongside whatever he does: records his path, decides rewind or breakage.
func clock_step(w, m: Dictionary, dt: float):
	var c: Dictionary=m.get("clock",{})
	match c.get("state",""):
		"","spent":
			var marks: Array=clock_marks(w);var used: int=int(m.get("clocks",0))
			if used<marks.size() and m.hp<m.max_hp*float(marks[used]) and m.phase in ["walk","recover","pose"]:start_clock(w,m)
		"running":
			# A mechanical tick every second; the last three are louder.
			if int(c.age)!=int(c.age+dt):w.sound("ch4_hb_tick",.02 if c.age<CLOCK_TIME-3.5 else .0)
			c.age+=dt;c.tick-=dt
			if c.tick<=0:c.tick=.05;c.trail.append(m.p)
			var dealt:=0.0
			for id in c.dealt:dealt+=float(c.dealt[id])
			if dealt>=REWIND_SHARE*m.max_hp and m.hp>0:
				c.state="rewind";c.age=0.0;c.hp_from=m.hp;m.phase="rewind";m.timer=REWIND_TIME;m.altitude=0.0
				var top:="";var best:=-1.0
				for id in c.dealt:
					if float(c.dealt[id])>best:best=float(c.dealt[id]);top=id
				var adapt: Dictionary=w.duel.adapt
				adapt[top]=.6 if float(adapt.get(top,1.0))>=1.0 else .4
				c.learned=top;w.hitstop=maxf(w.hitstop,.25);w.sound("ch4_hb_glitch");w.say("Я это уже видел",2.0)
				for i in range(w.hazards.size()-1,-1,-1):
					if w.hazards[i].get("steve",false):w.hazards.remove_at(i)
			elif c.age>=CLOCK_TIME:
				c.state="broken";m.phase="clock_broken";m.timer=BROKEN_TIME;m.altitude=0.0;w.framed=0.0
				w.sound("ch4_bell");w.sound("break");w.sound("ch4_hb_shatter",.05);w.shake=maxf(w.shake,.35);w.fx.ring(m.p,60.0,.6,"thorns")
		"rewind":
			if fposmod(c.age,.12)<dt:w.sound("ch4_hb_tick",.1)
			c.age+=dt
			var k: float=clampf(c.age/REWIND_TIME,0,1)
			var trail: Array=c.trail
			m.p=trail[clampi(int(round((1-k)*(trail.size()-1))),0,trail.size()-1)]
			m.hp=lerpf(float(c.hp_from),float(c.hp0),smoothstep(0,1,k))
			if c.age>=REWIND_TIME:m.hp=c.hp0;m.p=c.p0;c.state="spent";m.phase="walk";m.timer=.6
		"broken":
			if m.phase!="clock_broken":c.state="spent"

func step(w, m: Dictionary, dt: float):
	clock_step(w,m,dt)
	if m.phase=="rewind":m.moving=true;return
	m.burst_tick-=dt
	match m.phase:
		"walk","recover","loop":
			if watch_air(w,m) or read_hero(w,m):return
			if m.phase=="loop":
				m.dir=m.p.direction_to(w.player);strafe(w,m,dt)
				if m.timer<=0:recover(m,1.0)
				return
			m.dir=m.p.direction_to(w.player)
			if m.phase=="walk":strafe(w,m,dt,120.0)
			else:m.p=w.move_actor(m.p,-m.dir*30.0*dt,m.radius)
			if m.timer<=0:begin(w,m,choose(w,m))
		"counter":
			m.dir=m.charge
			if m.timer<=0:
				w.add_effect("ender_slash",m.p,.3,{"direction":m.charge,"radius":46.0});w.sound("swing",.08)
				var delta: Vector2=w.player-m.p
				if delta.length()<46 and delta.normalized().dot(m.charge)>.2:hit(w,m,m.p,HIT)
				recover(m,.8)
		"windup":
			if m.pattern not in [DASH,LEAP]:strafe(w,m,dt*.6)
			if m.timer<=0:release(w,m)
		"rush":
			m.p=w.move_actor(m.p,m.charge*(285.0 if second(w) else 250.0)*pace(w)*dt,m.radius);m.dir=m.charge
			if m.burst_tick<=0:m.burst_tick=.14;w.add_effect("ender_slash",m.p,.35,{"direction":m.charge,"radius":45.0})
			if m.p.distance_to(w.player)<36 and hit(w,m,m.p,HIT):w.player_push=m.charge*100
			if m.timer<=0:
				if m.combo>0:
					m.combo-=1;w.teleport_mob(m,arena(w,w.player-m.charge.rotated(PI/2)*90));m.charge=m.p.direction_to(w.player)
					m.phase="windup";m.timer=tempo(w,.58);m.windup_total=m.timer
				else:recover(m,1.0)
		"leap":
			var t: float=clampf(1-m.timer,0,1)
			m.p=m.leap_start.lerp(m.mark,smoothstep(0,1,t));m.altitude=sin(t*PI)*55;m.dir=m.charge
			if m.timer<=0:
				w.shake=.2;w.sound("mace_smash");w.add_effect("ender_slash",m.p,.5,{"direction":m.charge,"radius":65.0})
				w.fx.quake(w,m.p,1.6,m.p+m.charge*60);w.fx.erupt(w,m.p,"stone",9);w.fx.ring(m.p,70.0,.5,"toll")
				if w.player.distance_to(m.p)<43:hit(w,m,m.p,HIT)
				for j in range(16):shot(w,m.p,Vector2.from_angle(j*TAU/16),96)
				recover(m,1.1)
		"pursuit":
			m.dir=m.p.direction_to(w.player);m.p=w.move_actor(m.p,m.dir*120.0*pace(w)*dt,m.radius)
			if m.p.distance_to(w.player)<65 or m.timer<=0:
				m.charge=m.p.direction_to(w.player);m.phase="cleave_windup";m.timer=tempo(w,.6);m.windup_total=m.timer
		"cleave_windup":
			if m.timer<=0:
				m.phase="cleave";m.timer=.46;w.add_effect("ender_slash",m.p,.46,{"direction":m.charge,"radius":75.0});w.fx.slash(w,m.p,m.charge,75.0)
		"cleave":
			var delta: Vector2=w.player-m.p
			if delta.length()<75 and delta.normalized().dot(m.charge)>.1:hit(w,m,m.p,HIT)
			if m.timer<=0:
				for j in range(5):shot(w,m.p,m.charge.rotated((j-2)*.24),125)
				recover(m,1.0)
		"pose":
			# Blade lowered, looking at you: the opening he gives on purpose.
			m.dir=m.p.direction_to(w.player)
			if m.timer<=0:m.phase="walk";m.timer=.5
		"blink_chain":
			# Thousand cuts: blink after blink around the hero, every path a delayed cut.
			if m.burst_tick<=0:
				m.burst_tick=.16/pace(w);var old: Vector2=m.p
				w.teleport_mob(m,arena(w,w.player+Vector2.from_angle(m.attack_serial*2.3+.4)*118))
				if old.distance_to(m.p)>20:cut(w,old,m.p,m.timer+.55,10,false)
				m.attack_serial+=1;w.fx.flash(m.p,60.0,Color(.8,.5,1),.12)
			if m.timer<=0:m.phase="pose";m.timer=1.1;m.charge=m.p.direction_to(w.player);w.sound("ch4_hb_freeze")
		"echoes":
			m.dir=m.p.direction_to(w.player);strafe(w,m,dt)
			if m.timer<=0:recover(m,1.1)
		"skyfall":
			var age: float=3.4-m.timer
			if age<.9:m.altitude=lerpf(0,240,smoothstep(0,.9,age))
			elif age<2.7:m.altitude=240;m.mark=m.mark.lerp(w.player,minf(1,dt*3.5*pace(w)))
			else:m.altitude=lerpf(240,0,smoothstep(2.7,3.4,age))
			if age>=2.7:m.p=m.mark
			if m.timer<=0:
				m.altitude=0;m.p=m.mark;w.shake=.5
				if w.player.distance_to(m.p)<48:hit(w,m,m.p,SKYFALL_HIT)
				var gap: float=m.p.direction_to(w.player).angle()+PI*.5
				for j in range(26):
					var a: float=j*TAU/26
					if absf(wrapf(a-gap,-PI,PI))<.32 or absf(wrapf(a-gap-PI,-PI,PI))<.32:continue
					shot(w,m.p,Vector2.from_angle(a),105)
				w.fx.quake(w,m.p,2.6,m.p+Vector2(0,60));w.fx.erupt(w,m.p,"stone",16);w.fx.stain(m.p,22.0,"scorch",w.clock);w.fx.ring(m.p,120.0,.7,"toll");w.sound("mace_smash");w.sound("explosion")
				m.phase="pose";m.timer=1.2
		"projection_stance":
			m.dir=m.p.direction_to(w.player)
			if m.timer<=0:m.lap=0;plan_lap(w,m)
		"projection_preview":
			m.dir=m.p.direction_to(m.path[1]);m.charge=m.dir
			if m.timer<=0:
				m.phase="projection";m.after=0.0
				w.fx.ring(m.p,36.0+int(m.lap)*16.0,.35,"toll");w.sound("wind_burst",.05);w.shake=maxf(w.shake,.1+int(m.lap)*.08)
		"projection":
			var travel: float=lap_speed(w,int(m.lap))*dt
			var guard:=0
			while travel>.01 and m.phase=="projection" and guard<12:
				guard+=1
				var target: Vector2=m.path[int(m.seg)];var old: Vector2=m.p
				m.p=m.p.move_toward(target,travel);travel-=old.distance_to(m.p);m.dir=old.direction_to(target);m.charge=m.dir
				if can_frame(w) and Geometry2D.get_closest_point_to_segment(w.player,old,m.p).distance_to(w.player)<FRAME_REACH:
					frame_hero(w,m);break
				if m.p.distance_to(target)<.5:
					m.seg=int(m.seg)+1
					if int(m.seg)>=m.path.size():
						m.lap=int(m.lap)+1
						if int(m.lap)>=3:m.phase="winded";m.timer=1.3;w.sound("ch4_breath",.1)
						else:plan_lap(w,m)
						break
			m.moving=true;m.after-=dt
			if m.phase=="projection" and m.after<=0:
				m.after=.035;w.add_effect("end_afterimage",m.p,.3,{"actor":m.kind,"direction":m.visual_dir,"pose":m.visual.duplicate()})
		"framed_strike":
			m.dir=m.charge;w.framed=maxf(w.framed,.05)
			if m.timer<=0:
				w.framed=0.0;w.hit_grace=0.0;w.add_effect("frame_shatter",w.player,.5)
				var landed: bool=w.boss_strike(m.p,CRUSH,true)
				w.hitstop=maxf(w.hitstop,.2);w.shake=maxf(w.shake,.8);w.fx.quake(w,w.player,2.4,w.player+m.charge*50);w.fx.ring(w.player,60.0,.5,"toll")
				w.fx.flash(w.player,160.0,Color(1,.85,1),.2);w.sound("mace_smash");w.sound("ch4_punch_heavy")
				if landed:w.player_push=m.charge*160;taunt(w,m)
				recover(m,1.0)
		"intercept":
			m.dir=m.p.direction_to(w.player)
			if m.timer<=0:
				w.add_effect("ender_slash",m.p,.35,{"direction":Vector2.UP,"radius":INTERCEPT_REACH+10});w.sound("swing",.05);w.fx.ring(m.p,INTERCEPT_REACH,.3,"toll")
				if w.player.distance_to(m.mark)<INTERCEPT_REACH:hit(w,m,m.mark,HIT)
				recover(m,.8)
		"clock_wind":
			m.dir=m.p.direction_to(w.player)
			if m.timer<=0:m.phase="walk";m.timer=.3
		"clock_broken":
			m.dir=m.p.direction_to(w.player)
			if m.timer<=0:m.phase="walk";m.timer=.5
		"winded":
			m.dir=m.p.direction_to(w.player)
			if m.timer<=0:m.phase="walk";m.timer=.4
		"cast":
			m.dir=m.p.direction_to(w.player);strafe(w,m,dt);m.charge=m.dir
			if m.burst_tick<=0:
				m.burst_tick=tempo(w,.7)
				cast(w,m)
				m.attack_serial+=1;w.sound("shulker_shoot",.2)
			if m.timer<=0:recover(m,1.1)

## Windup for the chosen move: where he will be, what you will see coming.
func begin(w, m: Dictionary, pattern: int):
	m.pattern=pattern;m.combo=((2 if second(w) else 1)+(1 if learned(w)=="other" else 0)) if pattern==DASH else 0
	var history: Array=m.get("history",[]);history.append(pattern)
	if history.size()>6:history.pop_front()
	m.history=history;m.feinted=false
	m.charge=m.p.direction_to(w.player);m.mark=arena(w,w.player+w.tracked_velocity*.3,50)
	if pattern==DASH:
		w.fx.flash(m.p,80.0,Color(.8,.5,1),.15);w.teleport_mob(m,arena(w,w.player-w.facing*90));m.charge=m.p.direction_to(w.player)
	if pattern==LEAP:
		w.end_boss.cloud(w,m.mark,43,tempo(w,.8)+1.0,.35);w.hazards.back().steve=true;w.hazards.back().damage=HIT;m.leap_start=m.p
	m.phase="windup";m.timer=tempo(w,.8);m.windup_total=m.timer;m.burst_tick=0
	if pattern==PROJECTION:m.phase="projection_stance";m.timer=tempo(w,.9);m.windup_total=m.timer;w.sound("ch4_hb_charge",.1)
	w.sound("end_teleport",.1)

func release(w, m: Dictionary):
	m.burst_tick=0;m.attack_serial=0
	match m.pattern:
		DASH:
			# Against a shield or a patient blade he shows a dash and comes from the other side.
			if learned(w) in ["shield","other"] and not m.feinted and w.rng.randf()<.4:
				m.feinted=true;w.teleport_mob(m,arena(w,w.player+(w.player-m.p).normalized()*80));m.charge=m.p.direction_to(w.player)
				m.phase="windup";m.timer=tempo(w,.45);m.windup_total=m.timer;w.sound("end_teleport",.1);return
			m.phase="rush";m.timer=.6
		LOOP:m.phase="loop";m.timer=2.4;loop(w,m)
		LEAP:m.phase="leap";m.timer=1.0
		PURSUIT:m.phase="pursuit";m.timer=2.0
		BLINKS:m.phase="blink_chain";m.timer=.16*(8 if second(w) else 6)/pace(w)
		ECHOES:m.phase="echoes";m.timer=2.4;echoes(w,m)
		SKYFALL:m.phase="skyfall";m.timer=3.4;m.altitude=0;m.mark=w.player;w.sound("wind_burst");w.fx.dust(m.p,8,20)
		_:m.phase="cast";m.timer=2.8

## Echoes of himself from other loops run their old lines at the hero, one after another.
func echoes(w, m: Dictionary):
	var count: int=5 if second(w) else 3
	if not m.get("echoes_spoken",false):m.echoes_spoken=true;w.say("Этому нет числа",2.2)
	for j in range(count):
		var a: float=m.attack_serial*.9+j*TAU/count
		cut(w,w.player+Vector2.from_angle(a)*135,w.player-Vector2.from_angle(a)*135,tempo(w,.85)+j*.32,10,true)
	w.sound("end_teleport");w.fx.ring(m.p,90.0,.6,"evolve")

func cast(w, m: Dictionary):
	match m.pattern:
		FAN:
			var a: float=m.charge.angle()+sin(m.attack_serial*.85-1)*.65
			for j in range(9):shot(w,m.p,Vector2.from_angle(a+(j-4)*.2),92+(j%2)*24,.1*sin(m.attack_serial))
		RING:
			var gap: float=m.p.direction_to(w.player).angle()+PI/3
			for j in range(28):
				var a: float=j*TAU/28+m.attack_serial*.12
				if absf(wrapf(a-gap,-PI,PI))<.29 or absf(wrapf(a-gap-PI,-PI,PI))<.29:continue
				shot(w,m.p,Vector2.from_angle(a),75+(j%3)*17,.16 if m.attack_serial%2 else -.16)
		BOLTS:
			# Herobrine's tower storm, learned the hard way: marks, then bolts.
			for j in range(4):bolt(w,arena(w,w.player+w.tracked_velocity*.35+Vector2.from_angle(m.attack_serial*1.3+j*TAU/4)*(0 if j==0 else 46)),tempo(w,1.0))
		CROSS:
			# Crossed cuts: two of his lanes at once, the safe corners between.
			var d:=Vector2.from_angle(PI/4+m.attack_serial*PI/2)
			cut(w,m.mark-d*110,m.mark+d*110,tempo(w,1.0));cut(w,m.mark-d.orthogonal()*110,m.mark+d.orthogonal()*110,tempo(w,1.0))
		_:
			# Echo bodies preview exactly the segment that will be cut.
			var direction:=Vector2.from_angle(m.attack_serial*PI/2+.35)
			cut(w,m.mark-direction*95,m.mark+direction*95,tempo(w,.95))

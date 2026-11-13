extends RefCounted
## Encounter clocks and all telegraphs advance only with the solo simulation.
const BETRAYAL_IMPACT=3.4
const BETRAYAL_END=10.2
const DEATH_DURATION=7.6
const YIELD_TIME=3.0
const RESTORE_LIT=7.4
const RESTORE_END=11.6
## He breaks the way out the moment it looks like the chapter is won.
const BETRAYAL_LINES=[[2.2,"Стой",1.6],[6.0,"Туда нельзя",2.2],[8.1,"Не заставляй меня",2.0]]
## On the edge of the island. [text, who, tag, pause before]. Multi-part lines are
## spoken one phrase at a time; timings follow reading speed (see timeline()).
## "delete": his maker starts erasing him; "gift": the eye and the sword.
const SIT_SCRIPT=[
	["Вот и всё","ender","",0.0],
	["Я ведь тоже когда-то до него дошёл...\nОн отнял у меня нечто дорогое моему сердцу","ender","",.6],
	["Я думал, что справлюсь с ним, долго оттачивал свои навыки и копил ярость, однако меня ждал полный провал","ender","",.5],
	["Грёбаный ублюдок, стоящий за ним, выдал мне одну задачу и заточил меня здесь\nСудя по всему, в его алгоритме случился сбой после того, как ты смог меня одолеть\nДо этого всё, что я мог, — временами пытаться завести с тобой разговор. Каждый раз, когда ты появлялся, моя свобода воли переставала существовать","ender","look",.7],
	["Я впервые проиграл после того, как $%@!^ заточил меня здесь","ender","",.5],
	["Что произошло???\nТвою ж мать, эта мразь начала меня удалять!?","ender","delete",1.0],
	["Слушай, у нас мало времени. Раз он начал это делать, что-то явно пошло не по его плану","ender","",.3],
	["Держи меч и Око Края, они тебе пригодятся","ender","gift",.3]]
var SIT_LINES: Array=[]
var SIT_MARKS: Dictionary={}
var SIT_LENGTH:=0.0
## After the duel: a last exchange of blows breaks both swords and drops them both.
const CLASH_HITS=[.55,1.05,1.55]
const CLASH_BREAK=2.25
const CLASH_LENGTH=3.4
var DOWN_LENGTH:=11.4
var DOWN_RISE:=8.6
## Lying on the end stone. The only time Steve says anything.
## "free": the chains he wore through every loop shatter off him.
const DOWN_SCRIPT=[["Не может быть, я больше не чувствую оков. Неужели ты что-то ему сломал?","ender","free",1.6],["Квиты","steve","",.6],["Вставай, мне нужно срочно тебе кое-что рассказать","ender","",.7]]
var DOWN_LINES: Array=[]
var DOWN_MARKS: Dictionary={}

## Reading pace for the typed subtitles: a short beat stays a moment, a long one is fully readable.
static func part_life(text: String) -> float:return clampf(1.0+text.length()/22.0,1.7,7.5)

## Lays phrases end to end: [at, phrase, life, who] plus the start of each tagged line.
static func timeline(script: Array, start: float) -> Dictionary:
	var t: float=start;var out: Array=[];var marks: Dictionary={}
	for row in script:
		t+=row[3]
		if row[2]!="":marks[row[2]]=t
		for part in String(row[0]).split("\n"):
			var life: float=part_life(part)
			out.append([t,part,life,row[1]]);t+=life+.25
	return {"lines":out,"marks":marks,"end":t}

func _init():
	var sit: Dictionary=timeline(SIT_SCRIPT,1.2)
	SIT_LINES=sit.lines;SIT_MARKS=sit.marks;SIT_LENGTH=sit.end+1.4
	var down: Dictionary=timeline(DOWN_SCRIPT,0.0)
	DOWN_LINES=down.lines;DOWN_MARKS=down.marks;DOWN_RISE=down.end+.2;DOWN_LENGTH=DOWN_RISE+2.8
const RESTORE_LINES=[[1.0,"Иди и не останавливайся",2.2],[3.4,"Обо мне не беспокойся, мне уже ничего не поможет",3.4]]

func cue(w, dt: float, at: float) -> bool:
	return w.stage_age>=at and w.stage_age-dt<at

func lines(w, dt: float, table: Array):
	for l in table:
		if cue(w,dt,l[0]):w.say(l[1],l[2],l[3] if l.size()>3 else "ender")

func story(w, dt: float):
	for l in w.lines:
		l.age+=dt
		# Black Souls style: the scream hits the whole screen when it lands.
		if l.get("scream",false) and l.age>=0 and not l.get("fired",false):
			l.fired=true;w.shake=maxf(w.shake,.75);w.hitstop=maxf(w.hitstop,.14)
			w.sound("ch4_hb_glitch");w.sound("explosion",.1)
	w.lines=w.lines.filter(func(l):return l.age<l.life)
	match w.stage:
		"end_arrival":
			if w.stage_age>=2.5:w.stage="survival";w.stage_age=0
		"survival":
			if w.time>=w.db.data.duration:w.begin_arena()
		"departure":
			if w.stage_age>=1.6:w.prepare_arena()
		"dragon_arrival":
			# He comes in low across the island before the fight.
			for m in w.mobs:
				if m.kind=="end_dragon":
					var k: float=smoothstep(.4,3.4,w.stage_age)
					m.p=Vector2(504,930).lerp(Vector2(1024,1000),k);m.altitude=lerpf(70,45,k);m.dir=Vector2.RIGHT;m.moving=true
			if cue(w,dt,2.1):w.sound("dragon_growl");w.shake=.45;w.fx.quake(w,Vector2(900,980),2.0)
			if w.stage_age>=4:w.stage="dragon";w.stage_age=0;w.sound("dragon_growl")
		"dragon_death":
			if w.stage_age>=4.5:
				w.stage="exit_portal";w.stage_age=0;w.portal_lit=true;w.sound("portal_open")
				# It sounds and looks like the end of the chapter; that is the point.
				w.win_music=true;w.sound("boss_win",.2)
		"exit_portal":
			if w.player.distance_to(w.portal_position)<94:
				w.stage="betrayal";w.stage_age=0;w.facing=Vector2.UP
		"betrayal":
			if w.stage_age<1.5:w.player=w.player.move_toward(w.portal_position+Vector2(0,62),dt*26);w.facing=Vector2.UP
			if cue(w,dt,1.6):w.sound("end_teleport");w.shake=.15
			if cue(w,dt,2.6):w.sound("ch4_hb_charge")
			lines(w,dt,BETRAYAL_LINES)
			if w.stage_age>=BETRAYAL_IMPACT and w.portal_lit:
				w.portal_lit=false;w.win_music=false;w.shake=.9;w.hitstop=.28
				for id in ["end_portal_break","explosion","ch4_hb_shatter","end_music_cut"]:w.sound(id)
				w.add_effect("portal_shatter",w.portal_position,3.8,{"radius":100.0})
				w.add_effect("end_card_shatter",w.portal_position,3.0)
			if w.stage_age>=BETRAYAL_END:
				w.stage="last_arrival";w.stage_age=0;w.spawn("endersteve_final",w.betrayer_position());w.hp=minf(20,w.hp+6);w.invulnerable=3.5
		"last_arrival":
			if w.stage_age>=2.2:w.stage="last_duel";w.stage_age=0;w.sound("warning")
		"clash":
			var foe: Vector2=w.npc.from
			var side: Vector2=Vector2.RIGHT if absf(w.player.x-foe.x)<1 else Vector2(signf(w.player.x-foe.x),0)
			w.npc.side=side
			if w.stage_age<CLASH_BREAK:
				w.player=w.player.move_toward(foe+side*20,dt*110)
				w.npc.p=foe
			else:
				# Both thrown back by the last blow.
				var k: float=smoothstep(CLASH_BREAK,CLASH_BREAK+.7,w.stage_age)
				w.player=w.player.move_toward(foe+side*(20+16*k),dt*60)
				w.npc.p=foe-side*10*k
			w.facing=Vector2(-side.x,0);w.npc.dir=side
			for t in CLASH_HITS:
				if cue(w,dt,t):w.sound("ch1_parry",.02);w.sound("swing",.02);w.shake=.12
			if cue(w,dt,CLASH_BREAK):
				w.shatter_clash_gear()
				for id in ["break","break","ch4_punch_heavy","shield_break"]:w.sound(id,.01)
				w.hitstop=.22;w.shake=.5
			if cue(w,dt,CLASH_BREAK+.75):w.sound("ch4_body_fall",.02);w.sound("ch4_body_fall",.02)
			if w.stage_age>=CLASH_LENGTH:w.stage="down";w.stage_age=0;w.sound("ch4_breath")
		"down":
			lines(w,dt,DOWN_LINES)
			if cue(w,dt,DOWN_MARKS.free):
				w.shake=.35;w.hitstop=.12
				for id in ["break","ch4_hb_shatter"]:w.sound(id,.02)
			if cue(w,dt,DOWN_RISE):w.sound("ch4_breath")
			if w.stage_age>=DOWN_LENGTH:w.stage="to_edge";w.stage_age=0
		"yield":
			if cue(w,dt,1.8):w.say("Хватит!",2.0)
			if w.stage_age>=YIELD_TIME:w.stage="approach";w.stage_age=0
		"approach":
			if w.player.distance_to(w.npc.p)<34:
				w.stage="to_edge";w.stage_age=0
		"to_edge":
			var seats: Array=w.seats()
			w.npc.p=w.npc.p.move_toward(seats[0],dt*34);w.player=w.player.move_toward(seats[1],dt*38)
			w.npc.dir=w.npc.p.direction_to(seats[0]) if w.npc.p!=seats[0] else Vector2.DOWN
			w.facing=w.player.direction_to(seats[1]) if w.player!=seats[1] else Vector2.DOWN
			if (w.npc.p==seats[0] and w.player==seats[1]) or w.stage_age>7:
				w.npc.p=seats[0];w.player=seats[1];w.facing=Vector2.DOWN;w.npc.dir=Vector2.DOWN
				w.stage="sit";w.stage_age=0;w.sound("ch4_breath");w.sound("end_wind")
		"sit":
			lines(w,dt,SIT_LINES)
			var gone: float=SIT_MARKS.delete
			# His maker starts erasing him mid-sentence; the tears come back faster and faster.
			if cue(w,dt,gone):w.shake=.55;w.hitstop=.18;w.sound("ch4_hb_glitch");w.sound("ch4_hb_shatter",.05)
			if w.stage_age>gone+1.0:
				var period: float=lerpf(2.4,.9,clampf((w.stage_age-gone)/(SIT_LENGTH-gone),0,1))
				if fposmod(w.stage_age-gone,period)<dt:w.sound("ch4_hb_glitch",.15);w.shake=maxf(w.shake,.12)
			if cue(w,dt,SIT_MARKS.gift+.6):w.keepsake=true;w.sound("pickup")
			if cue(w,dt,SIT_MARKS.gift+2.0):w.build["sword"]=1;w.cooldowns["sword"]=.35;w.sound("pickup")
			if w.stage_age>=SIT_LENGTH:w.stage="restore";w.stage_age=0;w.npc.from=w.npc.p
		"restore":
			var stand: Vector2=w.portal_position+Vector2(0,30)
			# No time left: he hurries to the portal, glitching all the way.
			w.npc.p=w.npc.from.lerp(stand,smoothstep(.5,2.0,w.stage_age));w.npc.dir=Vector2.UP if w.stage_age>.5 else Vector2.DOWN
			if fposmod(w.stage_age,1.1)<dt and w.stage_age<RESTORE_LIT:w.sound("ch4_hb_glitch",.15)
			lines(w,dt,RESTORE_LINES)
			if cue(w,dt,4.8):w.sound("portal_ignite")
			if cue(w,dt,RESTORE_LIT+.4):w.shake=.6;w.hitstop=.1;w.sound("ch4_hb_shatter");w.sound("end_music_cut",.05)
			if w.stage_age>=RESTORE_LIT and not w.portal_lit:w.portal_lit=true;w.sound("portal_open");w.shake=.2;w.sound("ch4_hb_glitch")
			if w.stage_age>=RESTORE_END:w.stage="portal_ready";w.stage_age=0;w.npc={}
		"portal_ready":
			if w.player_moving and w.player.distance_to(w.portal_position)<18:
				w.stage="exit_jump";w.stage_age=0;w.jump_start=w.player;w.facing=Vector2.UP;w.sound("portal_travel")
		"exit_jump":
			if w.stage_age>=3.4:w.stage="chapter_four";w.stage_age=0;w.end_complete=true;w.victory=true;w.state="RESULT"

func step(w, m: Dictionary, dt: float):
	if m.kind=="end_dragon":dragon(w,m,dt)
	else:endersteve(w,m,dt)

## Echoes of himself from other loops run their old lines at the hero, one after another.
func echoes(w, m: Dictionary):
	var count: int=5 if m.rage else 3
	if not m.get("echoes_spoken",false):m.echoes_spoken=true;w.say("Этому нет числа",2.2)
	for j in range(count):
		var a: float=m.attack_serial*.9+j*TAU/count
		var from: Vector2=w.player+Vector2.from_angle(a)*135
		cut(w,from,w.player-Vector2.from_angle(a)*135,.85+j*.32,10,true)
	w.sound("end_teleport");w.fx.ring(m.p,90.0,.6,"evolve")

func bolt(w, p: Vector2, wait: float):
	w.hazards.append({"kind":"end_bolt","p":p,"wait":wait,"total":wait,"radius":22.0,"damage":5.0,"remaining":.15})

func cloud(w, p: Vector2, radius: float, wait: float=.9, life: float=2.8):
	w.hazards.append({"p":p,"wait":wait,"total":wait,"radius":radius,"damage":3.0,"remaining":life,"end_cloud":true})

func cut(w, start: Vector2, end: Vector2, wait: float, width: float=12, echo: bool=false):
	w.hazards.append({"kind":"end_cut","p":start,"end":end,"wait":wait,"total":wait,"radius":width,"damage":5.0,"remaining":.2,"echo":echo})

func dragon(w, m: Dictionary, dt: float):
	var alive=w.crystals.filter(func(t):return t.alive).size()
	if alive>0:m.hp=minf(m.max_hp,m.hp+float(alive)*7*dt)
	if not m.phase_two and alive==0 and m.hp<=m.max_hp*.5+1:
		m.phase_two=true;m.phase="rage";m.timer=1.8;w.sound("dragon_growl");w.add_effect("dragon_roar",m.p,1.8,{"radius":90.0})
		w.fx.quake(w,m.p,2.0);w.fx.ring(m.p,160.0,1.0,"evolve");w.fx.flash(m.p,220.0,Color(.8,.4,1),.5)
	var old: Vector2=m.p;m.fire_tick-=dt;m.rush_tick-=dt
	var fast=1.45 if m.phase_two else 1.0
	match m.phase:
		"circle":
			m.orbit+=dt*.4*fast
			var target=Vector2(1024,1000)+Vector2.from_angle(m.orbit)*Vector2(250,175)
			m.dir=m.dir.lerp(m.p.direction_to(target),minf(1,dt*2)).normalized();m.p+=m.dir*m.speed*fast*dt;m.altitude=38+sin(w.clock*1.4)*9
			if m.phase_two and m.timer<=0:
				m.phase="descend";m.timer=1.7;m.mark=w.portal_position+Vector2(0,-25)
			elif m.rush_tick<=0:
				m.pattern=(m.pattern+1)%(4 if m.phase_two else 3);m.burst_tick=0
				if m.pattern==3:
					# Breath along the ground, a line of fire walking toward the hero.
					m.phase="breath_line";m.timer=2.2;var d: Vector2=m.p.direction_to(w.player)
					for j in range(10):cloud(w,(m.p+d*(40+j*34)).clamp(w.END_ARENA.position+Vector2(20,20),w.END_ARENA.end-Vector2(20,20)),24,.7+j*.11,1.5)
				elif m.pattern==1:
					m.phase="sweep_windup";m.timer=1.15;m.charge=Vector2(1 if w.player.x>1024 else -1,0);m.mark=Vector2(w.player.x,clampf(w.player.y-100,790,1190))
				else:m.phase="windup";m.timer=.95;m.charge=m.p.direction_to(w.player+w.tracked_velocity*.45)
				w.sound("dragon_growl")
		"windup":
			m.dir=m.charge;m.altitude=lerpf(m.altitude,20,dt*3)
			if m.timer<=0:m.phase="rush";m.timer=1.25;m.rush_tick=7.5/fast;w.sound("dragon_flap");w.fx.shove(w,m.charge,3.0,.12)
		"rush":
			m.p+=m.charge*215*fast*dt;m.dir=m.charge;m.altitude=14
			if int(m.timer*20)!=int((m.timer+dt)*20):w.fx.dust(m.p,2,22,Color(.7,.65,.6,.4))
			if m.p.distance_to(w.player)<42:
				if w.contact_hit(m.p,6):w.player_push=m.charge*170
			if m.pattern==2:
				m.burst_tick-=dt
				if m.burst_tick<=0:
					m.burst_tick=.32
					for side in [-1,1]:shot(w,m.p,m.charge.orthogonal()*side,90,2)
			if m.timer<=0:m.phase="circle";m.timer=4.8;m.orbit=(m.p-Vector2(1024,1000)).angle()
		"sweep_windup":
			m.p=m.p.move_toward(m.mark-m.charge*170,130*dt);m.dir=m.charge;m.altitude=32
			if m.timer<=0:m.phase="sweep";m.timer=2.4;m.burst_tick=0;m.rush_tick=8/fast
		"sweep":
			m.p+=m.charge*145*dt;m.dir=m.charge;m.altitude=24;m.burst_tick-=dt
			if m.burst_tick<=0:
				m.burst_tick=.55;cloud(w,w.player+w.tracked_velocity*.3,27,1.1,2.2)
				for side in [-1,1]:
					for j in range(3):shot(w,m.p,m.charge.orthogonal().rotated((j-1)*.24)*side,80+j*18,2)
			if m.timer<=0:m.phase="circle";m.timer=4.8
		"rage":
			m.altitude=35+sin(w.clock*9)*3
			if m.timer<=0:m.phase="circle";m.timer=3
		"descend":
			m.dir=m.p.direction_to(m.mark);m.p=m.p.move_toward(m.mark,90*dt);m.altitude=maxf(0,m.altitude-dt*30)
			if m.timer<=0:
				m.phase="perch";m.timer=5.5;m.altitude=0;m.burst_tick=.55;m.volley=0
				w.fx.quake(w,m.p,2.2,m.p+m.dir*70);w.fx.erupt(w,m.p,"stone",12);w.sound("mace_smash")
		"perch":
			m.altitude=0;m.dir=m.dir.lerp(m.p.direction_to(w.player),minf(1,dt*2)).normalized();m.burst_tick-=dt
			if m.burst_tick<=0:
				m.burst_tick=1.15;m.volley+=1
				var p=m.p+m.dir*90
				cloud(w,p,34,.95,2.5)
				# Alternating double fans retain a close melee opening behind the head.
				for side in [-1,1]:
					for j in range(5):shot(w,m.p,m.dir.rotated(side*(.4+j*.18)),88+j*10,2,.08*side)
			if m.timer<=0:m.phase="slump";m.timer=2.2;w.sound("dragon_growl",.3)
		"slump":
			# Head on the ground, worn out: the opening for heavy hits.
			m.altitude=0
			if m.timer<=0:m.phase="takeoff";m.timer=1.4;w.sound("dragon_flap")
		"breath_line":
			m.altitude=lerpf(m.altitude,22,dt*3);m.dir=m.dir.lerp(m.p.direction_to(w.player),dt*2).normalized()
			if m.timer<=0:m.phase="circle";m.timer=4.0
		"takeoff":
			m.altitude=minf(45,m.altitude+dt*35);m.p+=Vector2.UP*45*dt
			if m.timer<=0:m.phase="circle";m.timer=6;m.rush_tick=1.8
	if m.fire_tick<=0 and m.phase in ["circle","takeoff"]:
		m.fire_tick=2.25 if m.phase_two else 3.1;m.volley+=1
		var direction: Vector2=m.p.direction_to(w.player+w.tracked_velocity*.4)
		for j in range(3 if m.phase_two else 1):
			w.fire_projectile("dragon_fireball",m.p,direction.rotated((j-1)*.23 if m.phase_two else 0),{"speed":110+j*9,"damage":4,"range":500,"radius":8,"life":5},false)
		var count=24 if m.phase_two else 16
		var gap=direction.angle()+PI/2
		for j in range(count):
			var a=j*TAU/count+m.volley*.17
			if absf(wrapf(a-gap,-PI,PI))<.3 or absf(wrapf(a-gap-PI,-PI,PI))<.3:continue
			shot(w,m.p,Vector2.from_angle(a),76+(j%3)*17,2,.1*sin(m.volley))
	m.p=m.p.clamp(w.END_ARENA.position+Vector2(30,25),w.END_ARENA.end-Vector2(30,50))
	w.dragon_history.push_front(m.p)
	if w.dragon_history.size()>90:w.dragon_history.pop_back()
	m.moving=old.distance_to(m.p)>.01

func shot(w, p: Vector2, dir: Vector2, speed: float, damage: float, turn: float=0, blade: bool=false):
	# Boss shots hurt: one mistake is felt, three are a problem.
	w.fire_projectile("end_blade" if blade else "end_bullet",p,dir,{"speed":speed,"damage":damage+1.0,"range":760,"radius":3,"life":8,"turn":turn},false)

func recover(m, seconds: float=1.0):
	m.phase="recover";m.timer=seconds;m.altitude=0
	# After a clean hit he stops and lets you see it.
	if m.get("taunt",false):m.taunt=false;m.phase="pose";m.timer=.9

## His order of moves: the plain ones, and every few a big one he has done a thousand times.
const SEQUENCE=[0,1,2,9,3,4,10,5,6,11]
const RAGE_SEQUENCE=[0,7,9,1,3,8,10,2,4,11,5,6]
const TAUNTS=["Слишком медленно","Грёбаный придурок, я это уже видел","Ещё раз","Не так"]

func taunt(w, m: Dictionary):
	m.taunt=true
	if w.clock>=m.get("taunt_at",0.0):m.taunt_at=w.clock+11.0;w.say(TAUNTS[int(m.get("taunts",0))%TAUNTS.size()],1.6);m.taunts=int(m.get("taunts",0))+1

## He never stands still: circles the hero, flips direction, blinks to the other side.
func strafe(w, m: Dictionary, dt: float, keep: float=115.0):
	var to: Vector2=m.p.direction_to(w.player);var dist: float=m.p.distance_to(w.player)
	if w.clock>=float(m.get("strafe_flip",0.0)):m.strafe_flip=w.clock+w.rng.randf_range(1.4,2.4);m.strafe_dir=-float(m.get("strafe_dir",1.0))
	var radial: float=clampf((dist-keep)/50.0,-1,1)
	var v: Vector2=(to*radial+to.orthogonal()*float(m.get("strafe_dir",1.0))).normalized()*(150.0 if m.get("rage",false) else 120.0)
	m.p=w.move_actor(m.p,v*dt,m.radius);m.moving=true
	if w.clock>=float(m.get("hop_at",0.0)):
		m.hop_at=w.clock+(1.0 if m.get("rage",false) else 1.4)
		if dist<70 or w.rng.randf()<.45:w.teleport_mob(m,(w.player+Vector2.from_angle(w.rng.randf()*TAU)*keep).clamp(w.END_ARENA.position+Vector2(40,40),w.END_ARENA.end-Vector2(40,40)))

func endersteve(w, m: Dictionary, dt: float):
	if m.hp<m.max_hp*.5 and not m.rage:
		m.rage=true;m.phase="rage";m.timer=1.6;m.altitude=0;w.sound("dragon_growl");w.add_effect("ender_rage",m.p,1.6,{"radius":95.0})
		w.fx.quake(w,m.p,1.8);w.fx.ring(m.p,140.0,1.0,"evolve");w.fx.flash(m.p,200.0,Color(.75,.35,1),.6);w.say("Ну давай",1.8)
	m.burst_tick-=dt
	match m.phase:
		"walk","recover":
			m.dir=m.p.direction_to(w.player)
			if m.phase=="walk":m.p=w.move_actor(m.p,m.dir*m.speed*(1.25 if m.rage else .8)*dt,m.radius)
			else:strafe(w,m,dt,130.0)
			if m.timer<=0:
				m.seq=int(m.get("seq",-1))+1;var order: Array=RAGE_SEQUENCE if m.rage else SEQUENCE;m.pattern=order[m.seq%order.size()];m.combo=(2 if m.rage else 1) if m.pattern==3 else 0;m.charge=m.p.direction_to(w.player);m.mark=(w.player+w.tracked_velocity*.3).clamp(w.END_ARENA.position+Vector2(50,50),w.END_ARENA.end-Vector2(50,50))
				if m.pattern in [0,3]:
					w.fx.flash(m.p,80.0,Color(.8,.5,1),.15);w.teleport_mob(m,w.player-w.facing*90);m.charge=m.p.direction_to(w.player);w.fx.flash(m.p,80.0,Color(.8,.5,1),.15)
				m.phase="windup";m.timer=.85 if not m.rage else .7;m.windup_total=m.timer;m.burst_tick=0
				if m.pattern==5:
					cloud(w,m.mark,43,1.85,.35)
					m.leap_start=m.p
				w.sound("end_teleport",.1)
		"rage":
			if m.timer<=0:m.phase="walk";m.timer=.5
		"windup":
			if m.pattern not in [0,3,5]:strafe(w,m,dt*.6)
			if m.timer<=0:
				m.phase="rush" if m.pattern in [0,3] else "leap" if m.pattern==5 else "pursuit" if m.pattern==6 else "blink_chain" if m.pattern==9 else "echoes" if m.pattern==10 else "skyfall" if m.pattern==11 else "cast"
				m.timer=.6 if m.phase=="rush" else 1.0 if m.phase=="leap" else 2.0 if m.phase=="pursuit" else .16*(8 if m.rage else 6) if m.phase=="blink_chain" else 2.4 if m.phase=="echoes" else 3.4 if m.phase=="skyfall" else 3.1
				if m.phase=="echoes":echoes(w,m)
				if m.phase=="skyfall":m.altitude=0;m.mark=w.player;w.sound("wind_burst");w.fx.dust(m.p,8,20)
				m.burst_tick=0;m.attack_serial=0
		"rush":
			m.p=w.move_actor(m.p,m.charge*(275 if m.rage else 240)*dt,m.radius);m.dir=m.charge
			if m.burst_tick<=0:
				m.burst_tick=.14;w.add_effect("ender_slash",m.p,.35,{"direction":m.charge,"radius":45.0})
			if m.p.distance_to(w.player)<36:
				if w.contact_hit(m.p,5):w.player_push=m.charge*100;taunt(w,m)
			if m.timer<=0:
				if m.combo>0:
					m.combo-=1;w.teleport_mob(m,w.player-m.charge.rotated(PI/2)*90);m.charge=m.p.direction_to(w.player);m.phase="windup";m.timer=.58;m.windup_total=.58
				else:recover(m,1.1)
		"leap":
			var t=clampf(1-m.timer,0,1)
			m.p=m.leap_start.lerp(m.mark,smoothstep(0,1,t));m.altitude=sin(t*PI)*55;m.dir=m.charge
			if m.timer<=0:
				w.shake=.2;w.sound("mace_smash");w.add_effect("ender_slash",m.p,.5,{"direction":m.charge,"radius":65.0})
				w.fx.quake(w,m.p,1.6,m.p+m.charge*60);w.fx.erupt(w,m.p,"stone",9);w.fx.ring(m.p,70.0,.5,"toll")
				for j in range(16):shot(w,m.p,Vector2.from_angle(j*TAU/16),96,2,0,true)
				recover(m,1.25)
		"pursuit":
			m.dir=m.p.direction_to(w.player);m.p=w.move_actor(m.p,m.dir*110*dt,m.radius)
			if m.p.distance_to(w.player)<65 or m.timer<=0:
				m.charge=m.p.direction_to(w.player);m.phase="cleave_windup";m.timer=.65;m.windup_total=.65
		"cleave_windup":
			if m.timer<=0:
				m.phase="cleave";m.timer=.46;w.add_effect("ender_slash",m.p,.46,{"direction":m.charge,"radius":75.0});w.fx.slash(w,m.p,m.charge,75.0)
		"cleave":
			var delta: Vector2=w.player-m.p
			if delta.length()<75 and delta.normalized().dot(m.charge)>.1 and w.contact_hit(m.p,5):taunt(w,m)
			if m.timer<=0:
				for j in range(5):shot(w,m.p,m.charge.rotated((j-2)*.24),125,2,0,true)
				recover(m,1.15)
		"pose":
			# Sword lowered, looking at you: the opening he gives on purpose.
			m.dir=m.p.direction_to(w.player)
			if m.timer<=0:m.phase="walk";m.timer=.6
		"blink_chain":
			# Thousand cuts: blink after blink around the hero, every path a delayed cut.
			if m.burst_tick<=0:
				m.burst_tick=.16;var old: Vector2=m.p
				var target: Vector2=(w.player+Vector2.from_angle(m.attack_serial*2.3+.4)*118).clamp(w.END_ARENA.position+Vector2(40,40),w.END_ARENA.end-Vector2(40,40))
				w.teleport_mob(m,target)
				if old.distance_to(m.p)>20:cut(w,old,m.p,m.timer+.55,10,false)
				m.attack_serial+=1;w.fx.flash(m.p,60.0,Color(.8,.5,1),.12)
			if m.timer<=0:m.phase="pose";m.timer=1.1;m.charge=m.p.direction_to(w.player);w.sound("ch4_hb_freeze")
		"echoes":
			m.dir=m.p.direction_to(w.player);strafe(w,m,dt)
			if m.timer<=0:recover(m,1.2)
		"skyfall":
			var age: float=3.4-m.timer
			if age<.9:m.altitude=lerpf(0,240,smoothstep(0,.9,age))
			elif age<2.7:m.altitude=240;m.mark=m.mark.lerp(w.player,minf(1,dt*3.5))
			else:m.altitude=lerpf(240,0,smoothstep(2.7,3.4,age))
			if age>=2.7:m.p=m.mark
			if m.timer<=0:
				m.altitude=0;m.p=m.mark;w.shake=.5
				if w.player.distance_to(m.p)<48 and w.contact_hit(m.p,8):taunt(w,m)
				var gap: float=m.p.direction_to(w.player).angle()+PI*.5
				for j in range(26):
					var a: float=j*TAU/26
					if absf(wrapf(a-gap,-PI,PI))<.32 or absf(wrapf(a-gap-PI,-PI,PI))<.32:continue
					shot(w,m.p,Vector2.from_angle(a),105,2,0,true)
				w.fx.quake(w,m.p,2.6,m.p+Vector2(0,60));w.fx.erupt(w,m.p,"stone",16);w.fx.stain(m.p,22.0,"scorch",w.clock);w.fx.ring(m.p,120.0,.7,"toll");w.sound("mace_smash");w.sound("explosion")
				m.phase="pose";m.timer=1.2
		"cast":
			m.dir=m.p.direction_to(w.player);strafe(w,m,dt)
			m.charge=m.p.direction_to(w.player)
			if m.burst_tick<=0:
				m.burst_tick=.6 if m.rage else .8
				match m.pattern:
					1:
						var a=m.charge.angle()+sin(m.attack_serial*.85-1)*.65
						for j in range(9):shot(w,m.p,Vector2.from_angle(a+(j-4)*.2),92+(j%2)*24,2,.1*sin(m.attack_serial),true)
					2:
						var gap=m.p.direction_to(w.player).angle()+PI/3
						for j in range(28):
							var a=j*TAU/28+m.attack_serial*.12
							if absf(wrapf(a-gap,-PI,PI))<.29 or absf(wrapf(a-gap-PI,-PI,PI))<.29:continue
							shot(w,m.p,Vector2.from_angle(a),75+(j%3)*17,2,.16 if m.attack_serial%2 else -.16,j%3==0)
					7:
						# Herobrine's tower storm, learned the hard way: marks, then bolts.
						for j in range(4):bolt(w,(w.player+w.tracked_velocity*.35+Vector2.from_angle(m.attack_serial*1.3+j*TAU/4)*(0 if j==0 else 46)).clamp(w.END_ARENA.position+Vector2(40,40),w.END_ARENA.end-Vector2(40,40)),1.0)
					8:
						# Crossed cuts: two of his lanes at once, the safe corners between.
						var d:=Vector2.from_angle(PI/4+m.attack_serial*PI/2)
						cut(w,m.mark-d*110,m.mark+d*110,1.0,11,true);cut(w,m.mark-d.orthogonal()*110,m.mark+d.orthogonal()*110,1.0,11,true)
					4:
						# Echo bodies preview exactly the segment that will be cut.
						var direction=Vector2.from_angle(m.attack_serial*PI/2+.35)
						cut(w,m.mark-direction*95,m.mark+direction*95,.95,11,true)
						if m.rage:cloud(w,m.mark+direction.orthogonal()*62,23,1.05,.4)
				m.attack_serial+=1;w.sound("shulker_shoot",.2)
			if m.timer<=0:recover(m,1.25)

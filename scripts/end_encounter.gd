extends RefCounted
## Encounter clocks and all telegraphs advance only with the solo simulation.
## Set from BETRAYAL_SCRIPT in _init(): the scream lands on the blow.
var BETRAYAL_IMPACT:=3.4
var BETRAYAL_END:=10.2
const DEATH_DURATION=7.6
const YIELD_TIME=3.0
const RESTORE_LIT=7.4
const RESTORE_END=11.6
## Rebirth after his first death: gone at GONE, back on his feet at FORM.
const REBIRTH_GONE:=2.9
const REBIRTH_FORM:=3.6
const REBIRTH_END:=7.2
## He breaks the way out the moment it looks like the chapter is won.
## He speaks while the end card is still up; the last word is the strike.
const BETRAYAL_SCRIPT=[["Ладно...","ender","",0.0],["У меня нет другого выбора...","ender","",0.0],["Ты ничем не отличаешься от остальных...","ender","",0.0],["НАЧНЁМ!","ender","impact",.35]]
var BETRAYAL_LINES: Array=[]
## Standing by the broken portal, in a hurry: no walk to the rim (2026-11-14).
## [text, who, tag, pause before]. Multi-part lines are spoken one phrase at a time.
## "delete": his maker starts erasing him; "gift": the eye (the sword is already Steve's).
const SIT_SCRIPT=[
	["Вот и всё","ender","",0.0],
	["Я ведь тоже когда-то до него дошёл...\nОн отнял у меня нечто дорогое моему сердцу","ender","",.6],
	["Я думал, что справлюсь с ним, долго оттачивал свои навыки и копил ярость, однако меня ждал полный провал","ender","",.5],
	["Грёбаный ублюдок, стоящий за ним, выдал мне одну задачу и заточил меня здесь\nСудя по всему, в его алгоритме случился сбой после того, как ты смог меня одолеть\nДо этого всё, что я мог, — временами пытаться завести с тобой разговор. Каждый раз, когда ты появлялся, моя свобода воли переставала существовать","ender","look",.7],
	["Я впервые проиграл после того, как $%@!^ заточил меня здесь","ender","",.5],
	["Что произошло???\nТвою ж мать, эта мразь начала меня удалять!?","ender","delete",1.0],
	["Слушай, у нас мало времени. Раз он начал это делать, что-то явно пошло не по его плану","ender","",.3],
	["Держи Око Края, оно тебе пригодится","ender","gift",.3]]
var SIT_LINES: Array=[]
var SIT_MARKS: Dictionary={}
var SIT_LENGTH:=0.0
## After the duel: a last exchange of blows breaks both swords and drops them both.
const CLASH_HITS=[.55,1.05,1.55]
const CLASH_BREAK=2.25
const CLASH_LENGTH=3.4
var DOWN_LENGTH:=11.4
var DOWN_RISE:=8.6
## The last iron sword is Steve's. EnderSteve lies down and waits; Steve does not strike.
## "why": the sword is lowered; "free": the chains shatter; "rise": he gets up.
const MERCY_SCRIPT=[["Давай. Мне терять нечего","ender","",1.6],["В следующей итерации я всё равно тебя достану","ender","",.3],["...Почему?","ender","why",3.4],["Квиты","steve","",.6],["Не может быть, я больше не чувствую оков\nНеужели ты что-то ему сломал?","ender","free",1.2],["Подожди, мне нужно срочно тебе кое-что рассказать","ender","rise",.5]]
var MERCY_LINES: Array=[]
var MERCY_MARKS: Dictionary={}
var MERCY_LENGTH:=0.0
## Seconds before "why" at which Steve raises the sword over him, and how long he holds it.
const RAISE_BEFORE:=3.2
const RAISE_HOLD:=1.7
const LOWER_TIME:=.9
const STANDOFF_LENGTH:=1.6
const RACE_INTRO:=1.0
## The bad ending: he takes the sword, the hero is on his knees.
const BAD_LINE_AT:=1.1
const BAD_RAISE:=3.3
const BAD_STRIKE:=4.1
const BAD_LENGTH:=6.6
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
	var betrayal: Dictionary=timeline(BETRAYAL_SCRIPT,1.75)
	BETRAYAL_LINES=betrayal.lines;BETRAYAL_IMPACT=betrayal.marks.impact;BETRAYAL_END=BETRAYAL_IMPACT+4.2
	var sit: Dictionary=timeline(SIT_SCRIPT,1.2)
	SIT_LINES=sit.lines;SIT_MARKS=sit.marks;SIT_LENGTH=sit.end+1.4
	var mercy: Dictionary=timeline(MERCY_SCRIPT,0.0)
	MERCY_LINES=mercy.lines;MERCY_MARKS=mercy.marks;MERCY_LENGTH=mercy.end+2.2
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
			if cue(w,dt,BETRAYAL_IMPACT-1.6):w.sound("ch4_hb_charge")
			lines(w,dt,BETRAYAL_LINES)
			if w.stage_age>=BETRAYAL_IMPACT and w.portal_lit:
				w.portal_lit=false;w.win_music=false;w.shake=.9;w.hitstop=.28
				for id in ["end_portal_break","explosion","ch4_hb_shatter","end_music_cut"]:w.sound(id)
				w.add_effect("portal_shatter",w.portal_position,3.8,{"radius":100.0})
				w.add_effect("end_card_shatter",w.portal_position,3.0)
				# The duel restarts from here: gear intact, the chapter not lost.
				w.save_duel_checkpoint("fight1")
			if w.stage_age>=BETRAYAL_END:
				w.stage="last_arrival";w.stage_age=0;w.spawn("endersteve_final",w.betrayer_position());w.hp=minf(20,w.hp+6);w.invulnerable=3.5;w.hit_grace=3.5
		"last_arrival":
			if w.stage_age>=2.2:w.stage="last_duel";w.stage_age=0;w.sound("warning")
		"rebirth":
			# Killed once, he goes back the way every loop goes: Return by Death.
			if cue(w,dt,.3):w.sound("return_by_death");w.shake=.35;w.hitstop=.1
			if cue(w,dt,REBIRTH_GONE):w.sound("ch4_hb_glitch");w.shake=.5
			if cue(w,dt,REBIRTH_FORM):w.sound("end_teleport");w.sound("ch4_hb_shatter",.05);w.shake=.4;w.fx.flash(w.betrayer_position(),200.0,Color(.75,.4,1),.4);w.fx.ring(w.betrayer_position(),90.0,.8,"evolve")
			if cue(w,dt,REBIRTH_FORM+.7):w.say(w.steve_boss.rebirth_line(w),3.4)
			if w.stage_age>=REBIRTH_END:begin_second(w)
		"fallen":
			pass
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
			if w.stage_age>=CLASH_LENGTH:begin_race(w)
		"standoff":
			# Both still on their feet, both out of breath: one more exchange.
			var foe: Vector2=w.npc.from
			var side: Vector2=Vector2.RIGHT if absf(w.player.x-foe.x)<1 else Vector2(signf(w.player.x-foe.x),0)
			w.npc.side=side;w.facing=Vector2(-side.x,0);w.npc.dir=side
			w.player=w.player.move_toward(foe+side*34,dt*60)
			if cue(w,dt,.2):w.sound("ch4_breath")
			if w.stage_age>=STANDOFF_LENGTH:w.stage="clash";w.stage_age=0
		"sword_race":
			race(w,dt)
		"mercy":
			mercy(w,dt)
		"bad_end":
			if cue(w,dt,.5):w.sound("pickup")
			if cue(w,dt,BAD_LINE_AT):w.say("В этой итерации — моя",2.0)
			if cue(w,dt,BAD_RAISE):w.sound("ch4_hb_charge")
			if cue(w,dt,BAD_STRIKE):
				w.hitstop=.25;w.shake=.9
				for id in ["ch4_punch_heavy","ch4_flesh_hit","death"]:w.sound(id,.02)
			if w.stage_age>=BAD_LENGTH:w.stage="bad_card";w.stage_age=0;w.sound("end_music_cut")
		"bad_card":
			pass
		"talk":
			lines(w,dt,SIT_LINES)
			var gone: float=SIT_MARKS.delete
			# His maker starts erasing him mid-sentence; the tears come back faster and faster.
			if cue(w,dt,gone):w.shake=.55;w.hitstop=.18;w.sound("ch4_hb_glitch");w.sound("ch4_hb_shatter",.05)
			if w.stage_age>gone+1.0:
				var period: float=lerpf(2.4,.9,clampf((w.stage_age-gone)/(SIT_LENGTH-gone),0,1))
				if fposmod(w.stage_age-gone,period)<dt:w.sound("ch4_hb_glitch",.15);w.shake=maxf(w.shake,.12)
			if cue(w,dt,SIT_MARKS.gift+.6):w.keepsake=true;w.sound("pickup")
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

## Fight two: the same body back on its feet, knowing the hero.
func begin_second(w):
	w.duel.fight=2;w.endsteve_corpse={}
	if w.duel.get("learned","")=="mace":w.duel.adapt.mace=minf(float(w.duel.adapt.get("mace",1.0)),.7)
	w.hp=minf(20,w.hp+4);w.save_duel_checkpoint("fight2")
	w.spawn("endersteve_final",w.betrayer_position());w.invulnerable=1.5;w.hit_grace=1.5
	w.stage="last_duel";w.stage_age=0;w.sound("warning")

## Both blades are gone; the last iron sword lies between them and the ruined portal.
func begin_race(w):
	var mid: Vector2=(w.player+w.npc.p)/2
	var away: Vector2=(w.npc.p-w.player).orthogonal().normalized()
	if away.dot(w.portal_position-mid)<0:away=-away
	var spot: Vector2=(mid+away*70).clamp(w.END_ARENA.position+Vector2(40,40),w.END_ARENA.end-Vector2(40,40))
	w.race={"sword":spot,"steve":w.player,"ender":w.npc.p,"won":false}
	w.sword_race.reset(hash([int(w.rng.seed),w.boss_victory_serial,int(w.clock*10)]))
	w.stage="sword_race";w.stage_age=0;w.sound("ch4_breath")

func race(w, dt: float):
	var q=w.sword_race;var spot: Vector2=w.race.sword
	if w.stage_age<RACE_INTRO:return
	if not q.started:q.started=true;w.sound("warning",.05)
	q.step(dt)
	for e in q.events:
		match e:
			"step":w.sound("ch1_step",.15)
			"dodged":w.sound("ch4_punch_miss",.05);w.shake=.15
			"cut":w.sound("ch4_punch",.05);w.shake=.3;w.hitstop=.08
			"grabbed":w.sound("pickup");w.sound("ch1_parry",.05);w.hitstop=.12
			"fumbled","mash_lost":w.sound("hurt",.1)
	q.events.clear()
	# Who is ahead: the hero by his presses and successes, him by his own pace.
	var mine: float=[q.bar()*.55,.55+(.2 if q.outcomes.size()>1 and q.outcomes[1] else .1)*(1.0 if q.beat>=1 else 0.0),.8][mini(q.beat,2)] if q.beat<2 else (.8+.2*q.ring())
	var his: float=[q.foe_bar()*.55,.62,.82+.1*q.ring()][mini(q.beat,2)]
	w.player=w.player.move_toward(w.race.steve.lerp(spot,clampf(mine,0,.97)),dt*160)
	w.npc.p=w.npc.p.move_toward(w.race.ender.lerp(spot,clampf(his,0,.97)),dt*160)
	w.facing=w.player.direction_to(spot) if w.player.distance_to(spot)>1 else w.facing;w.npc.dir=w.npc.p.direction_to(spot) if w.npc.p.distance_to(spot)>1 else w.npc.dir
	if q.result=="won":
		w.race.won=true;w.player=spot+(w.race.steve-spot).normalized()*6;w.build["sword"]=1;w.cooldowns["sword"]=.35
		var side: Vector2=Vector2(signf(w.npc.p.x-w.player.x) if absf(w.npc.p.x-w.player.x)>1 else 1.0,0)
		w.npc.p=w.player+side*22;w.npc.side=-side;w.facing=side;w.npc.dir=-side
		w.stage="mercy";w.stage_age=0
		if w.hp>0:w.run_progress.finish(w)
	elif q.result=="lost":
		w.npc.p=spot;w.npc.dir=w.npc.p.direction_to(w.player)
		var side: Vector2=Vector2(signf(w.player.x-spot.x) if absf(w.player.x-spot.x)>1 else 1.0,0)
		w.player=spot+side*22;w.facing=-side;w.npc.side=side
		w.stage="bad_end";w.stage_age=0

func mercy(w, dt: float):
	lines(w,dt,MERCY_LINES)
	var raise: float=MERCY_MARKS.why-RAISE_BEFORE
	if cue(w,dt,1.2):w.sound("ch4_body_fall",.05)
	if cue(w,dt,raise):w.sound("ch4_hb_charge",.05);w.shake=.1
	if w.stage_age>raise and w.stage_age<raise+RAISE_HOLD and fposmod(w.stage_age-raise,.62)<dt:w.sound("ch4_heartbeat",.02)
	if cue(w,dt,raise+RAISE_HOLD):w.sound("swing",.05)
	if cue(w,dt,MERCY_MARKS.free):
		# Something in him breaks: the chains of every loop fall off.
		w.shake=.55;w.hitstop=.16
		for id in ["break","ch4_hb_shatter","ch4_hb_glitch"]:w.sound(id,.02)
	if cue(w,dt,MERCY_MARKS.rise):w.sound("ch4_breath")
	if w.stage_age>=MERCY_LENGTH:w.stage="talk";w.stage_age=0

func step(w, m: Dictionary, dt: float):
	if m.kind=="end_dragon":dragon(w,m,dt)
	else:w.steve_boss.step(w,m,dt)

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

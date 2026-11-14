extends SceneTree
## Balance runs of the reworked EnderSteve duel (both fights) with the lab builds.
## Args after --: "naive" (no dodging, just circles him), "sugar" (Sugar V on top).
## A run may die up to MAX_TRIES times (the duel restarts from its checkpoint).
const EW=preload("res://scripts/end_world.gd")
const LAB=preload("res://scripts/boss_lab.gd")
const MAX_TRIES:=3
var naive:=false
var sugar:=false
## Human reaction: the steering decision is renewed only every LAG seconds.
var lag:=0.0
func _initialize():run.call_deferred()

## Danger of standing at `p` a moment from now.
func danger(w, p: Vector2) -> float:
	var score:=0.0
	for b in w.projectiles:
		if not b.get("steve",false) and b.kind not in ["end_blade","end_bullet"]:continue
		var d: float=Geometry2D.get_closest_point_to_segment(p,b.p,b.p+b.dir*b.speed*.5).distance_to(p)
		if d<20:score+=(20-d)*25
	for h in w.hazards:
		var d: float=Geometry2D.get_closest_point_to_segment(p,h.p,h.end).distance_to(p) if h.get("kind","")=="end_cut" else p.distance_to(h.p)
		if d<h.radius+14:score+=(h.radius+14-d)*30
	for m in w.mobs:
		if m.kind!="endersteve_final" or m.hp<=0:continue
		if p.distance_to(m.p)<30:score+=400
		match m.phase:
			"projection_preview","projection":
				var path: Array=m.get("path",[]);var from: Vector2=m.p
				for i in range(int(m.get("seg",1)),path.size()):
					var d: float=Geometry2D.get_closest_point_to_segment(p,from,path[i]).distance_to(p)
					if d<30:score+=(30-d)*60
					from=path[i]
			"intercept":
				var d: float=p.distance_to(m.mark)
				if d<34:score+=(34-d)*50
			"windup","rush":
				if m.get("pattern",-1)==0:
					var d: float=Geometry2D.get_closest_point_to_segment(p,m.p,m.p+m.charge*300).distance_to(p)
					if d<50:score+=(50-d)*35
			"cleave_windup","counter","framed_strike":
				if p.distance_to(m.p)<85:score+=(85-p.distance_to(m.p))*20
			"skyfall":
				if p.distance_to(m.mark)<60:score+=(60-p.distance_to(m.mark))*25
	return score

func steer(w, desired: Vector2) -> Vector2:
	var best:=INF;var answer:=Vector2.ZERO
	for i in range(17):
		var dir: Vector2=Vector2.ZERO if i==16 else Vector2.from_angle(i*TAU/16)
		var future: Vector2=w.move_actor(w.player,dir*w.movement_speed()*.4,6)
		var score: float=future.distance_to(desired)*.6+danger(w,future)
		if score<best:best=score;answer=dir
	return answer

func run():
	var args: PackedStringArray=OS.get_cmdline_user_args()
	naive=args.has("naive");sugar=args.has("sugar");lag=.2 if args.has("human") else 0.0
	var reports=[]
	for index in range(4):
		var w=EW.new();w.reset(724);w.state="RUNNING";LAB.equip(w,index)
		if sugar:w.items.sugar=5
		w.prepare_arena();w.mobs.clear();w.crystals.clear();w.portal_lit=false;w.stage="betrayal";w.stage_age=0
		w.save_duel_checkpoint("fight1");w.restore_duel_checkpoint("fight1")
		var held:=Vector2.ZERO;var since:=99.0
		var elapsed:=0.0;var deaths:=0;var minimum:=20.0;var reached:=1;var framed:=0;var was_framed:=false;var rewinds:=0;var breaks:=0;var seen_clock:=""
		while elapsed<1200.0:
			var target: Vector2=w.player
			if w.state=="LEVEL_UP":w.choose(0);w.tick_choices(1.0/60);continue
			if w.state=="CHEST":w.chest_delay=0;w.close_chest();continue
			match w.stage:
				"fallen":
					deaths+=1
					if deaths>=MAX_TRIES:break
					w.retry_duel();continue
				"last_duel":
					reached=maxi(reached,int(w.duel.fight))
					var m=null
					for v in w.mobs:
						if v.kind=="endersteve_final" and v.hp>0:m=v
					if m!=null:
						var c: Dictionary=m.get("clock",{})
						var calm: bool=c.get("state","")=="running"
						var keep: float=150.0 if calm else (90.0 if w.build.has("bow") or w.build.has("crossbow") else 45.0)
						target=m.p+Vector2.from_angle(elapsed*.7)*keep
						if c.get("state","")!=seen_clock:
							seen_clock=c.get("state","")
							if seen_clock=="rewind":rewinds+=1
							if seen_clock=="broken":breaks+=1
				"sword_race":
					var q=w.sword_race
					if q.live():
						match q.beat:
							0:q.press("attack")
							1:if q.age>.5:q.press(q.dir)
							2:if q.age>=.9:q.press("attack")
				"mercy":break
			since+=1.0/60
			var move: Vector2=held
			if since>=lag:since=0.0;move=w.player.direction_to(target) if naive else steer(w,target);held=move
			if w.player.distance_to(target)<4:move=Vector2.ZERO
			w.step(1.0/60,move)
			if w.framed>0 and not was_framed:framed+=1
			was_framed=w.framed>0
			elapsed+=1.0/60;minimum=minf(minimum,w.hp)
		var report={"build":LAB.presets(3)[index].name,"naive":naive,"sugar":sugar,"lag":lag,"won":w.stage=="mercy","deaths":deaths,"reached_fight":reached,"learned":w.duel.get("learned",""),"seconds":snappedf(elapsed,.1),"min_hp":snappedf(minimum,.1),"framed":framed,"rewinds":rewinds,"clock_breaks":breaks}
		reports.append(report);print("CH3_DUEL_RUN ",JSON.stringify(report))
	FileAccess.open("res://qa/ch3_duel_runs%s%s%s.json"%["_naive" if naive else "","_sugar" if sugar else "","_human" if lag>0 else ""],FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	quit()

extends SceneTree
## Partial stage C trials: ordinary HP and damage, max gear issued by QA only.
const FW=preload("res://scripts/chapter_four_world.gd")
var results: Array=[]
func _initialize():run.call_deferred()
func run():
	for style in ["melee","ranged","ritual","heart"]:
		var w=FW.new();w.reset(974);w.stage="survival";w.state="RUNNING";w.time=240
		match style:
			"melee":w.build={"sword":8,"bone_saw":8,"bell":8};w.items={"armor":5,"thorns":3,"bat_wings":5,"mirror_shard":3,"sugar":3,"empty_totem":1};w.evolved={"sword":true,"bone_saw":true,"armor":true}
			"ranged":w.build={"shotgun":8,"bow":8,"sky_tnt":8,"potion":8};w.items={"gunpowder":5,"armor":5,"sugar":3,"empty_totem":1};w.evolved={"shotgun":true,"sky_tnt":true}
			"ritual":w.build={"blood_pool":8,"red_torch":8,"embryo":8,"bell":8,"potion":8};w.items={"black_candle":5,"bedrock":5,"armor":5,"empty_totem":1};w.evolved={"blood_pool":true,"red_torch":true,"embryo":true,"bell":true}
			"heart":w.build={"sword":8,"shotgun":8,"bone_saw":8};w.items={"heart_booster":5,"armor":5,"bat_wings":5,"empty_totem":1};w.evolved={"sword":true,"shotgun":true,"bone_saw":true}
		w.arsenal.reset(w)
		var frames: Array=[];var peaks={"mobs":0,"pellets":0,"tnt":0,"effects":0,"clouds":0,"torches":0};var elapsed:=0.0
		for i in range(10800):
			if w.state=="RESULT":break
			if w.state=="LEVEL_UP":w.skip_reward()
			if w.state=="CHEST":w.chest_delay=0;w.close_chest()
			var movement:=Vector2.ZERO
			var threat=w.nearest(w.player,190)
			if threat!=null:
				var outward: Vector2=threat.p.direction_to(w.player)
				var desired: float=28 if style=="melee" else 100
				movement=outward if w.player.distance_to(threat.p)<desired else -outward*.35 if style=="melee" else outward.orthogonal()*.55
			else:movement=Vector2.from_angle(w.clock*.2)*.4
			# Stay in the playable central area while preserving real collision.
			if w.player.distance_to(Vector2(1024,1024))>500:movement=w.player.direction_to(Vector2(1024,1024))
			if style=="ritual" and w.hp>8:movement=Vector2.ZERO
			if style=="heart" and w.hp>w.arsenal.heart_price+5:w.active_item("heart")
			var begin=Time.get_ticks_usec();w.step(1.0/60,movement);frames.append((Time.get_ticks_usec()-begin)/1000.0);elapsed+=1.0/60
			peaks.mobs=maxi(peaks.mobs,w.mobs.size());peaks.pellets=maxi(peaks.pellets,w.arsenal.shots.size());peaks.tnt=maxi(peaks.tnt,w.arsenal.drops.size());peaks.effects=maxi(peaks.effects,w.effects.size());peaks.clouds=maxi(peaks.clouds,w.arsenal.clouds.size());peaks.torches=maxi(peaks.torches,w.arsenal.torches.size())
		frames.sort()
		var result={"style":style,"simulated":elapsed,"hp":w.hp,"state":w.state,"kills":w.kills,"totem_used":w.arsenal.totem_spent,"peak":peaks,"p95_ms":frames[int(frames.size()*.95)],"damage_by":w.damage_by,"ordinary_damage":true,"diagnostic_max_gear":true}
		results.append(result);print(JSON.stringify(result))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/chapter_four_c"))
	FileAccess.open("res://qa/chapter_four_c/partial_runs.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit()

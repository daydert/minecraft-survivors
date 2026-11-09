extends SceneTree
## Simulation fingerprint for refactoring: the same seeds and inputs must give
## byte-identical world state. `-- --record` rewrites qa/fixtures/determinism.json.
const Bot=preload("res://scripts/autoplay_bot.gd")
const FIXTURE="res://qa/fixtures/determinism.json"
const STEP=1.0/60
const SNAPSHOT_EVERY=30.0

var record=false

func _initialize():run.call_deferred()

func scenarios() -> Array:
	return [
		{"id":"coop_base_ch1","script":"res://scripts/world.gd","seed":151,"style":"sword","seconds":300.0},
		{"id":"campaign_ch1","script":"res://scripts/campaign_world.gd","seed":152,"style":"bow","seconds":300.0},
		{"id":"campaign_ch1_boss","script":"res://scripts/campaign_world.gd","seed":153,"style":"sword","seconds":150.0,"start":705.0},
		{"id":"nether","script":"res://scripts/nether_world.gd","seed":154,"style":"sword","seconds":300.0},
		{"id":"nether_boss","script":"res://scripts/nether_world.gd","seed":155,"style":"random","seconds":180.0,"start":705.0},
		{"id":"end","script":"res://scripts/end_world.gd","seed":156,"style":"sword","seconds":300.0},
		{"id":"end_boss","script":"res://scripts/end_world.gd","seed":157,"style":"random","seconds":240.0,"start":705.0},
	]

func fingerprint(w) -> Dictionary:
	var core=[w.state,float(w.time),w.clock,w.player,w.facing,w.hp,w.xp,w.level,w.kills,w.score,w.build,w.items,w.evolved,w.cooldowns,w.choices,w.rng.state,w.uid,w.spawn_credit,w.victory]
	var extra=[]
	for field in ["stage","stage_age","flight","jump_height","shield_charges","dash_left"]:
		if field in w:extra.append(w.get(field))
	return {
		"t":snappedf(w.time,.001),
		"core":var_to_str(core).md5_text(),
		"extra":var_to_str(extra).md5_text(),
		"mobs":var_to_str(w.mobs).md5_text(),
		"projectiles":var_to_str(w.projectiles).md5_text(),
		"pickups":var_to_str([w.orbs,w.loot,w.props]).md5_text(),
		"effects":var_to_str(w.effects).md5_text(),
		"sounds":var_to_str(w.sounds).md5_text(),
		"summary":"hp=%s lvl=%d kills=%d mobs=%d state=%s stage=%s" % [w.hp,w.level,w.kills,w.mobs.size(),w.state,w.get("stage") if "stage" in w else "-"],
	}

func safe_movement(w, bot) -> Vector2:
	var desired: Vector2=bot.movement(w)
	if not w.has_method("on_land") or desired.length_squared()<.01:return desired
	for i in range(16):
		var direction=desired.rotated((i/2+1)*TAU/32*(1 if i%2==0 else -1)) if i>0 else desired
		var safe=true
		for j in range(1,13):
			if not w.on_land(w.player+direction*w.movement_speed()*.8*j/12):safe=false;break
		if safe:return direction
	return Vector2.ZERO

func run_scenario(s: Dictionary) -> Array:
	var w=load(s.script).new()
	w.reset(s.seed)
	w.state="RUNNING"
	var bot=Bot.new(s.style)
	if s.has("start"):
		w.time=s.start
		w.build={"sword":8,"bow":8,"trident":6,"fire":5}
		w.items={"armor":5,"sugar":3,"blaze":3,"redstone":3}
		w.evolved={"sword":true}
		w.level=30
	var snapshots=[]
	var next_snapshot=w.time+SNAPSHOT_EVERY
	var end_time=w.time+s.seconds
	var guard=int(s.seconds*60*1.5)
	while guard>0 and w.time<end_time and w.state!="RESULT":
		guard-=1
		if w.state=="LEVEL_UP":
			if w.has_method("tick_choices"):
				if w.chosen_item.is_empty():w.choose(bot.choose(w))
				w.tick_choices(STEP)
			else:w.choose(bot.choose(w))
		elif w.state=="CHEST":
			w.chest_delay=0
			w.close_chest()
		else:
			if w.hp<6 and w.state=="RUNNING":w.hp=20.0
			w.step(STEP,safe_movement(w,bot))
		if w.time>=next_snapshot:
			snapshots.append(fingerprint(w))
			next_snapshot+=SNAPSHOT_EVERY
		w.sounds.clear()
	snapshots.append(fingerprint(w))
	return snapshots

func run():
	record="--record" in OS.get_cmdline_user_args()
	var results={}
	for s in scenarios():
		var started=Time.get_ticks_msec()
		results[s.id]=run_scenario(s)
		print("SCENARIO ",s.id," ",results[s.id].size()," snapshots, ",Time.get_ticks_msec()-started," ms; final ",results[s.id][-1].summary)
	if record:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/fixtures"))
		FileAccess.open(FIXTURE,FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
		print("DETERMINISM_RECORDED ",results.size()," scenarios")
		quit()
		return
	var expected=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var failures=[]
	for id in results:
		var got: Array=results[id]
		var want: Array=expected.get(id,[])
		if got.size()!=want.size():failures.append("%s: %d snapshots, expected %d" % [id,got.size(),want.size()])
		for i in range(mini(got.size(),want.size())):
			for key in want[i]:
				if str(got[i][key])!=str(want[i][key]):
					failures.append("%s @%s: %s differs (%s vs %s)" % [id,want[i].t,key,got[i].summary,want[i].summary])
					break
			if failures.size()>0 and failures[-1].begins_with(id):break
	for f in failures:push_error(f)
	print("DETERMINISM_RESULT %d scenarios; %d failures" % [results.size(),failures.size()])
	quit(1 if failures.size()>0 else 0)

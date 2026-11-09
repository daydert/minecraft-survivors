extends SceneTree
const World = preload("res://scripts/coop_world.gd")
const Solo = preload("res://scripts/world.gd")
const Codec = preload("res://scripts/coop_codec.gd")
var failures: Array = []
var checks = 0

func _initialize(): run.call_deferred()

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
	else: print("PASS: "+label)

func arena(seed_value: int = 724):
	var w = World.new(seed_value)
	w.configure(seed_value,{1:"Ведущий",2:"Друг"},1)
	return w

func run():
	var w = arena()
	check(w.players.size() == 2 and w.mob_multiplier == 2,"Two independent heroes and fixed double spawn")
	var solo = Solo.new(724)
	check(w.props == solo.props,"Coop and solo retain the same seeded collision map")
	w.step_coop(1.0/60,{1:Vector2.LEFT,2:Vector2.RIGHT})
	check(w.players[1].player.x < 1006 and w.players[2].player.x > 1042,"Both heroes move in one simulation tick")
	check(is_equal_approx(w.time,1.0/60),"The arena clock advances once for two players")
	w.use_actor(2)
	w.apply_upgrade("bow")
	w.apply_upgrade("armor")
	w.save_actor()
	w.use_actor(1)
	check(not w.build.has("bow") and not w.items.has("armor") and w.players[2].build.has("bow"),"Inventories and passives never alias between heroes")
	w.use_actor(2)
	w.hp = 3
	w.save_actor()
	w.use_actor(1)
	w.damage_area(w.players[2].player,4,2)
	check(w.hp == 20 and is_equal_approx(w.players[2].hp,1.2),"Damage and armor belong to the actual target")
	w.players[2].invulnerable = 0
	w.use_actor(2)
	w.invulnerable = 0
	w.use_actor(1)
	w.damage_area(w.players[2].player,4,8)
	w.mark_deaths()
	w.refresh_state()
	check(not w.players[2].alive and w.players[2].hp == 0 and w.state == "RUNNING","One death leaves the surviving host in combat")
	w.use_actor(2)
	w.apply_upgrade("apple")
	w.save_actor()
	check(w.hp == 0 and not w.players[2].alive,"Pickups cannot revive a dead participant")
	w.use_actor(1)
	var dead_position: Vector2 = w.players[2].player
	w.step_coop(.1,{2:Vector2.DOWN})
	check(w.players[2].player == dead_position and w.mob_multiplier == 2,"Dead input is ignored and spawn scaling stays doubled")
	w.local_id = 2
	w.refresh_state()
	check(w.state == "SPECTATING" and w.camera() == w.players[1].player.clamp(w.VIEW/2,Vector2.ONE*w.SIZE-w.VIEW/2),"Dead client spectates the living hero")
	w = arena()
	w.set_paused(2,true)
	var old_clock = w.clock
	var before: Vector2 = w.players[1].player
	w.step_coop(5,{1:Vector2.RIGHT})
	check(w.clock == old_clock and w.players[1].player == before and w.state == "WAITING","Guest pause freezes clocks and movement for both heroes")
	w.set_paused(1,true)
	w.set_paused(2,false)
	check(not w.can_step() and w.state == "PAUSED","Closing one pause never releases another player's pause")
	w.set_paused(1,false)
	check(w.can_step() and w.state == "RUNNING","Combat resumes after both participants release pause")
	w.use_actor(2)
	w.xp = w.db.required_xp(1)
	w.use_actor(1)
	w.step_coop(1.0/60,{})
	check(w.players[2].phase == "LEVEL_UP" and w.state == "WAITING","Guest upgrades stop the common arena")
	w.choose_for(1,0)
	check(w.players[2].phase == "LEVEL_UP","One player cannot select the other's upgrade")
	w.choose_for(2,99)
	check(w.players[2].phase == "LEVEL_UP","Invalid upgrade index is ignored")
	w.choose_for(2,0)
	check(w.can_step() and w.players[2].level == 2 and w.players[1].level == 1,"Guest selection resumes without changing host level")
	w = arena()
	w.drop_xp(w.players[1].player+Vector2(-16,0),1)
	for i in range(15): w.step_coop(1.0/60,{})
	check(w.orbs.is_empty() and w.players[1].xp == 1 and w.players[2].xp == 0,"An attracted orb moves to one collector instead of oscillating between heroes")
	w = arena()
	w.drop_xp(w.players[1].player+Vector2(-20,0),1)
	w.step_coop(1.0/60,{})
	w.disconnect_actor(1)
	w.use_actor(2)
	w.player = w.orbs[0].p
	w.save_actor()
	for i in range(3): w.step_coop(1.0/60,{})
	check(w.orbs.is_empty() and w.players[2].xp == 1,"A survivor can collect an orb whose original collector died")
	w.set_paused(1,true)
	w.disconnect_actor(1)
	check(w.can_step(),"Disconnecting a paused spectator cannot leave combat frozen")
	w = arena()
	w.use_actor(2)
	w.player = w.players[1].player+Vector2(80,0)
	w.use_actor(1)
	w.spawn("zombie",w.players[2].player+Vector2(0,12))
	w.move_mobs(.01)
	check(w.players[1].hp == 20 and w.players[2].hp < 20,"Mobs chase and hit the nearest living hero")
	w = arena()
	w.use_actor(2)
	w.player = w.players[1].player+Vector2(120,0)
	w.use_actor(1)
	w.fire_projectile("enemy_arrow",w.players[2].player+Vector2(-12,0),Vector2.RIGHT,{"speed":110,"damage":3,"range":220,"radius":3,"pierce":0},false)
	w.update_projectiles(.1)
	check(w.players[2].hp == 17 and w.active_id == 1,"Enemy arrows hit the guest and restore the caller's context")
	w = arena()
	w.use_actor(2)
	w.player = w.players[1].player+Vector2(90,0)
	var origin: Vector2 = w.player
	w.fire_projectile("trident",origin+Vector2(18,0),Vector2.RIGHT,{"speed":100,"damage":3,"range":220,"radius":3,"pierce":0},false)
	w.projectiles[0].returning = true
	w.use_actor(1)
	w.update_projectiles(.1)
	check(w.projectiles.is_empty() and w.active_id == 1,"Returning tridents home to their owner, including on the host")
	w = arena()
	w.use_actor(2)
	w.items = {"blaze":5}
	w.use_actor(1)
	w.spawn("zombie",w.player+Vector2(-90,0))
	w.mobs[0].merge({"burn":1.0,"burn_tick":0.0,"burn_owner":2},true)
	w.move_mobs(.01)
	check(w.mobs[0].hp == 5,"Flame damage uses its owner's passives even when the mob chases someone else")
	w = arena()
	w.time = 180
	w.events_done.clear()
	w.spawn_wave(1)
	check(w.pending_events.size()+w.mobs.filter(func(m):return m.kind == "elite").size() >= 2,"Scheduled enemies are doubled along with ordinary waves")
	w = arena()
	w.time = 2
	solo = Solo.new(724)
	solo.time = 2
	w.spawn_wave(.5)
	solo.spawn_wave(.5)
	check(is_equal_approx(w.spawn_credit+ w.normal_count(),2*(solo.spawn_credit+solo.normal_count())),"Spawn credits run at exactly twice solo's rate")
	w = arena()
	w.disconnect_actor(2)
	check(not w.players[2].alive and w.mob_multiplier == 2 and w.can_step(),"Disconnect consumes one life and preserves the surviving run")
	w.disconnect_actor(1)
	check(w.run_state == "RESULT" and not w.victory,"Both deaths produce the ordinary defeat screen")
	w = arena()
	w.time = 719.99
	w.step_coop(1.0/60,{})
	check(w.run_state == "FINALE" and w.players[1].in_finale and w.players[2].in_finale,"12:00 brings both living heroes into the original finale")
	w.set_paused(2,true)
	w.step_coop(5,{})
	check(w.finale.elapsed == 0,"Coop pause also freezes the canonical ending")
	w.set_paused(2,false)
	for id in w.players:
		w.use_actor(id)
		w.hp = 1000000
		w.invulnerable = 1000000
	w.use_actor(1)
	for i in range(2050): w.step_coop(1.0/60,{})
	check(w.finale.complete and not w.victory and w.players[1].hp == 0 and w.players[2].hp == 0,"Both invulnerable heroes inevitably fall into the Nether")
	w = arena()
	w.disconnect_actor(1)
	w.time = 719.99
	w.step_coop(1.0/60,{})
	check(not w.players[1].in_finale and w.players[2].in_finale and w.players[1].hp == 0,"A dead host watches the guest's ending without resurrection")
	for i in range(2050): w.step_coop(1.0/60,{})
	check(w.finale.complete and w.run_state == "RESULT","A surviving guest can finish the chapter after the host hero dies")
	w = arena()
	for i in range(500): w.spawn("zombie",Vector2(700+i%30*10,700+i/30*10))
	check(w.normal_count() == 500 and not w.spawn("zombie",Vector2(900,900)),"Double mob cap is enforced at 500")
	var largest = 0
	var bytes_total = 0
	for bucket in Codec.buckets(w):
		var bytes = Codec.encode(bucket)
		largest = maxi(largest,bytes.size())
		bytes_total += bytes.size()
		var decoded = Codec.decode(bytes)
		var exact_positions = decoded.mobs.size() == bucket.mobs.size()
		for i in range(decoded.mobs.size()):
			exact_positions = exact_positions and decoded.mobs[i].id == bucket.mobs[i].id and decoded.mobs[i].p == bucket.mobs[i].p and decoded.mobs[i].visual.state == bucket.mobs[i].visual.state
		check(exact_positions and Codec.encode(decoded) == bytes,"Compact entity bucket preserves exact positions, IDs and poses")
	var frame = Codec.frame(w,10,3,17)
	check(Codec.decode(Codec.encode(frame)) == frame,"Player/finale control snapshot round-trip")
	var samples = [{"tick":0,"data":{"orbs":[{"id":1,"p":Vector2.ZERO}]}},{"tick":6,"data":{"orbs":[{"id":1,"p":Vector2(60,0)}]}}]
	check(Codec.sample(samples,3,true).orbs[0].p == Vector2(30,0),"Snapshots interpolate between authoritative positions")
	check(Codec.sample(samples,60,true).orbs[0].p == Vector2(120,0),"Extrapolation is bounded to 100 ms")
	check(Codec.sample(samples,60,false).orbs[0].p == Vector2(60,0),"Paused replicas never extrapolate movement")
	var cache = {}
	check(Codec.sample_cached(samples,3,true,cache).orbs[0].p == Vector2(30,0),"Cached interpolation matches the immutable reference")
	check(Codec.sample_cached(samples,4,true,cache).orbs[0].p == Vector2(40,0) and samples[0].data.orbs[0].p == Vector2.ZERO,"Reusing display dictionaries never mutates authoritative history")
	check(Codec.sample_cached(samples,60,true,cache).orbs[0].p == Vector2(120,0),"Cached extrapolation retains the 100 ms limit")
	check(Codec.sample_cached(samples,60,false,cache).orbs[0].p == Vector2(60,0),"Cached renderer immediately stops extrapolating on pause")
	var report = {"checks":checks,"failures":failures,"500_mob_snapshot_bytes":bytes_total,"largest_bucket_bytes":largest}
	FileAccess.open("res://qa/coop_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("COOP_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

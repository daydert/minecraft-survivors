extends SceneTree
const World = preload("res://scripts/coop_world.gd")
const Session = preload("res://scripts/coop_session.gd")
const Codec = preload("res://scripts/coop_codec.gd")
var checks = 0
var failures: Array = []

func _initialize(): run.call_deferred()

func check(ok: bool, label: String):
	checks += 1
	if ok: print("PASS: "+label)
	else: failures.append(label); push_error(label)

func arena():
	var w = World.new(724)
	w.configure(724,{1:"Ведущий",2:"Друг",3:"Друг_2",4:"Друг_3"},1)
	return w

func run():
	var w = arena()
	var points = {}
	for a in w.players.values(): points[a.player] = true
	check(w.players.size() == 4 and points.size() == 4,"Four participants have distinct spawn positions")
	check(w.players.values().all(func(a):return w.free_at(a.player,6)),"All four spawns preserve the map collision geometry")
	var solo = preload("res://scripts/world.gd").new(724)
	var targets = w.players.values().map(func(a):return a.player)
	targets.append_array([Vector2(31,31),Vector2(2017,31),Vector2(1006,2017)])
	for target in targets:
		w.player = target
		w.update_flow()
		solo.player = target
		solo.update_flow()
		check(w.flow == solo.flow,"Cached navigation remains identical to the original BFS, including map edges")
	w = arena()
	var initial = w.players.duplicate(true)
	var inputs = {1:Vector2.LEFT,2:Vector2.RIGHT,3:Vector2.UP,4:Vector2.DOWN}
	w.step_coop(1.0/60,inputs)
	for id in inputs:
		check(w.players[id].player.is_equal_approx(initial[id].player+inputs[id]*82/60),"Each participant receives only their own movement")
	check(is_equal_approx(w.clock,1.0/60) and w.mob_multiplier == 2,"Four players advance one arena clock and retain fixed double spawn")
	w.use_actor(4)
	w.apply_upgrade("bow")
	w.apply_upgrade("sugar")
	w.use_actor(1)
	check(w.players[4].build.has("bow") and not w.players[1].build.has("bow") and not w.players[2].items.has("sugar") and not w.players[3].items.has("sugar"),"All four builds remain independent")
	w.damage_area(Vector2(1024,1024),120,2)
	w.save_actor()
	check(w.players.values().all(func(a):return a.hp == 18),"One explosion can damage all four heroes exactly once")
	w.set_paused(3,true)
	w.set_paused(4,true)
	var clock = w.clock
	w.step_coop(1,inputs)
	w.set_paused(3,false)
	check(w.clock == clock and not w.can_step(),"Third/fourth player pauses freeze everyone and remain independent")
	w.set_paused(4,false)
	check(w.can_step(),"The last participant releasing pause resumes the arena")
	w.use_actor(4)
	w.xp = w.db.required_xp(1)
	w.use_actor(1)
	w.step_coop(1.0/60,{})
	check(w.players[4].phase == "LEVEL_UP" and w.state == "WAITING","The fourth player's upgrade pauses the other three")
	w.choose_for(3,0)
	check(w.players[4].phase == "LEVEL_UP","Another participant cannot choose the fourth player's upgrade")
	w.choose_for(4,0)
	check(w.can_step() and w.players[4].level == 2,"The fourth player's own choice resumes play")
	w = arena()
	w.disconnect_actor(2)
	check(w.living().size() == 3 and w.mob_multiplier == 2,"One disconnect leaves three lives and double spawn")
	w.local_id = 2
	w.refresh_state()
	check(w.state == "SPECTATING","The dead participant observes the remaining party")
	w.disconnect_actor(1)
	w.disconnect_actor(3)
	w.local_id = 4
	w.refresh_state()
	check(w.state == "RUNNING" and w.living() == [4],"Only the fourth participant may remain alive without ending the run")
	w.disconnect_actor(4)
	check(w.run_state == "RESULT" and not w.victory,"The run ends only after all four lives are lost")
	w = arena()
	w.time = 719.99
	w.step_coop(1.0/60,{})
	points.clear()
	for a in w.players.values(): points[a.player] = true
	check(w.run_state == "FINALE" and points.size() == 4 and w.players.values().all(func(a):return a.in_finale),"All four heroes enter distinct positions in the original finale")
	for id in w.players:
		w.use_actor(id)
		w.hp = 1000000
		w.invulnerable = 1000000
	w.use_actor(1)
	for i in range(2050): w.step_coop(1.0/60,{})
	check(w.finale.complete and not w.victory and w.players.values().all(func(a):return a.hp == 0 and not a.alive),"The mandatory defeat and Nether ending apply to all four invulnerable heroes")
	w = arena()
	w.disconnect_actor(1)
	w.time = 719.99
	w.step_coop(1.0/60,{})
	var departed = w.finale_driver
	w.disconnect_actor(departed)
	check(w.finale_driver != departed and not w.players[departed].in_finale,"A disconnected cinematic driver transfers to another living participant")
	for i in range(2050): w.step_coop(1.0/60,{})
	check(w.finale.complete and w.players[departed].hp == 0 and not w.players[departed].alive,"The remaining heroes finish the finale without resurrecting the disconnected one")
	w = arena()
	w.time = 719.99
	w.step_coop(1.0/60,{})
	for i in range(1500): w.step_coop(1.0/60,{})
	w.disconnect_actor(2)
	check(w.run_state == "FINALE" and w.players[1].alive and w.players[1].hp == 0,"A departure after scripted defeat does not truncate the remaining portal sequence")
	for i in range(550): w.step_coop(1.0/60,{})
	check(w.finale.complete and not w.players[2].alive,"The remaining party still reaches the Nether after a late departure")
	w = arena()
	var shot = {"speed":100,"damage":1,"range":200,"radius":3,"pierce":0}
	for i in range(801): w.fire_projectile("arrow",w.player,Vector2.RIGHT,shot,false)
	check(w.projectiles.size() == 800,"Four-player projectile allowance is bounded without retaining the old two-player limit")
	for i in range(1281): w.add_effect("swing",w.player,.2)
	check(w.effects.size() == 1280,"Four-player effects remain bounded without dropping attacks at the old limit")
	var frame = Codec.decode(Codec.encode(Codec.frame(w,10,2,7)))
	check(frame.players.size() == 4 and frame.ack == 7 and frame.players[4].slot == 3,"Snapshots retain all four identities and the recipient's acknowledgement")
	var complete = Codec.buckets(w)
	var staggered = []
	for phase in range(3): staggered.append(Codec.buckets(w,phase))
	check(range(32).all(func(bucket):return staggered[bucket%3][bucket] == complete[bucket]),"Staggered updates retain every entity without reducing per-bucket frequency")
	var net = Session.new()
	for id in [2,3,4]: net.input_streams[id] = net.new_input_stream()
	for id in [2,3,4]:
		net.input_streams[id].queue[1] = inputs[id]
		net.input_streams[id].queue[2] = inputs[id]
	for id in [2,3,4]: check(net.consume_input(id) == inputs[id],"Each remote input stream retains its own direction")
	net.consume_input(2)
	check(net.input_streams[2].ack == 2 and net.input_streams[3].ack == 1 and net.input_streams[4].ack == 1,"One guest's acknowledgement never consumes another guest's command")
	net.input_streams.erase(2)
	check(net.consume_input(3) == inputs[3] and net.consume_input(4) == inputs[4],"Disconnecting one input stream leaves the others intact")
	net.input_reset()
	check(net.input_epoch == 1 and net.input_streams.values().all(func(s):return s.ack == 0 and s.queue.is_empty()),"Shared pause advances the input epoch and clears every remaining stream")
	net.free()
	var report = {"checks":checks,"failures":failures}
	FileAccess.open("res://qa/coop_four_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("COOP_FOUR_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

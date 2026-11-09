extends Node
## Host-authoritative ENet, 60 Hz inputs/simulation, 20 Hz independent snapshots.
## Channel 0: reliable lobby/control; 1: redundant input; 2: lossy world state.
const World = preload("res://scripts/coop_world.gd")
const Codec = preload("res://scripts/coop_codec.gd")
const PORT = 24567
const MAX_PLAYERS = 4
const PROTOCOL = "minecraft-survivors-coop-3"
const STEP = 1.0/60.0
var diagnostics = preload("res://scripts/coop_diagnostics.gd").new()
var game
var peer: ENetMultiplayerPeer
var active = false
var hosting = false
var running = false
var loading = false
var status = ""
var roster: Dictionary = {}
var nickname = "Стив"
var epoch = 0
var input_epoch = 0
var server_tick = 0
var sequence = 0
var ack = 0
var input_streams: Dictionary = {}
var awaiting_loaded: Dictionary = {}
var pending: Array = []
var predicted = Vector2.ZERO
var predicted_facing = Vector2.DOWN
var correction = Vector2.ZERO
var player_frames: Array = []
var entity_frames: Dictionary = {}
var entity_render_cache: Dictionary = {}
var assemblies: Dictionary = {}
var main_tick = -1
var estimated_tick = 0.0
var render_tick = 0.0
var last_receive = 0.0
var connect_started = 0.0
var last_sound = 0
var control_signature = ""
var last_can_step = false
var bytes_sent = 0
var max_bucket_bytes = 0
var corrections: Array = []
var received_frames = 0
var received_buckets = 0
var command_times: Dictionary = {}
var clock_anchor = 0.0
var time_anchor = 0.0
var finale_anchor: Dictionary = {}
var local_gait = 0.0
var last_local_movement = Vector2.ZERO
var bucket_payloads: Dictionary = {}
var correction_diagnostics: Array = []
var last_sim_ms = 0.0
var last_snapshot_ms = 0.0
var input_packets = 0
var client_send_tick = 0
var authority_position = Vector2.ZERO
var _log_waiting = false
var _log_bytes = 0
var _log_peer_id = 0

func _ready():
	multiplayer.peer_disconnected.connect(_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_server_lost)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.allow_object_decoding = false
	# All game traffic is host-authoritative. Peer-to-peer relay/presence is
	# unnecessary and can try to notify a peer already closed in the same poll.
	multiplayer.server_relay = false

func _process(delta: float):
	if not diagnostics.enabled: return
	diagnostics.measure("frame_ms",delta*1000)
	if delta > .05:
		diagnostics.limited_event("long_frame",{"frame_ms":delta*1000,"tick":server_tick if hosting else main_tick,"state":game.world.state},250)
	var waiting = network_waiting()
	if waiting != _log_waiting:
		_log_waiting = waiting
		diagnostics.event("network_waiting",{"waiting":waiting,"tick":main_tick,"snapshot_age_ms":(now()-last_receive)*1000})
	if diagnostics.sample_due():
		diagnostics.sample(telemetry_snapshot())
		_log_bytes = bytes_sent

func _exit_tree():
	if diagnostics.enabled: diagnostics.event("session_end",{"reason":"tree_exit"})
	diagnostics.close()

func begin_diagnostics(role: String, port: int):
	_log_bytes = bytes_sent
	_log_waiting = false
	_log_peer_id = multiplayer.get_unique_id()
	diagnostics.start({"role":role,"nick":nickname,"peer_id":_log_peer_id,"port":port,"version":"0.6.1","protocol":PROTOCOL,"engine":Engine.get_version_info().string,"os":OS.get_name(),"cpu_cores":OS.get_processor_count(),"display":DisplayServer.get_name(),"gpu":RenderingServer.get_video_adapter_name() if DisplayServer.get_name() != "headless" else "headless"})

func actor_telemetry() -> Array:
	var actors: Array = []
	if not game.world is World: return actors
	game.world.save_actor()
	for a in game.world.players.values():
		actors.append({"id":a.id,"nick":a.nick,"alive":a.alive,"connected":a.connected,"hp":a.hp,"phase":a.phase,"paused":a.paused,"p":[a.player.x,a.player.y]})
	return actors

func telemetry_snapshot() -> Dictionary:
	var w = game.world
	var peers: Array = []
	if peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		for id in remote_ids() if hosting else [1]:
			var enet = peer.get_peer(id)
			if enet == null or not enet.is_active(): continue
			var p = {"id":id,"rtt_ms":enet.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),"rtt_variance_ms":enet.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE),"last_rtt_ms":enet.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME),"reliable_loss_ratio":enet.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)/ENetPacketPeer.PACKET_LOSS_SCALE,"throttle":enet.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)}
			if input_streams.has(id):
				var stream: Dictionary = input_streams[id]
				p.merge({"ack":stream.ack,"queued":stream.queue.size(),"gap_ticks":stream.gap_ticks,"input_age_ms":(now()-stream.last_rx)*1000 if stream.last_rx >= 0 else -1,"input_packets":stream.received},true)
			peers.append(p)
	var row = {"epoch":epoch,"input_epoch":input_epoch,"role":"host" if hosting else "client","peer_id":_log_peer_id,"tick":server_tick if hosting else main_tick,"state":w.state,"clock":w.clock,"time":w.time,"loading":loading,"running":running,"waiting_loaded":awaiting_loaded.keys(),"fps":Engine.get_frames_per_second(),"physics_frames":Engine.get_physics_frames(),"process_frames":Engine.get_process_frames(),"app_tx_bytes_total":bytes_sent,"app_tx_bytes_window":bytes_sent-_log_bytes,"mobs":w.mobs.size(),"projectiles":w.projectiles.size(),"effects":w.effects.size(),"orbs":w.orbs.size(),"actors":actor_telemetry(),"position_space":"authority" if hosting else "rendered","peers":peers}
	if not hosting:
		row.merge({"snapshot_age_ms":(now()-last_receive)*1000 if main_tick >= 0 else -1,"ack":ack,"sequence":sequence,"pending":pending.size(),"correction_px":correction.length(),"predicted":[predicted.x,predicted.y],"authority":[authority_position.x,authority_position.y],"render_tick":render_tick,"estimated_tick":estimated_tick,"received_frames":received_frames,"received_buckets":received_buckets},true)
	if w.finale.active: row.finale = {"elapsed":w.finale.elapsed,"phase":w.finale.phase,"complete":w.finale.complete}
	return row

func mark_lag():
	if diagnostics.enabled: diagnostics.event("user_marker",telemetry_snapshot())

func open_log_folder():
	var path = ProjectSettings.globalize_path(diagnostics.directory)
	DirAccess.make_dir_recursive_absolute(path)
	OS.shell_open(path)

func now() -> float:
	return Time.get_ticks_msec()/1000.0

static func clean_nick(value: String) -> String:
	var result = ""
	for character in value.strip_edges():
		var code = character.unicode_at(0)
		if code >= 32 and code != 127 and code < 0x2000: result += character
	return result.left(16).strip_edges()

func fingerprint() -> String:
	return PROTOCOL+":"+FileAccess.get_file_as_string("res://data/balance.json").sha256_text()

func host(nick: String, port: int = PORT) -> bool:
	leave()
	nickname = clean_nick(nick)
	if nickname.is_empty():
		status = "Введите ник"
		return false
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port,MAX_PLAYERS-1,3)
	if error != OK:
		begin_diagnostics("host",port)
		diagnostics.event("connection_error",{"code":error})
		diagnostics.close()
		peer = null
		status = "Не удалось открыть порт %d" % port
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	hosting = true
	roster = {1:nickname}
	status = "Ожидание игрока"
	begin_diagnostics("host",port)
	return true

func join(address: String, nick: String, port: int = PORT) -> bool:
	leave()
	nickname = clean_nick(nick)
	if nickname.is_empty():
		status = "Введите ник"
		return false
	if not address.strip_edges().is_valid_ip_address():
		status = "Введите IP ZeroTier"
		return false
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address.strip_edges(),port,3)
	if error != OK:
		begin_diagnostics("client",port)
		diagnostics.event("connection_error",{"code":error})
		diagnostics.close()
		peer = null
		status = "Не удалось подключиться"
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	hosting = false
	connect_started = now()
	status = "Подключение…"
	begin_diagnostics("client",port)
	return true

func leave(reason: String = "local_leave"):
	if diagnostics.enabled:
		diagnostics.sample(telemetry_snapshot())
		diagnostics.event("session_end",{"reason":reason,"epoch":epoch,"tick":server_tick if hosting else main_tick})
	diagnostics.close()
	active = false
	running = false
	loading = false
	var api = multiplayer
	var parent = get_parent()
	var detach = peer != null and is_inside_tree() and parent != null
	# Let SceneCacheInterface remove this RPC node through tree_exited before
	# replacing the peer. The 4.7.2 release template otherwise tries to detach
	# an unbound cache callback from its bound connection during clear().
	if detach: parent.remove_child(self)
	if peer: peer.close()
	peer = null
	api.multiplayer_peer = OfflineMultiplayerPeer.new()
	if detach: parent.add_child(self)
	roster.clear()
	input_streams.clear()
	awaiting_loaded.clear()
	epoch = 0
	input_epoch = 0
	pending.clear()
	entity_frames.clear()
	entity_render_cache.clear()
	player_frames.clear()
	assemblies.clear()
	command_times.clear()
	status = ""

func _peer_connected(id: int):
	diagnostics.event("transport_connected",{"id":id})
	# Clients have a direct ENet peer only for the host; other player IDs may
	# arrive through Godot's relay notifications without a direct connection.
	if peer and (hosting or id == 1):
		peer.get_peer(id).set_timeout(16,3000,7000)
		peer.get_peer(id).ping_interval(250)
		# Bound traffic at the application layer. RTT jitter on a VPN must not
		# probabilistically starve the already tiny input stream. ENet exchanges
		# this configuration, so both ends must use the same parameters.
		peer.get_peer(id).throttle_configure(1000,32,0)
	if hosting and (running or loading): peer.disconnect_peer(id)

func _connected():
	if active and not hosting:
		_log_peer_id = multiplayer.get_unique_id()
		configure_transport(1)
		_hello.rpc_id(1,fingerprint(),nickname)

func configure_transport(id: int):
	peer.get_peer(id).throttle_configure(1000,32,0)
	peer.get_peer(id).ping_interval(250)
	peer.get_peer(id).ping()

@rpc("any_peer","call_remote","reliable",0)
func _hello(version: String, nick: String):
	var id = multiplayer.get_remote_sender_id()
	if not active or not hosting or running or loading or roster.size() >= MAX_PLAYERS or id == 1 or roster.has(id): return
	if version != fingerprint():
		_rejected.rpc_id(id,"Разные версии игры")
		return
	var safe = clean_nick(nick)
	if safe.is_empty():
		_rejected.rpc_id(id,"Введите ник")
		return
	roster[id] = safe
	diagnostics.event("lobby_join",{"id":id,"nick":safe,"roster":roster.duplicate()})
	configure_transport(id)
	status = ""
	broadcast_lobby()

func remote_ids() -> Array:
	return roster.keys().filter(func(id): return id != 1 and multiplayer.get_peers().has(id) and (not (running or loading) or game.world.players.get(id,{}).get("connected",false)))

func broadcast_lobby():
	for id in remote_ids(): _lobby.rpc_id(id,roster)

@rpc("authority","call_remote","reliable",0)
func _lobby(value: Dictionary):
	if not active or hosting or running: return
	roster = value
	diagnostics.event("lobby",{"roster":roster.duplicate()})
	status = "Ожидание ведущего"

@rpc("authority","call_remote","reliable",0)
func _rejected(reason: String):
	leave("rejected: "+reason)
	status = reason.left(80)

func _failed():
	if not active: return
	leave("connection_failed")
	status = "Не удалось подключиться"

func _server_lost(reason: String = "transport_disconnected"):
	if not active or hosting: return
	leave(reason)
	status = "Соединение с ведущим потеряно"
	game.world = preload("res://scripts/world.gd").new()
	game.screen = "multiplayer"
	game.sync_network_fields()

func _disconnected(id: int):
	if not active or not hosting: return
	diagnostics.event("peer_disconnected",{"id":id,"epoch":epoch,"tick":server_tick})
	if roster.has(id):
		if running or loading:
			game.world.disconnect_actor(id)
			if loading:
				awaiting_loaded.erase(id)
				finish_loading.call_deferred()
		else:
			roster.erase(id)
			status = "Ожидание игрока" if roster.size() == 1 else ""
			broadcast_lobby.call_deferred()
	input_streams.erase(id)
	# Other departures can still be queued in this ENet poll. The next physics
	# tick broadcasts the new state after the entire disconnect batch is drained.

func start_run(seed_value: int = 0):
	if not active or not hosting or loading: return
	for id in roster.keys():
		if id != 1 and not multiplayer.get_peers().has(id): roster.erase(id)
	if roster.size() < 2:
		running = false
		peer.refuse_new_connections = false
		game.world = preload("res://scripts/world.gd").new()
		game.screen = "multiplayer"
		status = "Ожидание игрока"
		return
	if seed_value == 0:
		var random = RandomNumberGenerator.new()
		random.randomize()
		seed_value = random.randi_range(1,2147483646)
	epoch += 1
	running = false
	loading = true
	peer.refuse_new_connections = true
	# Freeze membership before loading. Every remaining client must acknowledge
	# this epoch, including the slowest of the three remote players.
	var names = roster.duplicate()
	install_world(epoch,seed_value,names)
	awaiting_loaded.clear()
	for id in remote_ids(): awaiting_loaded[id] = true
	for id in remote_ids(): _prepare.rpc_id(id,epoch,seed_value,names)
	for id in multiplayer.get_peers():
		if not roster.has(id): peer.disconnect_peer(id)

func install_world(run_epoch: int, seed_value: int, names: Dictionary):
	epoch = run_epoch
	roster = names
	input_epoch = 0
	server_tick = 0
	sequence = 0
	ack = 0
	input_streams.clear()
	pending.clear()
	entity_frames.clear()
	entity_render_cache.clear()
	player_frames.clear()
	assemblies.clear()
	main_tick = -1
	received_frames = 0
	received_buckets = 0
	corrections.clear()
	local_gait = 0
	bucket_payloads.clear()
	estimated_tick = 0
	render_tick = 0
	last_sound = 0
	control_signature = ""
	last_can_step = true
	roster = names
	game.world = World.new(seed_value)
	game.world.configure(seed_value,roster,multiplayer.get_unique_id())
	diagnostics.event("run_start",{"seed":seed_value,"epoch":epoch,"roster":roster.duplicate()})
	if hosting:
		for id in remote_ids(): input_streams[id] = new_input_stream()
	predicted = game.world.player
	authority_position = predicted
	predicted_facing = game.world.facing
	correction = Vector2.ZERO
	game.screen = ""
	game.sync_network_fields()
	game.selected = 0
	game.audio.set_finale_music(false)
	last_receive = now()
	game.world.state = "WAITING"

@rpc("authority","call_remote","reliable",0)
func _prepare(run_epoch: int, seed_value: int, names: Dictionary):
	if not active or hosting or run_epoch <= epoch: return
	loading = true
	running = false
	install_world(run_epoch,seed_value,names)
	_loaded.rpc_id(1,epoch)

@rpc("any_peer","call_remote","reliable",0)
func _loaded(run_epoch: int):
	var id = multiplayer.get_remote_sender_id()
	if not hosting or not loading or run_epoch != epoch or not awaiting_loaded.has(id): return
	awaiting_loaded.erase(id)
	diagnostics.event("peer_loaded",{"id":id,"epoch":epoch,"remaining":awaiting_loaded.keys()})
	configure_transport(id)
	finish_loading()

func finish_loading():
	if not loading or not awaiting_loaded.is_empty(): return
	loading = false
	running = true
	diagnostics.event("run_go",{"epoch":epoch,"tick":server_tick})
	game.world.refresh_state()
	for id in remote_ids(): _go.rpc_id(id,epoch)
	send_snapshot(true)

@rpc("authority","call_remote","reliable",0)
func _go(run_epoch: int):
	if not active or hosting or run_epoch != epoch: return
	loading = false
	running = true
	configure_transport(1)
	game.world.refresh_state()

func new_input_stream() -> Dictionary:
	return {"ack":0,"queue":{},"started":false,"gap_ticks":0,"last_rx":-1.0,"received":0}

func input_reset():
	input_epoch += 1
	diagnostics.event("input_reset",{"epoch":epoch,"input_epoch":input_epoch,"tick":server_tick})
	for id in input_streams: input_streams[id] = new_input_stream()

func consume_input(id: int) -> Vector2:
	var stream: Dictionary = input_streams[id]
	var queue: Dictionary = stream.queue
	if queue.is_empty(): return Vector2.ZERO
	if not stream.started:
		stream.gap_ticks += 1
		if queue.size() < 2 and stream.gap_ticks < 6: return Vector2.ZERO
		stream.started = true
		stream.gap_ticks = 0
	var keys = queue.keys()
	keys.sort()
	# Bound input latency instead of processing a stalled client's old movement.
	while keys.size() > 8:
		stream.ack = keys.pop_front()
		queue.erase(stream.ack)
	var next: int = keys[0]
	if next > stream.ack+1 and stream.gap_ticks < 2:
		stream.gap_ticks += 1
		return Vector2.ZERO
	stream.gap_ticks = 0
	stream.ack = next
	var movement: Vector2 = queue[next]
	queue.erase(next)
	return movement

@rpc("any_peer","call_remote","unreliable",1)
func _inputs(run_epoch: int, generation: int, commands: Array):
	input_packets += 1
	if not active or not hosting or not running or run_epoch != epoch or generation != input_epoch or not game.world.can_step(): return
	var id = multiplayer.get_remote_sender_id()
	if not input_streams.has(id) or not game.world.players[id].connected or commands.size() > 12: return
	var stream: Dictionary = input_streams[id]
	stream.last_rx = now()
	stream.received += 1
	diagnostics.count("input_packets")
	for command in commands:
		if not command is Array or command.size() != 2 or not command[0] is int or not command[1] is Vector2: continue
		var seq: int = command[0]
		var direction: Vector2 = command[1]
		if not direction.is_finite() or seq <= stream.ack or seq > stream.ack+180: continue
		if stream.queue.size() < 120: stream.queue[seq] = direction.limit_length()

func command(kind: String, value: int = 0):
	if not active or not running: return
	if hosting: apply_command(1,kind,value)
	else: _command.rpc_id(1,epoch,kind,value)

@rpc("any_peer","call_remote","reliable",0)
func _command(run_epoch: int, kind: String, value: int):
	var id = multiplayer.get_remote_sender_id()
	if not hosting or not running or run_epoch != epoch or id == 1 or not roster.has(id) or not game.world.players[id].connected: return
	if kind not in ["pause","choice","chest"]: return
	# A small burst permits quick L / Esc and queued upgrades without letting
	# repeated requests consume an unbounded amount of simulation work.
	var budget: Dictionary = command_times.get(id,{"at":now(),"tokens":8.0})
	budget.tokens = minf(8,budget.tokens+(now()-budget.at)*12)
	budget.at = now()
	command_times[id] = budget
	if budget.tokens < 1: return
	budget.tokens -= 1
	apply_command(id,kind,value)

func apply_command(id: int, kind: String, value: int):
	diagnostics.event("command",{"id":id,"kind":kind,"value":value,"epoch":epoch,"tick":server_tick})
	var before: bool = game.world.can_step()
	match kind:
		"pause": game.world.set_paused(id,value != 0)
		"choice": game.world.choose_for(id,value)
		"chest": game.world.chest_for(id)
	if before != game.world.can_step(): input_reset()
	last_can_step = game.world.can_step()
	send_snapshot(true)

func tick(dt: float, movement: Vector2):
	if not active: return
	if not running:
		if not hosting and now()-connect_started > 12 and not loading and roster.is_empty(): _failed()
		return
	if hosting:
		server_tick += 1
		var allowed: bool = game.world.can_step()
		if allowed != last_can_step: input_reset()
		last_can_step = allowed
		var inputs = {1:movement if game.screen.is_empty() else Vector2.ZERO}
		if allowed:
			for id in input_streams: inputs[id] = consume_input(id)
		var sim_begin = Time.get_ticks_usec()
		game.world.step_coop(dt,inputs)
		last_sim_ms = (Time.get_ticks_usec()-sim_begin)/1000.0
		diagnostics.measure("simulation_ms",last_sim_ms)
		if last_sim_ms > 12: diagnostics.limited_event("slow_simulation",{"ms":last_sim_ms,"tick":server_tick,"mobs":game.world.mobs.size()},250)
		if allowed != game.world.can_step():
			input_reset()
			last_can_step = game.world.can_step()
		var signature = critical_signature()
		var changed = signature != control_signature
		if changed: diagnostics.event("state_changed",{"epoch":epoch,"tick":server_tick,"run_state":game.world.run_state,"actors":actor_telemetry()})
		# Stagger the 32 independent entity streams across the three physics
		# frames. Each still updates at 20 Hz, without one compression burst.
		send_snapshot(changed,server_tick % 3 == 0 or changed)
	else:
		if main_tick < 0: return
		if game.world.can_step() and game.world.players[game.world.local_id].alive and now()-last_receive < .3 and game.screen.is_empty() and pending.size() < 24:
			sequence += 1
			movement = movement.limit_length()
			pending.append([sequence,movement])
			if pending.size() > 120: pending.pop_front()
			predict_move(movement)
		else: movement = Vector2.ZERO
		last_local_movement = movement
		if movement != Vector2.ZERO: local_gait += dt
		client_send_tick += 1
		if client_send_tick % 2 == 0:
			_inputs.rpc_id(1,epoch,input_epoch,pending.slice(maxi(0,pending.size()-10)))

func predict_move(movement: Vector2):
	var w = game.world
	if w.finale.active and w.finale.phase not in ["storm","inferno"]: return
	var a: Dictionary = w.players[w.local_id]
	predicted = w.move_actor(predicted,movement*w.db.data.player_speed*(1+.08*a.items.get("sugar",0))*STEP,6)
	if movement != Vector2.ZERO: predicted_facing = movement.normalized()

func critical_signature() -> String:
	var values = [game.world.run_state]
	game.world.save_actor()
	for a in game.world.players.values(): values.append([a.alive,a.phase,a.paused,a.hp,a.level,a.build,a.items,a.evolved])
	return str(values)

func send_snapshot(reliable: bool = false, include_frame: bool = true):
	if not active or not hosting or not running or not peer or multiplayer.get_peers().is_empty(): return
	var targets = remote_ids()
	if targets.is_empty(): return
	var snapshot_begin = Time.get_ticks_usec()
	if include_frame:
		control_signature = critical_signature()
		var frame = Codec.frame(game.world,server_tick,input_epoch,0)
		for target in targets:
			frame.ack = input_streams.get(target,{"ack":0}).ack
			var packed = Codec.encode(frame)
			bytes_sent += packed.size()
			if reliable: _control.rpc_id(target,epoch,packed)
			else:
				var count = ceili(float(packed.size())/Codec.CHUNK)
				for part in range(count):
					_frame.rpc_id(target,epoch,server_tick,part,count,packed.slice(part*Codec.CHUNK,(part+1)*Codec.CHUNK))
	var phase = server_tick % 3
	var groups = Codec.buckets(game.world,phase)
	for bucket in range(Codec.BUCKETS):
		if bucket % 3 != phase: continue
		var data = Codec.encode(groups[bucket])
		if bucket_payloads.get(bucket,PackedByteArray()) == data and (server_tick-phase) % 60 != 0: continue
		bucket_payloads[bucket] = data
		max_bucket_bytes = maxi(max_bucket_bytes,data.size())
		bytes_sent += data.size()*targets.size()
		var count = ceili(float(data.size())/Codec.CHUNK)
		for target in targets:
			for part in range(count):
				_entities.rpc_id(target,epoch,server_tick,bucket,part,count,data.slice(part*Codec.CHUNK,(part+1)*Codec.CHUNK))
	last_snapshot_ms = (Time.get_ticks_usec()-snapshot_begin)/1000.0
	diagnostics.measure("snapshot_encode_ms",last_snapshot_ms)

@rpc("authority","call_remote","reliable",0)
func _control(run_epoch: int, bytes: PackedByteArray):
	diagnostics.count("state_payload_rx_bytes",bytes.size())
	receive_frame(run_epoch,bytes)

@rpc("authority","call_remote","unreliable",2)
func _frame(run_epoch: int, tick_value: int, part: int, count: int, bytes: PackedByteArray):
	diagnostics.count("state_payload_rx_bytes",bytes.size())
	if not active or hosting or run_epoch != epoch or tick_value <= main_tick: return
	if count < 1 or count > 32 or part < 0 or part >= count or bytes.size() > Codec.CHUNK: return
	var packed = assemble("f:"+str(tick_value),part,count,bytes)
	if not packed.is_empty(): receive_frame(run_epoch,packed)

func assemble(key: String, part: int, count: int, bytes: PackedByteArray) -> PackedByteArray:
	if count == 1: return bytes
	for old_key in assemblies.keys():
		if now()-assemblies[old_key].at > .5:
			diagnostics.count("expired_partial_updates")
			assemblies.erase(old_key)
	if not assemblies.has(key):
		if assemblies.size() >= 128: return PackedByteArray()
		assemblies[key] = {"at":now(),"count":count,"parts":{}}
	var assembly: Dictionary = assemblies[key]
	if assembly.count != count: return PackedByteArray()
	assembly.parts[part] = bytes
	if assembly.parts.size() != count: return PackedByteArray()
	var result = PackedByteArray()
	for index in range(count): result.append_array(assembly.parts[index])
	assemblies.erase(key)
	return result

func receive_frame(run_epoch: int, bytes: PackedByteArray):
	if not active or hosting or run_epoch != epoch: return
	var frame = Codec.decode(bytes)
	if frame.is_empty() or frame.get("tick",-1) <= main_tick: return
	if main_tick >= 0:
		diagnostics.measure("snapshot_gap_ms",(now()-last_receive)*1000)
		diagnostics.count("skipped_periodic_state_updates",maxi(0,int((frame.tick-1)/3)-int(main_tick/3)))
	# A snapshot is sent only after the host's complete loading barrier. It can
	# overtake the reliable _go message on another channel, so start displaying
	# and accepting local input immediately instead of waiting for its retry.
	loading = false
	running = true
	var w = game.world
	var old_render = predicted+correction
	var old_finale: bool = w.finale.active
	main_tick = frame.tick
	received_frames += 1
	last_receive = now()
	if received_frames == 1 or absf(estimated_tick-main_tick) > 30: estimated_tick = main_tick
	else: estimated_tick += clampf(main_tick-estimated_tick,-2,2)*.1
	var generation_changed = input_epoch != frame.input_epoch
	input_epoch = frame.input_epoch
	if generation_changed:
		pending.clear()
		sequence = 0
	ack = frame.ack
	pending = pending.filter(func(c): return c[0] > ack)
	w.active_id = 0
	for id in frame.players:
		w.players[id].merge(frame.players[id],true)
	for field in ["time","clock","kills","score","run_state","victory","message","message_timer"]: w.set(field,frame[field])
	for field in frame.finale: w.finale.set(field,frame.finale[field])
	clock_anchor = frame.clock
	time_anchor = frame.time
	finale_anchor = frame.finale.duplicate(true)
	for prop in w.props:
		if frame.broken.has(prop.id): prop.hp = 0
	w.use_actor(w.local_id)
	w.refresh_state()
	predicted = w.player
	authority_position = w.player
	predicted_facing = w.facing
	if w.can_step() and w.players[w.local_id].alive:
		for command_value in pending: predict_move(command_value[1])
	else: pending.clear()
	var distance = old_render.distance_to(predicted)
	diagnostics.measure("visual_error_px",distance)
	if distance > 4:
		diagnostics.limited_event("position_correction",{"epoch":epoch,"tick":main_tick,"input_epoch":input_epoch,"sequence":sequence,"ack":ack,"pending":pending.size(),"px":distance,"scene_changed":old_finale != w.finale.active,"authority":[authority_position.x,authority_position.y],"replayed":[predicted.x,predicted.y],"old_render":[old_render.x,old_render.y],"state":w.state})
	if distance > 12 and correction_diagnostics.size() < 32:
		correction_diagnostics.append({"tick":main_tick,"generation":input_epoch,"changed":generation_changed,"seq":sequence,"ack":ack,"pending":pending.size(),"old":old_render,"predicted":predicted,"authority":w.player,"distance":distance})
	corrections.append(distance)
	if corrections.size() > 7200: corrections.pop_front()
	# Teleports belong only to authored scene transitions, never normal movement.
	correction = old_render-predicted if distance < 64 and old_finale == w.finale.active else Vector2.ZERO
	var rows = []
	for id in frame.players: rows.append(frame.players[id])
	player_frames.append({"tick":main_tick,"data":{"players":rows}})
	while player_frames.size() > 16: player_frames.pop_front()
	for event in frame.sounds:
		if event[0] > last_sound:
			w.sounds.append(event[1])
			last_sound = event[0]

@rpc("authority","call_remote","unreliable",2)
func _entities(run_epoch: int, tick_value: int, bucket: int, part: int, count: int, bytes: PackedByteArray):
	diagnostics.count("entity_payload_rx_bytes",bytes.size())
	if not active or hosting or run_epoch != epoch or bucket < 0 or bucket >= Codec.BUCKETS: return
	if count < 1 or count > 32 or part < 0 or part >= count or bytes.size() > Codec.CHUNK: return
	var frames: Array = entity_frames.get(bucket,[])
	if not frames.is_empty() and tick_value <= frames.back().tick: return
	var data = assemble(str(bucket)+":"+str(tick_value),part,count,bytes)
	if data.is_empty(): return
	var value = Codec.decode(data)
	if value.is_empty(): return
	frames.append({"tick":tick_value,"data":value})
	while frames.size() > 12: frames.pop_front()
	entity_frames[bucket] = frames
	received_buckets += 1

func present(dt: float):
	if not active or hosting or not running or main_tick < 0: return
	var present_begin = Time.get_ticks_usec()
	var w = game.world
	estimated_tick = minf(estimated_tick+dt*60,main_tick+9)
	render_tick = maxf(render_tick,estimated_tick-6)
	var correction_step = minf(correction.length()*(1-exp(-dt*18)),dt*120)
	correction = correction.move_toward(Vector2.ZERO,correction_step)
	var actors = Codec.sample(player_frames,render_tick,w.can_step())
	# Always display immediate authoritative death/inventory/pause changes.
	w.save_actor()
	for a in actors.get("players",[]):
		if a.id == w.local_id: continue
		for field in ["player","facing","player_visual","weapon_visuals"]: w.players[a.id][field] = a[field]
	w.players[w.local_id].player = predicted+correction
	w.players[w.local_id].facing = predicted_facing
	w.active_id = 0
	w.use_actor(w.local_id)
	if w.can_step() and w.players[w.local_id].alive and (not w.finale.active or w.finale.phase in ["storm","inferno"]):
		var moving = last_local_movement != Vector2.ZERO
		w.player_moving = moving
		if w.player_visual.state in ["walk","idle"]:
			w.player_visual.state = "walk" if moving else "idle"
			w.player_visual.time = local_gait
	for pool in Codec.POOLS: w.get(pool).clear()
	for bucket in entity_frames:
		if not entity_render_cache.has(bucket): entity_render_cache[bucket] = {}
		var sample_value = Codec.sample_cached(entity_frames[bucket],render_tick,w.can_step(),entity_render_cache[bucket])
		for pool in sample_value: w.get(pool).append_array(sample_value[pool])
	# Advance visual clocks only while the authoritative simulation is moving.
	var elapsed = clampf((estimated_tick-main_tick)/60,0,.1) if w.can_step() else 0.0
	w.clock = clock_anchor+elapsed
	w.time = minf(float(w.db.data.duration),time_anchor+elapsed) if not w.finale.active else time_anchor
	if w.finale.active:
		w.finale.elapsed = minf(w.finale.DURATION,finale_anchor.elapsed+elapsed)
		w.finale.strikes = finale_anchor.strikes.duplicate(true)
		w.finale.waves = finale_anchor.waves.duplicate(true)
		for strike in w.finale.strikes: strike.age += elapsed
		for wave in w.finale.waves:
			wave.age += elapsed
			wave.radius += wave.speed*elapsed
	diagnostics.measure("presentation_ms",(Time.get_ticks_usec()-present_begin)/1000.0)
	if now()-last_receive > 8: _server_lost("snapshot_timeout")

func network_waiting() -> bool:
	return active and not hosting and running and now()-last_receive > .75

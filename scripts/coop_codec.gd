extends RefCounted
## Bounded binary Variants, never objects. Each independent bucket normally fits
## one UDP datagram; loss of one bucket cannot block the other 31 streams.
const BUCKETS = 32
const CHUNK = 900
const MAX_DECODED = 262144
const POOLS = ["mobs","projectiles","orbs","loot","effects"]
const PLAYER_FIELDS = ["player","facing","hp","invulnerable","xp","level","build","items","evolved","cooldowns","choices","player_visual","attack_visuals","weapon_visuals","chest_reward","chest_delay","moved","player_moving","id","nick","slot","alive","connected","paused","phase","in_finale"]
const MOB_FIELDS = ["id","kind","p","dir","hp","max_hp","speed","radius","timer","fuse","flash","burn","phase","charge","animation","visual","moving","visual_dir"]
const KINDS = ["zombie","skeleton","creeper","spider","slime","small_slime","elite","ravager","vindicator"]
const PHASES = ["walk","windup","attack","recover","charge","rest"]
const POSES = ["idle","walk","windup","attack","recover","hurt"]
const MOB_STRIDE = 27

static func encode(value: Dictionary) -> PackedByteArray:
	var wire = value
	if value.has("mobs"):
		wire = value.duplicate()
		var packed = PackedFloat32Array()
		packed.resize(value.mobs.size()*MOB_STRIDE)
		for i in range(value.mobs.size()):
			var m: Dictionary = value.mobs[i]
			var v: Dictionary = m.visual
			var row = [m.id,KINDS.find(m.kind),m.p.x,m.p.y,m.dir.x,m.dir.y,m.hp,m.max_hp,m.speed,m.radius,m.timer,m.fuse,m.flash,m.burn,PHASES.find(m.phase),m.charge.x,m.charge.y,m.animation,1 if m.moving else 0,m.visual_dir.x,m.visual_dir.y,POSES.find(v.state),v.time,v.gait,v.hurt,v.shot_age,v.travel]
			for j in range(MOB_STRIDE): packed[i*MOB_STRIDE+j] = row[j]
		wire.mobs = packed
	var raw = var_to_bytes(wire)
	var result = PackedByteArray()
	result.resize(4)
	result.encode_u32(0,raw.size())
	result.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	return result

static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 5 or bytes.size() > 65536: return {}
	var decoded_size = bytes.decode_u32(0)
	if decoded_size < 1 or decoded_size > MAX_DECODED: return {}
	var unpacked = bytes.slice(4).decompress(decoded_size,FileAccess.COMPRESSION_ZSTD)
	if unpacked.is_empty(): return {}
	var value = bytes_to_var(unpacked)
	if not value is Dictionary: return {}
	if value.get("mobs") is PackedFloat32Array:
		var packed: PackedFloat32Array = value.mobs
		if packed.size() % MOB_STRIDE != 0: return {}
		var rows = []
		for start in range(0,packed.size(),MOB_STRIDE):
			var k = int(packed[start+1])
			var phase = int(packed[start+14])
			var pose = int(packed[start+21])
			if k < 0 or k >= KINDS.size() or phase < 0 or phase >= PHASES.size() or pose < 0 or pose >= POSES.size(): return {}
			rows.append({"id":int(packed[start]),"kind":KINDS[k],"p":Vector2(packed[start+2],packed[start+3]),"dir":Vector2(packed[start+4],packed[start+5]),"hp":packed[start+6],"max_hp":packed[start+7],"speed":packed[start+8],"radius":packed[start+9],"timer":packed[start+10],"fuse":packed[start+11],"flash":packed[start+12],"burn":packed[start+13],"phase":PHASES[phase],"charge":Vector2(packed[start+15],packed[start+16]),"animation":packed[start+17],"moving":bool(packed[start+18]),"visual_dir":Vector2(packed[start+19],packed[start+20]),"visual":{"state":POSES[pose],"time":packed[start+22],"gait":packed[start+23],"hurt":packed[start+24],"shot_age":packed[start+25],"travel":packed[start+26]}})
		value.mobs = rows
	return value

static func frame(w, tick: int, input_epoch: int, ack: int) -> Dictionary:
	w.save_actor()
	var actors = {}
	for id in w.players:
		var a = {}
		for field in PLAYER_FIELDS: a[field] = w.players[id][field]
		actors[id] = a
	var f = w.finale
	var broken = []
	for p in w.props:
		if p.type == "pumpkin" and p.hp <= 0: broken.append(p.id)
	return {"tick":tick,"input_epoch":input_epoch,"ack":ack,"players":actors,"time":w.time,"clock":w.clock,"kills":w.kills,"score":w.score,"run_state":w.run_state,"victory":false,"message":w.message,"message_timer":w.message_timer,"broken":broken,"sounds":w.network_sounds.duplicate(),"finale":{"active":f.active,"complete":f.complete,"elapsed":f.elapsed,"phase":f.phase,"strikes":f.strikes,"waves":f.waves,"start_camera":f.start_camera}}

static func buckets(w, phase: int = -1, phases: int = 3) -> Array:
	var result = []
	for i in range(BUCKETS):
		var bucket = {}
		if phase < 0 or i % phases == phase:
			for pool in POOLS: bucket[pool] = []
		result.append(bucket)
	for pool in POOLS:
		for entity in w.get(pool):
			if not entity.has("id"): entity.id = w.next_id()
			var index = int(entity.id) % BUCKETS
			if phase >= 0 and index % phases != phase: continue
			var row = {}
			if pool == "mobs":
				for field in MOB_FIELDS: row[field] = entity[field]
			else:
				row = entity.duplicate()
				row.erase("hit")
			result[index][pool].append(row)
	return result

static func blend(a: Dictionary, b: Dictionary, fraction: float) -> Dictionary:
	var result = a.duplicate()
	if a.has("p") and b.has("p"): result.p = a.p.lerp(b.p,fraction)
	if a.has("player") and b.has("player"): result.player = a.player.lerp(b.player,fraction)
	for field in ["age","animation"]:
		if a.has(field) and b.has(field): result[field] = lerpf(a[field],b[field],fraction)
	for field in ["visual","player_visual"]:
		if a.has(field) and b.has(field) and a[field].state == b[field].state:
			result[field] = a[field].duplicate()
			result[field].time = lerpf(a[field].time,b[field].time,fraction)
	return result

static func sample(frames: Array, target: float, extrapolate: bool) -> Dictionary:
	if frames.is_empty(): return {}
	var a: Dictionary = frames[0]
	var b: Dictionary = a
	for frame_value in frames:
		if frame_value.tick <= target: a = frame_value
		b = frame_value
		if frame_value.tick >= target: break
	var data: Dictionary = a.data
	if b.tick > a.tick:
		var fraction = clampf((target-a.tick)/float(b.tick-a.tick),0,1)
		var result = {}
		for pool in data:
			var next = {}
			for row in b.data[pool]: next[row.id] = row
			result[pool] = []
			for row in data[pool]: result[pool].append(blend(row,next.get(row.id,row),fraction))
		return result
	if extrapolate and frames.size() >= 2 and target > a.tick:
		var previous: Dictionary = frames[frames.size()-2]
		var elapsed = clampf(target-a.tick,0,6)/maxf(1,a.tick-previous.tick)
		var result = {}
		for pool in data:
			var old = {}
			for row in previous.data[pool]: old[row.id] = row
			result[pool] = []
			for row in data[pool]:
				var copy = row.duplicate()
				if old.has(row.id):
					var key = "p" if row.has("p") else "player"
					copy[key] += (row[key]-old[row.id][key])*elapsed
				result[pool].append(copy)
		return result
	return data

static func sample_cached(frames: Array, target: float, extrapolate: bool, cache: Dictionary) -> Dictionary:
	# Rendering reuses entity dictionaries. Rebuilding hundreds of nested
	# Variants every display frame creates avoidable CPU/allocator spikes.
	if frames.is_empty(): return {}
	var a: Dictionary = frames[0]
	var b: Dictionary = a
	for frame_value in frames:
		if frame_value.tick <= target: a = frame_value
		b = frame_value
		if frame_value.tick >= target: break
	var extending = b.tick == a.tick and extrapolate and frames.size() >= 2 and target > a.tick
	if extending: b = frames[frames.size()-2]
	var key = [a.tick,b.tick,extending]
	if cache.get("key",[]) != key:
		var entities: Dictionary = cache.get("entities",{})
		var retained = {}
		var result = {}
		var pairs = []
		for pool in a.data:
			var next = {}
			for row in b.data[pool]: next[row.id] = row
			result[pool] = []
			for row in a.data[pool]:
				var entity: Dictionary = entities.get(row.id,{})
				entity.merge(row,true)
				if row.has("visual"): entity.visual = row.visual.duplicate()
				retained[row.id] = entity
				result[pool].append(entity)
				pairs.append([entity,row,next.get(row.id,row)])
		cache.merge({"key":key,"entities":retained,"result":result,"pairs":pairs},true)
	var fraction = clampf((target-a.tick)/float(b.tick-a.tick),0,1) if b.tick > a.tick else 0.0
	var extension = clampf(target-a.tick,0,6)/maxf(1,a.tick-b.tick) if extending else 0.0
	for pair in cache.pairs:
		var entity: Dictionary = pair[0]
		var first: Dictionary = pair[1]
		var last: Dictionary = pair[2]
		entity.p = first.p+(first.p-last.p)*extension if extending else first.p.lerp(last.p,fraction)
		for field in ["age","animation"]:
			if first.has(field) and last.has(field): entity[field] = lerpf(first[field],last[field],fraction)
		if first.has("visual") and first.visual.state == last.visual.state:
			entity.visual.time = lerpf(first.visual.time,last.visual.time,fraction)
			entity.visual.gait = lerpf(first.visual.gait,last.visual.gait,fraction)
	return cache.result

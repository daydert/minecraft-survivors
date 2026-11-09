extends RefCounted
## Local JSONL only. No uploads. The writer owns its FileAccess on a separate
## thread; gameplay only queues bounded strings and samples small counters.
const PREFIX = "survivors_coop_"
const MAX_QUEUED = 256
const MAX_SAMPLES = 600
var directory = "user://logs"
var max_file_bytes = 4*1024*1024
var max_history_files = 12
var enabled = false
var file_prefix = ""
var _started_ms = 0
var _sampled_ms = 0
var _thread: Thread
var _mutex = Mutex.new()
var _wake = Semaphore.new()
var _pending: Array[String] = []
var _stopping = false
var _dropped = 0
var _write_error = ""
var _metrics: Dictionary = {}
var _counters: Dictionary = {}
var _last_events: Dictionary = {}

func start(metadata: Dictionary):
	close()
	_started_ms = Time.get_ticks_msec()
	_sampled_ms = _started_ms
	_metrics.clear()
	_counters.clear()
	_last_events.clear()
	_pending.clear()
	_stopping = false
	_wake = Semaphore.new()
	_dropped = 0
	_write_error = ""
	var folder = ProjectSettings.globalize_path(directory)
	var error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		_write_error = "mkdir: "+str(error)
		return
	var stamp = Time.get_datetime_string_from_system(true).replace(":","-").replace("T","_")
	file_prefix = folder.path_join(PREFIX+stamp+"_"+str(metadata.get("role","peer"))+"_p"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec()))
	var header = metadata.duplicate(true)
	header.merge({"schema":1,"pid":OS.get_process_id(),"session":file_prefix.get_file()},true)
	_thread = Thread.new()
	enabled = true
	var started = _thread.start(_writer.bind(file_prefix,header,_started_ms,max_file_bytes,max_history_files))
	if started != OK:
		_write_error = "thread: "+str(started)
		enabled = false
		_thread = null
		return
	event("session_open",metadata)

func event(kind: String, fields: Dictionary = {}):
	if not enabled: return
	var row = fields.duplicate()
	row.merge({"event":kind,"t_ms":Time.get_ticks_msec()-_started_ms,"wall_ms":int(Time.get_unix_time_from_system()*1000)},true)
	var line = JSON.stringify(row)+"\n"
	if line.length() > 8192:
		line = JSON.stringify({"event":"oversized_event","kind":kind,"t_ms":row.t_ms})+"\n"
	_mutex.lock()
	var notify = _pending.is_empty()
	if _pending.size() < MAX_QUEUED: _pending.append(line)
	else: _dropped += 1
	_mutex.unlock()
	if notify: _wake.post()

func limited_event(kind: String, fields: Dictionary, gap_ms: int = 100):
	if not enabled: return
	var at = Time.get_ticks_msec()
	if at-_last_events.get(kind,-100000) < gap_ms: return
	_last_events[kind] = at
	event(kind,fields)

func measure(name: String, value: float):
	if not enabled or not is_finite(value): return
	if not _metrics.has(name): _metrics[name] = []
	var samples: Array = _metrics[name]
	if samples.size() < MAX_SAMPLES: samples.append(value)

func count(name: String, amount: int = 1):
	if enabled: _counters[name] = _counters.get(name,0)+amount

func sample_due() -> bool:
	return enabled and Time.get_ticks_msec()-_sampled_ms >= 1000

func sample(fields: Dictionary):
	if not enabled: return
	var summary = {}
	for name in _metrics:
		var values: Array = _metrics[name]
		values.sort()
		var total = 0.0
		for value in values: total += value
		summary[name] = {"n":values.size(),"mean":total/maxi(1,values.size()),"p95":values[maxi(0,ceili(values.size()*.95)-1)],"max":values.back()}
	var row = fields.duplicate()
	row.merge({"window_ms":Time.get_ticks_msec()-_sampled_ms,"metrics":summary,"counters":_counters.duplicate(),"writer":writer_status()},true)
	event("sample",row)
	_sampled_ms = Time.get_ticks_msec()
	_metrics.clear()
	_counters.clear()

func writer_status() -> Dictionary:
	_mutex.lock()
	var result = {"queued":_pending.size(),"dropped":_dropped,"error":_write_error}
	_mutex.unlock()
	return result

func close():
	enabled = false
	if _thread == null: return
	_mutex.lock()
	_stopping = true
	_mutex.unlock()
	_wake.post()
	_thread.wait_to_finish()
	_thread = null

func _set_error(value: String):
	_mutex.lock()
	_write_error = value
	_mutex.unlock()

func _finish_file(file: FileAccess, path: String):
	file.flush()
	file.close()
	DirAccess.rename_absolute(path,path.trim_suffix(".active.jsonl")+".jsonl")

func _prune(folder: String, keep: int):
	var old: Array = []
	for name in DirAccess.get_files_at(folder):
		if not name.begins_with(PREFIX) or not name.ends_with(".jsonl"): continue
		var path = folder.path_join(name)
		if name.ends_with(".active.jsonl"):
			# Other game instances can share user://. Never unlink their live
			# writer; only consider abandoned active files after a full day.
			if Time.get_unix_time_from_system()-FileAccess.get_modified_time(path) < 86400: continue
		old.append({"path":path,"mtime":FileAccess.get_modified_time(path)})
	old.sort_custom(func(a,b): return a.mtime < b.mtime if a.mtime != b.mtime else a.path < b.path)
	while old.size() > keep: DirAccess.remove_absolute(old.pop_front().path)

func _writer(prefix: String, metadata: Dictionary, started: int, limit: int, keep: int):
	var part = 0
	var path = prefix+"_%03d.active.jsonl" % part
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		_set_error("open: "+str(FileAccess.get_open_error()))
		return
	var header = metadata.duplicate()
	header.merge({"event":"log_part","part":part,"t_ms":0},true)
	file.store_line(JSON.stringify(header))
	_prune(prefix.get_base_dir(),keep)
	while true:
		_wake.wait()
		_mutex.lock()
		var batch = _pending
		_pending = []
		var stopping = _stopping
		_mutex.unlock()
		for line in batch:
			var bytes = line.to_utf8_buffer().size()
			if file.get_position()+bytes > limit:
				_finish_file(file,path)
				part += 1
				path = prefix+"_%03d.active.jsonl" % part
				file = FileAccess.open(path,FileAccess.WRITE)
				if file == null:
					_set_error("rotate: "+str(FileAccess.get_open_error()))
					return
				header.merge({"part":part,"t_ms":Time.get_ticks_msec()-started},true)
				file.store_line(JSON.stringify(header))
				_prune(prefix.get_base_dir(),keep)
			if file.get_position()+bytes <= limit: file.store_string(line)
			else: _set_error("event exceeds file limit")
		file.flush()
		if file.get_error() != OK: _set_error("write: "+str(file.get_error()))
		if stopping: break
	_finish_file(file,path)
	_prune(prefix.get_base_dir(),keep)

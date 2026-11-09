extends RefCounted
## Local profile; independent of run saves, settings and the cooperative protocol.
const CATALOG_PATH="res://data/achievements.json"
var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
var unlocked={}
var pending: Array[String]=[]
var path="user://achievements.json"
var recovered=false

func known(id: String) -> bool:
	return catalog.any(func(entry):return entry.id==id)

func entry(id: String) -> Dictionary:
	for item in catalog:
		if item.id==id:return item
	return {}

func load_profile(save_path: String="user://achievements.json"):
	path=save_path;unlocked.clear();pending.clear();recovered=false
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate):continue
		var parser=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate))!=OK:continue
		var parsed=parser.data
		if not parsed is Dictionary or parsed.get("version",0)!=1 or not parsed.get("unlocked") is Dictionary:continue
		for id in parsed.unlocked:
			if known(id) and parsed.unlocked[id] is String:unlocked[id]=parsed.unlocked[id]
		recovered=candidate!=path
		return

func save_profile() -> bool:
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify({"version":1,"unlocked":unlocked},"  ")+"\n");file.flush();file.close()
	var target=ProjectSettings.globalize_path(path)
	# Never replace a known-good backup with a corrupt primary after recovery.
	if FileAccess.file_exists(path) and not recovered:
		DirAccess.copy_absolute(target,target+".bak")
	var result=DirAccess.rename_absolute(target+".tmp",target)
	if result==OK:
		recovered=false
		DirAccess.copy_absolute(target,target+".bak")
	return result==OK

func unlock(id: String) -> bool:
	if not known(id) or unlocked.has(id):return false
	unlocked[id]=Time.get_datetime_string_from_system(true)
	if not save_profile():push_warning("Не удалось сохранить достижения: "+path)
	pending.append(id)
	return true

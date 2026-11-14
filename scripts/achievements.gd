extends RefCounted
## Local profile; independent of run saves, settings and the cooperative protocol.
const CATALOG_PATH="res://data/achievements.json"
var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
var unlocked={}
var pending: Array[String]=[]
var path="user://achievements.json"
var recovered=false
var tester_access=false
const CHAPTER_COMPLETIONS=["chapter_one","chapter_two","chapter_three","chapter_four","chapter_five"]

func available_chapters() -> int:
	if tester_access:return CHAPTER_COMPLETIONS.size()
	var highest=1
	# Older versions allowed selecting later chapters directly. Keep earned
	# progress from those profiles, including access to preceding chapters.
	for i in range(CHAPTER_COMPLETIONS.size()):
		if unlocked.has(CHAPTER_COMPLETIONS[i]):highest=maxi(highest,mini(5,i+2))
	return highest

func chapter_available(chapter: int) -> bool:
	return chapter>=1 and chapter<=available_chapters()

func enable_tester_access():
	if tester_access:return
	tester_access=true
	if not save_profile():push_warning("Не удалось сохранить доступ к главам: "+path)

func known(id: String) -> bool:
	return catalog.any(func(entry):return entry.id==id)

func entry(id: String) -> Dictionary:
	for item in catalog:
		if item.id==id:return item
	return {}

func is_secret(item: Dictionary) -> bool:
	return item.get("secret",false) or item.get("tier","")=="secret"

func display_entry(id: String) -> Dictionary:
	var item=entry(id).duplicate()
	if item.is_empty():return item
	item["hidden"]=is_secret(item) and not unlocked.has(id)
	if item.hidden:
		item.name="???";item.description="Секретное достижение";item.icon="unknown"
	return item

func load_profile(save_path: String="user://achievements.json"):
	path=save_path;unlocked.clear();pending.clear();recovered=false;tester_access=false
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate):continue
		var parser=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate))!=OK:continue
		var parsed=parser.data
		if not parsed is Dictionary or parsed.get("version",0)!=1 or not parsed.get("unlocked") is Dictionary:continue
		if parsed.get("tester_access",false) is bool:tester_access=parsed.get("tester_access",false)
		for id in parsed.unlocked:
			if known(id) and parsed.unlocked[id] is String:unlocked[id]=parsed.unlocked[id]
		recovered=candidate!=path
		return

func save_profile() -> bool:
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify({"version":1,"unlocked":unlocked,"tester_access":tester_access},"  ")+"\n");file.flush();file.close()
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

extends SceneTree
const Store=preload("res://scripts/achievements.gd")
var game
var checks:=0
var failures: Array=[]
var path: String
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func key(code: int,logical: int=0,echo: bool=false):
 var event=InputEventKey.new();event.pressed=true;event.echo=echo;event.physical_keycode=code;event.keycode=logical if logical else code
 game.input_lock=1.0;game._input(event)
func word_tester():
 for code in [KEY_T,KEY_E,KEY_S,KEY_T,KEY_E,KEY_R]:key(code,KEY_J)
func shot(name: String):
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://qa/chapter_access/"+name+".png")
func clear_files():
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
func run():
 path="user://qa_chapter_access_%d.json"%OS.get_process_id();clear_files()
 var store=Store.new();store.load_profile(path)
 check(store.available_chapters()==1 and store.chapter_available(1),"A fresh profile starts with chapter I")
 check(not store.chapter_available(0) and not store.chapter_available(2) and not store.chapter_available(6),"Other chapters and invalid chapter numbers are locked")
 store.unlock("first_evolution");store.unlock("herobrine")
 check(store.available_chapters()==1,"Challenges and the optional boss victory do not unlock chapters")
 for i in range(4):
  store.unlock(store.CHAPTER_COMPLETIONS[i])
  check(store.available_chapters()==i+2 and store.chapter_available(i+2),"Completing chapter %d unlocks exactly the next chapter"%(i+1))
 var loaded=Store.new();loaded.load_profile(path)
 check(loaded.available_chapters()==5 and not loaded.tester_access,"Normal progression survives reloading")
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"version":1,"unlocked":{"chapter_three":"old"}}));loaded.load_profile(path)
 check(loaded.available_chapters()==4 and not loaded.tester_access,"Old profiles keep earned access, including preceding chapters")
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"version":1,"unlocked":{},"tester_access":"true"}));loaded.load_profile(path)
 check(loaded.available_chapters()==1,"Only a boolean tester flag is accepted")
 clear_files();store.load_profile(path)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.set_process_input(true);game.achievements=store;game.qa_mode="chapter_access_review";root.size=Vector2i(640,360)
 game.action("chapters");await shot("locked")
 check(game.buttons.any(func(b):return b.id=="chapter_1") and not game.buttons.any(func(b):return b.id in ["chapter_2","chapter_3","chapter_4","chapter_5"]),"Locked rows contain no clickable or keyboard-selectable chapter buttons")
 var initial_world=game.world;game.action("chapter_4")
 check(game.world==initial_world and game.screen=="chapters","A direct normal UI action cannot start a locked chapter")
 store.unlock("chapter_one");store.pending.clear();await shot("chapter_two")
 check(game.buttons.any(func(b):return b.id=="chapter_2") and not game.buttons.any(func(b):return b.id=="chapter_3"),"The actual chapter list updates after progression")
 store.unlocked.clear();store.save_profile()
 for code in [KEY_T,KEY_E,KEY_S,KEY_X,KEY_T,KEY_E,KEY_R]:key(code)
 key(KEY_ENTER)
 check(not store.tester_access,"A mistyped tester sequence does not unlock anything")
 game.secret_keys="";word_tester()
 check(not store.tester_access,"The full word still requires Enter")
 game.secret_key_time=Time.get_ticks_msec()-3001;key(KEY_ENTER)
 check(not store.tester_access,"An expired sequence is rejected")
 game.screen="multiplayer";game.secret_keys="";word_tester();key(KEY_ENTER)
 check(not store.tester_access,"Multiplayer text entry cannot activate tester access")
 game.screen="inventory";game.world.state="PAUSED";game.secret_keys="";word_tester();key(KEY_ENTER)
 check(not store.tester_access,"The sequence does not activate during gameplay overlays")
 game.screen="chapters";game.world.state="MENU";game.coop.active=true;game.secret_keys="";word_tester();key(KEY_ENTER);game.coop.active=false
 check(not store.tester_access,"An active cooperative session cannot activate tester access")
 game.screen="chapters";game.secret_keys=""
 for code in [KEY_D,KEY_A,KEY_V,KEY_I,KEY_S,KEY_ENTER]:key(code)
 check(game.screen=="boss_lab","The existing DAVIS boss laboratory code still works")
 game.close_boss_lab();game.action("menu");game.secret_keys=""
 var clock: float=game.world.clock;var rng=game.world.rng.state
 key(KEY_T,KEY_J,true)
 check(game.secret_keys.is_empty(),"Auto-repeat does not advance the sequence")
 word_tester();key(KEY_KP_ENTER,KEY_KP_ENTER)
 check(store.tester_access and store.available_chapters()==5,"Physical TESTER keys plus keypad Enter unlock every chapter regardless of layout")
 check(game.screen=="chapters" and game.world.state=="MENU","Successful input opens chapter selection and consumes Enter")
 check(game.world.clock==clock and game.world.rng.state==rng,"Tester entry never advances simulation or combat RNG")
 check(store.unlocked.is_empty() and store.pending.is_empty(),"Tester access grants no fake achievements or completion records")
 await shot("tester")
 check(["chapter_1","chapter_2","chapter_3","chapter_4","chapter_5"].all(func(id):return game.buttons.any(func(b):return b.id==id)),"All five chapter buttons are visible after tester entry")
 loaded.load_profile(path)
 check(loaded.tester_access and loaded.available_chapters()==5,"Tester access persists across restarts")
 FileAccess.open(path,FileAccess.WRITE).store_string("{broken");loaded.load_profile(path)
 check(loaded.recovered and loaded.tester_access,"Backup recovery preserves tester access")
 clear_files()
 FileAccess.open("res://qa/chapter_access/results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("CHAPTER_ACCESS_RESULT %d checks; %d failures"%[checks,failures.size()])
 game.audio.shutdown();game.coop.diagnostics.close();game.quitting=true;quit(0 if failures.is_empty() else 1)

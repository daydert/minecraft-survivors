extends SceneTree
## Real Godot render. Portal montage selects checkpoints; erasure → wire →
## chair → door → logos → 2Fort → credits then advance at the original 60 Hz.
## The brawl is shortened with a one-HP opponent; this is a cinematic preview.
var game
var frames := 0
var cues: Array=[]
var music: Array=[]
var segments: Array=[]
var folder := "res://qa/recordings/chapter_five_cinematic_polish_frames"
func _initialize():run.call_deferred()
func mark(name: String):
 segments.append({"name":name,"time":frames/30.0});print("CINEMA_SEGMENT ",name," ",frames/30.0)
func shoot(w):
 var track: String=game.ch5_music()
 if music.is_empty() or music[-1].track!=track:music.append({"track":track,"time":frames/30.0})
 game.ui_time+=1.0/30;game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(folder+"/%05d.png"%frames);frames+=1
 if frames%600==0:print("CINEMA_CAPTURE ",frames)
func tick(w,move:=Vector2.ZERO):
 for k in range(2):
  w.step(1.0/60,move)
  for id in w.sounds:cues.append({"id":id,"time":frames/30.0+k/60.0})
  w.sounds.clear()
 await shoot(w)
func idle(w,seconds: float,move:=Vector2.ZERO):
 for k in range(roundi(seconds*30)):await tick(w,move)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film";root.size=Vector2i(640,360);game.settings.shake=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 game.action("chapter_5");var w=game.world;var n=w.notch;var f=n.finale;n.begin(w)
 for phase in ["to_ut","to_lanes","lanes_won","to_quake","to_code"]:
  n.change(phase);mark(phase);await idle(w,4.4)
 f.begin_erase();n.change("erase");mark("erase")
 await idle(w,4.0)
 for k in range(14):
  n.press(w,"accept");await idle(w,.25)
 while n.phase=="erase":await tick(w)
 mark("brawl_shortened");var fi=n.fighter;fi.ai=false
 await idle(w,2.4)
 var s=fi.steve();var nt=fi.notch();s.x=-1;nt.x=.1;s.face=1;nt.face=-1;nt.hp=1;nt.move="";nt.down=0;nt.block=false;nt.stun=0
 n.press(w,"accept")
 var guard := 0
 while fi.state=="fight" and guard<90:await tick(w);guard+=1
 assert(fi.state=="finisher","Preview hit did not reach the finisher")
 await idle(w,.8);n.press(w,"accept");mark("wire")
 while n.phase=="fists":await tick(w)
 mark("chair_full")
 while n.phase=="chair":await tick(w)
 mark("door_logos_2fort_full")
 while n.phase=="flight":await tick(w)
 mark("credits_full")
 while n.phase=="credits":await tick(w)
 var timeline={"fps":30,"frames":frames,"sound_events":cues,"music":music,"music_volume":.45,"effects_volume":.65,"diagnostic_montage":true,"segments":segments,"note":"Selected portal checkpoints and shortened brawl; original continuous chair/flight/credits timings."}
 FileAccess.open("res://qa/recordings/chapter_five_cinematic_polish_timeline.json",FileAccess.WRITE).store_string(JSON.stringify(timeline,"  "))
 if game.has_meta("ch5_view3d"):game.get_meta("ch5_view3d").release()
 await process_frame;game.audio.shutdown();game.quitting=true
 print("CINEMA_CAPTURE_COMPLETE ",frames," frames");quit()

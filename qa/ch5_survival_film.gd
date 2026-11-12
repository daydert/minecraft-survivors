extends SceneTree
## Continuous 12 minutes at 4× speed: 16 real 60 Hz steps per 15 FPS frame.
## HP held to inspect the whole chapter; real level-up choices, no time jumps.
var game
var bot=SurvivorBot.new("sword")
func _initialize():run.call_deferred()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film";root.size=Vector2i(640,360)
 game.action("chapter_5");var w=game.world;var frames:=0
 var folder: String="res://qa/recordings/ch5_survival_full_frames"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 while w.time<720 and w.stage!="notch":
  for k in range(16):
   if w.state=="LEVEL_UP":w.choose(bot.choose(w))
   elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
   w.hp=maxf(15,w.hp);w.step(1.0/60,bot.movement(w));w.sounds.clear()
  game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(folder+"/%05d.png"%frames);frames+=1
  if frames%600==0:print("SURVIVAL_FILM ",frames," simulation ",w.time)
 FileAccess.open("res://qa/recordings/ch5_survival_full_timeline.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":15,"frames":frames,"simulation_seconds":w.time,"speed":4,"diagnostic_hp":true}))
 game.audio.shutdown();game.quitting=true;print("SURVIVAL_COMPLETE ",frames);quit()

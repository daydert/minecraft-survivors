extends SceneTree
## Continuous 0–12 minute simulation, accelerated diagnostic observation.
## Player HP is held for inspecting late visuals; upgrades use real choices.
var game
var bot=SurvivorBot.new("sword")
func _initialize():run.call_deferred()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="film";root.size=Vector2i(640,360)
 game.action("chapter_5");var w=game.world;var next_shot := 0.0;var index := 0
 var folder: String="res://qa/ch5_survival_"+("after" if OS.get_cmdline_user_args().has("--after") else "before")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var max_loot := 0;var samples: Array=[]
 while w.time<720 and w.stage!="notch":
  for i in range(60):
   if w.state=="LEVEL_UP":w.choose(bot.choose(w))
   elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
   w.hp=maxf(15,w.hp);w.step(1.0/60,bot.movement(w));w.sounds.clear()
  max_loot=maxi(max_loot,w.loot.size())
  if w.time>=next_shot:
   game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
   root.get_texture().get_image().save_png(folder+"/%03d.png"%index)
   samples.append({"time":w.time,"loot":w.loot.size(),"mobs":w.mobs.size(),"build":w.build.duplicate(),"items":w.items.duplicate()});index+=1;next_shot+=10
 print("SURVIVAL_AUDIT ",w.time," frames ",index," max_loot ",max_loot)
 FileAccess.open(folder+"/audit.json",FileAccess.WRITE).store_string(JSON.stringify({"diagnostic_hp":true,"samples":samples,"max_loot":max_loot},"  "))
 game.audio.shutdown();game.quitting=true;quit()

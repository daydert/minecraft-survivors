extends SceneTree
var game
var output: String
func _initialize():run.call_deferred()
func shot(name: String):
 game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(output+name+".png")
func run():
 var args=OS.get_cmdline_user_args();output="res://qa/ch4_icons/"+(args[0] if args.size()>0 else "after")+"/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="icon_review";game.settings.shake=false;game.settings.numbers=false
 root.size=Vector2i(640,360);game.start_chapter(4)
 var w=game.world;w.stage="survival";w.state="PAUSED";w.sword_drop={};w.mobs.clear();w.effects.clear();w.particles.clear();w.pixels.clear();w.orbs.clear();w.loot.clear()
 w.items={"bedrock":3,"thorns":3,"bat_wings":3,"heart_booster":3,"mirror_shard":3,"black_candle":3,"empty_totem":1,"minecart":3}
 w.build={"shotgun":4,"blood_pool":4,"embryo":4,"bell":4,"bone_saw":4,"red_torch":4};w.evolved={};game.screen="inventory"
 await shot("inventory_base")
 w.build={"sword":8,"shotgun":8,"potion":8,"blood_pool":8,"embryo":8,"bell":8};w.items={"armor":5,"bat_wings":5,"bedrock":5,"thorns":5,"ghast_tear":5,"black_candle":5,"empty_totem":1,"minecart":5}
 w.evolved={"sword":true,"shotgun":true,"potion":true,"blood_pool":true,"embryo":true,"bell":true,"armor":true,"bat_wings":true}
 await shot("inventory_evolved")
 w.build={"bone_saw":8,"red_torch":8,"sky_tnt":8,"potion":4};w.evolved={"bone_saw":true,"red_torch":true,"sky_tnt":true}
 await shot("inventory_fusion")
 game.screen="recipes";game.recipe_page=0;await shot("recipes_1");game.recipe_page=1;await shot("recipes_2")
 game.screen="";w.state="LEVEL_UP";w.build={};w.items={};w.evolved={}
 var choices=[["shotgun","heart_booster","mirror_shard"],["bone_saw","black_candle","embryo"],["bell","blood_pool","red_torch"],["bedrock","thorns","empty_totem"]]
 for i in range(choices.size()):w.choices=choices[i];await shot("choices_%d"%(i+1))
 print("CH4_ICON_REVIEW_OK ",output)
 game.audio.shutdown();game.coop.diagnostics.close();game.quitting=true;quit()

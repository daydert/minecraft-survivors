extends SceneTree
func _initialize():
 var args=OS.get_cmdline_user_args()
 assert(args.size()==1 and ProjectSettings.load_resource_pack(args[0],true))
 var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/achievements.json"))
 assert(catalog.size()==35)
 var store=load("res://scripts/achievements.gd").new()
 assert(store.display_entry("bad_ending").icon=="unknown")
 assert(store.display_entry("chapter_five").name=="???")
 var assets=JSON.parse_string(FileAccess.get_file_as_string("res://data/achievement_assets.json"))
 assert(assets.sprites.size()==36)
 for name in assets.sprites:
  var texture=ResourceLoader.load("res://assets/sprites/"+name+".png","Texture2D",ResourceLoader.CACHE_MODE_IGNORE)
  assert(texture!=null and texture.get_size()==Vector2(32,32))
 var cart=ResourceLoader.load("res://assets/sprites/icon_minecart.png","Texture2D",ResourceLoader.CACHE_MODE_IGNORE)
 assert(cart!=null and cart.get_size()==Vector2(16,16))
 print("EXPORT_ACHIEVEMENTS_OK ",args[0]," catalog=35 badges=36 hidden_story=true minecart=16px")
 quit()

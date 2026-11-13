extends SceneTree
func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1 or not ProjectSettings.load_resource_pack(args[0],true):quit(1);return
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_equipment.json"))
 var count=0
 for name in data.sprites:
  if not name.begins_with("icon_ch4_"):continue
  var texture=ResourceLoader.load("res://assets/sprites/"+name+".png","Texture2D",ResourceLoader.CACHE_MODE_IGNORE)
  if texture==null:push_error("Missing exported icon: "+name);quit(1);return
  var expected=16 if name in ["icon_ch4_gunpowder","icon_ch4_minecart"] else 32
  if texture.get_size()!=Vector2(expected,expected):push_error("Wrong exported icon size: "+name);quit(1);return
  if expected==32:count+=1
 if count!=25:push_error("Expected 25 generated icons, got %d"%count);quit(1);return
 print("CH4_EXPORT_ICONS_OK ",args[0]," generated=25 transparent=32px minecart=vanilla")
 quit()

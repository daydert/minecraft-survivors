extends SceneTree
const PATHS=["res://data/chapter_four_balance.json","res://data/chapter_four_mobs.json"]
func image_hash(texture: Texture2D) -> String:
 var image=texture.get_image();image.convert(Image.FORMAT_RGBA8)
 var ctx=HashingContext.new();ctx.start(HashingContext.HASH_SHA256);ctx.update(image.get_data());return ctx.finish().hex_encode()
func _initialize():
 var expected={}
 for path in PATHS:expected[path]=FileAccess.get_file_as_string(path).sha256_text()
 var butcher="res://assets/sprites/ch4_butcher_atlas.png"
 var expected_image=image_hash(ResourceLoader.load(butcher,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE))
 var args=OS.get_cmdline_user_args()
 if args.size()<1 or not ProjectSettings.load_resource_pack(args[0],true):quit(2);return
 var stale=[]
 for path in PATHS:
  if FileAccess.get_file_as_string(path).sha256_text()!=expected[path]:stale.append(path)
 if image_hash(ResourceLoader.load(butcher,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE))!=expected_image:stale.append(butcher)
 var store=ResourceLoader.load("res://scripts/achievements.gd","GDScript",ResourceLoader.CACHE_MODE_IGNORE).new()
 var access=store.has_method("chapter_available") and store.chapter_available(1) and not store.chapter_available(2)
 print("BUILD_CONTENT ",JSON.stringify({"binary":args[0],"stale_chapter_four":stale,"chapter_access":access}))
 if args.size()>1 and args[1]=="require-current" and (not stale.is_empty() or not access):quit(1)
 else:quit()

extends SceneTree
func _initialize():run.call_deferred()
func run():
 var path := "res://data/chapter_five_cinema.json"
 assert(FileAccess.file_exists(path),"Cinematic data absent from export")
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(data.tracks.has("bad_end") and data.tracks.has("bad_qte") and data.tracks.has("finisher") and data.tracks.chair.frames.size()==1321)
 var v=load("res://scripts/chapter_five_view3d.gd").new();root.add_child(v)
 var f=load("res://scripts/chapter_five_finale.gd").new();f.change("chair");f.age=33
 v.ensure(null,"chair",Vector2i(640,360));v.sync_chair(f,33)
 assert(v.nodes.sword.get_parent()==v.rigs.steve.grip)
 v.ensure(null,"flight",Vector2i(640,360));f.change("flight");f.age=29.2;v.sync_flight(f,29.2)
 assert(v.nodes.worlds.size()==11 and v.nodes.other.visible)
 await process_frame;RenderingServer.force_draw(false)
 assert(v.viewport.get_texture().get_image().get_width()==640)
 v.ensure(null,"qte",Vector2i(640,360));var q=load("res://scripts/chapter_five_qte.gd").new();q.beat=1;q.age=1.15;q.resolved=true;q.success=true;v.sync_qte(q)
 assert(v.rigs.notch.root.visible)
 var n=load("res://scripts/chapter_five_notch.gd").new();n.bad_from_qte=true;n.age=11.1
 v.ensure(null,"bad_end",Vector2i(640,360));v.sync_bad_end(n)
 assert(v.nodes.beer.get_child_count()>0 and v.rigs.notch.root.visible)
 assert(FileAccess.file_exists("res://scripts/ui/evolution_view.gd"))
 var db=load("res://scripts/campaign_data.gd").new();db.configure(5)
 assert(db.weapons.has("repeating_block") and db.passives.has("breakpoint"))
 v.release();v.queue_free();await process_frame
 print("PACKED_CINEMA_SHA256 ",FileAccess.get_sha256(path))
 print("CH5_EXPORT_SMOKE PASS: packed motion, rig, 11 logos, 2Fort, QTE, new equipment, Compatibility render")
 quit()

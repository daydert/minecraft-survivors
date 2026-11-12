extends SceneTree
var v
func _initialize():run.call_deferred()
func run():
	v=load("res://scripts/chapter_five_view3d.gd").new();root.add_child(v)
	v.ensure(null,"flight",Vector2i(960,540))
	var f=load("res://scripts/chapter_five_finale.gd").new();f.change("flight")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/ch5_worlds_review"))
	for i in range(15):
		if i<11:
			var side=-1.0 if i%2==0 else 1.0
			var at=v.flight_world_position(i)
			f.age=8.0;v.nodes.cam_override=[at+Vector3(13,13,30),at+Vector3(0,4,0)]
		else:
			f.age=29.0
			var b=v.nodes.other.position
			var shots=[[Vector3(9,4,10),Vector3(0,6,-19)],[Vector3(-22,13,0),Vector3(0,3,0)],[Vector3(9,4,-10),Vector3(0,6,19)],[Vector3(45,40,45),Vector3(0,2,0)]]
			v.nodes.cam_override=[b+shots[i-11][0],b+shots[i-11][1]]
		v.sync_flight(f,f.age)
		await process_frame;await process_frame;RenderingServer.force_draw(false)
		v.viewport.get_texture().get_image().save_png("res://qa/ch5_worlds_review/%02d.png"%i)
	v.release();await process_frame;quit()

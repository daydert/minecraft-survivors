extends SceneTree
## Run against each embedded PCK with --main-pack, using the local Godot binary.
var game
var checks := 0
func check(value: bool, label: String = "Export invariant") -> bool:
 checks += 1
 if not value:
  push_error(label)
  quit(1)
 return value
func _initialize():run.call_deferred()
func run():
 const VIDEO := "res://assets/cinematics/ch1_intro.ogv"
 if not check(FileAccess.file_exists(VIDEO), "Video missing in package"):return
 if not check(FileAccess.file_exists("res://assets/cinematics/ch1_intro_poster.png"), "Poster missing in package"):return
 var stream = load(VIDEO)
 if not check(stream is VideoStreamTheora, "Package must contain native Theora"):return
 if not check(load("res://assets/cinematics/ch1_intro_sfx.ogg") is AudioStreamOggVorbis):return
 game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 game.start_chapter(1)
 if not check(game.chapter_one_prologue.active and game.world.state == "PROLOGUE"):return
 var p = game.chapter_one_prologue
 p.set_paused(true)
 for i in range(12): await process_frame
 if not check(p.player.is_playing()):return
 if not check(p.player.get_video_texture().get_width() == 960):return
 if not check(p.player.get_video_texture().get_height() == 540):return
 p.set_paused(true)
 var at: float = p.player.stream_position
 for i in range(12): await process_frame
 if not check(abs(p.player.stream_position - at) < .05):return
 p.finish()
 if not check(game.world.state == "INTRO" and game.world.time == 0):return
 if not check(game.world.build == {"sword": 1}):return
 game.action("menu")
 if not check(not p.active and p.get_child_count() == 0):return
 print("PACKED_CH1_VIDEO_SHA256 ", FileAccess.get_sha256(VIDEO))
 print("CH1_EXPORT_PASS: native Theora, 960x540 texture, decoder, pause, explicit intro, sword I, cleanup")
 game.quitting = true
 quit.call_deferred()

extends SceneTree
var game
var age := 0.0
var run_age := 0.0
var started := false
var snapshots := {}
var held_key := 0
var prologue_frames := 0
var last_video_position := 0.0
func move_key(code: int):
 if code == held_key: return
 for pair in [[held_key, false], [code, true]]:
  if pair[0] == 0: continue
  var event := InputEventKey.new()
  event.physical_keycode = pair[0]
  event.pressed = pair[1]
  Input.parse_input_event(event)
 held_key = code
func _initialize():run.call_deferred()
func run():
 game=load('res://scenes/main.tscn').instantiate();root.add_child(game)
 game.qa_mode='';game.settings.fullscreen=false
 game.settings.music=.45;game.settings.effects=.6;game.audio.update_volumes(.45,.6)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
 game.screen='chapters'
 for i in range(18): await process_frame
 game.action('chapter_1');game.set_process_input(false);started=true
func _process(delta):
 if not started:return false
 age+=delta
 if game.chapter_one_prologue.active:
  prologue_frames += 1
  last_video_position = game.chapter_one_prologue.player.stream_position
  # Recording is an automated uninterrupted viewing; no window-focus pauses.
  if game.chapter_one_prologue.paused:game.chapter_one_prologue.resume()
 elif game.world.state=='PAUSED':game.action('resume')
 elif game.world.state=='LEVEL_UP':game.world.choose(0)
 elif game.world.state=='RUNNING':
  run_age+=delta
  move_key(KEY_W if run_age<4 else KEY_A if run_age<7 else KEY_D if run_age<10 else KEY_W)
 if run_age>=12:
  move_key(0)
  FileAccess.open('res://qa/cinematics/ch1_intro/recording_runtime.json',FileAccess.WRITE).store_string(JSON.stringify({'duration':age,'run_time':game.world.time,'state':game.world.state,'sword':game.world.build.get('sword',0),'prologue_display_frames':prologue_frames,'last_video_position':last_video_position}))
  game.quitting=true;quit.call_deferred()
 return false

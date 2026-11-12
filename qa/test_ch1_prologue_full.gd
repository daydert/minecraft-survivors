extends SceneTree
## Requires the final 50-second Theora. Run with --fixed-fps 24.
var game
var checks := 0
var failures := []
func _initialize():run.call_deferred()
func check(value: bool, message: String):
 checks += 1
 if not value:failures.append(message);push_error(message)
func press(code: int):
 var event := InputEventKey.new();event.keycode=code;event.pressed=true;game._input(event)
func until(at: float):
 var frames := 0
 while game.chapter_one_prologue.active and game.chapter_one_prologue.player.stream_position<at and frames<3000:
  if game.chapter_one_prologue.paused:game.chapter_one_prologue.resume()
  await process_frame
  frames+=1
 check(frames<3000 and game.chapter_one_prologue.active,'Decoder reached '+str(at))
func run():
 game=load('res://scenes/main.tscn').instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 game.settings.music=0;game.settings.effects=0
 root.size=Vector2i(640,360)
 for at in [0.0,25.0,49.0]:
  game.start_chapter(1)
  var w=game.world;var seed_state=w.rng.state;var health=w.hp
  if at>0:await until(at)
  var p=game.chapter_one_prologue
  check(p.player.stream is VideoStreamTheora,'Real Theora stream')
  if at>0:
   press(KEY_ESCAPE)
   var held=p.player.stream_position
   game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
   var before=root.get_texture().get_image().get_data()
   for i in range(24):await process_frame
   game.queue_redraw();await process_frame;RenderingServer.force_draw(false)
   check(root.get_texture().get_image().get_data()==before,'Paused framebuffer exact at '+str(at))
   check(abs(p.player.stream_position-held)<.05,'Paused decoder exact at '+str(at))
   check((not p.music.playing or p.music.stream_paused) and (not p.effects.playing or p.effects.stream_paused),'Paused audio')
   press(KEY_ESCAPE)
  press(KEY_SPACE)
  check(w.state=='INTRO' and w.intro_age==0 and not p.active,'Skip at '+str(at)+' enters old intro')
  check(w.time==0 and w.rng.state==seed_state and w.hp==health,'Skip preserves clock, RNG, health')
  check(w.build=={'sword':1},'Skip preserves sword I')
  press(KEY_SPACE)
  check(w.state=='RUNNING','Separate input skips old intro')
 game.start_chapter(1)
 var w=game.world
 var frames := 0
 while game.chapter_one_prologue.active and frames<3000:
  if game.chapter_one_prologue.paused:game.chapter_one_prologue.resume()
  await process_frame
  frames+=1
 check(frames<3000 and w.state=='INTRO' and w.intro_age==0,'Natural end calls begin_intro exactly')
 check(w.time==0 and w.build=={'sword':1},'Natural end preserves starting state')
 check(game.chapter_one_prologue.get_child_count()==0,'Natural end releases players')
 game.start_chapter(1)
 game.chapter_one_prologue.set_paused(true)
 game.chapter_one_prologue.leave()
 check(game.world.state=='MENU' and not game.chapter_one_prologue.active,'Paused menu exit')
 game.start_chapter(1)
 check(game.chapter_one_prologue.active and not game.chapter_one_prologue.paused,'Fresh decoder after menu')
 game.action('menu')
 FileAccess.open('res://qa/cinematics/ch1_intro/full_game_checks.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failures':failures,'status':'pass' if failures.is_empty() else 'fail'}))
 print('CH1_FULL_CHECKS ',checks,' failures ',failures)
 game.quitting=true;game.audio.shutdown();quit(0 if failures.is_empty() else 1)

extends SceneTree
var game
var checks := 0
func _initialize():run.call_deferred()
func check(value: bool, label: String):
 checks += 1
 if not value:push_error(label);quit(1);assert(value,label)
func key(code):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;game._input(event)
func run():
 game=load('res://scenes/main.tscn').instantiate();root.add_child(game)
 game.qa_mode='prologue_test';game.set_process(false);game.set_physics_process(false)
 game.settings.fullscreen=false
 game.start_chapter(1)
 var w=game.world;var rng_state=w.rng.state;var hp=w.hp;var build=w.build.duplicate(true);var p=game.chapter_one_prologue
 check(w.state=='PROLOGUE' and p.active,'Real chapter starts the new owner')
 var clock=w.clock
 for i in range(120):game._physics_process(1.0/60)
 check(w.time==0 and w.clock==clock and w.rng.state==rng_state,'Prologue freezes combat time, clock and RNG')
 check(w.hp==hp and w.build==build,'Prologue preserves health and starting gear')
 key(KEY_ESCAPE);check(p.paused and p.player.paused,'Esc pauses movie')
 var at=p.player.stream_position
 for i in range(20):await process_frame
 check(abs(p.player.stream_position-at)<.06,'Paused movie holds its decoded position')
 key(KEY_ESCAPE);check(not p.paused,'Esc resumes')
 game._focus_lost();check(p.paused and p.music.stream_paused,'Focus loss pauses video and audio together')
 p.resume()
 key(KEY_SPACE);check(not p.active and w.state=='INTRO' and w.intro_age==0,'Skip explicitly begins existing intro')
 check(not w.intro_from_prologue,'Film ends on black, walk-in keeps its fade from black')
 check(game.input_lock>0,'Skip consumes and locks input')
 check(w.time==0 and w.rng.state==rng_state and w.build==build,'Skip does not change combat state')
 key(KEY_SPACE);check(w.state=='RUNNING','Existing intro skip still works')
 game.start_chapter(1);check(p.active and game.world.state=='PROLOGUE','Repeat chapter reloads movie')
 p.leave();check(not p.active and game.world.state=='MENU' and p.get_child_count()==0,'Exit releases video and returns to menu')
 game.start_chapter(1,false);check(not p.active and game.world.state=='RUNNING','Direct battle test bypasses prologue')
 game.start_chapter(1);p.finish();p.finish();check(game.world.state=='INTRO' and game.world.intro_age==0,'Completion is idempotent')
 # Let the untouched game intro finish naturally and enter ordinary play.
 w=game.world
 for i in range(720):w.step(1.0/60)
 check(w.state=='RUNNING' and w.time<.5,'Existing 11.6s intro does not spend run time')
 check(w.build.get('sword',0)==1,'Sword remains level I')
 game.action('menu')
 FileAccess.open('res://qa/cinematics/ch1_intro/game_checks.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'status':'pass'}))
 print('CH1_PROLOGUE_CHECKS ',checks)
 game.quitting=true;game.audio.shutdown();quit()

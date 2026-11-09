extends SceneTree
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	checks+=1
	if ok:print("PASS: "+label)
	else:failures.append(label);push_error(label)
func run():
	var audio=load("res://scripts/sound.gd").new();root.add_child(audio)
	check(audio.playlist.size()==3 and audio.music.stream.loop,"Menu uses the original looping track")
	for chapter in [1,2]:
		audio.reset_run_music()
		check(audio.track_index==0 and not audio.music.stream.loop,"Chapter %d starts the run playlist" % chapter)
		audio.music.finished.emit()
		check(audio.track_index==1 and audio.music.stream.resource_path.ends_with("music_2.ogg"),"Chapter %d advances to Music2" % chapter)
		audio.music.finished.emit()
		check(audio.track_index==2 and audio.music.stream.resource_path.ends_with("music_3.ogg"),"Chapter %d advances to Music3" % chapter)
		audio.music.finished.emit()
		check(audio.track_index==0,"Chapter %d playlist wraps after all three tracks" % chapter)
	audio.reset_run_music()
	audio.music.seek(audio.music.stream.get_length()-.1)
	await create_timer(.65).timeout
	check(audio.track_index==1,"A real end-of-file advances the playlist without a synthetic signal")
	audio.set_music_context("wither",true);audio._process(1)
	check(audio.wither_music.playing and audio.wither_mix==1 and not audio.boss_music.playing,"Wither fight selects its dedicated theme")
	check(audio.music.stream_paused and audio.wither_music.stream.loop,"Ambient progress waits while the Wither theme loops")
	audio.wither_music.seek(audio.wither_music.stream.get_length()-.1)
	await create_timer(.65).timeout
	check(audio.wither_music.playing and audio.wither_music.get_playback_position()<2,"The dedicated Wither recording loops at its actual end")
	audio.update_volumes(0,0)
	check(audio.wither_music.stream_paused and audio.wither_music.volume_db<=-90,"Zero volume mutes the new boss player")
	audio.update_volumes(.1,.4)
	check(not audio.wither_music.stream_paused and is_equal_approx(audio.wither_music.volume_db,linear_to_db(.1)),"Wither theme obeys the ten-percent music setting")
	audio.set_music_context("herobrine",true);audio._process(1)
	check(audio.boss_music.playing and audio.finale_music and not audio.wither_music.playing,"Herobrine retains his separate original theme")
	audio.set_music_context("",false);audio._process(1)
	check(audio.music.stream.loop and not audio.music.stream_paused and not audio.boss_music.playing,"Menu restores normal playback after either boss")
	for stream in audio.playlist:
		check(stream.get_length()>260 and stream is AudioStreamOggVorbis,"Playlist contains a complete decodable Vorbis track")
	check(absf(audio.wither_music.stream.get_length()-67.78365)<.02,"Wither theme retains the full supplied duration")
	audio.update_volumes(.4,.6)
	audio.play("boss_win")
	check(audio.win_stinger.playing and not audio.victory_music.playing and audio.celebration_state=="stinger","Boss victory plays the dedicated sound before its music")
	audio.set_music_context("victory",true)
	audio.win_stinger.seek(audio.win_stinger.stream.get_length()-.1)
	await create_timer(.65).timeout
	audio._process(.5)
	check(audio.victory_music.playing and audio.celebration_state=="music","Actual stinger completion starts the after-victory track")
	audio.victory_music.seek(audio.victory_music.stream.get_length()-.1)
	await create_timer(.65).timeout
	check(audio.victory_music.playing and audio.victory_music.get_playback_position()<2,"After-victory music repeats until leaving the location")
	audio.set_music_context("",false)
	check(not audio.win_stinger.playing and not audio.victory_music.playing,"Menu cancels the victory sequence")
	audio.update_volumes(0,0);audio.play("boss_win");audio._process(7)
	check(audio.celebration_state=="music" and audio.victory_music.stream_paused,"Muted victory sound still advances to muted music")
	audio.set_music_context("wither",true)
	check(audio.celebration_state=="" and not audio.victory_music.playing,"A new boss location replaces the after-victory music")
	FileAccess.open("res://qa/music_rotation_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	audio.shutdown();audio.set_process(false);await create_timer(.5).timeout;audio.free();audio=null;await process_frame;await create_timer(.2).timeout
	print("MUSIC_ROTATION_RESULT ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

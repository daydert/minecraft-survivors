class_name GameSound
extends Node
var music: AudioStreamPlayer
var boss_music: AudioStreamPlayer
var wither_music: AudioStreamPlayer
var dragon_music: AudioStreamPlayer
var endersteve_music: AudioStreamPlayer
var victory_music: AudioStreamPlayer
var win_stinger: AudioStreamPlayer
var victory_mix=0.0
var celebration_state=""
var celebration_wait=0.0
var finale_music=false
var music_mix=0.0
var herobrine_mix=0.0
var wither_mix=0.0
var dragon_mix=0.0
var endersteve_mix=0.0
var theme=""
var playlist: Array[AudioStreamOggVorbis]=[]
var track_index=0
var ambient_running=false
var voices = {}
var streams = {}
var music_volume = 0.45
var effects_volume = 0.65
var sound_map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/minecraft_audio.json"))
var variant_rng = RandomNumberGenerator.new()
const MAX_VOICES = 24

func _ready():
	sound_map.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/nether_audio.json")),true)
	sound_map.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/duel_audio.json")),true)
	sound_map.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/ghast_intro_audio.json")),true)
	sound_map.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/end_audio.json")),true)
	sound_map.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/achievement_audio.json")),true)
	for path in ["music","music_2","music_3"]:
		playlist.append(load("res://assets/audio/"+path+".ogg"))
	music=AudioStreamPlayer.new()
	add_child(music)
	music.finished.connect(next_track)
	play_track(0)
	boss_music=theme_player("music_herobrine")
	wither_music=theme_player("music_wither")
	dragon_music=theme_player("music_dragon")
	endersteve_music=theme_player("music_endersteve")
	victory_music=theme_player("music_victory")
	win_stinger=theme_player("boss_win")
	win_stinger.stream.loop=false
	win_stinger.finished.connect(start_victory_music)
	variant_rng.randomize()
	update_music_levels()

func theme_player(name: String) -> AudioStreamPlayer:
	var voice=AudioStreamPlayer.new()
	add_child(voice)
	voice.stream=load("res://assets/audio/"+name+".ogg")
	voice.stream.loop=true
	voice.volume_db=-120
	return voice

func play_track(index: int):
	track_index=posmod(index,playlist.size())
	music.stream=playlist[track_index]
	music.stream.loop=not ambient_running
	music.play()
	update_music_levels()

func next_track():
	play_track(track_index+1 if ambient_running else 0)

func reset_run_music():
	set_boss_theme("")
	ambient_running=true
	play_track(0)

func set_music_context(next_theme: String, running: bool):
	if ambient_running!=running:
		ambient_running=running
		if not running and track_index!=0:play_track(0)
		else:music.stream.loop=not running
	set_boss_theme(next_theme)

func set_boss_theme(next_theme: String):
	if theme==next_theme:return
	if next_theme!="victory":cancel_celebration()
	theme=next_theme
	finale_music=theme=="herobrine"
	if theme=="herobrine" and not boss_music.playing:boss_music.play()
	if theme=="wither" and not wither_music.playing:wither_music.play()
	if theme=="dragon" and not dragon_music.playing:dragon_music.play()
	if theme=="endersteve" and not endersteve_music.playing:endersteve_music.play()

func set_finale_music(enabled: bool):
	set_boss_theme("herobrine" if enabled else "")

func celebrate():
	set_boss_theme("victory")
	celebration_state="stinger"
	celebration_wait=win_stinger.stream.get_length()
	victory_music.stop();boss_music.stop();wither_music.stop()
	dragon_music.stop();endersteve_music.stop()
	herobrine_mix=0;wither_mix=0;dragon_mix=0;endersteve_mix=0;victory_mix=0;music_mix=1
	win_stinger.stream_paused=effects_volume<=0
	win_stinger.volume_db=linear_to_db(maxf(.000001,effects_volume))
	win_stinger.play()
	win_stinger.stream_paused=effects_volume<=0
	update_music_levels()

func start_victory_music():
	if celebration_state!="stinger" or theme!="victory":return
	celebration_state="music"
	win_stinger.stop()
	victory_music.play()

func cancel_celebration():
	celebration_state="";celebration_wait=0;victory_mix=0
	if is_instance_valid(win_stinger):win_stinger.stop()
	if is_instance_valid(victory_music):victory_music.stop()

func _process(delta):
	if celebration_state=="stinger":
		celebration_wait-=delta
		if celebration_wait<=0 and (effects_volume<=0 or not win_stinger.playing):start_victory_music()
	herobrine_mix=move_toward(herobrine_mix,1.0 if theme=="herobrine" else 0.0,delta/.9)
	wither_mix=move_toward(wither_mix,1.0 if theme=="wither" else 0.0,delta/.9)
	dragon_mix=move_toward(dragon_mix,1.0 if theme=="dragon" else 0.0,delta/.9)
	endersteve_mix=move_toward(endersteve_mix,1.0 if theme=="endersteve" else 0.0,delta/.9)
	victory_mix=move_toward(victory_mix,1.0 if theme=="victory" and celebration_state=="music" else 0.0,delta/.4)
	music_mix=1.0 if theme=="victory" else clampf(herobrine_mix+wither_mix+dragon_mix+endersteve_mix,0,1)
	update_music_levels()
	if theme!="herobrine" and herobrine_mix==0 and boss_music.playing:boss_music.stop()
	if theme!="wither" and wither_mix==0 and wither_music.playing:wither_music.stop()
	if theme!="dragon" and dragon_mix==0 and dragon_music.playing:dragon_music.stop()
	if theme!="endersteve" and endersteve_mix==0 and endersteve_music.playing:endersteve_music.stop()

func update_music_levels():
	if is_instance_valid(music):
		music.stream_paused=music_volume<=0 or music_mix>=1
		music.volume_db=linear_to_db(maxf(.000001,music_volume*(1-music_mix)))
	for pair in [[boss_music,herobrine_mix],[wither_music,wither_mix],[dragon_music,dragon_mix],[endersteve_music,endersteve_mix],[victory_music,victory_mix]]:
		if is_instance_valid(pair[0]):
			pair[0].stream_paused=music_volume<=0
			pair[0].volume_db=linear_to_db(maxf(.000001,music_volume*pair[1]))

func update_volumes(m: float, fx: float):
	music_volume = clampf(m,0,1)
	effects_volume = clampf(fx,0,1)
	update_music_levels()
	if is_instance_valid(win_stinger):
		win_stinger.stream_paused=effects_volume<=0
		win_stinger.volume_db=linear_to_db(maxf(.000001,effects_volume))
	for pool in voices.values():
		for voice in pool:
			if effects_volume<=0:voice.stop()
			voice.stream_paused=false
			voice.volume_db = linear_to_db(maxf(0.000001,effects_volume*float(voice.get_meta("gain",1.0))))

func play(id: String):
	if id=="boss_win":celebrate();return
	if effects_volume <= 0: return
	if not sound_map.has(id):
		push_warning("Unknown Minecraft sound event: "+id)
		return
	var active = 0
	for pool in voices.values():
		for v in pool:
			if v.playing: active += 1
	if active >= MAX_VOICES:return
	var spec: Dictionary = sound_map[id]
	var variant: Dictionary = spec.variants[variant_rng.randi_range(0,spec.variants.size()-1)]
	if not streams.has(variant.path): streams[variant.path] = load(variant.path)
	if not voices.has(id): voices[id] = []
	var voice = null
	for v in voices[id]:
		if not v.playing:
			voice = v
			break
	if voice == null:
		if voices[id].size() >= 4: return
		voice = AudioStreamPlayer.new()
		add_child(voice)
		voices[id].append(voice)
	voice.stream = streams[variant.path]
	voice.pitch_scale = float(variant.pitch)
	voice.set_meta("gain",float(spec.gain)*float(variant.volume))
	voice.volume_db = linear_to_db(maxf(0.00001,effects_volume*float(voice.get_meta("gain"))))
	voice.play()

func shutdown():
	set_process(false)
	cancel_celebration()
	theme=""
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for voice in [boss_music,wither_music,dragon_music,endersteve_music,victory_music,win_stinger]:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream=null
	for pool in voices.values():
		for voice in pool:
			voice.stop()
			voice.stream = null
	streams.clear()
	playlist.clear()

func _exit_tree():
	shutdown()

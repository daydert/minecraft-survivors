extends Node2D
## Shared game state, assets and pixel drawing primitives used by every UI module and renderer.

const WorldView = preload("res://scripts/ui/world_view.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const MenuScreens = preload("res://scripts/ui/menu_screens.gd")
const RunScreens = preload("res://scripts/ui/run_screens.gd")
const GearScreens = preload("res://scripts/ui/gear_screens.gd")
const QAHarness = preload("res://scripts/qa_harness.gd")


const W = preload("res://scripts/campaign_world.gd")
const OW = preload("res://scripts/overworld_world.gd")
const NW = preload("res://scripts/nether_world.gd")
const EW = preload("res://scripts/end_world.gd")
const FW = preload("res://scripts/chapter_four_world.gd")
var four_renderer = preload("res://scripts/chapter_four_renderer.gd").new()
var four_assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_assets.json"))
var four_assets_loaded := false
var four_mobs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_mobs.json"))
var four_equipment: Dictionary={}
var four_held_cache: Array=[]
var four_encounter_assets: Dictionary={}
var four_actor_cache: Array=[]
var end_renderer=preload("res://scripts/end_renderer.gd").new()
var recipe_page=0
var achievements=preload("res://scripts/achievements.gd").new()
var achievements_view=preload("res://scripts/achievements_view.gd").new()
var achievement_tier="all"
var achievement_page=0
var achievement_toast=""
var achievement_toast_age=0.0
var end_rift=preload("res://scripts/end_rift_view.gd").new()
var end_assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/end_assets.json"))
var end_assets_loaded=false
const BG = Color("101010")
const INK = Color("ffffff")
const MUTED = Color("aaaaaa")
const GOLD = Color("dddddd")
const LIME = Color("eeeeee")
var world = W.new()
var blood_rift=preload("res://scripts/blood_rift_view.gd").new()
var finale_renderer=preload("res://scripts/finale_renderer.gd").new()
var chapter_assets:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_assets.json"))
var audio: GameSound
var font: Font = preload("res://assets/fonts/minecraft/minecraft_regular.fnt")
var bold: Font = preload("res://assets/fonts/minecraft/minecraft_bold.fnt")
var button_styles: Array[StyleBoxTexture] = []
var textures = {}
var minecraft_assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/minecraft_assets.json"))
var buttons: Array = []
var selected = 0
var mouse = Vector2.ZERO
var ui_time = 0.0
## Presentation-only lights (fireflies, embers): {p, r, c, power, glow} in world space.
var ambient_lights: Array = []
var burst_level := 0
## Presentation-only camera lead in the direction of travel (solo survival).
var cam_lead := Vector2.ZERO
var lead_clock := 0.0
var burst_clock := -10.0
var router = preload("res://scripts/ui/screen_router.gd").new()
## Current full-screen view; "" means the world with its state overlay.
## Assigning navigates and forgets the overlay stack (see screen_router.gd).
var screen: String:
	get: return router.current
	set(value): router.goto(value)
var record = {"time":0.0,"kills":0,"score":0}
var pause_from = "RUNNING"
var solo_chapter = 1
var nether_renderer = preload("res://scripts/nether_renderer.gd").new()
var last_state = "MENU"
var input_lock = 0.0
var settings = {"music":0.4,"effects":0.6,"fullscreen":false,"shake":true,"flashes":true,"numbers":false,"lighting":true}
var qa_mode = ""
var qa_frames = 0
var autoplay_style = ""
var qa_controller
var fast_run = false
var frame_samples: Array = []
var sim_samples: Array = []
var stress_mode = false
var recording_stage = ""
var quitting = false
var chapter_preview=false
var secret_keys=""
var secret_key_time=0
var lab_chapter=1
const BossLab=preload("res://scripts/boss_lab.gd")
var coop = preload("res://scripts/coop_session.gd").new()
var nickname_field: LineEdit
var address_field: LineEdit
var network_nick = "Стив"
var network_address = ""
var stats_coop_was_paused = false
var coop_probe = false


func load_texture(name: String):
	var p = "res://assets/sprites/%s.png" % name
	if ResourceLoader.exists(p): textures[name] = load(p)

func ensure_end_assets(icons_only: bool=false):
	if end_assets_loaded:return
	for name in end_assets.sprites:
		if not icons_only or name.begins_with("icon_"):load_texture(name)
	if not icons_only:end_assets_loaded=true

func unload_end_assets():
	for name in end_assets.sprites:textures.erase(name)
	end_assets_loaded=false

func ensure_four_assets():
	if four_assets_loaded:return
	four_equipment=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_equipment.json"))
	four_encounter_assets=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_encounter_assets.json"))
	for name in four_assets.sprites+four_mobs.sprites+four_equipment.sprites+four_encounter_assets.sprites:load_texture(name)
	for name in four_assets.clips:
		var clip: Dictionary = four_assets.clips[name].duplicate(true)
		clip.total = 0.0;clip.uniform = true
		for duration in clip.durations:
			clip.total += duration
			if not is_equal_approx(duration,clip.durations[0]):clip.uniform = false
		minecraft_assets.clips[name] = clip
	four_assets_loaded = true

func unload_four_assets():
	for name in four_assets.sprites+four_mobs.sprites+four_equipment.get("sprites",[])+four_held_cache+four_encounter_assets.get("sprites",[])+four_actor_cache:textures.erase(name)
	four_held_cache.clear();four_equipment={}
	four_actor_cache.clear();four_encounter_assets={}
	for name in four_assets.clips:minecraft_assets.clips.erase(name)
	four_assets_loaded = false

func four_held_texture(name: String):
	if not four_equipment.get("held",{}).has(name):return null
	if not textures.has(name):load_texture(name)
	four_held_cache.erase(name);four_held_cache.append(name)
	while four_held_cache.size()>8:textures.erase(four_held_cache.pop_front())
	return textures.get(name)

func four_actor_texture(actor: String):
	if not four_encounter_assets.get("actors",{}).has(actor):return null
	var name:=actor+"_atlas"
	if not textures.has(name):load_texture(name)
	four_actor_cache.erase(name);four_actor_cache.append(name)
	while four_actor_cache.size()>8:textures.erase(four_actor_cache.pop_front())
	return textures.get(name)

func pixel_font_size(size: int) -> int:
	return maxi(8,int(round(float(size)/8))*8)

func text_at(value: String, p: Vector2, size: int = 10, color: Color = INK, heavy: bool = false):
	var f = bold if heavy else font
	var actual = pixel_font_size(size)
	draw_string(f,p.round()+Vector2.ONE*(actual/8),value,HORIZONTAL_ALIGNMENT_LEFT,-1,actual,Color(0,0,0,color.a))
	draw_string(f,p.round(),value,HORIZONTAL_ALIGNMENT_LEFT,-1,actual,color)

func centered(value: String, y: float, size: int = 12, color: Color = INK, heavy: bool = false):
	var f = bold if heavy else font
	text_at(value,Vector2((640-f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixel_font_size(size)).x)/2,y),size,color,heavy)

func panel(rect: Rect2, color: Color = Color("242424"), border: Color = Color("777777")):
	# Shared monochrome window frame, including legacy callers' color inputs.
	draw_rect(rect,Color.BLACK)
	draw_rect(rect.grow(-1),Color(0.14,0.14,0.14,color.a))
	draw_rect(rect.grow(-1),Color("777777"),false,1)
	draw_line(rect.position+Vector2(2,2),rect.position+Vector2(rect.size.x-3,2),Color("aaaaaa"))

func button(rect: Rect2, label: String, id: String):
	var index = buttons.size()
	buttons.append({"rect":rect,"id":id})
	var active = selected == index
	draw_style_box(button_styles[1 if active else 0],rect)
	var size = 8
	var tw = bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text_at(label,rect.position+Vector2((rect.size.x-tw)/2,rect.size.y/2+3),size,INK,true)

func sprite(name: String, p: Vector2, size: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE):
	if not textures.has(name): return
	var tex: Texture2D = textures[name]
	if size == Vector2.ZERO: size = tex.get_size()
	draw_texture_rect(tex,Rect2(p,size),false,tint)

func item_icon(id: String, p: Vector2, scale_factor: float = 1.0, evolution: bool = false, equipment_level: int = -1):
	var name: String = world.db.icon(id,evolution)
	if not coop.active and world.db.has_method("equipment_icon"):
		name=world.db.equipment_icon(id,world.build.get(id,world.items.get(id,1)) if equipment_level<0 else equipment_level,evolution)
	if name in ["netherite","flamebow","channeling"] or (evolution and minecraft_assets.clips.has(name+"_enchanted")):
		draw_clip(name+"_enchanted",p,Vector2.ONE*16*scale_factor,item_time())
	else: sprite("icon_"+name,p,Vector2.ONE*16*scale_factor)

func item_time() -> float:
	# Menus have no simulation. All in-run visuals use its paused clock.
	return ui_time if world.state=="MENU" else world.clock

func clip_frame(name: String, time: float, looping: bool = true) -> int:
	var clip: Dictionary = minecraft_assets.clips[name]
	var total: float = clip.total
	if clip.uniform:
		var frame_index = int((maxf(0,time)+0.000001)/float(clip.durations[0]))
		return int(clip.frames[frame_index%clip.frames.size() if looping else mini(clip.frames.size()-1,frame_index)])
	var remaining = fposmod(maxf(0,time),total) if looping else clampf(time,0,total)
	for i in range(clip.frames.size()):
		if remaining < float(clip.durations[i]): return int(clip.frames[i])
		remaining -= float(clip.durations[i])
	return int(clip.frames.back())

func draw_clip(name: String, p: Vector2, size: Vector2, time: float, tint: Color = Color.WHITE, looping: bool = true):
	if not textures.has(name):return
	var frame_size = Vector2(minecraft_assets.clips[name].frame_size[0],minecraft_assets.clips[name].frame_size[1])
	draw_texture_rect_region(textures[name],Rect2(p,size),Rect2(Vector2(clip_frame(name,time,looping)*frame_size.x,0),frame_size),tint)

func oval(p: Vector2, size: Vector2, color: Color):
	draw_set_transform(p,0,size)
	draw_circle(Vector2.ZERO,1,color)
	draw_set_transform(Vector2.ZERO)

func dim(alpha: float = 0.72):
	draw_rect(Rect2(0,0,640,360),Color(0,0,0,alpha))

func wrapped(value: String, p: Vector2, width: float, size: int=10, color: Color=INK, heavy: bool=false):
	size = pixel_font_size(size)
	var f=bold if heavy else font
	var line=""
	var y=p.y
	for word in value.split(" "):
		if f.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			if not line.is_empty():
				text_at(line,Vector2(p.x,y),size,color,heavy)
				y+=size+5
				line=""
			var fragment=""
			for letter in word:
				if not fragment.is_empty() and f.get_string_size(fragment+letter+"-",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
					text_at(fragment+"-",Vector2(p.x,y),size,color,heavy)
					y+=size+5
					fragment=""
				fragment+=letter
			line=fragment+" "
			continue
		if f.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and not line.is_empty():
			text_at(line,p+Vector2(0,y-p.y),size,color,heavy)
			y+=size+5
			line=""
		line+=word+" "
	text_at(line,p+Vector2(0,y-p.y),size,color,heavy)

func format_time(t: float) -> String:
	return "%02d:%02d" % [int(t)/60,int(t)%60]

func gear_title(id: String, evolution: bool = false, level: int = -1) -> String:
	if not coop.active and world.db.has_method("equipment_title"):
		return world.db.equipment_title(id,world.build.get(id,world.items.get(id,1)) if level<0 else level,evolution)
	return world.db.title(id,evolution)

func is_nether() -> bool:
	return not coop.active and world is NW and world.chapter_number()==2

func is_four() -> bool:
	return not coop.active and world is FW

func is_end() -> bool:
	return not coop.active and world is EW

func invulnerable_tint() -> Color:
	return Color(1,0.65,0.55,0.65) if settings.flashes and world.invulnerable>0 and fmod(world.clock,0.14)<0.07 else Color.WHITE

func network_view_id() -> int:
	var id: int = world.local_id
	if world.players[id].alive or world.players[id].in_finale: return id
	for a in world.players.values():
		if a.alive or a.in_finale: return a.id
	return id

# Forwarders: renderers, tests and coop call these on the game node.

func draw_actor(kind: String, p: Vector2, dir: Vector2, anim: float, moving: bool, tint: Color, phase: String = "walk", actor_scale: float = 1.0, visual: Dictionary = {}):
	WorldView.draw_actor(self, kind, p, dir, anim, moving, tint, phase, actor_scale, visual)

func draw_bow(p: Vector2, aim: Vector2, draw_amount: float, flame: bool = false):
	WorldView.draw_bow(self, p, aim, draw_amount, flame)

func draw_held_weapons(p: Vector2):
	WorldView.draw_held_weapons(self, p)

func draw_projectile(b: Dictionary, offset: Vector2):
	WorldView.draw_projectile(self, b, offset)

func draw_effect(e: Dictionary, offset: Vector2):
	WorldView.draw_effect(self, e, offset)

func character_stats() -> Dictionary:
	return GearScreens.character_stats(self)

func create_network_fields():
	MenuScreens.create_network_fields(self)

func sync_network_fields():
	MenuScreens.sync_network_fields(self)

func capture():
	QAHarness.capture(self)

func prepare_end_capture():
	QAHarness.prepare_end_capture(self)

extends SceneTree
## Chapter V stage B: hidden vanilla items as weapons, their evolutions and passives.
var game
var checks=0
var failures=[]
var out="res://qa/chapter_five/"
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: ",label)
	else:failures.append(label);push_error(label)
func render(name: String="") -> Image:
	game.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(false)
	var image=root.get_texture().get_image()
	if not name.is_empty():image.save_png(out+name+".png")
	return image
func advance(seconds: float,movement: Vector2=Vector2.ZERO):
	for i in range(ceili(seconds*60)):
		var w=game.world
		if w.state=="LEVEL_UP":w.skip_reward()
		elif w.state=="CHEST":w.chest_delay=0;w.close_chest()
		else:w.step(1.0/60,movement)
func fresh(build: Dictionary, items: Dictionary={}):
	game.action("chapter_5");var w=game.world
	w.db.data.waves=[{"at":0,"rate":0,"weights":{"token":1}}]
	for id in w.next_event:w.next_event[id]=99999.0
	w.build=build;w.items=items;w.invulnerable=999
	for id in build:w.cooldowns[id]=0.0
	return w
func crowd(w,center: Vector2,n: int,kind:="token",hp:=200.0):
	for k in range(n):
		w.spawn(kind,center+Vector2.from_angle(k*2.4)*(4+k*3))
		w.mobs.back().hp=hp;w.mobs.back().max_hp=hp;w.mobs.back().speed=0.0
func total_hp(w) -> float:
	var t:=0.0
	for m in w.mobs:t+=m.hp
	return t
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.qa_mode="review";game.settings.shake=false;game.settings.numbers=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(640,360)
	var w=fresh({})
	var db=w.db
	check(db.weapons.has("debug_stick") and db.weapons.has("command_block") and not db.weapons.has("trident") and not db.weapons.has("potion"),"V offers its own items instead of the chapter II pool")
	check(db.passives.has("recovery_compass") and not db.passives.has("fire_resist"),"…and its own passives")
	check(db.description("barrier",0).begins_with("Невидимые") and db.description("barrier",1).begins_with("Блоки"),"Descriptions name what the next level changes")
	for id in ["debug_stick","command_block","barrier","structure_block","spawn_egg","knowledge_book","recovery_compass"]:
		check(game.textures.has("icon_"+id),"Icon for "+id)
	# debug stick
	w=fresh({"debug_stick":3});crowd(w,w.player+Vector2(70,0),3);var hp=total_hp(w)
	advance(.05);check(total_hp(w)<hp and w.arsenal.beams.size()==2,"The debug stick chains to its second target")
	var slowed=w.mobs.filter(func(m):return m.get("slow",0.0)>0).size()
	advance(1.3);var pushed=w.mobs.any(func(m):return m.knock.length()>0)
	check(slowed>0 or pushed,"It alternates slowing and shoving")
	await render("b_stick")
	w=fresh({"debug_stick":8},{"knowledge_book":1});w.evolved["debug_stick"]=true;crowd(w,w.player+Vector2(60,0),4,"token",100.0)
	for m in w.mobs:m.hp=15
	advance(.05);check(w.mobs.filter(func(m):return m.hp>0).size()<=1,"«State: dead» finishes weakened enemies")
	# command block
	w=fresh({"command_block":1});crowd(w,w.player+Vector2(150,40),6);crowd(w,w.player+Vector2(-120,0),1)
	hp=total_hp(w);advance(.2);await render("b_command_wait");advance(.5)
	check(total_hp(w)<=hp-22*6+1,"/kill hits the densest cluster")
	await render("b_command")
	w=fresh({"command_block":8},{"chain_block":1});w.evolved["command_block"]=true
	crowd(w,w.player+Vector2(150,0),4);crowd(w,w.player+Vector2(-150,0),4);crowd(w,w.player+Vector2(0,150),4)
	advance(1.4);check(w.mobs.all(func(m):return m.hp<200),"The command chain reaches all three clusters")
	# barrier
	w=fresh({"barrier":3});var bs=w.arsenal.stats(w,"barrier")
	var spot: Vector2=w.player+Vector2.from_angle(w.arsenal.orbit+bs.speed/60.0)*bs.radius
	w.shots.append({"p":spot,"v":Vector2.ZERO,"life":3.0,"damage":3.0,"glyph":"x","delay":0.0,"icon":"","age":0.0})
	w.invulnerable=0;hp=w.hp;advance(1.0/60);check(w.shots.is_empty() and w.hp==hp,"Barrier blocks snuff enemy shots")
	crowd(w,w.player+Vector2(34,0),1);advance(1.5);check(w.mobs[0].hp<200,"…and bruise what they touch")
	await render("b_barrier")
	w=fresh({"barrier":8},{"light_block":1});w.evolved["barrier"]=true;crowd(w,w.player+Vector2(120,0),1);crowd(w,w.player+Vector2(-120,0),1);crowd(w,w.player+Vector2(0,120),1)
	advance(1.4);check(w.mobs.filter(func(m):return m.hp<200).size()>=1,"«Cutting light» beams reach beyond the ring")
	await render("b_light")
	# structure block
	w=fresh({"structure_block":1});crowd(w,w.player+Vector2(120,0),6);hp=total_hp(w);advance(.5);await render("b_paste_wait");advance(.6)
	var per: float=(hp-total_hp(w))/6.0
	check(per>14*1.5,"A paste hurts more the more enemies are inside")
	await render("b_paste")
	# spawn egg
	w=fresh({"spawn_egg":2});advance(.1);check(w.arsenal.allies.size()==1,"The egg summons an ally from a past chapter")
	crowd(w,w.player+Vector2(60,0),1);advance(3.0);check(w.mobs[0].hp<200,"Allies fight for you")
	await render("b_ally")
	advance(12.0);check(w.arsenal.allies.size()<=2,"Allies expire without the name tag evolution")
	# passives
	w=fresh({},{"knowledge_book":5});w.drop_xp(w.player+Vector2(200,0),10);check(w.orbs.back().value==15,"Knowledge book: +10% experience per level")
	check(w.db.stats("sword",1,false,{"chain_block":4}).interval<w.db.stats("sword",1,false,{}).interval,"Chain block shortens every cooldown")
	w=fresh({},{"recovery_compass":1});w.invulnerable=0;advance(3.5);var mark=w.player;advance(1.0,Vector2.RIGHT)
	w.hp=2;w.damage_player(10)
	check(w.hp>=6 and w.state=="RUNNING" and w.player.distance_to(mark)<40,"Ctrl+Z rolls a lethal blow back three seconds")
	w.invulnerable=0;w.hp=2;w.damage_player(10);advance(.05)
	check(w.state=="RESULT","…once per cooldown")
	w=fresh({},{"structure_void":2});w.invulnerable=0;hp=w.hp;w.shots.append({"p":w.player+Vector2(4,0),"v":Vector2.ZERO,"life":1.0,"damage":4.0,"glyph":"x","delay":0.0,"icon":"","age":0.0});advance(.02)
	check(is_equal_approx(hp-w.hp,maxf(1,2.8-0.2*w.items.get("armor",0))),"Structure void softens code shots")
	# evolution through a chest
	w=fresh({"spawn_egg":8},{"name_tag":1});w.time=400;w.loot.append({"kind":"chest","p":w.player,"born":400.0});advance(.2)
	check(w.evolved.has("spawn_egg"),"A chest after 6:00 evolves a maxed item with its passive")
	print("CHAPTER_FIVE_ARSENAL_RESULT %d checks; %d failures" % [checks,failures.size()])
	quit(1 if failures.size() else 0)

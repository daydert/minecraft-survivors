extends SceneTree
const W=preload("res://scripts/nether_world.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if ok:print("PASS: "+label)
	else:failures.append(label);push_error(label)
func advance(w, seconds: float):
	for i in range(ceili(seconds*60)):w.step(1.0/60)
func explosives(w, seconds: float):
	for i in range(ceili(seconds*60)):w.update_explosives(1.0/60)
func run():
	var w=W.new(724);w.state="RUNNING";w.magma.clear()
	check(is_equal_approx(w.db.stats("bed",1).radius,97.5),"Bed I blast radius grows from 65 to 97.5")
	for level in [1,4,8]:
		for evolved in [false,true]:
			var old_radius=65.0
			for i in range(level-1):old_radius+=w.db.data.upgrades.bed[i].get("radius",0)
			old_radius=old_radius*1.3+(16 if evolved else 0)
			check(is_equal_approx(w.db.stats("bed",level,evolved,{"amethyst":3}).radius,old_radius*1.5),"Bed radius scales all levels, upgrades and evolution by exactly 1.5")
	w.place_explosive("bed",w.db.stats("bed",1));var bed=w.explosives[0]
	w.spawn("zoglin",bed.p+Vector2(85,0));w.rebuild_hit_grid();var mob=w.mobs[0]
	w.player=bed.p+Vector2(10,0);w.update_explosives(.7)
	check(mob.hp<mob.max_hp,"The real bed explosion reaches an enemy beyond its previous radius")
	w.mobs.clear();w.effects.clear();w.rebuild_hit_grid()
	w.build={"tnt":8};w.player=Vector2(1024,1024);w.facing=Vector2.RIGHT
	w.place_explosive("tnt",w.db.stats("tnt",8))
	check(w.explosives.size()==1 and w.tnt_groups.size()==1,"Only the detonator appears immediately")
	explosives(w,.3);check(w.explosives.size()==1,"The second TNT waits for its placement interval")
	w.facing=Vector2.UP;explosives(w,.04);var anchor=w.explosives[0].p
	check(w.explosives.size()==2 and w.explosives[1].p.y<anchor.y-15,"Turning before delayed placement aims the next charge upward")
	w.facing=Vector2.LEFT;explosives(w,.32)
	check(w.explosives.size()==3 and w.explosives[2].p.x<anchor.x-15,"A later charge independently follows the new facing")
	explosives(w,.86)
	check(w.explosives.all(func(b):return b.launched and b.height>=0 and b.v.length()>0),"The detonator propels the real delayed charges in their chosen directions")
	explosives(w,3);check(w.explosives.is_empty() and w.tnt_groups.is_empty(),"Ordinary TNT leaves no delayed or live charges")
	w.explosives.clear();w.tnt_groups.clear();w.evolved={"tnt":true};w.facing=Vector2.RIGHT
	w.place_explosive("tnt",w.db.stats("tnt",8,true))
	var child_count=0;var first_child_at=-1.0
	for i in range(240):
		w.update_explosives(1.0/60)
		var n=w.explosives.filter(func(b):return b.get("child",false)).size()
		child_count=maxi(child_count,n)
		if n>0 and first_child_at<0:first_child_at=i/60.0
	check(child_count>=9 and first_child_at>2,"Evolved flying charges split into a visible second wave of small TNT")
	check(w.explosives.is_empty() and w.tnt_groups.is_empty(),"Cluster children expire and cannot recursively multiply")
	w.place_explosive("tnt",w.db.stats("tnt",8,true));w.state="PAUSED";var age=w.tnt_groups[0].age
	w.step(3);check(w.tnt_groups[0].age==age,"Pause freezes delayed TNT placement")
	w.discard("tnt");check(w.tnt_groups.is_empty() and w.explosives.is_empty(),"Deleting TNT clears pending placement as well as existing charges")
	w.reset(724);w.state="RUNNING";w.prepare_arena();w.build={}
	var state=w.rng.state;var hp=w.hp
	advance(w,3.2)
	check(w.stage=="arrival" and not w.ghast.ruptured and w.projectiles.is_empty(),"The fake Ghast appears before any live Wither attacks")
	check(w.sounds.has("ghast_intro_cry") and w.sounds.has("ghast_intro_charge") and not w.sounds.has("herobrine"),"Ghast voice and charge precede the Wither reveal")
	advance(w,2.1)
	check(w.ghast.ruptured and w.ghast.pieces.size()==17,"Internal rupture creates seventeen independent textured body parts")
	check(w.rng.state==state and w.hp==hp,"Visual debris does not change combat RNG or health")
	var piece=w.ghast.pieces[0];var at=piece.p;var height=piece.height
	advance(w,.3)
	check(piece.p!=at and piece.height!=height,"Debris has physical travel and vertical motion")
	w.state="PAUSED";var clock=w.clock;at=piece.p;age=piece.age
	w.step(5)
	check(w.clock==clock and piece.p==at and piece.age==age,"Pause freezes the full fake-boss reveal and debris")
	w.state="RUNNING";advance(w,1.1)
	check(w.sounds.has("herobrine") and w.stage=="arrival","Wither emergence receives its sound after the Ghast bursts")
	advance(w,4)
	check(w.stage=="wither" and w.mobs.size()==1 and w.mobs[0].kind=="wither","Control returns only after the full emergence animation")
	advance(w,3)
	check(w.ghast.pieces.is_empty(),"Scattered Ghast parts fade completely during the fight")
	w.reset(724);check(w.ghast.pieces.is_empty() and not w.ghast.ruptured and w.ghast.cues==0,"Retry resets all cinematic state")
	w.state="RUNNING";w.prepare_arena();w.stage="portal";w.mobs.clear();w.build={}
	w.player=Vector2(800,1140);w.defeated_boss={"p":Vector2(800,880)};w.arena_camera=(w.player+w.defeated_boss.p)/2+Vector2(0,-28)
	var old=w.camera();w.apply_upgrade("ender_eye");w.update_arena_camera(.016)
	check(w.portal_camera_focus and w.camera().x>old.x and w.camera().distance_to(old)<10,"Eye pickup starts a smooth pan toward the portal")
	for i in range(180):w.update_arena_camera(1.0/60)
	check(w.camera().x>old.x+120,"The camera leaves the old drop position behind")
	w.player=w.portal_position+Vector2(40,0);w.step(.01)
	check(w.stage=="lighting" and not w.pearl and w.portal_camera_focus,"Portal focus persists after the Eye is consumed")
	w.reset(724);check(not w.portal_camera_focus,"A new run clears the portal camera anchor")
	FileAccess.open("res://qa/ghast_update_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("GHAST_UPDATE_RESULT ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)

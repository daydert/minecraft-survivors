extends RefCounted
## Observes solo play without changing combat, clocks or random generators.
var enabled=true
var chapter=1
var completed=false
var damage_taken=0.0
var healing_used=false
var evolved_once=false
var sword_only=true
var bow_allowed=true
var bow_exposure={}
var bow_obtained=false
var starter_sword=true
var highest_weapon_slots=0
var events: Array[String]=[]
var awarded={}

func reset(chapter_number: int):
	enabled=true;chapter=chapter_number;completed=false;damage_taken=0;healing_used=false
	evolved_once=false;sword_only=true;bow_allowed=true;bow_exposure.clear();bow_obtained=false;starter_sword=true
	highest_weapon_slots=0;events.clear();awarded.clear()

func award(id: String):
	if not enabled or awarded.has(id):return
	awarded[id]=true;events.append(id)

func observe(w):
	if not enabled or completed:return
	highest_weapon_slots=maxi(highest_weapon_slots,w.build.size())
	if w.build.has("bow"):bow_obtained=true
	if not w.build.has("sword"):starter_sword=false
	for id in w.build:
		if id!="sword":sword_only=false
		if id!="bow" and (w.build[id]>1 or w.evolved.has(id)):bow_allowed=false
	if not w.evolved.is_empty():evolved_once=true;award("first_evolution")
	if w.build.size()>=6 and w.items.size()>=8:award("full_inventory")

func step(w, dt: float):
	if not enabled or completed:return
	observe(w)
	if chapter!=1:return
	for id in w.build:
		if id=="bow":continue
		# The untouched starting sword is allowed until the first bow is found.
		if id=="sword" and starter_sword and not bow_obtained:continue
		# Keep each item's total exposure across removal/reacquisition. Menus freeze dt.
		bow_exposure[id]=bow_exposure.get(id,0.0)+dt
		if bow_exposure[id]>3.00001:bow_allowed=false

func damage(amount: float):
	if enabled and not completed:damage_taken+=maxf(0,amount)

func healing():
	if enabled and not completed:healing_used=true

func evolution(id: String):
	if not enabled or completed:return
	evolved_once=true;award("first_evolution")
	if id!="bow":bow_allowed=false

func finish(w):
	if not enabled or completed:return
	observe(w);completed=true
	match chapter:
		1:
			award("chapter_one")
			if sword_only and w.build.has("sword"):award("sword_only")
			if bow_allowed and w.build.has("bow"):award("bow_only")
			if damage_taken<=0:award("untouched")
		2:
			award("chapter_two")
			if highest_weapon_slots<=2:award("two_weapons")
		3:award("chapter_three")
	if chapter in [2,3]:
		if not evolved_once:award("no_evolutions")
		if not healing_used:award("no_healing")

func drain() -> Array[String]:
	var result=events.duplicate();events.clear();return result

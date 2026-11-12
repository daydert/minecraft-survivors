extends RefCounted
## IV-only data adapter; legacy campaign recipes and formulas retain their path.
static func configure(db):
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_four_arsenal.json"))
	db.data.four_arsenal=data
	for group in ["weapons","upgrades","passives","recipes"]:db.data[group].merge(data[group],true)
	for id in data.exclude_weapons:db.weapons.erase(id);db.recipes.erase(id)
	for id in data.exclude_passives:db.passives.erase(id)
	db.recipes.fishing.passive="ghast_tear"
	db.data.four_buffs={"damage":1.0,"speed":1.0}
	if db.data.weapons.has("potion"):db.data.weapons.potion.name="Зелья"

static func stats(db,id: String,level: int,evolution: bool,items: Dictionary) -> Dictionary:
	var s: Dictionary=db.stats_standard(id,level,evolution and id!="sword",items)
	if evolution:
		match id:
			"sword":s.damage+=36*(1+.1*items.get("blaze",0))*float(db.data.aura_damage);s.radius+=18;s.interval*=.85
			"shotgun":s.pellets+=3;s.damage*=1.15
			"blood_pool":s.damage+=5;s.radius+=8
			"embryo":s.damage*=1.3;s.interval*=.8
			"bell":s.damage+=10
			"bone_saw":s.damage+=3
			"red_torch":s.damage+=4
			"potion":s.duration=s.get("duration",3.0)+1.5
	if id in ["bed","tnt","sky_tnt"]:s.damage*=1+.06*items.get("gunpowder",0)
	s.damage*=float(db.data.four_buffs.damage)
	s.interval/=float(db.data.four_buffs.speed)
	return s

static func components(db,id: String) -> Array:
	var r: Dictionary=db.recipes[id]
	if r.has("requires"):return r.requires
	return [{"id":id,"level":8,"kind":"weapon","evolved":false},{"id":r.passive,"level":1,"kind":"passive","evolved":false}]

static func ready(w,id: String) -> bool:
	if w.evolved.has(id):return false
	for r in components(w.db,id):
		var collection: Dictionary=w.build if r.kind=="weapon" else w.items
		if int(collection.get(r.id,0))<int(r.level):return false
		if r.get("evolved",false) and not w.evolved.has(r.id):return false
	return true

static func icon(db,id: String,evolution: bool) -> String:
	if evolution and db.recipes.has(id):return db.recipes[id].icon
	if id=="end_eye":return "end_eye"
	if id in db.data.four_arsenal.weapons or id in db.data.four_arsenal.passives or id=="potion":return "ch4_"+id
	return ""

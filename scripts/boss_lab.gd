extends RefCounted
## Explicit diagnostic entry. Never used by ordinary rewards or networking.
static func presets(chapter: int) -> Array:
	if chapter==3:
		return [
			{"name":"Рывок","weapons":["sword","spear","mace","shield","knockback_stick","end_crystal"],"items":["elytra","sugar","feather","shulker_shell","blaze","redstone","armor","ghast_tear"]},
			{"name":"Дыхание","weapons":["bow","trident","crossbow","dragon_breath","shield","end_crystal"],"items":["blaze","redstone","amethyst","rabbit_foot","armor","ghast_tear","shulker_shell","ender_pearl"]},
			{"name":"Край","weapons":["spear","mace","knockback_stick","end_crystal","dragon_breath","shield"],"items":["elytra","sugar","feather","amethyst","rabbit_foot","shulker_shell","armor","ghast_tear"]},
			{"name":"Смешанная","weapons":["sword","bow","mace","end_crystal","dragon_breath","shield"],"items":["blaze","redstone","amethyst","feather","rabbit_foot","shulker_shell","armor","ghast_tear"]}]
	if chapter==1:
		return [
			{"name":"Клинки","weapons":["sword","fangs","fire","potion"]},
			{"name":"Стрелы","weapons":["bow","trident","potion","fire"]},
			{"name":"Смешанная","weapons":["sword","bow","trident","fire","potion","fangs"]},
			{"name":"Пламя","weapons":["sword","fire","potion","bow","fangs"]}]
	return [
		{"name":"Клинки","weapons":["sword","axe","hoe","fishing","bed","fangs"],"items":["blaze","armor","hopper","gold_boots","amethyst","fire_resist","redstone","ghast_tear"]},
		{"name":"Стрелы","weapons":["sword","bow","trident","crossbow","tnt","potion"],"items":["blaze","redstone","amethyst","sugar","armor","fire_resist","feather","ghast_tear"]},
		{"name":"Ловушки","weapons":["axe","hoe","tnt","bed","potion","fishing"],"items":["armor","hopper","feather","fire_resist","gold_boots","redstone","blaze","ghast_tear"]},
		{"name":"Пламя","weapons":["sword","fire","bow","crossbow","fangs","fishing"],"items":["blaze","redstone","gold_boots","fire_resist","armor","amethyst","ghast_tear","sugar"]}]

static func equip(w, index: int):
	w.run_progress.enabled=false
	var preset=presets(w.chapter_number())[clampi(index,0,3)]
	w.build.clear();w.items.clear();w.evolved.clear();w.cooldowns.clear()
	for id in preset.weapons:w.build[id]=8
	for id in preset.get("items",["blaze","redstone","amethyst","sugar","armor","hopper"]):w.items[id]=5
	for id in w.build:
		if w.db.recipes.has(id) and w.items.has(w.db.recipes[id].passive):w.evolved[id]=true
	if w.build.has("shield") and w.has_method("block_hit"):w.shield_charges=int(w.db.stats("shield",8,w.evolved.has("shield"),w.items).count)
	w.level=40;w.xp=0;w.hp=20;w.invulnerable=0

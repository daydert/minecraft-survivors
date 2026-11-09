extends RefCounted
## Preserve the original cooperative finale while dispatching the solo duel.
var legacy=preload("res://scripts/legacy_finale_renderer.gd").new()
var duel=preload("res://scripts/herobrine_renderer.gd").new()
func renderer(g):return duel if g.world.finale.has_method("duel_phase") else legacy
func stage(g,offset: Vector2):renderer(g).stage(g,offset)
func floor_effects(g,offset: Vector2):renderer(g).floor_effects(g,offset)
func player(g,p: Vector2):renderer(g).player(g,p)
func foreground(g,offset: Vector2):renderer(g).foreground(g,offset)
func nether(g,alpha: float=1):legacy.nether(g,alpha)
func ending(g):renderer(g).ending(g)

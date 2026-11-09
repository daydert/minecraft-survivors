extends SceneTree
## Compatibility entry point. The same probe is embedded in both exports.
func _initialize():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var probe = load("res://scripts/coop_probe.gd").new()
	probe.game = game
	game.add_child(probe)

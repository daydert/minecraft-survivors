extends Node
var review
func _process(_delta):
	review.tick()
	# Hidden Wayland windows also need fresh pixels. The movie writer still
	# receives the ordinary SceneTree frame, with its deterministic audio clock.
	RenderingServer.force_draw(false)

extends RefCounted
## Screen flow as a stack. Opening an overlay remembers the screen and world state
## underneath; closing restores both exactly. `goto` is plain navigation and
## forgets the stack (menu, settings, chapter choice, starting a run).

var current := ""
var stack: Array[Dictionary] = []

func goto(screen: String):
	stack.clear()
	current = screen

## Opens `screen` above the current one. `pause` puts the world into PAUSED.
func open(screen: String, world, pause: bool = true):
	stack.push_back({"screen": current, "state": world.state})
	current = screen
	if pause:
		world.state = "PAUSED"

## Returns to the screen and world state saved by the matching `open`.
## Without one, falls back to `fallback` and leaves the world untouched.
func close(world, fallback: String = "") -> bool:
	if stack.is_empty():
		current = fallback
		return false
	var frame: Dictionary = stack.pop_back()
	current = frame.screen
	world.state = frame.state
	return true

func depth() -> int:
	return stack.size()

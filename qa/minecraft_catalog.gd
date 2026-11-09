extends "res://scripts/main.gd"
## Use the production item renderer on an isolated review canvas.
var reviewer

func _draw():
	if reviewer != null: reviewer.draw_catalog()

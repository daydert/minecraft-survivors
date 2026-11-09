extends Node2D
func _init():
	material=ShaderMaterial.new()
	material.shader=load("res://shaders/blood_rift.gdshader")
	z_index=50
	visible=false
func configure(enabled: bool, at: Vector2, progress: float, phase: float, wipe: float=0):
	visible=enabled
	if not enabled:return
	material.set_shader_parameter("center",at/Vector2(640,360))
	material.set_shader_parameter("progress",progress)
	material.set_shader_parameter("phase",phase)
	material.set_shader_parameter("wipe",wipe)
	queue_redraw()
func _draw():draw_rect(Rect2(0,0,640,360),Color.WHITE)

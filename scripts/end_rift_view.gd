extends Node2D
func _init():
	material=ShaderMaterial.new();material.shader=preload("res://shaders/end_rift.gdshader");z_index=49;visible=false
func configure(enabled: bool, at: Vector2, power: float, phase: float):
	visible=enabled
	if not enabled:return
	material.set_shader_parameter("center",at/Vector2(640,360));material.set_shader_parameter("power",power);material.set_shader_parameter("phase",phase);queue_redraw()
func _draw():draw_rect(Rect2(0,0,640,360),Color.WHITE)

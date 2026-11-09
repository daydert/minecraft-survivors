extends Node2D
## The secret-ending body survives the screen wipe and sinks behind the portal.
const TEXTURE=preload("res://assets/sprites/herobrine_remains.png")
const FRAME=48
var game

func _init():
	z_index=51
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	visible=false

func scene():
	if not is_instance_valid(game) or not game.screen.is_empty() or game.world.state!="FINALE":return null
	var f=game.world.finale
	if not f.has_method("duel_phase") or not f.first_stage_won or f.phase not in ["vanish","portal","fall"]:return null
	if f.phase=="fall" and f.phase_age>=1.65:return null
	return f

func _ready():refresh()
func _process(_delta):refresh()
func refresh():
	visible=scene()!=null
	if visible:queue_redraw()

func _draw():
	var f=scene()
	if f==null:return
	var ground: Vector2=game.world.player+Vector2(320,180)-game.world.camera()
	var alpha=smoothstep(.35,1.05,f.phase_age) if f.phase=="vanish" else 1.0
	var settle=smoothstep(.4,1.5,f.phase_age) if f.phase=="vanish" else 1.0
	var frames=TEXTURE.get_width()/FRAME
	var frame=mini(frames-1,int(settle*frames))
	var drop=smoothstep(.2,1.55,f.phase_age) if f.phase=="fall" else 0.0
	var scale=Vector2(1-.55*drop,1-.65*drop)
	var at=ground+Vector2(0,-5+32*drop*drop)
	g_shadow(ground,alpha*(1-drop))
	draw_set_transform(at.floor(),0,scale)
	for row in range(0,FRAME,2):
		var height=2.0
		if f.phase=="fall":
			# Clip the sinking body at the horizontal surface of the portal.
			height=minf(height,(ground.y+12-at.y)/scale.y-(row-24))
		if height<=0:continue
		draw_texture_rect_region(TEXTURE,Rect2(-24,row-24,FRAME,height),Rect2(frame*FRAME,row,FRAME,height),Color(1,.72,.68,alpha*(1-smoothstep(.85,1,drop))))
	draw_set_transform(Vector2.ZERO)

func g_shadow(at: Vector2,alpha: float):
	draw_set_transform(at.floor(),0,Vector2(1,.25))
	draw_circle(Vector2.ZERO,13,Color(0,0,0,.4*alpha))
	draw_set_transform(Vector2.ZERO)

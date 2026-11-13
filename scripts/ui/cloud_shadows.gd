extends RefCounted
## A ground texture, independent of the actor-shadow setting. Frozen by world
## time and removed as soon as Herobrine's encounter starts. Chapter I only.
static func draw(g,offset: Vector2):
 if g.is_nether() or g.is_end() or g.is_four() or g.is_five() or g.world.finale.active:return
 if not g.textures.has("cloud_shadow"):g.load_texture("cloud_shadow")
 var texture: Texture2D=g.textures.get("cloud_shadow")
 if texture==null:return
 # One cloud texel per 12 px: the shadows read as the square vanilla cloud cells.
 var tile: Vector2=Vector2(texture.get_size())*12.0
 var drift:=Vector2(g.world.clock*9.0,0.0)
 var origin:=Vector2i(((-offset-drift)/tile).floor())
 for y in range(origin.y,origin.y+2):
  for x in range(origin.x,origin.x+2):
   g.draw_texture_rect(texture,Rect2((Vector2(x,y)*tile+offset+drift).floor(),tile),false)

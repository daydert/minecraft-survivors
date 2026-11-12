extends RefCounted
## One continuous, nearest-sampled pixel puddle. The projected ellipse sits on
## the floor; flying potions and their particles have a separate air pass.
static func draw(g,p: Vector2,radius: float,alpha: float):
 if not g.textures.has("witch_puddle"):g.load_texture("witch_puddle")
 var texture: Texture2D=g.textures.get("witch_puddle")
 if texture==null:return
 g.draw_texture_rect(texture,Rect2((p-Vector2(radius,radius*.5)).floor(),Vector2(radius*2,radius)),false,Color(1,1,1,alpha))

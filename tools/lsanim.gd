extends Node
func _ready() -> void:
	for rel in ["jimmy.glb","nummey.glb","nummey_villain.glb","jetpack.glb"]:
		var n := Assets.load_scene(rel)
		if n == null: continue
		for ap in n.find_children("*","AnimationPlayer",true,false):
			print(rel, " ", (ap as AnimationPlayer).get_animation_list(), " ")
		for mi in n.find_children("*","MeshInstance3D",true,false):
			var m := mi as MeshInstance3D
			if m.mesh and m.mesh.get_blend_shape_count()>0:
				print(rel," blend ", m.name, " ", m.mesh.get_blend_shape_count())
	get_tree().quit()

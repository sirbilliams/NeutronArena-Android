extends Node
func _ready() -> void:
	var m := Assets.load_scene("jimmy.glb") as Node3D
	add_child(m)
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	for n in ["Bip01 L Toe0", "Bip01 R Toe0", "Bip01 L Foot", "Bip01 L Calf"]:
		print(n, " rest local ", sk.get_bone_rest(sk.find_bone(n)).origin)
	var b := Assets.load_scene("ase/n2/goofbootfly.glb") as Node3D
	print("boot aabb ", Fx.aabb_of(b))
	get_tree().quit()

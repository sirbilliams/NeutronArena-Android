class_name FeelMod
extends SkeletonModifier3D
## Runs after the AnimationPlayer each frame and adds two procedural spine offsets (world-space rotations, no clip needed):
## twist  - counter-rotates the torso about the vertical axis so the legs can be turned towards the move direction while the upper body keeps facing the aim (strafe / backpedal)
## flinch - short backward lean + head snap (rotation about the model's right axis), amplitude 0..1
var twist := 0.0          # rad, torso counter-rotation (legs are turned by +twist on the model root)
var flinch := 0.0         # 0..1 envelope
var flinch_side := 0.0    # -1..1 lateral component
var facing := 0.0         # world yaw of the model (Player.model_yaw)
var spine_name := "Bip01 Spine"
var head_name := "Bip01 Head"
const FLINCH_BACK := 0.32  # rad at amplitude 1
const FLINCH_HEAD := 0.30

func _rot_world(sk: Skeleton3D, idx: int, axis_world: Vector3, ang: float) -> void:
	if idx < 0 or absf(ang) < 0.0005:
		return
	var w := sk.global_transform.basis
	var ax := (w.inverse() * axis_world).normalized()
	var gp := sk.get_bone_global_pose(idx)
	gp.basis = Basis(ax, ang) * gp.basis
	sk.set_bone_global_pose(idx, gp)

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or (absf(twist) < 0.0005 and flinch < 0.001):
		return
	var spine := sk.find_bone(spine_name)
	var head := sk.find_bone(head_name)
	var right := Vector3(cos(facing), 0.0, -sin(facing))
	var fwd := Vector3(-sin(facing), 0.0, -cos(facing))
	if absf(twist) > 0.0005:
		_rot_world(sk, spine, Vector3.UP, -twist)
	if flinch > 0.001:
		_rot_world(sk, spine, right, flinch * FLINCH_BACK)
		_rot_world(sk, spine, fwd, -flinch * flinch_side * 0.18)
		_rot_world(sk, head, right, flinch * FLINCH_HEAD)

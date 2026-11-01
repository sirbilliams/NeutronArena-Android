extends Node3D
## Walk -> run -> stop probe: per-frame world rotation of head / neck / spine / pelvis + pelvis height, active clip, speed_scale.
## godot --headless --fixed-fps 60 --path . res://tools/walkprobe.tscn -- [--team=0|1] [--csv=path]
class StubWorld extends Node:
	var match_over := false
	func local_team() -> int:
		return 0
const BONES := ["Bip01 Head", "Bip01 Neck", "Bip01 Spine", "Bip01 Pelvis"]
var player: Player
var prev := {}
var maxj := {}
var spikes := []
var csv := ""
var rows := PackedStringArray()

func _ready() -> void:
	var team := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--team="): team = int(a.substr(7))
		if a.begins_with("--csv="): csv = a.substr(6)
	Config.test_mode = true
	var sb := StaticBody3D.new(); sb.collision_layer = 1
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(400, 2, 400); cs.shape = sh; sb.add_child(cs); sb.position = Vector3(0, -1, 0); add_child(sb)
	player = Player.new(); player.peer_id = 1; player.team = team; player.world = StubWorld.new(); player.position = Vector3(0, 0.05, 0)
	add_child(player)
	for i in 40: await get_tree().physics_frame
	var sk: Skeleton3D = player.model.find_children("*", "Skeleton3D", true, false)[0]
	var idx := {}
	for b in BONES: idx[b] = sk.find_bone(b)
	print("bones ", idx, " tracks idle/walk/run ", player.anim.get_animation("jimmyidle").get_track_count(), "/", player.anim.get_animation("jimmywalk").get_track_count(), "/", player.anim.get_animation("jimmyfullrun").get_track_count())
	var phases := [["idle", Vector2.ZERO, 1.0], ["walk", Vector2(0, -0.15), 2.0], ["mid", Vector2(0, -0.35), 1.0], ["run", Vector2(0, -1.0), 2.2], ["stop", Vector2.ZERO, 1.2]]
	var f := 0
	for ph in phases:
		player.test_move = ph[1]
		var n := int(ph[2] * 60)
		for i in n:
			await get_tree().process_frame
			await get_tree().physics_frame
			f += 1
			var q := {}
			for b in BONES:
				var gb := sk.global_transform.basis * sk.get_bone_global_pose(idx[b]).basis
				q[b] = gb.orthonormalized().get_rotation_quaternion()
			var py := (sk.global_transform * sk.get_bone_global_pose(idx["Bip01 Pelvis"]).origin).y
			var ap := player.anim
			var line := "%d,%s,%s,%.2f,%.3f,%.3f,%.3f" % [f, ph[0], ap.current_animation, ap.speed_scale, ap.current_animation_position, player.h_speed, py]
			for b in BONES:
				var j := 0.0
				if prev.has(b):
					j = rad_to_deg((prev[b] as Quaternion).angle_to(q[b]))
				maxj[b] = maxf(maxj.get(b, 0.0), j)
				if j > 15.0:
					spikes.append("f%d %s %s %s pos=%.3f spd=%.2f jump=%.1f" % [f, ph[0], b, ap.current_animation, ap.current_animation_position, ap.speed_scale, j])
				line += ",%.1f" % j
			if (f>=59 and f<=70) or (f>=313 and f<=324): print('POSE f',f,ph[0],'head euler(deg)',(Basis(q['Bip01 Head'])*Vector3(0,0,-1)),'headfwdLocalToModel', (Basis(player.model.global_transform.basis.get_rotation_quaternion().inverse()*(q['Bip01 Head'] as Quaternion))).get_euler()*57.2958)
			prev = q
			rows.append(line)
	print("MAX JUMP deg/frame: ", maxj)
	print("spikes(>15deg): ", spikes.size())
	for s in spikes.slice(0, 40): print("  ", s)
	if csv != "":
		var fa := FileAccess.open(csv, FileAccess.WRITE)
		fa.store_line("frame,phase,clip,speed,animpos,hspeed,pelvis_y,j_head,j_neck,j_spine,j_pelvis")
		for r in rows: fa.store_line(r)
	get_tree().quit()

extends Node
## Character select screenshots, both teams (+ a locked Libby variant). tools/vrun.sh res://tools/shots_charsel.tscn -- --out=DIR
var out := "/home/bill/Projects/arena-assets/shots/chars"

func shot(name: String) -> void:
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var layer := CanvasLayer.new(); add_child(layer)
	var cs := CharacterSelect.new()
	cs.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cs)
	cs.open(Config.TEAM_JIMMY, &"carl")
	await get_tree().create_timer(2.0).timeout
	await shot("select_jimmy_team")
	cs.open(Config.TEAM_NEGATRON, &"ecindy")
	await get_tree().create_timer(2.0).timeout
	await shot("select_negatron_team")
	Characters.debug_locked = [&"libby"]
	cs.open(Config.TEAM_JIMMY, &"jimmy")
	(cs._cards[&"libby"] as Button).grab_focus()
	await get_tree().create_timer(1.5).timeout
	await shot("select_libby_locked")
	get_tree().quit()

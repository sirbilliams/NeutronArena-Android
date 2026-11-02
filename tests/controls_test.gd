extends "res://scripts/net_test.gd"
## Headless controls test (tests/run_controls_test.sh): L1/R1 item cycling, R2 firing the selected item, gyro off/on.
func _ready() -> void:
	_ct()

func _lo(g: StringName) -> Dictionary:
	return {&"primary": &"bubble_gun", &"gadget": g, &"movement": &"sprint", &"ultimate": &"rocket_ship"}

func _has_btn(action: String, b: JoyButton) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == b:
			return true
	return false

func _ct() -> void:
	check(await main.start_host(), "host started")
	world = main.world
	check(await wait_for(func(): return world.players.has(1) and world.info.has(1), 40.0), "host player spawned")
	var me: Player = world.players[1]
	# --- input map
	check(_has_btn("item_prev", JOY_BUTTON_LEFT_SHOULDER) and _has_btn("item_next", JOY_BUTTON_RIGHT_SHOULDER), "L1 = item_prev, R1 = item_next")
	var r2 := false
	for e in InputMap.action_get_events("fire"):
		if e is InputEventJoypadMotion and e.axis == JOY_AXIS_TRIGGER_RIGHT:
			r2 = true
	check(r2, "R2 = fire")
	check(not _has_btn("gadget", JOY_BUTTON_LEFT_SHOULDER) and not _has_btn("movement", JOY_BUTTON_RIGHT_SHOULDER), "L1/R1 no longer bound to gadget/movement")
	# --- cycling order + wrap
	var kinds := func() -> Array:
		var out := []
		for i in me.item_list(): out.append(i.kind)
		return out
	check(kinds.call() == [&"weapon", &"gadget", &"ultimate"], "items: weapon, gadget, ultimate %s" % str(kinds.call()))
	me.sel_item = 0
	var seq := []
	for i in 4:
		me.cycle_item(1); seq.append(me.selected_kind())
	check(seq == [&"gadget", &"ultimate", &"weapon", &"gadget"], "R1 cycles forward and wraps %s" % str(seq))
	seq = []
	for i in 4:
		me.cycle_item(-1); seq.append(me.selected_kind())
	check(seq == [&"weapon", &"ultimate", &"gadget", &"weapon"], "L1 cycles backward and wraps %s" % str(seq))
	# --- R2 with the weapon selected: keeps firing, no gadget
	var inf: Dictionary = world.info[1]
	inf.gadget_ready = 0.0; me.gadget_cd = 0.0
	check(me.item_fire(true, true) and not me.item_fire(false, false), "weapon selected: fire held -> weapon fires, released -> stops")
	check(me.gadget_cd == 0.0 and inf.gadget_ready == 0.0, "weapon selected: no gadget used")
	# --- R2 fires every gadget through the server, cooldowns respected
	for gid in GadgetData.all_ids():
		world.info[1].pending = Loadout.sanitize(_lo(gid))
		world._srv_apply_loadout(1, false)
		check(await wait_for(func(): return me.gadget.id == gid, 5.0), "loadout has gadget %s" % gid)
		inf = world.info[1]
		inf.gadget_ready = 0.0; me.gadget_cd = 0.0
		me.sel_item = 0; me.cycle_item(1)
		var cd := GadgetData.get_gadget(gid).f("cooldown")
		var held := me.item_fire(true, true)
		check(not held and me.gadget_cd > cd - 0.5, "%s: R2 fired it (client cooldown %.1f)" % [gid, me.gadget_cd])
		await get_tree().create_timer(0.3).timeout
		var ready: float = inf.gadget_ready
		check(ready > world._now() + cd * 0.5, "%s: server started the cooldown" % gid)
		me.gadget_cd = 0.0   # even if the client allowed it, the server refuses during cooldown
		me.item_fire(true, true)
		await get_tree().create_timer(0.3).timeout
		check(is_equal_approx(inf.gadget_ready, ready), "%s: second R2 during cooldown rejected by the server" % gid)
	# --- R2 fires the selected ultimate (needs charge)
	world.info[1].pending = Loadout.sanitize(_lo(&"energy_shield"))
	world._srv_apply_loadout(1, false)
	await get_tree().create_timer(0.3).timeout
	inf = world.info[1]
	me.sel_item = 2
	me.ult_charge = 0; inf.ult_charge = 0
	me.item_fire(true, true)
	await get_tree().create_timer(0.3).timeout
	check(not world.srv_has(1, "ult"), "ultimate without charge: R2 does nothing")
	var cost := int(me.ultimate.f("cost"))
	me.ult_charge = cost; inf.ult_charge = cost
	me.item_fire(true, true)
	check(await wait_for(func(): return world.srv_has(1, "ult"), 5.0), "ultimate with charge: R2 activates it (server)")
	# --- gyro
	Config.gyro_enabled = false
	Config.gyro_sens = 1.0; Config.gyro_invert_y = false
	me.cam_yaw = 0.0; me.cam_pitch = 0.0
	me.apply_gyro(Vector3(2, 3, 1), 0.1)
	check(me.cam_yaw == 0.0 and me.cam_pitch == 0.0, "gyro off: camera unchanged")
	check(Config.gyro_enabled == false and not Config.gyro_supported(), "gyro defaults off, unsupported on desktop")
	Config.gyro_enabled = true
	me.apply_gyro(Vector3(2, 3, 1), 0.1)
	check(is_equal_approx(me.cam_yaw, 0.3) and is_equal_approx(me.cam_pitch, 0.2), "gyro on: yaw +0.3, pitch +0.2")
	Config.gyro_invert_y = true
	me.cam_pitch = 0.0
	me.apply_gyro(Vector3(2, 0, 0), 0.1)
	check(is_equal_approx(me.cam_pitch, -0.2), "invert Y flips pitch")
	Config.gyro_sens = 2.0
	me.cam_yaw = 0.0
	me.apply_gyro(Vector3(0, 1, 0), 0.1)
	check(is_equal_approx(me.cam_yaw, 0.2), "sensitivity scales")
	Config.gyro_enabled = false
	Config.gyro_sens = 1.0; Config.gyro_invert_y = false
	await finish()

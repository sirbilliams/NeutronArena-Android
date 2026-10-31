extends "res://scripts/net_test.gd"
## Headless loadout test (tests/run_loadout_test.sh). Roles lo_server, lo_client, lo_observer on localhost.
func _ready() -> void:
	match role:
		"server": _lo_server()
		"client": _lo_client()
		"observer": _lo_observer()

func _connected() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _lo(primary: StringName, gadget: StringName, movement: StringName, ult: StringName) -> Dictionary:
	return {&"primary": primary, &"gadget": gadget, &"movement": movement, &"ultimate": ult}

func _set_srv_loadout(id: int, lo: Dictionary) -> void:
	world.info[id].pending = Loadout.sanitize(lo)
	world._srv_apply_loadout(id, false)

# ---------------------------------------------------------------- server
func _lo_server() -> void:
	check(await main.start_host(), "host started")
	world = main.world
	check(await wait_for(func(): return world.players.size() >= 3, 40.0), "3 players joined")
	var cid := 0
	for id in world.players:
		if world.players[id].team == Config.TEAM_NEGATRON:
			cid = id
	var me: Player = world.players[1]
	var vic: Player = world.players[cid]
	# --- loadout choice replicates + applies (first confirm = first spawn: immediate)
	check(await wait_for(func(): return world.info[cid].loadout.primary == &"mega_burp", 40.0), "client's Heavy choice reached the server and applied on first spawn")
	check(world.info[cid].max_hp == 150 and world.info[cid].hp == 150, "Heavy has 150 HP (server)")
	check(vic.max_hp == 150, "Heavy max_hp on server-side player node")
	check(world.info[cid].loadout.movement == &"none", "Heavy has no movement ability")
	check(await wait_for(func(): return world.info[cid].pending.get(&"primary", &"") == &"burp_gun", 40.0), "second choice (Blaster) queued as pending")
	check(world.info[cid].loadout.primary == &"mega_burp", "pending choice NOT applied before respawn")
	world.srv_hit(cid, 1, 1000)
	await get_tree().create_timer(Config.RESPAWN_TIME + 1.0).timeout
	check(world.info[cid].alive and world.info[cid].loadout.primary == &"burp_gun" and world.info[cid].max_hp == 100 and world.info[cid].hp == 100, "pending Blaster loadout applied on respawn (hp back to 100)")
	check(vic.weapon.id == &"burp_gun" and vic.max_hp == 100, "server-side player node updated")
	world.info[1].ult_charge = 0
	# --- gadget used by the client through the network (client -> server RPC)
	me.global_position = vic.global_position + Vector3(0, 0.1, -6.0)
	me.velocity = Vector3.ZERO
	check(await wait_for(func(): return world.srv_has(1, "shrink"), 30.0), "client's shrink ray (RPC) shrank the host")
	# --- every primary damages
	var tp := func(): me.global_position = vic.global_position + Vector3(0, 0.1, -6.0); me.velocity = Vector3.ZERO
	var res := {}
	for wid in [&"bubble_gun", &"burp_gun", &"water_gun", &"mega_burp", &"baseball"]:
		_set_srv_loadout(1, _lo(wid, &"shrink_ray", &"sprint", &"rocket_ship"))
		tp.call()
		_reset_victim(cid)
		world.info[1].last_fire = -10.0
		await get_tree().create_timer(0.5).timeout
		var w: WeaponData = me.weapon
		check(w.id == wid, "host holds %s" % wid)
		me.fire_cd = 0.0
		await _shoot_at(me, vic, w, 1.0)
		await get_tree().create_timer(1.2).timeout
		var d: int = 100 - world.info[cid].hp
		res[wid] = d
		check(d > 0, "%s damages (%d)" % [wid, d])
		if wid == &"water_gun":
			check(world.srv_has(cid, "slow"), "water gun slows the target")
		if wid == &"mega_burp":
			check(d == 70, "Mega Burp full charge = 70 (%d)" % d)
		if wid == &"bubble_gun":
			check(d == 20, "bubble gun = 20")
	# --- shrink ray multiplier
	_set_srv_loadout(1, _lo(&"bubble_gun", &"shrink_ray", &"sprint", &"rocket_ship"))
	world.info[1].gadget_ready = 0.0
	tp.call()
	_reset_victim(cid)
	await get_tree().create_timer(0.5).timeout
	world._srv_gadget(1, me.muzzle(), ((vic.global_position + Vector3(0, 0.8, 0)) - me.muzzle()).normalized())
	await get_tree().create_timer(0.4).timeout
	check(world.srv_has(cid, "shrink"), "shrink ray hit the target")
	world.info[1].last_fire = -10.0
	me.fire_cd = 0.0
	await _shoot_at(me, vic, me.weapon, 1.0)
	await get_tree().create_timer(1.0).timeout
	check(100 - world.info[cid].hp == 30, "shrunk target takes +50%%: 20 -> %d" % (100 - world.info[cid].hp))
	# --- energy shield absorbs
	_set_srv_loadout(cid, _lo(&"burp_gun", &"energy_shield", &"goof_boots", &"goddard_scooter"))
	world.info[cid].st.erase("shrink")
	_reset_victim(cid)
	world.info[cid].gadget_ready = 0.0
	world._srv_gadget(cid, vic.global_position + Vector3(0, 1, 0), Vector3.FORWARD)
	await get_tree().create_timer(0.4).timeout
	check(world.srv_has(cid, "shield") and world.info[cid].shield_hp == 60, "shield active with 60 absorb")
	world.info[1].last_fire = -10.0
	me.fire_cd = 0.0
	tp.call()
	await get_tree().create_timer(0.4).timeout
	await _shoot_at(me, vic, me.weapon, 1.0)
	await get_tree().create_timer(1.0).timeout
	check(world.info[cid].hp == 100 and world.info[cid].shield_hp == 40, "bubble absorbed by shield (hp %d, shield %d)" % [world.info[cid].hp, world.info[cid].shield_hp])
	world.srv_hit(cid, 1, 100)
	check(world.info[cid].hp == 40 and world.info[cid].shield_hp == 0, "overflow damage passes after shield breaks (hp %d)" % world.info[cid].hp)
	# --- power phase: invulnerable, can't shoot
	await get_tree().create_timer(0.3).timeout
	_set_srv_loadout(cid, _lo(&"bubble_gun", &"power_phase", &"sprint", &"goddard_scooter"))
	_reset_victim(cid)
	world.info[cid].gadget_ready = 0.0
	world._srv_gadget(cid, vic.global_position + Vector3(0, 1, 0), Vector3.FORWARD)
	check(world.srv_has(cid, "phase"), "power phase active")
	world.srv_hit(cid, 1, 50)
	check(world.info[cid].hp == 100, "phase = invulnerable")
	# --- ultimate: charges from damage, then activates
	_set_srv_loadout(1, _lo(&"bubble_gun", &"energy_shield", &"sprint", &"rocket_ship"))
	world.info[1].ult_charge = 0
	world._srv_ultimate(1)
	check(not world.srv_has(1, "ult"), "ultimate refused while uncharged")
	var cost := int(UltimateData.get_ultimate(&"rocket_ship").f("cost"))
	world.info[cid].st.erase("phase")
	tp.call()
	var shots := 0
	while world.info[1].ult_charge < cost and shots < 20:
		_reset_victim(cid)
		world.info[1].last_fire = -10.0
		me.fire_cd = 0.0
		await _shoot_at(me, vic, me.weapon, 1.0)
		await get_tree().create_timer(0.7).timeout
		shots += 1
	check(world.info[1].ult_charge >= cost, "ultimate charged from damage dealt (%d / %d after %d shots)" % [world.info[1].ult_charge, cost, shots])
	world._srv_ultimate(1)
	check(world.srv_has(1, "ult") and world.info[1].ult_charge == 0, "ultimate activated, charge spent")
	_reset_victim(cid)
	world.info[1].last_fire = -10.0
	me.fire_cd = 0.0
	await get_tree().create_timer(0.3).timeout
	await _shoot_at(me, vic, me.effective_weapon(), 1.0)
	await get_tree().create_timer(1.0).timeout
	check(100 - world.info[cid].hp == 45, "rocket ship fires rockets: 45 damage (%d)" % (100 - world.info[cid].hp))
	await get_tree().create_timer(8.0).timeout
	await finish()

func _reset_victim(cid: int) -> void:
	world.info[cid].hp = 100
	world.info[cid].alive = true
	world.c_hp.rpc(cid, 100)

func _shoot_at(shooter: Player, target: Player, w: WeaponData, chg: float) -> void:
	var tp := target.global_position + Vector3(0, 0.7, 0)
	var dist := shooter.muzzle().distance_to(tp)
	var t := dist / w.projectile_speed
	tp.y += 0.5 * w.gravity * t * t
	shooter.fire((tp - shooter.muzzle()).normalized(), chg)

# ---------------------------------------------------------------- client
func _lo_client() -> void:
	check(await main.start_join("127.0.0.1"), "joined")
	world = main.world
	check(await wait_for(func(): return world.players.has(multiplayer.get_unique_id()), 20.0), "own player spawned")
	var me: Player = world.players[multiplayer.get_unique_id()]
	await get_tree().create_timer(1.0).timeout
	world.request_loadout(Loadout.from_class(&"heavy"))
	check(await wait_for(func(): return me.loadout.primary == &"mega_burp" and me.max_hp == 150, 20.0), "client sees confirmed Heavy loadout (replicated) with 150 max HP")
	check(me.hp == 150, "client hp 150")
	await get_tree().create_timer(1.5).timeout
	world.request_loadout(Loadout.from_class(&"blaster"))
	check(await wait_for(func(): return me.pending_loadout.get(&"primary", &"") == &"burp_gun", 20.0), "client sees its queued loadout")
	check(me.loadout.primary == &"mega_burp", "client still Heavy until respawn")
	check(await wait_for(func(): return me.loadout.primary == &"burp_gun" and me.alive, 40.0), "client got Blaster loadout after respawn")
	check(me.max_hp == 100 and me.hp == 100 and me.gadget.id == &"shrink_ray" and me.movement.id == &"goof_boots", "Blaster slots: burp gun / shrink ray / goof boots")
	var host: Player = world.players[1]
	check(await wait_for(func(): return host.global_position.distance_to(me.global_position) < 12.0, 60.0), "host came close")
	await get_tree().create_timer(0.6).timeout
	me.try_gadget(((host.global_position + Vector3(0, 0.8, 0)) - me.muzzle()).normalized())
	check(await wait_for(func(): return me.has_status("shield"), 90.0), "client saw its own shield status replicated")
	check(await wait_for(func(): return not _connected(), 150.0), "server finished")
	await finish()

# ---------------------------------------------------------------- observer
func _lo_observer() -> void:
	check(await main.start_join("127.0.0.1"), "joined")
	world = main.world
	check(await wait_for(func(): return world.players.size() >= 3, 30.0), "sees 3 players")
	var cl: Player = null
	for p in world.players.values():
		if p.team == Config.TEAM_NEGATRON:
			cl = p
	check(await wait_for(func(): return cl.loadout.primary == &"mega_burp" and cl.max_hp == 150, 60.0), "observer sees client's Heavy loadout")
	check(await wait_for(func(): return cl.loadout.primary == &"burp_gun" and cl.max_hp == 100, 60.0), "observer sees client's Blaster loadout after respawn")
	check(await wait_for(func(): return world.players[1].has_status("ult"), 150.0), "observer sees host's ultimate active")
	check(await wait_for(func(): return not _connected(), 150.0), "server finished")
	await finish()

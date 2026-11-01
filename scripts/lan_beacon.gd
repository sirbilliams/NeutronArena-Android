class_name LanBeacon
extends Node
## LAN discovery over UDP. Host mode: broadcasts a small JSON beacon once per second. Listen mode: collects beacons.
## Packet: {"g":"neutron-arena","v":1,"name","players","bots","max","map","port"}.
const MAGIC := "neutron-arena"
const EXPIRE := 4.0
var mode := ""                  # "host" | "listen"
var udp := PacketPeerUDP.new()
var info_cb := Callable()       # host: returns {name, players, bots, max, map, port}
var found := {}                 # "ip:port" -> {ip, port, name, players, bots, max, map, seen}
var t := 0.0
signal changed

static func host_name() -> String:
	var n := OS.get_environment("USER")
	if n == "":
		n = OS.get_model_name()
	if n == "" or n == "GenericDevice":
		n = "Host"
	return n

func start_host(cb: Callable) -> void:
	mode = "host"
	info_cb = cb
	udp.set_broadcast_enabled(true)
	t = 0.0

func start_listen() -> bool:
	mode = "listen"
	var err := udp.bind(Config.beacon_port, "*")
	if err != OK:
		push_warning("LAN beacon listen failed: %d" % err)
		return false
	return true

func _exit_tree() -> void:
	udp.close()

func _process(dt: float) -> void:
	if mode == "host":
		t -= dt
		if t <= 0.0:
			t = 1.0
			var d: Dictionary = info_cb.call()
			d["g"] = MAGIC
			d["v"] = 1
			var pkt := JSON.stringify(d).to_utf8_buffer()
			for addr in ["255.255.255.255", "127.0.0.1"]:
				udp.set_dest_address(addr, Config.beacon_port)
				udp.put_packet(pkt)
	elif mode == "listen":
		var dirty := false
		while udp.get_available_packet_count() > 0:
			var ip := udp.get_packet_ip()
			var txt := udp.get_packet().get_string_from_utf8()
			var d = JSON.parse_string(txt)
			if typeof(d) != TYPE_DICTIONARY or d.get("g", "") != MAGIC:
				continue
			var port := int(d.get("port", Config.PORT))
			var key := "%s:%d" % [ip, port]
			if not found.has(key):
				dirty = true
			found[key] = {"ip": ip, "port": port, "name": str(d.get("name", "?")), "players": int(d.get("players", 0)), "bots": int(d.get("bots", 0)), "max": int(d.get("max", 10)), "map": str(d.get("map", "")), "seen": Time.get_ticks_msec() / 1000.0}
		var now := Time.get_ticks_msec() / 1000.0
		for k in found.keys():
			if now - found[k].seen > EXPIRE:
				found.erase(k)
				dirty = true
		if dirty:
			changed.emit()

func games() -> Array:
	return found.values()

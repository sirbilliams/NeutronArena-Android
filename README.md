# Negatron Arena (Phase 1 prototype)

Original 5v5 bubble-gun team deathmatch (Jimmy vs Negatron). Loads character and level art at runtime from the
player's own game export (glb files, never committed). Godot 4.7.

Assets folder (default `~/Projects/arena-assets`, change in the menu or `NEGATRON_ASSETS=...`) must contain
`levels/level5c.glb`, `jimmy.glb`, `nummey_villain.glb`, `nummey.glb`.

Run: `godot --path . ` then Host / Join (IP). CLI: `-- --host`, `-- --join=IP`, `-- --port=N`.
Controls: WASD + mouse + LMB, or left stick / right stick / RT, A = jump, Esc frees the mouse.
Loadout (4 slots, all numbers in scripts/balance.gd): gadget Q / LB, movement Shift / RB (hold; also A-hold = jetpack, A in air = double jump/glide),
ultimate F / LB+RB (charges from damage dealt), loadout menu L / Back (also opens on first spawn and while dead; applies on respawn).
Test: `tests/run_net_test.sh` (headless server + client + observer on localhost).
Screenshots: `tools/vrun.sh res://tools/shots.tscn` (nested virtual KWin, needs a GPU).
Loadout test: `tests/run_loadout_test.sh` (host + client + observer over localhost). Loadout shots: `tools/vrun.sh res://tools/shots_loadout.tscn`.

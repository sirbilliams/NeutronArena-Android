# Negatron Arena (Phase 1 prototype)

Original 5v5 bubble-gun team deathmatch (Jimmy vs Negatron). Loads character and level art at runtime from the
player's own game export (glb files, never committed). Godot 4.7.

Assets folder (default `~/Projects/arena-assets`, change in the menu or `NEGATRON_ASSETS=...`) must contain
`levels/level5c.glb`, `jimmy.glb`, `nummey_villain.glb`, `nummey.glb`.

Run: `godot --path . ` then Host / Join (IP). CLI: `-- --host`, `-- --join=IP`, `-- --port=N`.
Controls: WASD + mouse + LMB, or left stick / right stick / RT (R1), A = jump, Esc frees the mouse.
Test: `tests/run_net_test.sh` (headless server + client + observer on localhost).
Screenshots: `tools/vrun.sh res://tools/shots.tscn` (nested virtual KWin, needs a GPU).

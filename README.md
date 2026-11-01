# Negatron Arena (Phase 1 prototype)

Original 5v5 bubble-gun team deathmatch (Jimmy vs Negatron). Loads character and level art at runtime from the
player's own game export (glb files, never committed). Godot 4.7.

Assets folder (default `~/Projects/arena-assets`, change in the menu or `NEGATRON_ASSETS=...`) must contain
`levels/level5c.glb`, `jimmy.glb`, `nummey_villain.glb`, `nummey.glb`.

Run: `godot --path . ` then Host / Join (IP). CLI: `-- --host`, `-- --join=IP`, `-- --port=N`.
Controls: WASD + mouse + LMB, or left stick / right stick / RT (R1), A = jump, Esc frees the mouse.
Test: `tests/run_net_test.sh` (headless server + client + observer on localhost).
Screenshots: `tools/vrun.sh res://tools/shots.tscn` (nested virtual KWin, needs a GPU).

## Map (5v5)
`LAYOUT` in `scripts/arena_level.gd`: "museum" (default) = Candy Bar (Jimmy) to museum plaza (Negatron), ~392 m apart, one fenced
rectangle over the serpentine street route (blocks between legs are open = flanks); "compact" = the 124 m street block at the Candy Bar end.
Forward spawn zones (2 per team, data in `LAYOUTS[..].fwd`): a dead player respawns at the most forward team zone with no living
enemy within 25 m, else the next one back, finally the base (server decides, `World._respawn_spawn`). Cover along the route is generated (one MultiMesh).
Level load: play area stays one batch (fewest draw calls), far backdrop is chunked + range-limited.
Tests: `tests/run_net_test.sh`, `tests/run_zone_test.sh` (forward-spawn rule). Perf: `tools/vrun.sh res://tools/perf.tscn [-- --core=12000]`.

## Android (AYN Thor, arm64, Compatibility/GLES3 renderer)
One-time setup (everything under `~`, no sudo; the flatpak sees the whole host):
```
# Godot export templates 4.7.2 (android_debug.apk, android_release.apk, android_source.zip, version.txt)
#   -> ~/.var/app/org.godotengine.Godot/data/godot/export_templates/4.7.2.stable/
# JDK 17 (Temurin tarball)  -> ~/.local/share/jdk/jdk-17.0.21+9
# Android SDK cmdline-tools -> ~/Android/Sdk/cmdline-tools/latest, then:
sdkmanager --sdk_root=$HOME/Android/Sdk "platform-tools" "build-tools;36.1.0" "platforms;android-36"
# debug keystore (kept outside the repo)
keytool -genkeypair -keystore ~/.local/share/negatron-arena-keys/debug.keystore -storepass android \
  -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
# ~/.var/app/org.godotengine.Godot/config/godot/editor_settings-4.7.tres:
#   export/android/java_sdk_path, export/android/android_sdk_path, export/android/debug_keystore(_user/_pass)
```
Build (headless, output outside the repo):
```
flatpak run org.godotengine.Godot --headless --path . --export-debug "Android Thor" ~/Projects/arena-assets/build/negatron-arena-debug.apk
aapt dump badging ~/Projects/arena-assets/build/negatron-arena-debug.apk | head -3   # build-tools/36.1.0
apksigner verify --print-certs ~/Projects/arena-assets/build/negatron-arena-debug.apk
```
Install: `adb install -r negatron-arena-debug.apk` (or copy the apk to the Thor and open it).

Game files on the Thor: copy your exported files to `/sdcard/NegatronArena/` keeping the layout
(`levels/level5c.glb`, `jimmy.glb`, `nummey.glb`, `nummey_villain.glb`), e.g.
`adb push ~/Projects/arena-assets/levels ~/Projects/arena-assets/*.glb /sdcard/NegatronArena/` (push into the `levels` dir by hand if adb flattens it).
On first start the app asks for "All files access"; if the assets are missing it shows the folder to copy to and a re-check button.
Also searched: `/sdcard/Android/data/com.negatronarena.game/files/NegatronArena` (needs no permission when pushed with adb).

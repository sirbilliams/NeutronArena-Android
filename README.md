# Negatron Arena (Phase 1 prototype)

Original 5v5 bubble-gun team deathmatch (Jimmy vs Negatron). The art comes from the player's own copies of the PC games and is
imported **inside the app** (nothing is bundled or committed): first launch shows a Setup screen, the player picks their Jimmy Neutron vs.
Jimmy Negatron CD image (required) and optionally the Jimmy Neutron: Boy Genius CD image (adds the N1 gadget models); the app unpacks the
InstallShield cabinet and converts models, animations and the Carl city level to glb files in `user://imported/` (about 5 MB, ~133 MB of
temporary disk while it runs). "Re-import game files" in the menu runs it again. Godot 4.7.

How it works: `addons/naimport` is a GDExtension (`native/`, C++) with the ISO 9660 + unshield reader, the Granny decoder, the OMT
level/prop reader, the ASE parser and the three glTF writers (ports of the offline tools in neutron2 `tools/granny|omt|ase`).
`scripts/setup_screen.gd` is the UI (touch + gamepad, per-stage progress, errors for wrong disc / not an ISO / no space).
Build the library (not committed): `native/build.sh linux` and `native/build.sh android` (inside the `omtbuild` distrobox; Android needs the
NDK `ndk;27.2.12479018`); then `godot --headless --path . --import`. Details + licences: `native/THIRD_PARTY.md`.
Dev fallback (the old way): an asset folder with the glbs (`NEGATRON_ASSETS=...` or the menu field) is used when nothing is imported.
Tests: `tests/run_setup_test.sh` (real import through the setup screen, needs your ISOs), `tools/compare_glb.py <imported> <reference>`.

Run: `godot --path . ` then Host / Join (IP). CLI: `-- --host`, `-- --join=IP`, `-- --port=N`.
Controls: WASD + mouse + LMB, or left stick / right stick / RT, A = jump, Esc frees the mouse.
Loadout (4 slots, all numbers in scripts/balance.gd): gadget Q / LB, movement Shift / RB (hold; also A-hold = jetpack, A in air = double jump/glide),
ultimate F / LB+RB (charges from damage dealt), loadout menu L / Back (also opens on first spawn and while dead; applies on respawn).
Test: `tests/run_net_test.sh` (headless server + client + observer on localhost).
Screenshots: `tools/vrun.sh res://tools/shots.tscn` (nested virtual KWin, needs a GPU).
Loadout test: `tests/run_loadout_test.sh` (host + client + observer over localhost). Loadout shots: `tools/vrun.sh res://tools/shots_loadout.tscn`.

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

## Import from the installed port apps (Android)
If *Jimmy Neutron vs Jimmy Negatron* (`com.sirbilliams.negatron`) and/or *Boy Genius* (`com.sirbilliams.neutron1`) are installed with their
game set up, the setup screen offers "Use files from ... (installed)" first; the ISO buttons stay as the alternative (mixing is fine).
The ports share their game folder read-only through `GameFilesProvider` (signature|knownSigner permission); Arena's Android plugin
`SharedImport` (`android/plugins/sharedimport`, a Godot v2 plugin, needs the gradle export) copies only the ~40 files the converters need.
- One-time: `tools/setup_android_build.sh` (installs the Godot gradle template), `tools/build_android_plugin.sh` (AAR).
- Android only grants access to the **release** build signed with Arena's own key (`tools/export_release.sh`, key in
  `~/.config/negatron-arena-signing`, never committed); its certificate digest is listed in the ports (`known_game_file_readers`).
  Debug builds are denied: the UI then says to use the ISO. Needs Android 12+ (older Android: ISO only).
- Desktop: "…or choose an extracted game folder" converts from an already extracted game (`NaImporter.import_from_dirs`).

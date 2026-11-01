# Third-party code in native/ (libnaimport)

| Component | Where | Licence |
|---|---|---|
| unshield 1.5.1 (InstallShield cabinet reader) incl. ConvertUTF and md5 | `third_party/unshield/` (copy of the neutron2 port's pinned tree; `LICENSE`) | MIT (David Eriksson) |
| Open Media Toolkit (OMT) 2.5, subset: database, 3D shape/material/polygon, canvas (PNG export), streams, RLE/CRC | `src/omt/src`, `src/omt/inc` (from the neutron2 SDL2 port of OMT; original file notices kept; `src/omt/LICENSE-LGPL.txt`) | LGPL 2.1 or later (Yves Schmid). The complete source is here, so it can be modified and relinked. `src/omt/shim/SDL.h` is a stand-in for the few SDL calls the subset makes (no SDL is linked). |
| Granny 1.2b replacement (`.grn` reader + animation runtime) | `src/granny/` (from neutron2 `game/granny`, a clean-room reimplementation; no RAD Granny code) | the neutron2 project's own code; `granny.dll` itself is never bundled: its Bink tables are read from the player's own disc image at import time |
| `NegImport.c/.h` (ISO 9660 + cabinet) | `src/iso/` (from neutron2 `engine/importer`, reworked to read through a callback and to extract only a file list) | neutron2 project |
| `grn_dump.cpp`, `omt_dump.cpp`, `gdmp_glb.cpp`, `level_glb.cpp`, `ase_glb.cpp` | `src/granny`, `src/omt`, `src/glue` | ports of neutron2 `tools/granny/grndump2.cpp + gdmp2gltf.py`, `tools/omt/omtdump.cpp + omt2gltf.py`, `tools/ase/ase2gltf.py` |
| godot-cpp 4.5 | fetched by `fetch-deps.sh` into `godot-cpp/` (not committed) | MIT |

No game data (ISOs, extracted files, converted glb/png) is ever committed (`.gitignore`: `*.glb`, `*.png`, `*.iso`, `*.gdmp`, `*.odmp`).

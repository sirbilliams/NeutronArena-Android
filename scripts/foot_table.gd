class_name FootTable
extends RefCounted
## Measured foot data per animation (baked by tools/footprobe.gd from the CPU-skinned pose, 60 samples/cycle).
## lift = metres the model must be raised so the lowest sole vertex sits on the floor (p10 of the per-frame lowest vertex).
## gs   = ground speed (m/s) of the planted foot at playback speed 1 (median): the speed that gives zero foot slide.
## The glb animations are authored ~0.4-0.5 m below the model origin (feet at 0 only in the bind pose), so a constant is wrong per clip.
const DATA := {
	"jimmyidle": {"lift": 0.4545, "gs": 0.0},
	"jimmywalk": {"lift": 0.4144, "gs": 0.54},
	"jimmyfullrun": {"lift": 0.5011, "gs": 2.43},
	"jimmyscooter": {"lift": 0.0269, "gs": 0.0},
	"jimmyscooterstop": {"lift": 0.0860, "gs": 0.0},
	"nummeystop": {"lift": 0.4061, "gs": 0.0},
	"nummeywalk": {"lift": 0.4418, "gs": 0.54},
	"nummeyrun": {"lift": 0.4282, "gs": 2.83},
}
## time inside the run clip used as the held jump / fall pose (legs tucked, both feet off the ground)
const AIR_T := {"jimmyfullrun": 0.23, "nummeyrun": 0.65}

static func lift(anim: String) -> float:
	return DATA.get(anim, {"lift": 0.45}).lift

static func gs(anim: String) -> float:
	return DATA.get(anim, {"gs": 0.0}).gs

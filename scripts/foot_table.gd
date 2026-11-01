class_name FootTable
extends RefCounted
## Measured foot data per animation (baked with `tests/run_move_test.sh --cal` on the real Player model: CPU-skinned pose, 40 samples/cycle; gs from tools/footprobe.gd).
## lift = metres the model must be raised so the lowest sole vertex sits on the floor (p10 of the per-frame lowest vertex).
## gs   = ground speed (m/s) of the planted foot at playback speed 1 (median): the speed that gives zero foot slide.
## The glb animations are authored ~0.4-0.5 m below the model origin (feet at 0 only in the bind pose), so a constant is wrong per clip.
const DATA := {
	"jimmyidle": {"lift": 0.5154, "gs": 0.0},
	"jimmywalk": {"lift": 0.4161, "gs": 0.54},
	"jimmyfullrun": {"lift": 0.5019, "gs": 2.43},
	"jimmyscooter": {"lift": 0.0311, "gs": 0.0},
	"jimmyscooterstop": {"lift": 0.0846, "gs": 0.0},
	"nummeystop": {"lift": 0.4599, "gs": 0.0},
	"nummeywalk": {"lift": 0.4424, "gs": 0.54},
	"nummeyrun": {"lift": 0.4337, "gs": 2.83},
}
## time inside the run clip used as the held jump / fall pose (legs tucked, both feet off the ground)
const AIR_T := {"jimmyfullrun": 0.23, "nummeyrun": 0.65}

static func lift(anim: String) -> float:
	return DATA.get(anim, {"lift": 0.45}).lift

static func gs(anim: String) -> float:
	return DATA.get(anim, {"gs": 0.0}).gs

class_name FootTable
extends RefCounted
## Measured foot data per animation (baked with `tests/run_move_test.sh --cal` on the real Player model: CPU-skinned pose, 40 samples/cycle; gs from tools/footprobe.gd).
## lift = metres the model must be raised so the lowest sole vertex sits on the floor (p10 of the per-frame lowest vertex).
## gs   = ground speed (m/s) of the planted foot at playback speed 1 (median): the speed that gives zero foot slide.
## The glb animations are authored ~0.4-0.5 m below the model origin (feet at 0 only in the bind pose), so a constant is wrong per clip. Player sets AnimationPlayer.deterministic so clips never inherit un-keyed bones from the previous one.
const DATA := {
	"jimmyidle": {"lift": 0.4544, "gs": 0.0},
	"jimmywalk": {"lift": 0.4161, "gs": 0.54},
	"jimmyfullrun": {"lift": 0.5019, "gs": 2.43},
	"jimmyscooter": {"lift": 0.0022, "gs": 0.0},
	"jimmyscooterstop": {"lift": 0.0753, "gs": 0.0},
	"jimmyjump": {"lift": 0.2541, "gs": 0.0},
	"jimmyfall": {"lift": 0.4151, "gs": 0.0},
	"jimmyfly": {"lift": 0.3192, "gs": 0.0},
	"nummeyfly": {"lift": 0.2121, "gs": 0.0},
	"numflyair": {"lift": 0.4340, "gs": 0.0},
	"nummeystop": {"lift": 0.4061, "gs": 0.0},
	"nummeywalk": {"lift": 0.4424, "gs": 0.54},
	"nummeyrun": {"lift": 0.4337, "gs": 2.83},
	# roster characters (tools/charcal.gd, at CharModel k = 1; Player multiplies lift and gs by the character factor). Libby: vertex animation has no planted foot, gs is a stride estimate.
	"carl_walk": {"lift": 0.0445, "gs": 1.21},
	"carl_run": {"lift": 0.0693, "gs": 6.11},
	"carl_idle": {"lift": -0.0070, "gs": 0.00},
	"carl_jump": {"lift": 0.5361, "gs": 0.68},
	"carl_fall": {"lift": 0.7242, "gs": 0.53},
	"carl_fly": {"lift": 0.6166, "gs": 0.11},
	"carl_scooter": {"lift": 0.4358, "gs": 0.04},
	"carl_scooterstop": {"lift": 0.6006, "gs": 0.00},
	"cindy_walk": {"lift": 0.5067, "gs": 0.78},
	"cindy_idle": {"lift": 0.5577, "gs": 0.00},
	"cindy_run": {"lift": 0.5021, "gs": 3.02},
	"cindy_jump": {"lift": 0.4892, "gs": 0.46},
	"cindy_fall": {"lift": 0.5797, "gs": 0.25},
	"cindy_fly": {"lift": 0.4769, "gs": 0.07},
	"cindy_scooter": {"lift": 0.4239, "gs": 0.02},
	"cindy_scooterstop": {"lift": 0.5653, "gs": 0.00},
	"sheen_idle": {"lift": 0.3877, "gs": 0.00},
	"sheen_walk": {"lift": 0.4184, "gs": 0.75},
	"sheen_run": {"lift": 0.4851, "gs": 3.09},
	"sheen_jump": {"lift": 0.4876, "gs": 0.44},
	"sheen_fall": {"lift": 0.5734, "gs": 0.23},
	"sheen_fly": {"lift": 0.4833, "gs": 0.07},
	"sheen_scooter": {"lift": 0.3599, "gs": 0.02},
	"sheen_scooterstop": {"lift": 0.5473, "gs": 0.00},
	"libby_idle": {"lift": 0.4214, "gs": 0.00},
	"libby_walk": {"lift": 0.4185, "gs": 0.90},
	"libby_run": {"lift": 0.4253, "gs": 2.60},
}
## time inside the run clip used as the held jump / fall pose (legs tucked, both feet off the ground)
const AIR_T := {"jimmyfullrun": 0.23, "nummeyrun": 0.65, "carl_run": 0.03, "cindy_run": 0.20, "sheen_run": 0.20, "libby_run": 0.4}

static func lift(anim: String) -> float:
	return DATA.get(anim, {"lift": 0.45}).lift

static func gs(anim: String) -> float:
	return DATA.get(anim, {"gs": 0.0}).gs

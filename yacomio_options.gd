extends RefCounted

## Preload-safe game data keeps the model, manifest and controls consistent.

const GAME_ID := "yacomio"
const SAVE_PATH := "user://yacomio.cfg"
const TAP_GAIN := 5
const TAP_KEY := "controls/yacomio_tap"
const RNA_KEY := "controls/yacomio_rna"
const DNA_KEY := "controls/yacomio_dna"
const TAP_ACTION := &"yacomio_tap"
const RNA_ACTION := &"yacomio_rna"
const DNA_ACTION := &"yacomio_dna"

const UPGRADES := {
	"rna": {"title": "Unlock RNA", "cost": 10, "rate": 1},
	"dna": {"title": "Unlock DNA Replication", "cost": 50, "rate": 3},
}

const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": TAP_KEY, "action": TAP_ACTION, "default": KEY_M, "title": "Tap microbe",
		"description": "Gain 5 Evolution Points.",
		"player": 0, "heading": "Microbial Beginnings",
	},
	{
		"key": RNA_KEY, "action": RNA_ACTION, "default": KEY_1, "title": "Buy RNA",
		"description": "Spend 10 EP once to add 1 EP per second.",
		"player": 0, "heading": "Microbial Beginnings",
	},
	{
		"key": DNA_KEY, "action": DNA_ACTION, "default": KEY_2, "title": "Buy DNA Replication",
		"description": "Spend 50 EP once to add 3 EP per second.",
		"player": 0, "heading": "Microbial Beginnings",
	},
]

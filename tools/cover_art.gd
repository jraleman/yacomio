extends RefCounted

## A macro photograph of the colony's actual upgraded microbe, without its display basin.
const Helpers = preload("res://tools/cover_art_helpers.gd")
const Models = preload("res://games/yacomio/colony_models.gd")


## A curious little organism gets the cover, rather than an abstract app badge.
static func design() -> Dictionary:
	return {
		"paper": Color("d3efcc"), "ink": Color("24543f"), "accent": Color("64bb92"),
		"motif": "bubbles", "camera": Vector3(-12, 13, 8),
		"photo": Rect2(0, 280, 1024, 650),
		"lettering": [
			{"text": "SMALL BEGINNINGS.", "at": Vector2(61, 83), "size": 35, "font": "mono"},
			{"text": "YaComio!", "at": Vector2(50, 264), "size": 172, "font": "serif"},
			{"text": "GROW INTO SOMETHING BIG.", "at": Vector2(62, 980), "size": 35, "font": "round"},
		],
	}


## Removing only the display basin preserves every original cell mesh and material.
static func build(parent: Node) -> Node:
	var root := Helpers.group(parent)
	var upgrades: Array[String] = ["rna", "dna", "membrane"]
	var colony := Models.build(0, upgrades)
	var cell := colony.get_node("Microbe") as Node3D
	colony.remove_child(cell)
	root.add_child(cell)
	colony.free()
	cell.position = Vector3.ZERO
	cell.rotation_degrees.z = -8
	var smaller := cell.duplicate() as Node3D
	Helpers.place(root, smaller, Vector3(-1.1, -0.7, -0.1), Vector3(0, 18, 20), 0.33)
	return root

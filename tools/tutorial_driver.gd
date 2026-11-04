extends RefCounted

## The recording earns both upgrades through real bound keys on a fresh colony.
## It never edits resource state or changes the live production rate.

signal keycap_requested(text: String)

const Options := preload("res://games/yacomio/yacomio_options.gd")
const ACTIONS: Array[Dictionary] = [
	{"time": 3.4, "action": Options.TAP_ACTION, "button": "TapMicrobe"},
	{"time": 4.2, "action": Options.TAP_ACTION, "button": "TapMicrobe"},
	{"time": 7.4, "action": Options.RNA_ACTION, "button": "BuyRNA"},
	{"time": 12.4, "action": Options.TAP_ACTION, "button": "TapMicrobe"},
	{"time": 13.2, "action": Options.TAP_ACTION, "button": "TapMicrobe"},
	{"time": 14.0, "action": Options.TAP_ACTION, "button": "TapMicrobe"},
	{"time": 14.8, "action": Options.TAP_ACTION, "button": "TapMicrobe"},
	{"time": 15.6, "action": Options.TAP_ACTION, "button": "TapMicrobe"},
	{"time": 17.2, "action": Options.DNA_ACTION, "button": "BuyDNA"},
]

var _next_action := 0
var _fresh := false
var _releases: Array[InputEventKey] = []


func configure(variant: String) -> bool:
	_next_action = 0
	_fresh = false
	return variant == "solo"


func steps() -> Array[Dictionary]:
	return [
		{
			"time": 0.0, "title": "Evolution begins",
			"body": "Your colony earns 1 EP per active second. There is no deadline.",
		},
		{
			"time": 3.0, "title": "Tap the microbe",
			"body": "Click, tap or press M to add 5 Evolution Points.",
		},
		{
			"time": 7.0, "title": "Unlock RNA",
			"body": "Spend 10 EP once to add 1 EP per second.",
		},
		{
			"time": 12.0, "title": "Grow toward DNA",
			"body": "Keep tapping and saving. DNA costs 50 EP and adds 3 EP per second.",
		},
		{
			"time": 18.0, "title": "A little more life",
			"body": "Both upgrades earn 5 EP/s. Progress auto-saves; paused and offline time earn nothing.",
		},
	]


func duration() -> float:
	return 24.0


func settings_overrides() -> Dictionary:
	return {
		Options.TAP_KEY: KEY_M, Options.RNA_KEY: KEY_1, Options.DNA_KEY: KEY_2,
		"ui/scale": 1.0,
	}


func configure_session(session: Node) -> void:
	session.call("configure_single_player")


func start(scene: Node) -> void:
	var state: RefCounted = scene.get("_state")
	_fresh = int(state.get("ep")) == 0 and (state.get("upgrades") as Array).is_empty()
	if not _fresh:
		push_error("YaComio walkthrough requires a fresh, isolated save profile.")


func update(scene: Node, time: float, _delta: float) -> void:
	_release_keys()
	if not _fresh or not bool(scene.get("_round_active")):
		return
	while _next_action < ACTIONS.size() and time >= float(ACTIONS[_next_action]["time"]):
		var definition := ACTIONS[_next_action]
		var scroll := scene.get_node("%EvolutionScroll") as ScrollContainer
		scroll.ensure_control_visible(scene.get_node("%" + str(definition["button"])))
		_press(StringName(definition["action"]))
		_next_action += 1


func validate_finished(scene: Node) -> bool:
	_release_keys()
	var state: RefCounted = scene.get("_state")
	var owned: Array = state.get("upgrades")
	return (
		_fresh and _next_action == ACTIONS.size()
		and owned.has("rna") and owned.has("dna")
		and int(state.call("ep_per_second")) == 5
		and int(scene.get("_save_error")) == OK
	)


func _press(action: StringName) -> void:
	for source in InputMap.action_get_events(action):
		if source is InputEventKey:
			var event := source.duplicate() as InputEventKey
			event.pressed = true
			event.echo = false
			Input.parse_input_event(event)
			_releases.append(event)
			keycap_requested.emit(OS.get_keycode_string(event.physical_keycode))
			return
	push_error("YaComio walkthrough could not resolve action %s." % action)


func _release_keys() -> void:
	for press in _releases:
		var release := press.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
	_releases.clear()

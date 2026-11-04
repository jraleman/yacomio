extends GameShell

## The shell keeps navigation, pause and accessibility; this adapter saves only
## actual resource mutations, never menu time or a synthetic session score.

const Options := preload("res://games/yacomio/yacomio_options.gd")
const EvolutionState := preload("res://games/yacomio/evolution_state.gd")

@onready var _panel: PanelContainer = %EvolutionPanel
@onready var _ep_label: Label = %EvolutionPoints
@onready var _tap_button: Button = %TapMicrobe
@onready var _rna_button: Button = %BuyRNA
@onready var _dna_button: Button = %BuyDNA
@onready var _save_status: Label = %SaveStatus

var _state := EvolutionState.new()
var _load_error := OK
var _save_error := OK
var _capture_inset := 0.0


func game_id() -> String:
	return Options.GAME_ID


func _build_playfield() -> void:
	_load_error = _state.load_save()
	_tap_button.pressed.connect(_tap_microbe)
	_rna_button.pressed.connect(_buy_upgrade.bind("rna"))
	_dna_button.pressed.connect(_buy_upgrade.bind("dna"))
	get_viewport().size_changed.connect(_layout_panel)
	_layout_panel()
	_on_controls_changed()


func _configure_mode_ui() -> void:
	super()
	_player_one_caption.text = "%s - EP THIS VISIT" % _player_name(PLAYER_ONE).to_upper()
	_time_caption.text = "EP PER SECOND"
	_time_label.text = str(_state.ep_per_second())
	_callout.text = "MICROBIAL BEGINNINGS"


func _activate_round() -> void:
	_panel.show()
	_refresh_progress()
	if not _tap_button.disabled:
		_tap_button.grab_focus()


func _finish_round() -> void:
	_panel.hide()


func _update_round(delta: float, _time_left: float) -> void:
	if not _can_act():
		return
	var generated := _state.advance(delta)
	if generated > 0:
		_scores[PLAYER_ONE] += generated
		_update_scores()
		_persist_progress()


func _handle_gameplay_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if event.is_action_pressed(Options.TAP_ACTION):
		_tap_microbe()
	elif event.is_action_pressed(Options.RNA_ACTION):
		_buy_upgrade("rna")
	elif event.is_action_pressed(Options.DNA_ACTION):
		_buy_upgrade("dna")
	else:
		return
	get_viewport().set_input_as_handled()


func _tap_microbe() -> void:
	if not _can_act():
		return
	_scores[PLAYER_ONE] += _state.tap()
	_update_scores()
	_persist_progress()


func _buy_upgrade(id: String) -> void:
	if not _can_act():
		return
	if not _state.buy(id):
		if _save_error == OK:
			_save_status.text = (
				"Already unlocked." if _state.upgrades.has(id)
				else "You need %d more EP." % (
					int(Options.UPGRADES[id]["cost"]) - _state.ep
				)
			)
		return
	_persist_progress()


func _can_act() -> bool:
	return (
		_round_active and not get_tree().paused and not Router.is_transitioning()
		and (_load_error == OK or _load_error == ERR_FILE_NOT_FOUND)
	)


func _persist_progress() -> void:
	_save_error = _state.save()
	_refresh_progress()


func _refresh_progress() -> void:
	var unreadable := _load_error != OK and _load_error != ERR_FILE_NOT_FOUND
	_ep_label.text = "Save unavailable" if unreadable else "%d Evolution Points" % _state.ep
	_time_label.text = "--" if unreadable else str(_state.ep_per_second())
	_tap_button.disabled = unreadable or not _round_active
	_refresh_upgrade(_rna_button, "rna", unreadable)
	_refresh_upgrade(_dna_button, "dna", unreadable)
	if unreadable:
		_save_status.text = (
			"Could not load your save (error %d). Nothing was overwritten. "
			+ "Use Main Menu > Saves to back up or delete it before retrying."
		) % _load_error
	elif _save_error != OK:
		_save_status.text = (
			"Progress is NOT saved (error %d). Keep the game open "
			+ "and check available storage."
		) % _save_error
	else:
		_save_status.text = "Progress saves automatically. No offline gains."


func _refresh_upgrade(button: Button, id: String, unreadable: bool) -> void:
	var upgrade: Dictionary = Options.UPGRADES[id]
	var owned := _state.upgrades.has(id)
	button.text = "%s (%s)" % [
		upgrade["title"], "Unlocked" if owned else "%d EP" % upgrade["cost"],
	]
	button.disabled = unreadable or not _round_active or not _state.can_buy(id)


func _on_controls_changed() -> void:
	super()
	_hint.text = "Tap: %s   |   RNA: %s   |   DNA: %s   |   Esc: Pause" % [
		OS.get_keycode_string(Settings.binding_keycode(Options.TAP_KEY)),
		OS.get_keycode_string(Settings.binding_keycode(Options.RNA_KEY)),
		OS.get_keycode_string(Settings.binding_keycode(Options.DNA_KEY)),
	]


func _layout_panel() -> void:
	var bounds := _playfield_bounds()
	var width := minf(1080.0, bounds.size.x)
	var height := maxf(
		0.0, bounds.size.y - maxf(0.0, _capture_inset - BOTTOM_CLEARANCE)
	)
	_panel.position = bounds.position + Vector2((bounds.size.x - width) * 0.5, 0.0)
	_panel.size = Vector2(width, height)


func _set_capture_inset(bottom: float) -> void:
	_capture_inset = maxf(bottom, 0.0)
	_layout_panel()

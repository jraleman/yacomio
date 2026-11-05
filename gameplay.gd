extends GameShell

## The shared shell owns navigation and visit results; the colony owns its
## persistent timeline. Neither pause menus nor confirmation dialogs earn EP.

const Options := preload("res://games/yacomio/yacomio_options.gd")
const EvolutionState := preload("res://games/yacomio/evolution_state.gd")
const TokenBank := preload("res://games/yacomio/token_bank.gd")

@onready var _panel: PanelContainer = %EvolutionPanel
@onready var _body: BoxContainer = %EvolutionBody
@onready var _view: Control = %ColonyView
@onready var _scroll: ScrollContainer = %EvolutionScroll
@onready var _heading: Label = %EraHeading
@onready var _description: Label = %EraDescription
@onready var _ep_label: Label = %EvolutionPoints
@onready var _resources_label: Label = %ResourcesLabel
@onready var _wallet_label: Label = %WalletLabel
@onready var _tap_button: Button = %TapMicrobe
@onready var _upgrades_column: VBoxContainer = %UpgradeList
@onready var _gate_label: Label = %EvolutionGate
@onready var _gate_progress: ProgressBar = %GateProgress
@onready var _evolve_button: Button = %Evolve
@onready var _event_button: Button = %MilestoneEvent
@onready var _event_description: Label = %EventDescription
@onready var _leap_button: Button = %EvolutionaryLeap
@onready var _leap_dialog: ConfirmationDialog = %LeapConfirmation
@onready var _journal_button: Button = %FinishVisit
@onready var _save_status: Label = %SaveStatus

var _state := EvolutionState.new()
var _load_error := OK
var _save_error := OK
var _wallet_error := OK
var _capture_inset := 0.0
var _built := false
var _confirmation_active := false
var _status_note := ""
var _upgrade_buttons: Dictionary[String, Button] = {}
var _upgrade_rows: Dictionary[String, VBoxContainer] = {}
var _visit_tokens_start := 0
var _finished_colony: Dictionary = {}


func game_id() -> String:
	return Options.GAME_ID


func _build_playfield() -> void:
	_load_error = _state.load_save()
	if _load_error == OK:
		var was_suspended := not _state.offline_eligible
		var gains := _state.apply_offline()
		var parts := PackedStringArray()
		for resource in Options.RESOURCE_KEYS:
			if gains[resource] > 0:
				parts.append("+%s %s" % [Options.number(gains[resource]), Options.RESOURCES[resource]["short"]])
		if not parts.is_empty():
			_status_note = "Welcome back: %s. Offline gains earn no tokens." % ", ".join(parts)
		elif _state.clock_rolled_back:
			_status_note = "The clock moved backwards. No offline gains were awarded."
		elif was_suspended:
			_status_note = "The previous session was interrupted while suspended. Its unknown offline interval was not counted."
	_tap_button.pressed.connect(_tap_microbe)
	_build_upgrade_buttons()
	_evolve_button.pressed.connect(_evolve)
	_event_button.pressed.connect(_trigger_event)
	_leap_button.pressed.connect(_request_prestige)
	_journal_button.pressed.connect(_end_visit)
	_leap_dialog.confirmed.connect(_confirm_prestige)
	_leap_dialog.canceled.connect(_cancel_prestige)
	_leap_dialog.close_requested.connect(_cancel_prestige)
	Store.equipped_changed.connect(_on_equipment_changed)
	Store.points_changed.connect(_on_wallet_changed)
	get_viewport().size_changed.connect(_layout_panel)
	_built = true
	_layout_panel()
	_on_controls_changed()


func _build_upgrade_buttons() -> void:
	for id in Options.UPGRADE_ORDER:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_upgrades_column.add_child(row)
		var button := Button.new()
		button.name = (
			"BuyRNA" if id == "rna" else "BuyDNA" if id == "dna"
			else "BuyMembrane" if id == "membrane" else "Buy_" + id
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(button)
		button.owner = self
		button.unique_name_in_owner = true
		button.pressed.connect(_buy_upgrade.bind(id))
		var description := Label.new()
		description.text = str(Options.UPGRADES[id]["description"])
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(description)
		_upgrade_buttons[id] = button
		_upgrade_rows[id] = row


func _configure_mode_ui() -> void:
	super()
	_player_one_caption.text = "%s - EP THIS VISIT" % _player_name(PLAYER_ONE).to_upper()
	_time_caption.text = "EP PER SECOND"
	_time_label.text = Options.number(_state.ep_per_second())
	_callout.hide()
	_play_again_button.text = "Continue colony"
	_round_instructions.text = "Continue resumes this colony. Only a confirmed evolutionary leap resets it."
	_share_card_hint.text = (
		"A snapshot of this visit. The QR opens DeskCanSaw's website, "
		+ "not a public colony record."
	)


func _activate_round() -> void:
	_panel.show()
	_state.offline_eligible = true
	_visit_tokens_start = _state.earned_tokens()
	if _readable_save():
		_persist_progress()
	else:
		_refresh_progress()
	if not _tap_button.disabled:
		_tap_button.grab_focus()


func _finish_round() -> void:
	_finished_colony = _colony_snapshot()
	if _readable_save():
		_state.offline_eligible = false
		_save_error = _state.save()
	_panel.hide()
	_view.call("set_motion", false)


func _update_round(delta: float, _time_left: float) -> void:
	if not _can_act():
		return
	var generated := _state.advance(delta)
	if _state.advanced_seconds > 0:
		_scores[PLAYER_ONE] = mini(Options.MAX_RESOURCE, _scores[PLAYER_ONE] + generated)
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
	elif event.is_action_pressed(Options.MEMBRANE_ACTION):
		_buy_upgrade("membrane")
	elif event.is_action_pressed(Options.EVOLVE_ACTION):
		_evolve()
	elif event.is_action_pressed(Options.JOURNAL_ACTION):
		_end_visit()
	else:
		return
	get_viewport().set_input_as_handled()


func _tap_microbe() -> void:
	if not _can_act():
		return
	_status_note = ""
	_scores[PLAYER_ONE] = mini(Options.MAX_RESOURCE, _scores[PLAYER_ONE] + _state.tap())
	_update_scores()
	_persist_progress()


func _buy_upgrade(id: String) -> void:
	if not _can_act():
		return
	if not _state.buy(id):
		_status_note = "That upgrade is owned or its displayed requirements are not met."
		_refresh_progress()
		return
	_status_note = ""
	_persist_progress()


func _evolve() -> void:
	if not _can_act() or not _state.evolve():
		return
	_status_note = "A new era: %s." % Options.STAGES[_state.stage]["title"]
	_persist_progress()
	_configure_mode_ui()
	_scroll.scroll_vertical = 0
	_layout_panel()
	AudioManager.play_level_unlock()
	AudioManager.request_caption(_status_note)
	_tap_button.grab_focus()


func _event_for_era() -> String:
	if not _state.active_event.is_empty():
		return _state.active_event
	for id in Options.EVENT_ORDER:
		if int(Options.EVENTS[id]["stage"]) == _state.stage:
			return id
	return ""


func _trigger_event() -> void:
	var id := _event_for_era()
	if not _can_act() or id.is_empty() or not _state.trigger_event(id):
		return
	_status_note = "%s started." % Options.EVENTS[id]["title"]
	_persist_progress()
	AudioManager.request_caption(_status_note)


func _request_prestige() -> void:
	if not _can_act() or not _state.can_prestige():
		return
	_confirmation_active = true
	get_tree().paused = true
	var bounds := get_viewport_rect().size
	var unit := bounds.x / maxf(get_window().size.x, 1.0)
	var target := Vector2i(
		roundi(minf(560.0 * unit, bounds.x - 32.0 * unit)),
		roundi(minf(340.0 * unit, bounds.y - 32.0 * unit))
	)
	var label := _leap_dialog.get_label()
	label.custom_minimum_size.x = target.x - 32.0 * unit
	label.size.x = label.custom_minimum_size.x
	label.add_theme_font_size_override("font_size", roundi(16.0 * unit))
	for button in [_leap_dialog.get_cancel_button(), _leap_dialog.get_ok_button()]:
		button.custom_minimum_size.y = 46.0 * unit
		button.add_theme_font_size_override("font_size", roundi(18.0 * unit))
	_leap_dialog.popup_centered(target)
	_leap_dialog.get_cancel_button().grab_focus()


func _confirm_prestige() -> void:
	if not _confirmation_active:
		return
	_confirmation_active = false
	_leap_dialog.hide()
	_state.prestige()
	get_tree().paused = false
	_status_note = "Evolutionary leap %d: +%s%% permanent production." % [
		_state.leaps, Options.number(_state.leaps * Options.LEAP_BONUS * 100.0),
	]
	_persist_progress()
	_configure_mode_ui()
	_scroll.scroll_vertical = 0
	_tap_button.grab_focus()
	AudioManager.request_caption(_status_note)


func _cancel_prestige() -> void:
	if not _confirmation_active:
		return
	_confirmation_active = false
	_leap_dialog.hide()
	get_tree().paused = false
	_leap_button.grab_focus()


func _end_visit() -> void:
	if _can_act() and _persist_progress():
		_end_round()


func _readable_save() -> bool:
	return _load_error == OK or _load_error == ERR_FILE_NOT_FOUND


func _can_act() -> bool:
	return (
		_round_active and not get_tree().paused and not Router.is_transitioning()
		and _readable_save() and not _confirmation_active
	)


func _persist_progress() -> bool:
	_save_error = _state.save()
	if _save_error == OK:
		_wallet_error = TokenBank.reconcile(Store, _state)
		for id in _state.milestones:
			_unlock_round_achievement(id)
	_refresh_progress()
	return _save_error == OK and _wallet_error == OK


func _refresh_progress() -> void:
	var unreadable := not _readable_save()
	var era: Dictionary = Options.STAGES[_state.stage]
	_heading.text = str(era["title"])
	_description.text = str(era["description"])
	_ep_label.text = "Save unavailable" if unreadable else "%s Evolution Points" % Options.number(_state.ep)
	_time_label.text = "--" if unreadable else Options.number(_state.ep_per_second())
	_tap_button.text = "Gather EP (+%s)" % Options.number(_state.tap_gain())
	_tap_button.disabled = unreadable or not _round_active
	var lines := PackedStringArray()
	for resource in Options.RESOURCE_KEYS:
		if resource == "ep" or _state.stage < int(Options.RESOURCES[resource]["stage"]):
			continue
		var rate_text := Options.number(_state.rate(resource))
		if resource == "light" and not _state.is_daylight():
			rate_text = "0"
		var line := "%s: %s  |  +%s/s" % [
			Options.RESOURCES[resource]["short"], Options.number(_state.amount(resource)), rate_text,
		]
		if resource == "light":
			line += " (%s, %ds)" % [
				"day" if _state.is_daylight() else "night",
				(Options.DAY_SECONDS if _state.is_daylight() else Options.CYCLE_SECONDS) - _state.day_second,
			]
		lines.append(line)
	_resources_label.text = "\n".join(lines)
	_resources_label.visible = not lines.is_empty() and not unreadable
	_wallet_label.text = "%s  |  %d leaps (+%s%%)" % [
		Store.format_points(game_id(), Store.points(game_id())), _state.leaps,
		Options.number(_state.leaps * Options.LEAP_BONUS * 100.0),
	]
	for id in _upgrade_buttons:
		_refresh_upgrade(_upgrade_buttons[id], id, unreadable)
	_evolve_button.visible = _state.stage + 1 < Options.STAGES.size()
	_evolve_button.disabled = unreadable or not _round_active or not _state.can_evolve()
	if _evolve_button.visible:
		_evolve_button.text = "Evolve: %s" % Options.STAGES[_state.stage + 1]["title"]
	_gate_label.text = _gate_text()
	_gate_progress.value = _gate_percent()
	_gate_progress.visible = _evolve_button.visible
	var event := _event_for_era()
	_event_button.visible = not event.is_empty()
	_event_description.visible = _event_button.visible
	if not event.is_empty():
		_event_button.text = (
			"%s: %ds remaining" % [Options.EVENTS[event]["title"], _state.event_remaining]
			if not _state.active_event.is_empty() else
			"%s (%s)" % [Options.EVENTS[event]["title"],
				"Completed" if _state.completed_events.has(event) else "Start"]
		)
		_event_description.text = str(Options.EVENTS[event]["description"])
		_event_button.disabled = unreadable or not _round_active or not _state.can_trigger_event(event)
	_leap_button.visible = _state.upgrades.has("civilization")
	_leap_button.disabled = unreadable or not _round_active or not _state.can_prestige()
	_journal_button.disabled = unreadable or not _round_active
	if not unreadable:
		_view.call("configure", _colony_snapshot())
		_view.call("set_motion", _round_active and not _reduced_motion_enabled)
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
	elif _wallet_error != OK:
		_save_status.text = (
			"Colony saved, but cosmetic tokens could not be reconciled (error %d). "
			+ "Do not delete progress; restore a complete backup through Main Menu > Saves."
		) % _wallet_error
	elif _state.at_storage_limit():
		_save_status.text = (
			"A counter reached 1P and stopped safely. Spend or reset resources to free "
			+ "resource space; lifetime token earnings keep their ceiling."
		)
	else:
		_save_status.text = _status_note if not _status_note.is_empty() else (
			"Auto-saved. 100 active EP = 1 Spore Token. Offline resources earn no tokens."
		)


func _refresh_upgrade(button: Button, id: String, unreadable: bool) -> void:
	var upgrade: Dictionary = Options.UPGRADES[id]
	var owned := _state.upgrades.has(id)
	_upgrade_rows[id].visible = (
		int(upgrade["stage"]) == _state.stage
		or (int(upgrade["stage"]) < _state.stage and not owned)
	)
	var shortcut := _upgrade_shortcut(id)
	button.text = "%s (%s)" % [
		str(upgrade["title"]) + shortcut,
		"Unlocked" if owned else Options.costs_text(upgrade["costs"]),
	]
	var requirements := PackedStringArray()
	for required: String in upgrade["requires"]:
		if not _state.upgrades.has(required):
			requirements.append(str(Options.UPGRADES[required]["title"]))
	button.tooltip_text = str(upgrade["description"])
	if not requirements.is_empty():
		button.tooltip_text += "\nRequires: " + ", ".join(requirements)
	button.accessibility_description = button.tooltip_text
	button.disabled = unreadable or not _round_active or not _state.can_buy(id)


func _upgrade_shortcut(id: String) -> String:
	var keys := {"rna": Options.RNA_KEY, "dna": Options.DNA_KEY, "membrane": Options.MEMBRANE_KEY}
	return " [%s]" % OS.get_keycode_string(Settings.binding_keycode(keys[id])) if keys.has(id) else ""


func _gate_text() -> String:
	if _state.stage + 1 == Options.STAGES.size():
		return (
			"Timeline complete. Keep growing, finish this visit or choose an optional leap."
			if _state.can_prestige() else "Establish Civilization to complete this timeline."
		)
	var next: Dictionary = Options.STAGES[_state.stage + 1]
	var missing := PackedStringArray()
	for id: String in next["requires"]:
		if not _state.upgrades.has(id):
			missing.append(str(Options.UPGRADES[id]["title"]))
	var event := str(next["event"])
	if not event.is_empty() and not _state.completed_events.has(event):
		missing.append(str(Options.EVENTS[event]["title"]) + " completed")
	var text := "Next era costs: " + Options.costs_text(next["costs"])
	if not missing.is_empty():
		text += "\nAlso requires: " + ", ".join(missing)
	return text


func _gate_percent() -> float:
	if _state.stage + 1 == Options.STAGES.size():
		return 100.0 if _state.can_prestige() else 0.0
	var next: Dictionary = Options.STAGES[_state.stage + 1]
	var progress := 0.0
	var count := 0
	for resource: String in next["costs"]:
		progress += minf(1.0, float(_state.amount(resource)) / float(next["costs"][resource]))
		count += 1
	for id: String in next["requires"]:
		progress += 1.0 if _state.upgrades.has(id) else 0.0
		count += 1
	var event := str(next["event"])
	if not event.is_empty():
		progress += 1.0 if _state.completed_events.has(event) else 0.0
		count += 1
	return progress * 100.0 / maxf(count, 1)


func _on_controls_changed() -> void:
	super()
	_hint.text = "Gather: %s  |  Evolve: %s  |  Finish visit: %s  |  Esc: Pause" % [
		OS.get_keycode_string(Settings.binding_keycode(Options.TAP_KEY)),
		OS.get_keycode_string(Settings.binding_keycode(Options.EVOLVE_KEY)),
		OS.get_keycode_string(Settings.binding_keycode(Options.JOURNAL_KEY)),
	]
	if _built:
		_refresh_progress()


func _on_equipment_changed(id: String, _slot: String, _item: String) -> void:
	if id == game_id() and _built:
		_view.call("configure", _colony_snapshot())


func _on_wallet_changed(id: String, _points: int) -> void:
	if id == game_id() and _built:
		_refresh_progress()


func _set_reduced_motion_enabled(enabled: bool) -> void:
	super(enabled)
	if _built:
		_view.call("set_motion", _round_active and not enabled)


func _layout_panel() -> void:
	var bounds := _playfield_bounds()
	var width := minf(1600.0, bounds.size.x)
	var height := maxf(
		0.0, bounds.size.y - maxf(0.0, _capture_inset - BOTTOM_CLEARANCE)
	)
	_panel.position = bounds.position + Vector2((bounds.size.x - width) * 0.5, 0.0)
	_panel.size = Vector2(width, height)
	var unit := get_viewport_rect().size.x / maxf(get_window().size.x, 1.0)
	var portrait := Responsive.is_portrait(get_viewport_rect().size)
	_body.vertical = portrait
	_body.add_theme_constant_override("separation", roundi(16.0 * unit))
	_view.size_flags_stretch_ratio = 0.35 if portrait else 1.0
	_scroll.size_flags_stretch_ratio = 0.65 if portrait else 1.0
	for label: Label in [_heading, _ep_label]:
		label.add_theme_font_size_override("font_size", roundi(24.0 * unit))
	for label: Label in [
		_description, _resources_label, _wallet_label, _gate_label,
		_event_description, _save_status,
	]:
		label.add_theme_font_size_override("font_size", roundi(16.0 * unit))
	var buttons: Array[Button] = [
		_tap_button, _evolve_button, _event_button, _leap_button, _journal_button,
	]
	buttons.append_array(_upgrade_buttons.values())
	for button in buttons:
		button.custom_minimum_size.y = 46.0 * unit
		button.add_theme_font_size_override("font_size", roundi(18.0 * unit))
	for row: VBoxContainer in _upgrade_rows.values():
		(row.get_child(1) as Label).add_theme_font_size_override("font_size", roundi(14.0 * unit))
	_layout_visit_panels(unit)


func _layout_visit_panels(unit: float) -> void:
	var compact := get_window().size.x < 600
	_score_screen_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_round_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for panel in [_round_panel, _score_panel]:
		panel.custom_minimum_size.x = minf(1180.0 * unit, get_viewport_rect().size.x - 48.0 * unit)
		for label: Label in panel.find_children("*", "Label", true, false):
			if not label.has_meta("yacomio_base_font"):
				label.set_meta("yacomio_base_font", label.get_theme_font_size("font_size"))
			var original := int(label.get_meta("yacomio_base_font"))
			var pixels := 28 if original > 64 else 24 if original >= 32 else 12 if original < 18 else 16
			label.add_theme_font_size_override("font_size", roundi(pixels * unit))
		for button: Button in panel.find_children("*", "Button", true, false):
			button.custom_minimum_size.y = 46.0 * unit
			button.add_theme_font_size_override("font_size", roundi(18.0 * unit))
	_score_panel.get_node("Layout/Report/SharePanel").visible = not compact
	_game_hits_stat.get_parent().get_parent().visible = not compact
	var extra := player_stats_panel(PLAYER_ONE).get_node_or_null("Layout/ExtraStats")
	if extra != null:
		extra.visible = not compact
	var eyebrow := _score_panel.get_node("Layout/Eyebrow") as Label
	eyebrow.text = "ERA %d / %d - EVOLUTION JOURNAL" % [
		_state.stage + 1, Options.STAGES.size(),
	] if compact else "EVOLUTION JOURNAL"


func _set_capture_inset(bottom: float) -> void:
	_capture_inset = maxf(bottom, 0.0)
	_layout_panel()


func _colony_snapshot() -> Dictionary:
	var balances := _state.resources.duplicate()
	balances["ep"] = _state.ep
	return {
		"stage": _state.stage, "upgrades": _state.upgrades.duplicate(),
		"membrane": Store.equipped_id(game_id(), Options.MEMBRANE_SLOT),
		"habitat": Store.equipped_id(game_id(), Options.HABITAT_SLOT),
		"daylight": _state.is_daylight(), "rate": _state.ep_per_second(), "leaps": _state.leaps,
		"balances": balances,
		"tokens_this_visit": _state.earned_tokens() - _visit_tokens_start,
	}


func _populate_score_screen(result_text: String, result_color: Color) -> void:
	super(result_text, result_color)
	_game_duration_stat.text = "%d SEC" % roundi(_round_elapsed)
	_game_hits_stat.text = "%d / %d" % [int(_finished_colony["stage"]) + 1, Options.STAGES.size()]
	_game_accuracy_stat.text = Options.number(float(_finished_colony["rate"]))
	_layout_visit_panels(get_viewport_rect().size.x / maxf(get_window().size.x, 1.0))


func _populate_player_stats(player: int) -> void:
	super(player)
	if player != PLAYER_ONE:
		return
	_player_one_stats_score.text = Options.number(_scores[PLAYER_ONE])
	_player_one_stats_hits.text = str((_finished_colony["upgrades"] as Array).size())
	_player_one_stats_misses.text = str(_finished_colony["tokens_this_visit"])
	_player_one_stats_accuracy.text = Options.number(float(_finished_colony["rate"]))
	_player_one_stats_streak.text = str(_finished_colony["leaps"])


func _round_totals() -> Dictionary:
	return {"hits": 0, "attempts": 0}


func _player_stats(player: int) -> Dictionary:
	var details: Array[Dictionary] = []
	var snapshot := _finished_colony if not _finished_colony.is_empty() else _colony_snapshot()
	var balances: Dictionary = snapshot["balances"]
	for resource: String in balances:
		if int(snapshot["stage"]) >= int(Options.RESOURCES[resource]["stage"]):
			details.append({
				"label": Options.RESOURCES[resource]["short"],
				"value": Options.number(float(balances[resource])),
			})
	return {
		"score": _scores[player], "hits": 0, "misses": 0, "accuracy": 0,
		"streak": 0, "details": details,
	}


func _round_points_earned(_one: int, _two: int) -> int:
	return 0


func _round_highlight_summary() -> String:
	return "%s | %d upgrades | %d Spore Tokens earned this visit" % [
		Options.STAGES[_state.stage]["title"], _state.upgrades.size(),
		_state.earned_tokens() - _visit_tokens_start,
	]


func _describe_round_outcome(_one: int, _two: int) -> Dictionary:
	if _save_error != OK:
		return {
			"result": "PROGRESS NOT SAVED", "color": Color("ef8490"),
			"subtitle": "Checkpoint failed (error %d). Keep the game open and check available storage." % _save_error,
		}
	return {
		"result": "VISIT SAVED", "color": Color("7bd9a5"),
		"subtitle": "Your colony keeps its progress. Continue starts another visit, not a reset.",
	}


func _share_payload() -> Dictionary:
	var data := super()
	data["colony"] = _finished_colony.duplicate(true)
	data["mode"] = "Evolution journal"
	data["score_caption"] = "EP this visit"
	data["accuracy_caption"] = "EP per second"
	data["accuracy"] = Options.number(float(_finished_colony.get("rate", 0.0)))
	data["hits_caption"] = "Era"
	data["hits"] = ["Microbes", "Sunlight", "Complex", "Land", "Human"][int(_finished_colony.get("stage", 0))]
	data["combo_caption"] = "Leaps"
	data["combo"] = str(_finished_colony.get("leaps", 0))
	data["challenge"] = "Small beginnings. A world of possibilities."
	data["qr_heading"] = "Visit the studio"
	data["qr_copy"] = "Opens DeskCanSaw's website, not a public colony record."
	data["cta"] = "Grow. Evolve. Share."
	return data


func _notification(what: int) -> void:
	if not _built or not _readable_save():
		return
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED]:
		_state.offline_eligible = what == NOTIFICATION_UNPAUSED and _round_active
		_persist_progress()


func _exit_tree() -> void:
	if not _built:
		return
	_built = false
	if _confirmation_active:
		_confirmation_active = false
		get_tree().paused = false
	if _readable_save():
		_state.offline_eligible = true
		_save_error = _state.save()
		if _save_error == OK and is_instance_valid(Store):
			_wallet_error = TokenBank.reconcile(Store, _state)

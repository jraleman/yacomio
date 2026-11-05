extends SceneTree

## Drive real controls, pause and reload while preserving the player's save.
## Load the shell at runtime because it uses autoload instances.

const Options := preload("res://games/yacomio/yacomio_options.gd")
const Fixture := preload("res://games/yacomio/tests/progress_fixture.gd")
const State := preload("res://games/yacomio/evolution_state.gd")
const Bank := preload("res://games/yacomio/token_bank.gd")

var _failures := PackedStringArray()
var _packed: PackedScene
var _fixture := Fixture.new()
var _opened: Array[Node] = []
var _window_size := Vector2i.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_window_size = root.size
	root.size = Vector2i(1280, 720)
	var session := get_root().get_node_or_null("GameSession")
	_packed = load("res://games/yacomio/gameplay.tscn") as PackedScene
	if session == null or _packed == null:
		printerr("YaComio scene and shared GameSession are required.")
		quit(1)
		return
	GameCatalog.select(Options.GAME_ID)
	session.call("configure_single_player")
	if _fixture.begin(self) != OK:
		quit(1)
		return
	await _test_play_and_reload()
	await _test_full_timeline_and_journal()
	await _test_optional_upgrade_access()
	await _test_shared_screens()
	_test_token_reconciliation()
	await _test_damaged_save()
	for game in _opened:
		if is_instance_valid(game):
			game.free()
	_expect(_fixture.restore() == OK, "The player's complete YaComio progress must be restored.")
	root.size = _window_size
	await create_timer(0.8, true, false, true).timeout
	var audio_manager := root.get_node("AudioManager")
	for player: AudioStreamPlayer in audio_manager.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await create_timer(0.1, true, false, true).timeout
	if _failures.is_empty():
		print("YaComio scene tests passed (%s)." % DisplayServer.get_name())
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _open() -> Node:
	var game := _packed.instantiate()
	get_root().add_child(game)
	_opened.append(game)
	game.set_process(false)
	await process_frame
	await process_frame
	return game


func _test_play_and_reload() -> void:
	var game := await _open()
	var state: RefCounted = game.get("_state")
	_expect(bool(game.get("_round_active"))
		and (game.get_node("%RoundTimer") as Timer).is_stopped(),
		"Idle gameplay must start without arming a countdown or lives rule.")
	var tap := game.get_node("%TapMicrobe") as Button
	var rna := game.get_node("%BuyRNA") as Button
	var dna := game.get_node("%BuyDNA") as Button
	_expect(rna.disabled and dna.disabled,
		"Unaffordable upgrades must begin disabled.")
	await _click(game, tap)
	_expect(int(state.get("ep")) == 5,
		"A real pointer click must award one tap, not two.")
	var settings := get_root().get_node("Settings")
	var key := InputEventKey.new()
	key.physical_keycode = int(settings.call("binding_keycode", Options.TAP_KEY))
	key.pressed = true
	get_root().push_input(key, true)
	key = key.duplicate() as InputEventKey
	key.pressed = false
	get_root().push_input(key, true)
	await process_frame
	_expect(int(state.get("ep")) == 10 and not rna.disabled,
		"The live keyboard shortcut must use the same economy and enable RNA.")
	await _click(game, rna)
	_expect(int(state.get("ep")) == 0 and int(state.call("ep_per_second")) == 2
		and rna.disabled and rna.text.contains("Unlocked"),
		"Buying RNA must spend 10 EP once and label it as unlocked.")
	game.call("_update_round", 1.0, 0.0)
	_expect(int(state.get("ep")) == 2, "The scene must feed play time into upgraded production.")
	paused = true
	game.call("_update_round", 50.0, 0.0)
	tap.pressed.emit()
	_expect(int(state.get("ep")) == 2, "Paused time and paused actions must earn no EP.")
	paused = false
	game.call("_update_round", 24.0, 0.0)
	await _click(game, dna)
	_expect(int(state.get("ep")) == 0 and int(state.call("ep_per_second")) == 5,
		"DNA must spend 50 EP and raise the combined rate to 5 EP/s.")
	game.call("_update_round", 120.0, 0.0)
	_expect(int(state.get("ep")) == 600 and bool(game.get("_round_active")),
		"Long active play must remain untimed after both upgrades.")
	await _test_layouts(game)
	game.free()
	game = await _open()
	state = game.get("_state")
	_expect(int(state.get("ep")) == 600 and int(state.call("ep_per_second")) == 5,
		"A new scene must resume the automatically saved colony without offline gains.")
	game.free()


func _click(game: Node, button: Button) -> void:
	var scroll := game.get_node("%EvolutionScroll") as ScrollContainer
	scroll.ensure_control_visible(button)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_root().push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_root().push_input(event, true)
	await process_frame


func _test_layouts(game: Node) -> void:
	var original := get_root().size
	for dimensions: Vector2i in [
		Vector2i(320, 568), Vector2i(844, 390),
		Vector2i(1280, 720), Vector2i(2560, 1080),
	]:
		get_root().size = dimensions
		await process_frame
		await process_frame
		await process_frame
		var panel := game.get_node("%EvolutionPanel") as Control
		var scroll := game.get_node("%EvolutionScroll") as ScrollContainer
		var viewport_size := get_root().get_visible_rect().size
		_expect(panel.position.x >= 0.0 and panel.position.y >= 0.0
			and panel.get_rect().end.x <= viewport_size.x + 1.0
			and panel.get_rect().end.y <= viewport_size.y + 1.0
			and scroll.size.y > 0.0,
			"Gameplay must retain on-screen, scrollable content at %s." % dimensions)
		var buttons: Array = (game.get("_upgrade_buttons") as Dictionary).values()
		for node_name in ["TapMicrobe", "Evolve", "MilestoneEvent", "EvolutionaryLeap", "FinishVisit"]:
			buttons.append(game.get_node("%" + node_name))
		for button: Button in buttons:
			if not button.is_visible_in_tree():
				continue
			_expect(button.size.x <= scroll.size.x + 1.0,
				"Action buttons must fit horizontally at %s." % dimensions)
	get_root().size = original
	await process_frame


func _test_damaged_save() -> void:
	var file := ConfigFile.new()
	file.set_value("save", "version", 999)
	file.set_value("progress", "ep", 42)
	file.set_value("progress", "upgrades", [])
	_expect(file.save(Options.SAVE_PATH) == OK, "Damaged-save fixture must be writable.")
	var bytes := FileAccess.get_file_as_bytes(Options.SAVE_PATH)
	var game := await _open()
	game.call("_update_round", 100.0, 0.0)
	(game.get_node("%TapMicrobe") as Button).pressed.emit()
	_expect((game.get_node("%TapMicrobe") as Button).disabled
		and (game.get_node("%SaveStatus") as Label).text.contains("Nothing was overwritten")
		and FileAccess.get_file_as_bytes(Options.SAVE_PATH) == bytes,
		"An unreadable save must disable play, explain recovery and remain untouched.")
	game.free()


func _test_full_timeline_and_journal() -> void:
	var game := await _open()
	var state: RefCounted = game.get("_state")
	for era in Options.STAGES.size():
		for id in Options.UPGRADE_ORDER:
			if int(Options.UPGRADES[id]["stage"]) != era or (state.get("upgrades") as Array).has(id):
				continue
			var tries := 0
			while not bool(state.call("can_buy", id)) and tries < 100:
				game.call("_update_round", 60.0, 0.0)
				tries += 1
			_expect(bool(state.call("can_buy", id)), "Actual production must fund %s." % id)
			if not bool(state.call("can_buy", id)):
				game.free()
				return
			var buttons: Dictionary = game.get("_upgrade_buttons")
			await _click(game, buttons[id])
			_expect((state.get("upgrades") as Array).has(id),
				"A real upgrade click must buy %s in the current era." % id)
			if not (state.get("upgrades") as Array).has(id):
				game.free()
				return
		if era + 1 < Options.STAGES.size():
			var gate: Dictionary = Options.STAGES[era + 1]
			var event := str(gate["event"])
			if not event.is_empty():
				await _click(game, game.get_node("%MilestoneEvent"))
				_expect(str(state.get("active_event")) == event,
					"The real event button must start the era's required event.")
				game.call("_update_round", float(Options.EVENTS[event]["duration"]), 0.0)
			var tries := 0
			while not bool(state.call("can_evolve")) and tries < 100:
				game.call("_update_round", 60.0, 0.0)
				tries += 1
			await _click(game, game.get_node("%Evolve"))
			_expect(int(state.get("stage")) == era + 1,
				"The real Evolve button must pass each completed gate.")
			if int(state.get("stage")) != era + 1:
				game.free()
				return
	_expect(bool(state.call("can_prestige")), "The complete human upgrade path must offer a leap.")
	state.set("ep", Options.MAX_RESOURCE)
	var before_bp := int((state.get("resources") as Dictionary)["bp"])
	game.call("_update_round", 120.0, 0.0)
	var saved := ConfigFile.new()
	saved.load(Options.SAVE_PATH)
	_expect(int((saved.get_value("progress", "resources") as Dictionary)["bp"]) > before_bp,
		"Other resources and full daylight cycles must still save when EP is at its ceiling.")
	await _test_layouts(game)
	var store := get_root().get_node("Store")
	var before_tokens := int(store.call("points", Options.GAME_ID))
	var before_production := float(state.call("ep_per_second"))
	_expect(before_tokens > 0, "Live passive EP must fund the shared cosmetic store.")
	_expect(bool(store.call("purchase", Options.GAME_ID, "yacomio_membrane_amber")),
		"Earned tokens must buy and equip an actual declared colony colour.")
	_expect(float(state.call("ep_per_second")) == before_production,
		"Buying cosmetics must not alter any evolution production rate.")
	var dialog := game.get_node("%LeapConfirmation") as ConfirmationDialog
	await _click(game, game.get_node("%EvolutionaryLeap"))
	_expect(paused and dialog.visible and dialog.get_cancel_button().has_focus(),
		"Prestige must pause the colony and place initial focus on Cancel.")
	var before_ep := int(state.get("ep"))
	game.call("_update_round", 1000.0, 0.0)
	_expect(int(state.get("ep")) == before_ep, "Confirmation time must generate no resources.")
	dialog.get_cancel_button().pressed.emit()
	await process_frame
	_expect(not paused and int(state.get("stage")) == 4 and int(state.get("leaps")) == 0,
		"Cancelling the confirmation must preserve the entire timeline.")
	await _click(game, game.get_node("%EvolutionaryLeap"))
	dialog.get_ok_button().pressed.emit()
	await process_frame
	_expect(not paused and int(state.get("stage")) == 0 and int(state.get("leaps")) == 1
		and bool(store.call("is_owned", Options.GAME_ID, "yacomio_membrane_amber")),
		"Confirming must reset the timeline once, preserving the purchased cosmetic.")
	game.call("_update_round", 4.0, 0.0)
	_expect(int(state.get("ep")) == 5, "The actual next timeline must apply its +25% bonus.")
	var wallet_before_journal := int(store.call("points", Options.GAME_ID))
	await _click(game, game.get_node("%FinishVisit"))
	_expect(not bool(game.get("_round_active"))
		and int(store.call("points", Options.GAME_ID)) == wallet_before_journal,
		"Finishing a visit must open shared results without paying active tokens twice.")
	_expect((game.get_node("%PlayerOneStatsAccuracy") as Label).text == "1.25"
		and not bool(state.get("offline_eligible")),
		"The journal must show meaningful production stats and suspend catch-up during results.")
	var payload: Dictionary = game.call("_share_payload")
	var frozen: Dictionary = payload["colony"]
	_expect(frozen.has("membrane"), "The finished journal must contain its actual colony snapshot.")
	if not frozen.has("membrane"):
		game.free()
		return
	store.call("equip", Options.GAME_ID, Options.DEFAULT_MEMBRANE, Options.MEMBRANE_SLOT)
	var later: Dictionary = game.call("_share_payload")
	_expect(frozen["membrane"] == "yacomio_membrane_amber"
		and later["colony"]["membrane"] == frozen["membrane"],
		"The journal must freeze its actual colony outfit, not read later equipment.")
	game.call("_start_round")
	_expect(int(state.get("leaps")) == 1 and int(state.get("ep")) == 5
		and bool(game.get("_round_active")),
		"Continue must resume the saved colony, not perform another reset.")
	game.free()


func _test_optional_upgrade_access() -> void:
	var game := await _open()
	var state: RefCounted = game.get("_state")
	for order: Array in [["rna", "dna", "membrane"], ["chloroplast", "algae"]]:
		for id: String in order:
			var tries := 0
			while not bool(state.call("can_buy", id)) and tries < 100:
				game.call("_update_round", 60.0, 0.0)
				tries += 1
			await _click(game, (game.get("_upgrade_buttons") as Dictionary)[id])
		var tries := 0
		while not bool(state.call("can_evolve")) and tries < 100:
			game.call("_update_round", 60.0, 0.0)
			tries += 1
		await _click(game, game.get_node("%Evolve"))
	var optional := (game.get("_upgrade_buttons") as Dictionary)["photoprotection"] as Button
	_expect(int(state.get("stage")) == 2 and optional.is_visible_in_tree(),
		"An unbought optional upgrade must remain accessible after leaving its era.")
	var tries := 0
	while not bool(state.call("can_buy", "photoprotection")) and tries < 100:
		game.call("_update_round", 60.0, 0.0)
		tries += 1
	await _click(game, optional)
	_expect((state.get("upgrades") as Array).has("photoprotection"),
		"The retained earlier-era button must still buy the upgrade normally.")
	game.free()


func _test_shared_screens() -> void:
	var store := get_root().get_node("Store")
	var before: Dictionary = store.call("export_save", Options.GAME_ID)
	var bytes := FileAccess.get_file_as_bytes(Options.SAVE_PATH)
	for path in ["res://scenes/menus/store.tscn", "res://scenes/menus/gallery.tscn"]:
		var packed := load(path) as PackedScene
		var menu := packed.instantiate()
		menu.set("game_context_id", Options.GAME_ID)
		get_root().add_child(menu)
		await process_frame
		await process_frame
		if path.contains("gallery"):
			var buttons: Array = menu.get("_buttons")
			for button: Button in buttons:
				button.pressed.emit()
			var stage: Node = menu.get("_stage")
			_expect(stage != null and (stage.get("_configured") as Dictionary)["id"] == "civilization",
				"The real shared gallery must configure the final actual exhibit.")
		else:
			_expect(not (menu.get("_cards") as Array).is_empty(),
				"The real shared store must build usable cosmetic cards.")
		menu.free()
	var intro := (load("res://games/yacomio/intro.tscn") as PackedScene).instantiate()
	get_root().add_child(intro)
	await process_frame
	for index in 4:
		(intro.get_node("%NextButton") as Button).pressed.emit()
	_expect(int(intro.get("_card_index")) == 4
		and (intro.get_node("%NextButton") as Button).text == "Done",
		"The opening must advance at the player's pace and end with Done.")
	intro.free()
	_expect(FileAccess.get_file_as_bytes(Options.SAVE_PATH) == bytes
		and (store.call("export_save", Options.GAME_ID) as Dictionary) == before,
		"Browsing the store, free gallery and story must never advance or mutate progress.")


func _test_token_reconciliation() -> void:
	var store := get_root().get_node("Store")
	var original: Dictionary = store.call("export_save", Options.GAME_ID)
	store.call("erase_save", Options.GAME_ID)
	var state := State.new()
	state.advance(1000.0)
	_expect(Bank.reconcile(store, state) == OK and int(store.call("points", Options.GAME_ID)) == 10,
		"One thousand active EP must reconcile to ten Spore Tokens.")
	_expect(bool(store.call("purchase", Options.GAME_ID, "yacomio_membrane_amber")),
		"The reconciliation fixture must buy a priced cosmetic.")
	_expect(Bank.reconcile(store, state) == OK and Bank.reconcile(store, state) == OK
		and int(store.call("points", Options.GAME_ID)) == 2,
		"Repeated reconciliation must retain spending and never duplicate an award.")
	state.last_seen = 1000
	state.apply_offline(1_000_000)
	_expect(Bank.reconcile(store, state) == OK and int(store.call("points", Options.GAME_ID)) == 2,
		"Offline EP must never leak into the cosmetic wallet.")
	store.call("import_save", Options.GAME_ID, original)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

extends SceneTree

## Drive real controls, pause and reload while preserving the player's save.
## Load the shell at runtime because it uses autoload instances.

const Options := preload("res://games/yacomio/yacomio_options.gd")

var _failures := PackedStringArray()
var _packed: PackedScene
var _saved_bytes := PackedByteArray()
var _had_save := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := get_root().get_node_or_null("GameSession")
	_packed = load("res://games/yacomio/gameplay.tscn") as PackedScene
	if session == null or _packed == null:
		printerr("YaComio scene and shared GameSession are required.")
		quit(1)
		return
	GameCatalog.select(Options.GAME_ID)
	session.call("configure_single_player")
	_had_save = FileAccess.file_exists(Options.SAVE_PATH)
	if _had_save:
		_saved_bytes = FileAccess.get_file_as_bytes(Options.SAVE_PATH)
		DirAccess.remove_absolute(Options.SAVE_PATH)
	await _test_play_and_reload()
	await _test_damaged_save()
	_restore_save()
	await create_timer(0.15, true, false, true).timeout
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
		for node_name in ["TapMicrobe", "BuyRNA", "BuyDNA"]:
			var button := game.get_node("%" + node_name) as Button
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


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open(Options.SAVE_PATH, FileAccess.WRITE)
		if file == null:
			_failures.append("Could not restore the original YaComio save.")
		else:
			file.store_buffer(_saved_bytes)
	elif FileAccess.file_exists(Options.SAVE_PATH):
		DirAccess.remove_absolute(Options.SAVE_PATH)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

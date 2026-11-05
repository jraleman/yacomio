extends SceneTree

## Require a real Compatibility renderer: inspect actual geometry, rasterized
## exhibits, gameplay layouts, reduced motion and the generated share image.

const Options := preload("res://games/yacomio/yacomio_options.gd")
const Models := preload("res://games/yacomio/colony_models.gd")
const Fixture := preload("res://games/yacomio/tests/progress_fixture.gd")

var _failures := PackedStringArray()
var _fixture := Fixture.new()
var _settings: Node
var _original_size := Vector2i.ZERO
var _original_scale := 1.0
var _original_motion := false
var _artifacts := ""
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("YaComio rendered tests require a graphics window; omit --headless.")
		quit(1)
		return
	_settings = root.get_node("Settings")
	_original_size = root.size
	_original_scale = float(_settings.call("get_value", "ui/scale", 1.0))
	_original_motion = bool(_settings.call("reduced_motion_enabled"))
	root.size = Vector2i(1280, 720)
	_settings.call("set_value", "ui/scale", 1.0)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	GameCatalog.select(Options.GAME_ID)
	root.get_node("GameSession").call("configure_single_player")
	if _fixture.begin(self) != OK:
		_finish()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--artifacts="):
			_artifacts = argument.trim_prefix("--artifacts=")
	if not _artifacts.is_empty():
		_expect(DirAccess.make_dir_recursive_absolute(_artifacts) == OK,
			"Rendered-test artifact directory must be writable.")
	await _test_actual_exhibits()
	await _test_readonly_presentations()
	await _test_gameplay_layouts()
	await _test_motion_and_share()
	await _test_phone_confirmation()
	if is_instance_valid(_game):
		_game.free()
	_expect(_fixture.restore() == OK, "Rendered tests must restore the player's progress.")
	_finish()


func _test_actual_exhibits() -> void:
	var stage := (load("res://games/yacomio/gallery_stage.tscn") as PackedScene).instantiate() as Control
	root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1200, 800)
	var hashes: Array[int] = []
	var store := root.get_node("Store")
	var wallet: Dictionary = store.call("export_save", Options.GAME_ID)
	var had_save := FileAccess.file_exists(Options.SAVE_PATH)
	for exhibit in Options.GALLERY_EXHIBITS:
		stage.call("configure", exhibit)
		stage.call("set_view", 0.0, 0.0, 1.0)
		await _draw_frames()
		var model := stage.get("_model") as Node3D
		_expect(model != null and model.find_children("*", "MeshInstance3D", true, false).size() > 8,
			"An exhibit must contain actual subject geometry, not just a badge or base.")
		if model == null:
			continue
		var box := Models.bounds(model)
		_expect(box.size.x > 0 and box.size.y > 0 and box.size.z > 0
			and box.position.is_finite() and box.size.is_finite(),
			"Every real exhibit must have finite, non-flat bounds.")
		var camera := stage.get("_camera") as Camera3D
		var viewport := stage.get("_viewport") as SubViewport
		for corner in 8:
			var point := box.position + Vector3(
				box.size.x if corner & 1 else 0.0,
				box.size.y if corner & 2 else 0.0,
				box.size.z if corner & 4 else 0.0
			)
			var pixel := camera.unproject_position(point)
			_expect(not camera.is_position_behind(point)
				and Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(2.0).has_point(pixel),
				"Default framing must retain the whole actual exhibit.")
		var image := viewport.get_texture().get_image()
		_expect(_has_subject_pixels(image), "The real viewport must rasterize a coloured 3D subject.")
		var digest := hash(image.get_data())
		_expect(not hashes.has(digest), "Different exhibits must render different actual models.")
		hashes.append(digest)
		_save_image(image, "exhibit_%s.png" % exhibit["id"])
	var camera := stage.get("_camera") as Camera3D
	var before := camera.transform
	stage.call("set_view", 0.8, 0.35, 1.2)
	_expect(camera.transform != before, "Gallery orbit/zoom must move the actual camera.")
	stage.free()
	_expect(FileAccess.file_exists(Options.SAVE_PATH) == had_save
		and (store.call("export_save", Options.GAME_ID) as Dictionary) == wallet,
		"Rendering and orbiting late-era exhibits must not create progress or move tokens.")


func _test_gameplay_layouts() -> void:
	_game = (load("res://games/yacomio/gameplay.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	_game.set_process(false)
	await _draw_frames()
	for dimensions: Vector2i in [
		Vector2i(320, 568), Vector2i(844, 390),
		Vector2i(1280, 720), Vector2i(2560, 1080),
	]:
		root.size = dimensions
		await _draw_frames()
		var view := _game.get_node("%ColonyView") as Control
		var scroll := _game.get_node("%EvolutionScroll") as ScrollContainer
		var panel := _game.get_node("%EvolutionPanel") as Control
		_expect(view.size.x > 0 and view.size.y > 0 and scroll.size.x > 0 and scroll.size.y > 0,
			"The actual colony and scrollable actions must retain space at %s." % dimensions)
		_expect(root.get_visible_rect().grow(1).encloses(panel.get_global_rect()),
			"The rendered gameplay panel must remain on-screen at %s." % dimensions)
		var viewport := view.get("_viewport") as SubViewport
		_expect(_has_subject_pixels(viewport.get_texture().get_image()),
			"The actual colony must remain visible through each rendered layout.")
		var tap := _game.get_node("%TapMicrobe") as Button
		scroll.ensure_control_visible(tap)
		await _draw_frames()
		_expect(scroll.get_global_rect().grow(1).encloses(tap.get_global_rect()),
			"Focus scrolling must expose the entire actual tap target at %s." % dimensions)
		scroll.scroll_vertical = 0
		await _draw_frames()
		_save_image(root.get_texture().get_image(), "gameplay_%dx%d.png" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	await _draw_frames()


func _test_motion_and_share() -> void:
	var view := _game.get_node("%ColonyView") as Control
	_game.call("_set_reduced_motion_enabled", false)
	await _draw_frames()
	var model := view.get("_model") as Node3D
	_expect(model.rotation.y != 0.0, "Enabled ambient motion must reach the actual colony rig.")
	_game.call("_set_reduced_motion_enabled", true)
	var rotation := model.rotation
	var position := model.position
	await _draw_frames()
	_expect(model.rotation == rotation and model.position == position
		and not bool(view.get("_motion")),
		"Reduced motion must park actual geometry, not merely set a preference flag.")
	_game.call("_tap_microbe")
	_game.call("_end_visit")
	_game.call("_on_see_score_pressed")
	var preview := _game.get_node("%ShareCardPreview") as TextureRect
	for frame in 120:
		if preview.texture != null and not bool(_game.get("_sharing")):
			break
		await process_frame
	_expect(preview.texture != null, "The actual shared journal must generate its score image.")
	if preview.texture != null:
		var image := preview.texture.get_image()
		_expect(image.get_size() == Vector2i(1200, 630),
			"The generated journal must retain the framework's export dimensions.")
		_save_image(image, "journal.png")
	await _draw_frames()
	_save_image(root.get_texture().get_image(), "journal_screen.png")
	root.size = Vector2i(320, 568)
	await _draw_frames()
	_expect(root.get_visible_rect().grow(1.0).encloses(
		(_game.get_node("%ScorePanel") as Control).get_global_rect()),
		"The actual phone journal must retain readable statistics and on-screen actions.")
	_save_image(root.get_texture().get_image(), "journal_screen_320x568.png")
	root.size = Vector2i(1280, 720)
	await _draw_frames()


func _test_readonly_presentations() -> void:
	var store := root.get_node("Store")
	var wallet: Dictionary = store.call("export_save", Options.GAME_ID)
	var had_save := FileAccess.file_exists(Options.SAVE_PATH)
	var intro := (load("res://games/yacomio/intro.tscn") as PackedScene).instantiate()
	root.add_child(intro)
	for dimensions: Vector2i in [Vector2i(320, 568), Vector2i(844, 390)]:
		root.size = dimensions
		for index in 5:
			intro.call("_show_card", index)
			await _draw_frames()
			var stage := intro.get_node("%Stage") as Control
			var viewport := stage.get("_viewport") as SubViewport
			_expect(_has_subject_pixels(viewport.get_texture().get_image()),
				"Each opening card must actually render its original subject at %s." % dimensions)
			for name in ["NextButton", "SkipButton"]:
				_expect(root.get_visible_rect().encloses((intro.get_node("%" + name) as Button).get_global_rect()),
					"Opening navigation must remain on-screen at %s." % dimensions)
		_save_image(root.get_texture().get_image(), "intro_%dx%d.png" % [dimensions.x, dimensions.y])
	intro.free()
	root.size = Vector2i(1280, 720)
	var preview := (load("res://games/yacomio/store_preview.tscn") as PackedScene).instantiate() as Control
	root.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.size = Vector2(900, 600)
	var hashes: Array[int] = []
	for item in Options.STORE_ITEMS:
		preview.call("configure", item)
		await _draw_frames()
		var viewport := preview.get("_viewport") as SubViewport
		var image := viewport.get_texture().get_image()
		_expect(_has_subject_pixels(image), "The store must render the actual cosmetic subject.")
		if int(item["price"]) > 0:
			var digest := hash(image.get_data())
			_expect(not hashes.has(digest), "Different paid cosmetics must change actual rendered appearance.")
			hashes.append(digest)
			_save_image(image, "cosmetic_%s.png" % item["id"])
	preview.free()
	_expect(FileAccess.file_exists(Options.SAVE_PATH) == had_save
		and (store.call("export_save", Options.GAME_ID) as Dictionary) == wallet,
		"Actual opening and store renders must leave evolution and the wallet unchanged.")


func _test_phone_confirmation() -> void:
	_game.call("_start_round")
	var state: RefCounted = _game.get("_state")
	for era in Options.STAGES.size():
		state.set("ep", 1_000_000)
		for resource: String in Options.RESOURCE_KEYS:
			if resource != "ep" and int(Options.RESOURCES[resource]["stage"]) <= era:
				(state.get("resources") as Dictionary)[resource] = 1_000_000
		for id: String in Options.UPGRADE_ORDER:
			if int(Options.UPGRADES[id]["stage"]) == era:
				_expect(bool(state.call("buy", id)), "The rendered-dialog fixture must unlock %s." % id)
		if era + 1 < Options.STAGES.size():
			var event := str(Options.STAGES[era + 1]["event"])
			if not event.is_empty():
				state.call("trigger_event", event)
				state.call("advance", float(Options.EVENTS[event]["duration"]))
			_expect(bool(state.call("evolve")), "The rendered-dialog fixture must reach the next era.")
	_game.call("_persist_progress")
	root.size = Vector2i(320, 568)
	await _draw_frames()
	_game.call("_request_prestige")
	await _draw_frames()
	var dialog := _game.get_node("%LeapConfirmation") as ConfirmationDialog
	_expect(dialog.visible and paused
		and root.get_visible_rect().encloses(Rect2(Vector2(dialog.position), Vector2(dialog.size))),
		"The real confirmation must fit the phone and suspend the colony: viewport=%s, dialog=%s at %s, content=%s, label=%s." % [
			root.get_visible_rect(), dialog.size, dialog.position,
			dialog.content_scale_factor, dialog.get_label().size,
		])
	_save_image(root.get_texture().get_image(), "leap_320x568.png")
	dialog.get_cancel_button().pressed.emit()
	_expect(not paused and int(state.get("stage")) == 4 and int(state.get("leaps")) == 0,
		"Cancelling the phone confirmation must leave the completed civilization intact.")
	root.size = Vector2i(1280, 720)


func _draw_frames() -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw


func _has_subject_pixels(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var visible := 0
	var colours: Dictionary[int, bool] = {}
	for y in range(0, image.get_height(), maxi(1, image.get_height() / 24)):
		for x in range(0, image.get_width(), maxi(1, image.get_width() / 24)):
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.1:
				continue
			visible += 1
			var colour := roundi(pixel.r * 15) * 256 + roundi(pixel.g * 15) * 16 + roundi(pixel.b * 15)
			colours[colour] = true
	return visible > 20 and colours.size() > 8


func _save_image(image: Image, name: String) -> void:
	if not _artifacts.is_empty():
		_expect(image.save_png(_artifacts.path_join(name)) == OK,
			"Rendered verification artifact must save: %s." % name)


func _finish() -> void:
	_settings.call("set_value", "ui/scale", _original_scale)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, _original_motion)
	root.size = _original_size
	if _failures.is_empty():
		print("YaComio rendered tests passed (%s)." % DisplayServer.get_name())
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

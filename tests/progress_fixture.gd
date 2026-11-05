extends RefCounted

## Tests replace only this game's progress and restore it through the shared
## APIs, preserving every other game's wallet and achievements.

const Options := preload("res://games/yacomio/yacomio_options.gd")

var _store: Node
var _achievements: Node
var _store_save: Dictionary = {}
var _achievement_save: Dictionary = {}
var _bytes := PackedByteArray()
var _had_file := false
var _active := false


func begin(tree: SceneTree) -> Error:
	_store = tree.root.get_node_or_null("Store")
	_achievements = tree.root.get_node_or_null("AchievementManager")
	if _store == null or _achievements == null:
		push_error("YaComio tests require the shared progress autoloads.")
		return ERR_UNAVAILABLE
	_had_file = FileAccess.file_exists(Options.SAVE_PATH)
	if _had_file:
		var file := FileAccess.open(Options.SAVE_PATH, FileAccess.READ)
		if file == null:
			return FileAccess.get_open_error()
		_bytes = file.get_buffer(file.get_length())
	_store_save = _store.call("export_save", Options.GAME_ID)
	_achievement_save = _achievements.call("export_save", Options.GAME_ID)
	_active = true
	var status: Error = _store.call("erase_save", Options.GAME_ID)
	if status == OK:
		status = _achievements.call("erase_save", Options.GAME_ID)
	if status == OK and _had_file:
		status = DirAccess.remove_absolute(Options.SAVE_PATH)
	if status != OK:
		restore()
		push_error("YaComio: could not isolate test progress (error %d)." % status)
	return status


func restore() -> Error:
	if not _active:
		return OK
	var status := OK
	if _had_file:
		var file := FileAccess.open(Options.SAVE_PATH, FileAccess.WRITE)
		if file == null:
			status = FileAccess.get_open_error()
		else:
			file.store_buffer(_bytes)
			file.flush()
			status = file.get_error()
	elif FileAccess.file_exists(Options.SAVE_PATH):
		status = DirAccess.remove_absolute(Options.SAVE_PATH)
	var wallet_status: Error = _store.call("import_save", Options.GAME_ID, _store_save)
	var achievement_status: Error = _achievements.call(
		"import_save", Options.GAME_ID, _achievement_save
	)
	if status == OK:
		status = wallet_status if wallet_status != OK else achievement_status
	if status != OK:
		push_error("YaComio: could not restore test progress (error %d)." % status)
	else:
		_active = false
	return status

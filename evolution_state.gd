extends RefCounted

## Resource rules have no scene or autoload dependency. Only supplied play time
## earns EP; saves contain no wall clock or offline catch-up.

const Options := preload("res://games/yacomio/yacomio_options.gd")
const SAVE_VERSION := 1

var ep := 0
var upgrades: Array[String] = []
var _tick_elapsed := 0.0


func ep_per_second() -> int:
	var rate := 1
	for id in upgrades:
		rate += int(Options.UPGRADES[id]["rate"])
	return rate


func advance(delta: float) -> int:
	if not is_finite(delta) or delta < 0.0:
		push_error("YaComio: play time must be finite and non-negative.")
		return 0
	_tick_elapsed += delta
	var ticks := floori(_tick_elapsed)
	_tick_elapsed -= ticks
	var generated := ticks * ep_per_second()
	ep += generated
	return generated


func tap() -> int:
	ep += Options.TAP_GAIN
	return Options.TAP_GAIN


func can_buy(id: String) -> bool:
	return (
		Options.UPGRADES.has(id) and not upgrades.has(id)
		and ep >= int(Options.UPGRADES[id]["cost"])
	)


func buy(id: String) -> bool:
	if not Options.UPGRADES.has(id):
		push_warning("YaComio: unknown upgrade '%s'." % id)
		return false
	if not can_buy(id):
		return false
	ep -= int(Options.UPGRADES[id]["cost"])
	upgrades.append(id)
	return true


## Validate the whole snapshot before changing live state. A newer or damaged
## save must never be replaced by an apparently successful fresh game.
func load_save(path: String = Options.SAVE_PATH) -> Error:
	var file := ConfigFile.new()
	var status := file.load(path)
	if status == ERR_FILE_NOT_FOUND:
		return status
	if status != OK:
		push_warning("YaComio: could not read %s (error %d)." % [path, status])
		return status
	var version: Variant = file.get_value("save", "version", null)
	var saved_ep: Variant = file.get_value("progress", "ep", null)
	var saved_upgrades: Variant = file.get_value("progress", "upgrades", null)
	if (
		not version is int or version != SAVE_VERSION
		or not saved_ep is int or saved_ep < 0 or not saved_upgrades is Array
	):
		return _invalid_save(path)
	var restored: Array[String] = []
	for id: Variant in saved_upgrades:
		if not id is String or not Options.UPGRADES.has(id) or restored.has(id):
			return _invalid_save(path)
		restored.append(id)
	ep = saved_ep
	upgrades.assign(restored)
	_tick_elapsed = 0.0
	return OK


func save(path: String = Options.SAVE_PATH) -> Error:
	var file := ConfigFile.new()
	file.set_value("save", "version", SAVE_VERSION)
	file.set_value("progress", "ep", ep)
	file.set_value("progress", "upgrades", upgrades)
	var status := file.save(path)
	if status != OK:
		push_warning("YaComio: could not save %s (error %d)." % [path, status])
	return status


func _invalid_save(path: String) -> Error:
	push_warning("YaComio: unsupported or damaged save at %s; left untouched." % path)
	return ERR_INVALID_DATA

extends SceneTree

## Pin the original economy and reject damaged saves without mutating state.

const State := preload("res://games/yacomio/evolution_state.gd")

var _failures := PackedStringArray()
var _path := "user://yacomio_state_test_%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_ticks_and_taps()
	_test_upgrade_orders()
	_test_save_round_trip()
	_test_invalid_saves()
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	if _failures.is_empty():
		print("YaComio evolution state tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_ticks_and_taps() -> void:
	var state := State.new()
	_expect(state.advance(0.25) == 0 and state.ep == 0,
		"Partial seconds must not award a whole resource tick.")
	_expect(state.advance(0.75) == 1 and state.ep == 1,
		"A fresh colony must generate exactly 1 EP per second.")
	_expect(state.advance(3.5) == 3 and state.advance(0.5) == 1,
		"Long frames must retain both whole ticks and their remainder.")
	_expect(state.tap() == 5 and state.ep == 10,
		"Each tap must add exactly 5 EP independently of passive generation.")


func _test_upgrade_orders() -> void:
	for order: Array in [["rna", "dna"], ["dna", "rna"]]:
		var state := State.new()
		_expect(not state.buy("rna") and state.ep == 0,
			"Unaffordable upgrades must not spend points or change production.")
		for id: String in order:
			var cost := 10 if id == "rna" else 50
			state.ep = cost
			_expect(state.buy(id) and state.ep == 0,
				"An affordable upgrade must spend its exact cost, in either order.")
			state.ep = 100
			var rate := state.ep_per_second()
			_expect(not state.buy(id) and state.ep == 100
				and state.ep_per_second() == rate,
				"An upgrade must never charge or apply twice.")
		_expect(state.ep_per_second() == 5 and state.advance(2.0) == 10,
			"RNA and DNA must add 1 and 3 EP/s to the original base rate.")


func _test_save_round_trip() -> void:
	var state := State.new()
	state.ep = 87
	state.buy("dna")
	state.advance(0.75)
	_expect(state.save(_path) == OK, "Progress must be writable as a native save.")
	var restored := State.new()
	_expect(restored.load_save(_path) == OK and restored.ep == 37
		and restored.upgrades == ["dna"] and restored.ep_per_second() == 4,
		"Reloading must preserve the wallet and derive production from owned upgrades.")
	_expect(restored.advance(0.25) == 0 and restored.ep == 37,
		"Reloading must not grant offline or previous-session partial ticks.")
	_expect(restored.advance(0.75) == 4,
		"Passive production must restart with the restored upgrades.")


func _test_invalid_saves() -> void:
	var state := State.new()
	state.ep = 20
	state.buy("rna")
	for values: Array in [
		[1, -1, []], [1, 2.5, []], [1, 10, ["unknown"]],
		[1, 10, ["rna", "rna"]], [1, 10, "rna"], [2, 10, []],
	]:
		var file := ConfigFile.new()
		file.set_value("save", "version", values[0])
		file.set_value("progress", "ep", values[1])
		file.set_value("progress", "upgrades", values[2])
		_expect(file.save(_path) == OK, "Invalid-save fixture must be writable.")
		var bytes := FileAccess.get_file_as_bytes(_path)
		_expect(state.load_save(_path) == ERR_INVALID_DATA
			and state.ep == 10 and state.upgrades == ["rna"],
			"Invalid progress must leave the entire live colony unchanged.")
		_expect(FileAccess.get_file_as_bytes(_path) == bytes,
			"Refusing a save must not overwrite it.")
	DirAccess.remove_absolute(_path)
	_expect(state.load_save(_path) == ERR_FILE_NOT_FOUND,
		"A missing save must be distinguishable from a damaged save.")
	_expect(state.save(_path + "/missing.cfg") != OK,
		"A write failure must be returned to the caller, not treated as success.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

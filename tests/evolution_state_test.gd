extends SceneTree

## Preserve the original economy while covering all eras, time and safe resets.

const State := preload("res://games/yacomio/evolution_state.gd")
const Options := preload("res://games/yacomio/yacomio_options.gd")

var _failures := PackedStringArray()
var _path := "user://yacomio_state_test_%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_ticks_and_taps()
	_test_upgrade_orders()
	_test_save_round_trip()
	_test_invalid_saves()
	_test_era_gates_and_completion()
	_test_daylight_and_unlimited_offline()
	_test_events_across_offline_time()
	_test_prestige_and_fractional_production()
	_test_legacy_migration()
	_test_current_save_validation()
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


func _test_era_gates_and_completion() -> void:
	var state := State.new()
	state.ep = 10000
	_expect(not state.evolve() and not state.buy("fish") and state.stage == 0,
		"Money alone must not bypass era gates or expose future upgrades.")
	_expect(not state.buy("membrane") and state.ep == 10000,
		"Membranes must require both strands and refuse to spend on a locked upgrade.")
	_reach(state, 4)
	_expect(state.stage == 4 and not state.can_evolve()
		and state.completed_events.has("cambrian") and state.completed_events.has("extinction"),
		"Every era must be reachable through its actual upgrade and event gates.")
	_expect(not state.can_prestige(), "Entering the human era must not complete civilization.")
	_buy_era(state)
	_expect(state.upgrades.has("civilization") and state.can_prestige()
		and state.rate("culture") > 0 and state.rate("population") > 0,
		"Human upgrades must produce culture/population and unlock prestige only at completion.")
	var rates: Dictionary[String, float] = {}
	for resource in Options.RESOURCE_KEYS:
		rates[resource] = state.rate(resource)
	state.ep = 0
	for resource in state.resources:
		state.resources[resource] = 0
	_expect(state.trigger_event("golden"), "Agriculture must open the optional Golden Age.")
	state.advance(120.0)
	for resource in Options.RESOURCE_KEYS:
		var seconds := 60 if resource == "light" else 120
		_expect(state.amount(resource) == floori(rates[resource] * seconds * 2.0),
			"The Golden Age must double each unlocked resource, respecting daylight.")
	_expect(state.completed_events.has("golden") and not state.can_trigger_event("golden"),
		"The Golden Age must expire and remain a one-time event until a leap.")


func _test_daylight_and_unlimited_offline() -> void:
	var state := State.new()
	_reach(state, 1)
	state.ep = 0
	state.resources["light"] = 0
	state.advance(60.0)
	_expect(state.resources["light"] == 120 and not state.is_daylight(),
		"Photosynthesis must produce Light during the 60-second day.")
	var ep_at_night := state.ep
	state.advance(60.0)
	_expect(state.resources["light"] == 120 and state.ep > ep_at_night and state.is_daylight(),
		"Night must stop Light, not EP, and finish the saved daylight cycle.")
	_expect(state.save(_path, 1000) == OK, "Offline fixture must be writable.")
	var restored := State.new()
	_expect(restored.load_save(_path) == OK, "Offline fixture must reload.")
	var active_before := restored.active_ep
	var year := 365 * 24 * 60 * 60
	var gains := restored.apply_offline(1000 + year)
	_expect(gains["ep"] == year * 24 and gains["light"] == year
		and restored.active_ep == active_before and restored.stage == 1,
		"Unlimited offline time must use saved rates/daylight, never buy upgrades or earn tokens.")
	_expect(restored.apply_offline(1000 + year)["ep"] == 0,
		"A single live state must not apply the same offline interval twice.")
	restored.offline_eligible = false
	_expect(restored.apply_offline(1000 + year + 3600)["ep"] == 0,
		"A suspended/crashed paused session must not count menu time as offline production.")
	_expect(restored.apply_offline(900)["ep"] == 0 and restored.clock_rolled_back,
		"A backwards clock must grant no negative or duplicate resources.")


func _test_events_across_offline_time() -> void:
	var state := State.new()
	_reach(state, 3)
	_fund(state)
	state.buy("land_plants")
	state.buy("dinosaurs")
	_expect(state.trigger_event("extinction") and not state.trigger_event("extinction"),
		"An event must require its upgrades and never start twice.")
	state.resources["bp"] = 0
	_expect(state.save(_path, 2000) == OK, "An active event must save.")
	var restored := State.new()
	_expect(restored.load_save(_path) == OK and restored.event_remaining == 60,
		"Reloading must retain the exact remaining event duration.")
	var gains := restored.apply_offline(2120)
	_expect(gains["bp"] == 1140 and restored.active_event.is_empty()
		and restored.completed_events.has("extinction")
		and restored.milestones.has("yacomio_extinction"),
		"Catch-up must split at expiry, restore normal rates and pay the event reward once.")
	var balance := restored.resources["bp"]
	restored.apply_offline(2120)
	_expect(restored.resources["bp"] == balance and not restored.can_trigger_event("extinction"),
		"A completed event must not repay or restart in the same timeline.")


func _test_prestige_and_fractional_production() -> void:
	var state := State.new()
	_expect(not state.prestige(), "An incomplete timeline must never reset.")
	_reach(state, 4)
	_buy_era(state)
	var earned := state.active_ep
	var milestones := state.milestones.duplicate()
	_expect(state.prestige() and state.stage == 0 and state.ep == 0
		and state.upgrades.is_empty() and state.completed_events.is_empty()
		and state.active_ep == earned and state.leaps == 1,
		"Prestige must reset the timeline, not earned tokens or permanent leaps.")
	for id: String in milestones:
		_expect(state.milestones.has(id), "Prestige must preserve every permanent milestone.")
	for value: int in state.resources.values():
		_expect(value == 0, "Prestige must clear every spendable evolution resource.")
	_expect(not state.prestige() and state.leaps == 1 and state.advance(1.0) == 1,
		"A completed civilization pays one leap, with +25% production on the next timeline.")
	_expect(state.save(_path, 3000) == OK, "Fractional prestige production must save.")
	var restored := State.new()
	_expect(restored.load_save(_path) == OK and restored.advance(3.0) == 4,
		"Fractional resource carry must survive saves: four seconds at 1.25 EP/s earn five EP.")
	restored.ep = Options.MAX_RESOURCE - 2
	restored.advance(1e12)
	_expect(restored.ep == Options.MAX_RESOURCE and restored.at_storage_limit(),
		"A very long absence must saturate safely rather than overflow a resource.")


func _test_legacy_migration() -> void:
	var file := ConfigFile.new()
	file.set_value("save", "version", 1)
	file.set_value("progress", "ep", 37)
	file.set_value("progress", "upgrades", ["dna"])
	_expect(file.save(_path) == OK, "Legacy fixture must be writable.")
	var state := State.new()
	_expect(state.load_save(_path) == OK and state.ep == 37
		and state.upgrades == ["dna"] and state.stage == 0 and state.ep_per_second() == 4,
		"Version-one colonies must retain their exact EP and independent RNA/DNA order.")
	_expect(state.apply_offline(4000)["ep"] == 0 and state.active_ep == 0,
		"Legacy saves without a timestamp must not invent offline gains or historical tokens.")
	_expect(state.save(_path, 4000) == OK and state.load_save(_path) == OK,
		"A migrated colony must round-trip through the new schema.")


func _test_current_save_validation() -> void:
	var live := State.new()
	live.tap()
	for change: Array in [
		["progress", "stage", 4],
		["progress", "resources", {"light": 1}],
		["progress", "fractions", {"ep": -0.1}],
		["progress", "fractions", {"ip": 0.5}],
		["progress", "active_event", "unknown"],
		["progress", "milestones", ["unknown"]],
		["save", "offline_eligible", "yes"],
		["save", "last_seen", -1],
	]:
		var fixture := State.new()
		fixture.save(_path, 5000)
		var file := ConfigFile.new()
		file.load(_path)
		file.set_value(str(change[0]), str(change[1]), change[2])
		file.save(_path)
		var bytes := FileAccess.get_file_as_bytes(_path)
		_expect(live.load_save(_path) == ERR_INVALID_DATA and live.ep == 5
			and live.milestones == ["yacomio_first_tap"],
			"Invalid extended progress must leave the complete live state unchanged.")
		_expect(FileAccess.get_file_as_bytes(_path) == bytes,
			"Refusing an extended save must not modify the player's file.")


func _reach(state: State, target: int) -> void:
	while state.stage < target:
		_buy_era(state)
		var gate: Dictionary = Options.STAGES[state.stage + 1]
		var event := str(gate["event"])
		if not event.is_empty():
			_expect(state.trigger_event(event), "A funded progression must start its required event.")
			state.advance(float(Options.EVENTS[event]["duration"]))
		_fund(state)
		var previous := state.stage
		_expect(state.evolve(), "A funded, completed era must evolve.")
		if state.stage == previous:
			return


func _buy_era(state: State) -> void:
	for id in Options.UPGRADE_ORDER:
		if int(Options.UPGRADES[id]["stage"]) != state.stage:
			continue
		_fund(state)
		_expect(state.buy(id), "Every declared upgrade must be reachable in authored order: %s." % id)


func _fund(state: State) -> void:
	state.ep = 1_000_000
	for resource in state.resources:
		if state.stage >= int(Options.RESOURCES[resource]["stage"]):
			state.resources[resource] = 1_000_000


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

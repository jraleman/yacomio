extends RefCounted

## Node-free evolution rules. Offline catch-up integrates fixed production and
## daylight analytically; only real active generation earns cosmetic tokens.

const Options := preload("res://games/yacomio/yacomio_options.gd")
const SAVE_VERSION := 2

var ep := 0
var upgrades: Array[String] = []
var stage := 0
var resources: Dictionary[String, int] = {
	"light": 0, "bcp": 0, "bp": 0, "ip": 0, "culture": 0, "population": 0,
}
var leaps := 0
var active_ep := 0
var milestones: Array[String] = []
var completed_events: Array[String] = []
var active_event := ""
var event_remaining := 0
var day_second := 0
var last_seen := 0
var offline_eligible := true
var clock_rolled_back := false
var advanced_seconds := 0
var _fractions: Dictionary[String, float] = {}
var _tick_elapsed := 0.0


func amount(resource: String) -> int:
	return ep if resource == "ep" else int(resources.get(resource, 0))


func production_multiplier() -> float:
	return 1.0 + float(leaps) * Options.LEAP_BONUS


func rate(resource: String) -> float:
	if not Options.RESOURCES.has(resource):
		push_error("YaComio: unknown resource '%s'." % resource)
		return 0.0
	if stage < int(Options.RESOURCES[resource]["stage"]):
		return 0.0
	var rates: Dictionary = Options.STAGES[stage]["rates"]
	var result := float(rates.get(resource, 0))
	for id in upgrades:
		var gains: Dictionary = Options.UPGRADES[id]["rates"]
		result += float(gains.get(resource, 0))
	if resource == "ep":
		for id in upgrades:
			result *= float(Options.UPGRADES[id].get("ep_multiplier", 1.0))
	result *= production_multiplier()
	if not active_event.is_empty():
		var factors: Dictionary = Options.EVENTS[active_event]["multipliers"]
		result *= float(factors.get(resource, factors.get("all", 1.0)))
	return result


func ep_per_second() -> float:
	return rate("ep")


func is_daylight() -> bool:
	return day_second < Options.DAY_SECONDS


func tap_gain() -> float:
	return float(Options.STAGES[stage]["tap"]) * production_multiplier()


func advance(delta: float) -> int:
	advanced_seconds = 0
	if not is_finite(delta) or delta < 0.0:
		push_error("YaComio: play time must be finite and non-negative.")
		return 0
	_tick_elapsed += delta
	var ticks := floori(_tick_elapsed)
	advanced_seconds = ticks
	_tick_elapsed -= ticks
	return _advance_ticks(ticks, true)


func tap() -> int:
	_mark("first_tap")
	return _generate("ep", tap_gain(), true)


func earned_tokens() -> int:
	return floori(float(active_ep) / Options.EP_PER_TOKEN)


func can_buy(id: String) -> bool:
	return (
		Options.UPGRADES.has(id) and not upgrades.has(id)
		and stage >= int(Options.UPGRADES[id]["stage"])
		and _owns_all(Options.UPGRADES[id]["requires"])
		and _can_afford(Options.UPGRADES[id]["costs"])
	)


func buy(id: String) -> bool:
	if not Options.UPGRADES.has(id):
		push_warning("YaComio: unknown upgrade '%s'." % id)
		return false
	if not can_buy(id):
		return false
	_spend(Options.UPGRADES[id]["costs"])
	upgrades.append(id)
	_mark(id)
	return true


func can_evolve() -> bool:
	if stage + 1 >= Options.STAGES.size():
		return false
	var next: Dictionary = Options.STAGES[stage + 1]
	return (
		_owns_all(next["requires"]) and _can_afford(next["costs"])
		and (str(next["event"]).is_empty() or completed_events.has(str(next["event"])))
	)


func evolve() -> bool:
	if not can_evolve():
		return false
	_spend(Options.STAGES[stage + 1]["costs"])
	stage += 1
	_mark(str(Options.STAGES[stage]["id"]))
	return true


func can_trigger_event(id: String) -> bool:
	return (
		Options.EVENTS.has(id) and stage >= int(Options.EVENTS[id]["stage"])
		and not completed_events.has(id) and active_event.is_empty()
		and _owns_all(Options.EVENTS[id]["requires"])
	)


func trigger_event(id: String) -> bool:
	if not Options.EVENTS.has(id):
		push_warning("YaComio: unknown event '%s'." % id)
		return false
	if not can_trigger_event(id):
		return false
	active_event = id
	event_remaining = int(Options.EVENTS[id]["duration"])
	return true


func can_prestige() -> bool:
	return upgrades.has("civilization") and leaps < Options.MAX_RESOURCE


func prestige() -> bool:
	if not can_prestige():
		return false
	leaps += 1
	ep = 0
	for resource in resources:
		resources[resource] = 0
	stage = 0
	upgrades.clear()
	completed_events.clear()
	active_event = ""
	event_remaining = 0
	day_second = 0
	_fractions.clear()
	_tick_elapsed = 0.0
	_mark("leap")
	return true


## No purchases, era changes or token earnings happen while the game is closed.
func apply_offline(now: int = -1) -> Dictionary[String, int]:
	var timestamp := _timestamp(now)
	var gains: Dictionary[String, int] = {}
	var before: Dictionary[String, int] = {}
	for resource in Options.RESOURCE_KEYS:
		before[resource] = amount(resource)
	clock_rolled_back = last_seen > timestamp
	if clock_rolled_back:
		push_warning("YaComio: the clock moved backwards; no offline resources awarded.")
	elif last_seen > 0 and offline_eligible:
		_advance_ticks(timestamp - last_seen, false)
	last_seen = timestamp
	for resource in Options.RESOURCE_KEYS:
		gains[resource] = amount(resource) - before[resource]
	return gains


func at_storage_limit() -> bool:
	for resource in Options.RESOURCE_KEYS:
		if amount(resource) == Options.MAX_RESOURCE:
			return true
	return active_ep == Options.MAX_RESOURCE


func _advance_ticks(ticks: int, active: bool) -> int:
	var before := ep
	while ticks > 0:
		var step := mini(ticks, event_remaining) if event_remaining > 0 else ticks
		var daylight := _daylight_before(day_second + step) - _daylight_before(day_second)
		for resource in Options.RESOURCE_KEYS:
			var seconds := daylight if resource == "light" else step
			_generate(resource, rate(resource) * float(seconds), active)
		day_second = (day_second + step) % Options.CYCLE_SECONDS
		ticks -= step
		if event_remaining > 0:
			event_remaining -= step
			if event_remaining == 0:
				_complete_event()
	return ep - before


static func _daylight_before(seconds: int) -> int:
	return (
		floori(float(seconds) / Options.CYCLE_SECONDS) * Options.DAY_SECONDS
		+ mini(seconds % Options.CYCLE_SECONDS, Options.DAY_SECONDS)
	)


func _generate(resource: String, generated: float, active: bool) -> int:
	var available := Options.MAX_RESOURCE - amount(resource)
	var total := minf(float(available), generated + float(_fractions.get(resource, 0.0)))
	var whole := floori(total)
	_fractions[resource] = total - whole
	if resource == "ep":
		ep += whole
		if active:
			active_ep = mini(Options.MAX_RESOURCE, active_ep + whole)
	else:
		resources[resource] += whole
	return whole


func _complete_event() -> void:
	var id := active_event
	var reward: Dictionary = Options.EVENTS[id]["reward"]
	active_event = ""
	completed_events.append(id)
	for resource: String in reward:
		_generate(resource, float(reward[resource]), false)
	_mark(id)


func _owns_all(required: Array) -> bool:
	for id: String in required:
		if not upgrades.has(id):
			return false
	return true


func _can_afford(costs: Dictionary) -> bool:
	for resource: String in costs:
		if amount(resource) < int(costs[resource]):
			return false
	return true


func _spend(costs: Dictionary) -> void:
	for resource: String in costs:
		if resource == "ep":
			ep -= int(costs[resource])
		else:
			resources[resource] -= int(costs[resource])


func _mark(name: String) -> void:
	var id := "yacomio_" + name
	if Options.ACHIEVEMENTS.has(id) and not milestones.has(id):
		milestones.append(id)


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
	if (
		not file.has_section_key("save", "version")
		or not file.has_section_key("progress", "ep")
		or not file.has_section_key("progress", "upgrades")
	):
		return _invalid_save(path)
	var version: Variant = file.get_value("save", "version")
	var saved_ep: Variant = file.get_value("progress", "ep")
	var saved_upgrades: Variant = file.get_value("progress", "upgrades")
	if (
		not version is int or version not in [1, SAVE_VERSION]
		or not _valid_count(saved_ep) or not saved_upgrades is Array
	):
		return _invalid_save(path)
	var restored: Array[String] = []
	for id: Variant in saved_upgrades:
		if (
			not id is String or not Options.UPGRADES.has(id) or restored.has(id)
			or (version == 1 and id not in ["rna", "dna"])
		):
			return _invalid_save(path)
		restored.append(id)
	if version == 1:
		_reset_loaded_state()
		ep = saved_ep
		upgrades.assign(restored)
		for id in restored:
			_mark(id)
		return OK
	return _load_current(file, saved_ep, restored, path)


func save(path: String = Options.SAVE_PATH, now: int = -1) -> Error:
	var file := ConfigFile.new()
	file.set_value("save", "version", SAVE_VERSION)
	file.set_value("progress", "ep", ep)
	file.set_value("progress", "upgrades", upgrades)
	file.set_value("progress", "stage", stage)
	file.set_value("progress", "resources", resources)
	file.set_value("progress", "leaps", leaps)
	file.set_value("progress", "active_ep", active_ep)
	file.set_value("progress", "milestones", milestones)
	file.set_value("progress", "completed_events", completed_events)
	file.set_value("progress", "active_event", active_event)
	file.set_value("progress", "event_remaining", event_remaining)
	file.set_value("progress", "day_second", day_second)
	file.set_value("progress", "fractions", _fractions)
	var timestamp := _timestamp(now)
	file.set_value("save", "last_seen", timestamp)
	file.set_value("save", "offline_eligible", offline_eligible)
	var temporary := path + ".pending"
	var status := file.save(temporary)
	if status == OK:
		status = DirAccess.rename_absolute(temporary, path)
	if status == OK:
		last_seen = timestamp
	elif FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	if status != OK:
		push_warning("YaComio: could not save %s (error %d)." % [path, status])
	return status


func _load_current(file: ConfigFile, saved_ep: int, restored: Array[String], path: String) -> Error:
	var values: Dictionary = {}
	for key in [
		"stage", "resources", "leaps", "active_ep", "milestones", "completed_events",
		"active_event", "event_remaining", "day_second", "fractions",
	]:
		if not file.has_section_key("progress", key):
			return _invalid_save(path)
		values[key] = file.get_value("progress", key)
	if (
		not file.has_section_key("save", "last_seen")
		or not file.has_section_key("save", "offline_eligible")
	):
		return _invalid_save(path)
	var timestamp: Variant = file.get_value("save", "last_seen")
	var eligible: Variant = file.get_value("save", "offline_eligible")
	if (
		not values["stage"] is int or int(values["stage"]) < 0
		or int(values["stage"]) >= Options.STAGES.size()
		or not _valid_count(values["leaps"]) or not _valid_count(values["active_ep"])
		or not _valid_count(timestamp) or not eligible is bool
		or not values["resources"] is Dictionary or not values["fractions"] is Dictionary
		or not values["active_event"] is String or not values["event_remaining"] is int
		or not values["day_second"] is int or int(values["day_second"]) < 0
		or int(values["day_second"]) >= Options.CYCLE_SECONDS
		or not _valid_ids(values["milestones"], Options.ACHIEVEMENTS.keys())
		or not _valid_ids(values["completed_events"], Options.EVENT_ORDER)
	):
		return _invalid_save(path)
	var saved_stage := int(values["stage"])
	var balances: Dictionary = values["resources"]
	var fractions: Dictionary = values["fractions"]
	if balances.size() != resources.size():
		return _invalid_save(path)
	for resource in resources:
		if (
			not balances.has(resource) or not _valid_count(balances[resource])
			or (saved_stage < int(Options.RESOURCES[resource]["stage"]) and balances[resource] != 0)
		):
			return _invalid_save(path)
	for key: Variant in fractions:
		var value: Variant = fractions[key]
		if (
			not key is String or not Options.RESOURCES.has(key)
			or not (value is float or value is int)
			or not is_finite(float(value)) or float(value) < 0.0 or float(value) >= 1.0
			or (saved_stage < int(Options.RESOURCES[key]["stage"]) and float(value) != 0.0)
		):
			return _invalid_save(path)
	for id in restored:
		var upgrade: Dictionary = Options.UPGRADES[id]
		if int(upgrade["stage"]) > saved_stage:
			return _invalid_save(path)
		for required: String in upgrade["requires"]:
			if not restored.has(required):
				return _invalid_save(path)
	for era in range(1, saved_stage + 1):
		for required: String in Options.STAGES[era]["requires"]:
			if not restored.has(required):
				return _invalid_save(path)
		var required_event := str(Options.STAGES[era]["event"])
		if not required_event.is_empty() and not values["completed_events"].has(required_event):
			return _invalid_save(path)
	for id: String in values["completed_events"]:
		if int(Options.EVENTS[id]["stage"]) > saved_stage:
			return _invalid_save(path)
	var event := str(values["active_event"])
	var remaining := int(values["event_remaining"])
	if event.is_empty():
		if remaining != 0:
			return _invalid_save(path)
	elif (
		not Options.EVENTS.has(event) or values["completed_events"].has(event)
		or remaining <= 0 or remaining > int(Options.EVENTS[event]["duration"])
		or int(Options.EVENTS[event]["stage"]) > saved_stage
	):
		return _invalid_save(path)
	else:
		for required: String in Options.EVENTS[event]["requires"]:
			if not restored.has(required):
				return _invalid_save(path)
	_reset_loaded_state()
	ep = saved_ep
	upgrades.assign(restored)
	stage = saved_stage
	for resource in resources:
		resources[resource] = int(balances[resource])
	leaps = int(values["leaps"])
	active_ep = int(values["active_ep"])
	milestones.assign(values["milestones"])
	completed_events.assign(values["completed_events"])
	active_event = event
	event_remaining = remaining
	day_second = int(values["day_second"])
	for resource: String in fractions:
		_fractions[resource] = float(fractions[resource])
	last_seen = timestamp
	offline_eligible = eligible
	return OK


func _reset_loaded_state() -> void:
	ep = 0
	upgrades.clear()
	stage = 0
	for resource in resources:
		resources[resource] = 0
	leaps = 0
	active_ep = 0
	milestones.clear()
	completed_events.clear()
	active_event = ""
	event_remaining = 0
	day_second = 0
	_fractions.clear()
	last_seen = 0
	offline_eligible = true
	clock_rolled_back = false
	advanced_seconds = 0
	_tick_elapsed = 0.0


static func _valid_count(value: Variant) -> bool:
	return value is int and int(value) >= 0 and int(value) <= Options.MAX_RESOURCE


static func _valid_ids(value: Variant, allowed: Array) -> bool:
	if not value is Array:
		return false
	var seen: Array[String] = []
	for id: Variant in value:
		if not id is String or not allowed.has(id) or seen.has(id):
			return false
		seen.append(id)
	return true


static func _timestamp(now: int) -> int:
	return floori(Time.get_unix_time_from_system()) if now < 0 else now


func _invalid_save(path: String) -> Error:
	push_warning("YaComio: unsupported or damaged save at %s; left untouched." % path)
	return ERR_INVALID_DATA

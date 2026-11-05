extends RefCounted

## Derive the shared wallet from saved active EP and permanent purchase prices.
## Reconciliation is idempotent even if a crash splits the two save writes.

const Options := preload("res://games/yacomio/yacomio_options.gd")
const State := preload("res://games/yacomio/evolution_state.gd")


static func reconcile(store: Node, state: State) -> Error:
	var data: Dictionary = store.call("export_save", Options.GAME_ID)
	var spent := 0
	for raw_id: Variant in data.get("owned", PackedStringArray()):
		var item := Options.store_item(str(raw_id))
		if item.is_empty():
			push_warning("YaComio: cannot price saved cosmetic '%s'; wallet left unchanged." % raw_id)
			return ERR_INVALID_DATA
		spent += int(item["price"])
	var earned := state.earned_tokens()
	if spent > earned:
		push_warning("YaComio: cosmetic purchases exceed saved token earnings; wallet left unchanged.")
		return ERR_INVALID_DATA
	data["points"] = earned - spent
	var status: Error = store.call("import_save", Options.GAME_ID, data)
	return status

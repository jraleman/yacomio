extends RefCounted

## Preload-safe progression and presentation data shared by the game and menus.

const GAME_ID := "yacomio"
const SAVE_PATH := "user://yacomio.cfg"
const TAP_GAIN := 5
const EP_PER_TOKEN := 100
const MAX_RESOURCE := 1_000_000_000_000_000
const DAY_SECONDS := 60
const CYCLE_SECONDS := 120
const LEAP_BONUS := 0.25
const TAP_KEY := "controls/yacomio_tap"
const RNA_KEY := "controls/yacomio_rna"
const DNA_KEY := "controls/yacomio_dna"
const MEMBRANE_KEY := "controls/yacomio_membrane"
const EVOLVE_KEY := "controls/yacomio_evolve"
const JOURNAL_KEY := "controls/yacomio_journal"
const TAP_ACTION := &"yacomio_tap"
const RNA_ACTION := &"yacomio_rna"
const DNA_ACTION := &"yacomio_dna"
const MEMBRANE_ACTION := &"yacomio_membrane"
const EVOLVE_ACTION := &"yacomio_evolve"
const JOURNAL_ACTION := &"yacomio_journal"

const RESOURCE_KEYS: Array[String] = [
	"ep", "light", "bcp", "bp", "ip", "culture", "population",
]
const RESOURCES := {
	"ep": {"title": "Evolution Points", "short": "EP", "stage": 0},
	"light": {"title": "Light Energy", "short": "Light", "stage": 1},
	"bcp": {"title": "Biological Complexity", "short": "BCP", "stage": 2},
	"bp": {"title": "Biodiversity", "short": "BP", "stage": 3},
	"ip": {"title": "Intelligence", "short": "IP", "stage": 4},
	"culture": {"title": "Culture", "short": "Culture", "stage": 4},
	"population": {"title": "Population", "short": "Population", "stage": 4},
}

const STAGES: Array[Dictionary] = [
	{
		"id": "microbial", "title": "Microbial Beginnings",
		"description": "A tiny colony. RNA, DNA and membranes make room for more life.",
		"rates": {"ep": 1}, "tap": 5,
		"costs": {}, "requires": [], "event": "",
	},
	{
		"id": "photosynthesis", "title": "Photosynthesis",
		"description": "Algae catch daylight. Light Energy pauses at night; EP never does.",
		"rates": {"ep": 15, "light": 2}, "tap": 25,
		"costs": {"ep": 200}, "requires": ["rna", "dna", "membrane"], "event": "",
	},
	{
		"id": "multicellular", "title": "Complex Life",
		"description": "Build sponges, jellyfish and fish; a Cambrian Bloom speeds the colony.",
		"rates": {"ep": 80, "light": 6, "bcp": 2}, "tap": 100,
		"costs": {"ep": 1500, "light": 100},
		"requires": ["chloroplast", "algae"], "event": "",
	},
	{
		"id": "terrestrial", "title": "Terrestrial Ecosystems",
		"description": "Plants, insects and animals fill a toy island. Adapt to a changing world.",
		"rates": {"ep": 300, "light": 8, "bcp": 10, "bp": 2}, "tap": 500,
		"costs": {"ep": 7500, "bcp": 350},
		"requires": ["sponge", "jellyfish", "nervous_system", "fish"], "event": "cambrian",
	},
	{
		"id": "human", "title": "Human Civilization",
		"description": "Tools, language and agriculture grow culture, population and a little city.",
		"rates": {"ep": 1000, "light": 10, "bcp": 30, "bp": 10, "ip": 2}, "tap": 2000,
		"costs": {"bcp": 5000, "bp": 500},
		"requires": ["land_plants", "mammals", "flowering_plants"], "event": "extinction",
	},
]

const UPGRADE_ORDER: Array[String] = [
	"rna", "dna", "membrane",
	"chloroplast", "algae", "photoprotection",
	"sponge", "jellyfish", "nervous_system", "fish",
	"land_plants", "insects", "dinosaurs", "feathers", "warm_blooded",
	"mammals", "flowering_plants",
	"primates", "tools", "language", "agriculture", "culture", "science", "civilization",
]

const UPGRADES := {
	"rna": {
		"title": "RNA", "stage": 0, "costs": {"ep": 10}, "rates": {"ep": 1},
		"requires": [], "description": "Adds 1 EP per second. A first strand inside the microbe.",
	},
	"dna": {
		"title": "DNA Replication", "stage": 0, "costs": {"ep": 50}, "rates": {"ep": 3},
		"requires": [], "description": "Adds 3 EP per second. RNA and DNA can be bought in either order.",
	},
	"membrane": {
		"title": "Simple Membranes", "stage": 0, "costs": {"ep": 100}, "rates": {"ep": 5},
		"requires": ["rna", "dna"], "description": "Adds 5 EP per second and prepares photosynthesis.",
	},
	"chloroplast": {
		"title": "Chloroplast Efficiency", "stage": 1,
		"costs": {"ep": 250, "light": 10}, "rates": {"ep": 10, "light": 3},
		"ep_multiplier": 2.0, "requires": [],
		"description": "Doubles EP production and adds 3 Light per daylight second.",
	},
	"algae": {
		"title": "Algae Gardens", "stage": 1,
		"costs": {"ep": 600, "light": 30}, "rates": {"ep": 20, "light": 4},
		"requires": ["chloroplast"], "description": "Adds 20 base EP/s and 4 daylight Light/s.",
	},
	"photoprotection": {
		"title": "Protective Pigments", "stage": 1,
		"costs": {"ep": 1000, "light": 60}, "rates": {"ep": 35, "light": 2},
		"requires": ["algae"], "description": "An optional garden upgrade: more EP and daylight Light.",
	},
	"sponge": {
		"title": "Sponges", "stage": 2,
		"costs": {"ep": 1000, "bcp": 10}, "rates": {"ep": 30, "bcp": 2},
		"requires": [], "description": "Simple multicellular shapes add 2 BCP per second.",
	},
	"jellyfish": {
		"title": "Jellyfish", "stage": 2,
		"costs": {"light": 100, "bcp": 40}, "rates": {"bcp": 4},
		"requires": ["sponge"], "description": "Soft bells and tentacles add 4 BCP per second.",
	},
	"nervous_system": {
		"title": "Nervous Systems", "stage": 2,
		"costs": {"ep": 2500, "bcp": 100}, "rates": {"bcp": 7},
		"requires": ["jellyfish"], "description": "Connected senses add 7 BCP per second.",
	},
	"fish": {
		"title": "Fish", "stage": 2,
		"costs": {"ep": 5000, "bcp": 200}, "rates": {"ep": 100, "bcp": 10},
		"requires": ["nervous_system"], "description": "A little shoal adds 100 base EP/s and 10 BCP/s.",
	},
	"land_plants": {
		"title": "Land Plants", "stage": 3,
		"costs": {"ep": 10000, "bcp": 500}, "rates": {"bcp": 5, "bp": 3},
		"requires": [], "description": "The island turns green: adds 3 BP per second.",
	},
	"insects": {
		"title": "Insects", "stage": 3,
		"costs": {"bcp": 400, "bp": 20}, "rates": {"bp": 4},
		"requires": ["land_plants"], "description": "Six-legged neighbours add 4 BP per second.",
	},
	"dinosaurs": {
		"title": "Dinosaur Age", "stage": 3,
		"costs": {"bcp": 700, "bp": 60}, "rates": {"ep": 200, "bp": 6},
		"requires": ["land_plants"], "description": "Toy dinosaurs add 6 BP/s and open Changing World.",
	},
	"feathers": {
		"title": "Feathers", "stage": 3,
		"costs": {"bcp": 600, "bp": 80}, "rates": {"bp": 3},
		"requires": ["dinosaurs"], "description": "An optional adaptation that adds 3 BP per second.",
	},
	"warm_blooded": {
		"title": "Warm-Blooded Adaptations", "stage": 3,
		"costs": {"bcp": 1000, "bp": 100}, "rates": {"bp": 6},
		"requires": ["insects"], "description": "Adds 6 BP/s and prepares the mammals upgrade.",
	},
	"mammals": {
		"title": "Mammals", "stage": 3,
		"costs": {"bcp": 1500, "bp": 150}, "rates": {"ep": 300, "bp": 12},
		"requires": ["warm_blooded"], "description": "Small island residents add 12 BP per second.",
	},
	"flowering_plants": {
		"title": "Flowering Plants", "stage": 3,
		"costs": {"bcp": 1000, "bp": 120}, "rates": {"bp": 8},
		"requires": ["land_plants"], "description": "Flowers add 8 BP/s and complete the ecosystem gate.",
	},
	"primates": {
		"title": "Primates", "stage": 4,
		"costs": {"ip": 10}, "rates": {"ip": 1}, "requires": [],
		"description": "Adds 1 IP per second. This is a playful timeline, not an evolutionary ladder.",
	},
	"tools": {
		"title": "Tools", "stage": 4,
		"costs": {"bcp": 1000, "ip": 25}, "rates": {"ep": 500, "ip": 3},
		"requires": ["primates"], "description": "A little workbench adds 3 IP per second.",
	},
	"language": {
		"title": "Language", "stage": 4,
		"costs": {"bp": 500, "ip": 60}, "rates": {"ip": 5, "culture": 1},
		"requires": ["tools"], "description": "Adds 5 IP/s and starts Culture at 1 per second.",
	},
	"agriculture": {
		"title": "Agriculture", "stage": 4,
		"costs": {"bp": 1000, "ip": 120}, "rates": {"ip": 7, "culture": 2, "population": 2},
		"requires": ["language"], "description": "Fields start Population growth at 2 per second.",
	},
	"culture": {
		"title": "Culture and Community", "stage": 4,
		"costs": {"ip": 250, "culture": 100},
		"rates": {"ip": 10, "culture": 4, "population": 2},
		"requires": ["agriculture"], "description": "Adds IP, Culture and Population production.",
	},
	"science": {
		"title": "Science", "stage": 4,
		"costs": {"ip": 600, "culture": 300},
		"rates": {"ip": 25, "culture": 6, "population": 5},
		"requires": ["culture"], "description": "An observatory adds 25 IP, 6 Culture and 5 Population per second.",
	},
	"civilization": {
		"title": "Civilization", "stage": 4,
		"costs": {"ip": 1500, "culture": 800, "population": 800},
		"rates": {"ip": 50, "culture": 10, "population": 10},
		"requires": ["science"], "description": "Complete the timeline. Keep growing or choose an evolutionary leap.",
	},
}

const EVENT_ORDER: Array[String] = ["cambrian", "extinction", "golden"]
const EVENTS := {
	"cambrian": {
		"title": "Cambrian Bloom", "stage": 2, "duration": 60,
		"requires": ["sponge", "jellyfish"], "multipliers": {"ep": 2.0, "bcp": 2.0},
		"reward": {"bcp": 100},
		"description": "Double EP and BCP for 60 simulated seconds, then gain 100 BCP.",
	},
	"extinction": {
		"title": "Changing World", "stage": 3, "duration": 60,
		"requires": ["dinosaurs"], "multipliers": {"bp": 0.5},
		"reward": {"bcp": 500, "bp": 150},
		"description": "An extinction-era adaptation: half BP for 60 seconds, then gain 500 BCP and 150 BP. Nothing is destroyed.",
	},
	"golden": {
		"title": "Golden Age", "stage": 4, "duration": 120,
		"requires": ["agriculture"], "multipliers": {"all": 2.0}, "reward": {},
		"description": "Double all production for 120 simulated seconds. One Golden Age per timeline.",
	},
}

const ACHIEVEMENTS := {
	"yacomio_first_tap": {"title": "A Little Nudge", "description": "Gather EP by tapping.", "badge": "TAP"},
	"yacomio_rna": {"title": "First Strand", "description": "Unlock RNA.", "badge": "RNA"},
	"yacomio_dna": {"title": "Double Strand", "description": "Unlock DNA Replication.", "badge": "DNA"},
	"yacomio_photosynthesis": {"title": "Borrowed Sunlight", "description": "Reach photosynthesis.", "badge": "SUN"},
	"yacomio_multicellular": {"title": "Better Together", "description": "Reach complex life.", "badge": "BCP"},
	"yacomio_cambrian": {"title": "A Sea of Possibilities", "description": "Complete a Cambrian Bloom.", "badge": "SEA"},
	"yacomio_terrestrial": {"title": "First Footing", "description": "Reach terrestrial ecosystems.", "badge": "LAND"},
	"yacomio_extinction": {"title": "Room for Change", "description": "Complete Changing World.", "badge": "ADAPT"},
	"yacomio_human": {"title": "Shared Ideas", "description": "Reach human civilization.", "badge": "IDEA"},
	"yacomio_golden": {"title": "Golden Days", "description": "Complete a Golden Age.", "badge": "GOLD"},
	"yacomio_civilization": {"title": "A World of Our Own", "description": "Establish civilization.", "badge": "CITY"},
	"yacomio_leap": {"title": "Small Beginnings, Again", "description": "Make an evolutionary leap.", "badge": "LEAP"},
}

const MEMBRANE_SLOT := "yacomio_membrane"
const HABITAT_SLOT := "yacomio_habitat"
const DEFAULT_MEMBRANE := "yacomio_membrane_jade"
const DEFAULT_HABITAT := "yacomio_habitat_pond"
const STORE_CURRENCY := {
	"name": "Spore Token", "plural": "Spore Tokens",
	"points_per_score": 0.0, "round_bonus": 0, "win_bonus": 0,
}
const STORE_SLOTS: Array[Dictionary] = [
	{"id": MEMBRANE_SLOT, "kind": "membrane", "title": "Colony colour"},
	{"id": HABITAT_SLOT, "kind": "habitat", "title": "Habitat"},
]
## Prices are permanent: the wallet is earned tokens minus owned-item costs.
const STORE_ITEMS: Array[Dictionary] = [
	{
		"id": DEFAULT_MEMBRANE, "kind": "membrane", "title": "Jade Colony",
		"description": "The original green colony. Cosmetic only.", "price": 0,
		"default": true, "color": Color("7bd9a5"), "heading": "Colony colours", "badge": "JADE",
	},
	{
		"id": "yacomio_membrane_amber", "kind": "membrane", "title": "Amber Colony",
		"description": "Warm golden bodies and city roofs. Cosmetic only.", "price": 8,
		"color": Color("efba63"), "heading": "Colony colours", "badge": "AMBER",
	},
	{
		"id": "yacomio_membrane_violet", "kind": "membrane", "title": "Violet Colony",
		"description": "Purple membranes, creatures and roofs. Cosmetic only.", "price": 16,
		"color": Color("bc9cef"), "heading": "Colony colours", "badge": "VIOLET",
	},
	{
		"id": "yacomio_membrane_ice", "kind": "membrane", "title": "Ice Colony",
		"description": "Cool blue membranes, creatures and roofs. Cosmetic only.", "price": 24,
		"color": Color("8cdaed"), "heading": "Colony colours", "badge": "ICE",
	},
	{
		"id": DEFAULT_HABITAT, "kind": "habitat", "title": "Quiet Pond",
		"description": "The original teal diorama base. Cosmetic only.", "price": 0,
		"default": true, "color": Color("368b91"), "heading": "Habitats", "badge": "POND",
	},
	{
		"id": "yacomio_habitat_twilight", "kind": "habitat", "title": "Twilight Basin",
		"description": "A plum base with a pale rim. No daylight or production changes.", "price": 12,
		"color": Color("7662a8"), "heading": "Habitats", "badge": "DUSK",
	},
	{
		"id": "yacomio_habitat_sand", "kind": "habitat", "title": "Amber Basin",
		"description": "A sandy base with a warm rim. No resource changes.", "price": 18,
		"color": Color("c8985c"), "heading": "Habitats", "badge": "SAND",
	},
	{
		"id": "yacomio_habitat_aurora", "kind": "habitat", "title": "Aurora Basin",
		"description": "A blue base with bright green edging. No resource changes.", "price": 30,
		"color": Color("397fc4"), "heading": "Habitats", "badge": "AURORA",
	},
]

const GALLERY_EXHIBITS: Array[Dictionary] = [
	{"id": "microbe", "title": "First Microbe", "stage": 0, "upgrades": [], "heading": "Small beginnings",
		"description": "The same original membrane, nucleus and cilia that start your colony."},
	{"id": "replication", "title": "Strands and Membranes", "stage": 0,
		"upgrades": ["rna", "dna", "membrane"], "heading": "Small beginnings",
		"description": "RNA beads, a double DNA strand and a budding neighbour."},
	{"id": "algae", "title": "Daylight Garden", "stage": 1,
		"upgrades": ["chloroplast", "algae"], "heading": "Life in water",
		"description": "Original aquatic stalks and a microbe carrying chloroplasts."},
	{"id": "sponge", "title": "Sponges and Jellyfish", "stage": 2,
		"upgrades": ["sponge", "jellyfish"], "heading": "Life in water",
		"description": "Porous sponge tubes and soft jellyfish bells, built exactly as in play."},
	{"id": "fish", "title": "A Little Shoal", "stage": 2,
		"upgrades": ["sponge", "jellyfish", "nervous_system", "fish"], "heading": "Life in water",
		"description": "Original toy fish with paired fins and separate tail shapes."},
	{"id": "dinosaurs", "title": "Dinosaur Island", "stage": 3,
		"upgrades": ["land_plants", "insects", "dinosaurs", "feathers"], "heading": "Life on land",
		"description": "A long-necked toy dinosaur, tiny insects and fern-like island plants."},
	{"id": "mammals", "title": "A Growing Ecosystem", "stage": 3,
		"upgrades": ["land_plants", "insects", "mammals", "flowering_plants"], "heading": "Life on land",
		"description": "Original round-eared mammals and flowering trees share the island."},
	{"id": "village", "title": "Fields and Community", "stage": 4,
		"upgrades": ["primates", "tools", "language", "agriculture", "culture"], "heading": "Shared ideas",
		"description": "Small people, a workbench, houses and cultivated fields."},
	{"id": "civilization", "title": "City and Observatory", "stage": 4,
		"upgrades": ["primates", "tools", "language", "agriculture", "culture", "science", "civilization"],
		"heading": "Shared ideas", "description": "The completed original city, including its domed observatory."},
]

const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": TAP_KEY, "action": TAP_ACTION, "default": KEY_M, "title": "Gather EP",
		"description": "Gather EP. Starts at 5 EP; later eras and leaps strengthen the tap.",
		"player": 0, "heading": "Evolution",
	},
	{
		"key": RNA_KEY, "action": RNA_ACTION, "default": KEY_1, "title": "Buy RNA",
		"description": "Spend 10 EP once to add 1 EP per second.",
		"player": 0, "heading": "Microbial Beginnings",
	},
	{
		"key": DNA_KEY, "action": DNA_ACTION, "default": KEY_2, "title": "Buy DNA Replication",
		"description": "Spend 50 EP once to add 3 EP per second.",
		"player": 0, "heading": "Microbial Beginnings",
	},
	{
		"key": MEMBRANE_KEY, "action": MEMBRANE_ACTION, "default": KEY_3,
		"title": "Buy Simple Membranes", "description": "Buy the last microbial upgrade.",
		"player": 0, "heading": "Microbial Beginnings",
	},
	{
		"key": EVOLVE_KEY, "action": EVOLVE_ACTION, "default": KEY_E,
		"title": "Evolve", "description": "Spend the displayed gate costs to enter the next era.",
		"player": 0, "heading": "Evolution",
	},
	{
		"key": JOURNAL_KEY, "action": JOURNAL_ACTION, "default": KEY_J,
		"title": "Finish visit", "description": "Save the colony and open results and its share card.",
		"player": 0, "heading": "Evolution",
	},
]


static func number(value: float) -> String:
	for unit: Array in [
		[1e15, "P"], [1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"],
	]:
		if value >= float(unit[0]):
			return "%.1f%s" % [value / float(unit[0]), unit[1]]
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value


static func costs_text(costs: Dictionary) -> String:
	var parts := PackedStringArray()
	for resource in RESOURCE_KEYS:
		if costs.has(resource):
			parts.append("%s %s" % [number(float(costs[resource])), RESOURCES[resource]["short"]])
	return " + ".join(parts)


static func store_item(id: String) -> Dictionary:
	for item in STORE_ITEMS:
		if str(item["id"]) == id:
			return item
	return {}

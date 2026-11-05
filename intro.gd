extends MenuScreen

## Player-paced original-model story cards. Opening a story never loads a
## colony, consumes offline time or writes progress.

const CARDS: Array[Dictionary] = [
	{
		"title": "Small beginnings",
		"body": "A tiny microbe in a quiet pond. Gather Evolution Points, build RNA, DNA "
			+ "and membranes, then choose when to evolve. There is no round deadline.",
		"stage": 0, "upgrades": ["rna", "dna", "membrane"],
	},
	{
		"title": "Borrowed sunlight",
		"body": "Algae catch the light. Day and night each last 60 simulated seconds. "
			+ "Light rests at night; the colony keeps producing EP. Closed time earns "
			+ "resources at saved rates, without an offline time limit.",
		"stage": 1, "upgrades": ["chloroplast", "algae"],
	},
	{
		"title": "Better together",
		"body": "Sponges, jellyfish and fish add Biological Complexity. Start a Cambrian "
			+ "Bloom for a temporary boost. Each era explains the upgrades, resource "
			+ "costs and events needed for the next.",
		"stage": 2, "upgrades": ["sponge", "jellyfish", "nervous_system", "fish"],
	},
	{
		"title": "Room for change",
		"body": "Plants, insects and animals fill a toy island. Changing World briefly "
			+ "slows Biodiversity, then rewards adaptation. Nothing is destroyed. "
			+ "This playful timeline is not an evolutionary ladder or literal science.",
		"stage": 3, "upgrades": ["land_plants", "insects", "dinosaurs", "mammals", "flowering_plants"],
	},
	{
		"title": "A world of our own",
		"body": "Tools, language and agriculture grow culture, population and civilization. "
			+ "Finish a visit to share its journal, or confirm an optional leap: start "
			+ "again with +25% production. Earned cosmetics, Spore Tokens and achievements "
			+ "stay. The Store and free Gallery live on the title and pause menus.",
		"stage": 4,
		"upgrades": ["primates", "tools", "language", "agriculture", "culture", "science", "civilization"],
	},
]

@export_file("*.tscn") var next_scene := "res://scenes/menus/main_menu.tscn"

@onready var _margins: MarginContainer = %Margins
@onready var _body: BoxContainer = %Body
@onready var _stage: Control = %Stage
@onready var _scroll: ScrollContainer = %CopyScroll
@onready var _title: Label = %Title
@onready var _step: Label = %Step
@onready var _heading: Label = %Heading
@onready var _copy: Label = %Copy
@onready var _skip: Button = %SkipButton
@onready var _next: Button = %NextButton

var _card_index := 0
var _finished := false


func _ready() -> void:
	margins = _margins
	first_focus = _next
	_skip.pressed.connect(_on_skip_pressed)
	_next.pressed.connect(_on_next_pressed)
	Settings.changed.connect(_on_setting_changed)
	_show_card(0)
	super()


func go_back() -> void:
	_on_skip_pressed()


func _on_next_pressed() -> void:
	if _finished:
		return
	if _card_index + 1 == CARDS.size():
		_on_skip_pressed()
	else:
		_show_card(_card_index + 1)


func _show_card(index: int) -> void:
	_card_index = index
	var card := CARDS[index]
	_heading.text = str(card["title"])
	_copy.text = str(card["body"])
	_step.text = "%d / %d" % [index + 1, CARDS.size()]
	_next.text = "Done" if index + 1 == CARDS.size() else "Next"
	_stage.call("configure", card)
	_scroll.scroll_vertical = 0


func _on_skip_pressed() -> void:
	if _finished:
		return
	_finished = true
	_skip.disabled = true
	_next.disabled = true
	_stage.hide()
	if Router.is_transitioning():
		await Router.transition_finished
	if is_inside_tree():
		Router.goto(next_scene)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "ui/scale":
		refresh_layout()


func _on_layout_changed(size: Vector2) -> void:
	var unit := size.x / maxf(get_window().size.x, 1.0)
	var portrait := Responsive.is_portrait(size)
	_body.vertical = portrait
	_stage.size_flags_stretch_ratio = 0.4 if portrait else 1.0
	_scroll.size_flags_stretch_ratio = 0.6 if portrait else 1.0
	_title.add_theme_font_size_override("font_size", roundi(24.0 * unit))
	_step.add_theme_font_size_override("font_size", roundi(14.0 * unit))
	_heading.add_theme_font_size_override("font_size", roundi(24.0 * unit))
	_copy.add_theme_font_size_override("font_size", roundi(18.0 * unit))
	for button in [_skip, _next]:
		button.custom_minimum_size.y = 46.0 * unit
		button.add_theme_font_size_override("font_size", roundi(18.0 * unit))

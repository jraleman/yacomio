extends RefCounted

## The catalog discovers an untimed, solo module without framework branches.

const Options := preload("res://games/yacomio/yacomio_options.gd")


static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "YaComio!"
	game.tagline = "Small beginnings. A little more life."
	game.menu_order = 16
	game.gameplay_scene_path = "res://games/yacomio/gameplay.tscn"
	game.intro_scene_path = "res://games/yacomio/intro.tscn"
	game.tutorial_video_path = "res://games/yacomio/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/yacomio/assets/video/tutorial_poster.webp"
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.uses_shell_round_rules = false
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.control_bindings = Options.CONTROL_BINDINGS
	game.achievements = Options.ACHIEVEMENTS
	game.store_currency = Options.STORE_CURRENCY
	game.store_slots = Options.STORE_SLOTS
	game.store_items = Options.STORE_ITEMS
	game.store_preview_scene_path = "res://games/yacomio/store_preview.tscn"
	game.gallery_exhibits = Options.GALLERY_EXHIBITS
	game.gallery_stage_scene_path = "res://games/yacomio/gallery_stage.tscn"
	game.share_art_scene_path = "res://games/yacomio/share_art.tscn"
	game.save_files = [{
		"path": Options.SAVE_PATH,
		"title": "Evolution timeline",
		"description": "Five eras, resources, upgrades, events, active EP earnings and permanent leaps.",
	}]
	game.stats_url = "https://deskcansaw.com"
	game.copy = {
		"single_player_description": "Grow a colony from microbes to civilization at your own pace.",
		"instructions_headline": "Small Beginnings. A Whole World.",
		"instructions_rules": (
			"Start with 1 EP per second and gather 5 EP per tap. RNA costs 10 EP "
			+ "and adds 1 EP/s; DNA costs 50 EP and adds 3 EP/s, in either order. "
			+ "Buy membranes, then meet the displayed requirements and choose Evolve.\n"
			+ "Five eras add Light Energy, Biological Complexity (BCP), Biodiversity (BP), "
			+ "Intelligence (IP), Culture and Population. Every upgrade is bought once per "
			+ "timeline. Day and night each last 60 simulated seconds; only Light stops at night.\n"
			+ "Start the Cambrian Bloom and Changing World events when their upgrades are ready. "
			+ "Their 60-second timers must finish before the next era. A Golden Age doubles "
			+ "production for 120 seconds. Events destroy nothing and expire while offline.\n"
			+ "Establish Civilization to complete the timeline. An optional, confirmed "
			+ "Evolutionary Leap resets resources, upgrades and events for +25% permanent "
			+ "production per leap. Tokens, cosmetics and achievements remain.\n"
			+ "Progress auto-saves. Closed time earns unlimited resources at saved upgrade "
			+ "rates and daylight cycles, but no tokens. Pause and confirmation time earn nothing. "
			+ "Counters stop safely at 1 quadrillion (1P).\n"
			+ "100 actively generated EP earn one Spore Token. The Store sells cosmetic "
			+ "colony colours and habitats, never production advantages. The free Gallery "
			+ "shows the same original models. Finish visit saves and opens results/share; "
			+ "Continue resumes the colony, not a reset. The QR opens the studio website.\n"
			+ "This is a playful five-era timeline, not a literal account of evolution."
		),
		"instructions_demo_prompt": "TAP. GROW. REPEAT.",
		"instructions_solo_summary": (
			"Resume your saved colony. The HUD counts EP generated during this visit, "
			+ "not offline income or a round deadline. Resources are spent on evolution; "
			+ "Spore Tokens are a separate cosmetic wallet."
		),
		"instructions_player_one_controls": (
			"Click or tap Gather EP and upgrade buttons, use the shortcuts "
			+ "below, or navigate buttons with a keyboard/controller. "
			+ "Esc or the controller pause button opens the shared pause menu."
		),
		"store_intro": (
			"Earn one Spore Token for every 100 active EP. Colony colours and habitats "
			+ "are cosmetic, shared across eras and kept through leaps. Offline time pays no tokens."
		),
		"gallery_intro": "Nine free exhibits from the actual original colony models. Drag to orbit and scroll to zoom.",
	}
	game.credits = [{
		"heading": "YaComio!",
		"lines": [
			"Game design, code, original vector logo and procedural toy models - DeskCanSaw",
			"Five-era native evolution game inspired by the original YaComio roadmap",
		],
	}]
	var theme := GameTheme.new()
	theme.logo_texture_path = "res://games/yacomio/assets/icon.svg"
	theme.accent = Color("7bd9a5")
	theme.light = Color("def8e8")
	theme.plaque_color = Color("122c26")
	theme.background_top = Color("173a32")
	theme.background_bottom = Color("091b20")
	theme.style_share_card = true
	game.theme = theme
	return game

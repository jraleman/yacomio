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
	game.tutorial_video_path = "res://games/yacomio/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/yacomio/assets/video/tutorial_poster.webp"
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.uses_shell_round_rules = false
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.control_bindings = Options.CONTROL_BINDINGS
	game.save_files = [{
		"path": Options.SAVE_PATH,
		"title": "Microbial progress",
		"description": "Evolution Points and purchased RNA/DNA upgrades.",
	}]
	game.stats_url = "https://deskcansaw.com"
	game.copy = {
		"single_player_description": "Grow a microbial colony at your own pace.",
		"instructions_headline": "Microbial Beginnings",
		"instructions_rules": (
			"Start with 1 Evolution Point (EP) per second. Tap the microbe "
			+ "for 5 EP.\nBuy RNA for 10 EP to add 1 EP per second, and "
			+ "DNA Replication for 50 EP to add 3 EP per second. "
			+ "Each upgrade can be bought once, in either order.\n"
			+ "Progress saves automatically. There is no deadline or later "
			+ "stage yet. Paused and offline time earn no EP."
		),
		"instructions_demo_prompt": "TAP. GROW. REPEAT.",
		"instructions_solo_summary": (
			"Resume your saved colony. Evolution Points are spent on upgrades; "
			+ "the HUD also counts EP generated during this visit."
		),
		"instructions_player_one_controls": (
			"Click or tap the microbe and upgrade buttons, use the shortcuts "
			+ "below, or navigate buttons with a keyboard/controller. "
			+ "Esc or the controller pause button opens the shared pause menu."
		),
	}
	game.credits = [{
		"heading": "YaComio!",
		"lines": [
			"Game design, code and original vector microbe - DeskCanSaw",
			"Native Godot port of the Microbial Beginnings prototype",
		],
	}]
	var theme := GameTheme.new()
	theme.logo_texture_path = "res://games/yacomio/assets/icon.svg"
	theme.accent = Color("7bd9a5")
	theme.light = Color("def8e8")
	theme.plaque_color = Color("122c26")
	theme.background_top = Color("173a32")
	theme.background_bottom = Color("091b20")
	game.theme = theme
	return game

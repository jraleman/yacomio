# YaComio!

A native Godot 4.7 incremental game module for DeskCanSaw's `godot-base`.
This repository belongs at `godot-base\games\yacomio`; open the parent's
`project.godot`, not a separate project inside this folder.

## Play

From `godot-base`:

```powershell
godot --path . -- --game=yacomio
godot --path . -- --game=all
```

The shared framework supplies the studio opening, branded title screen,
instructions, settings, pause menu and save manager. The gameplay scene inherits
`GameShell` and opts out of countdowns and lives.

## Microbial Beginnings

- Start with **0 Evolution Points (EP)** and earn **1 EP per second**.
- Tap or click **Tap Microbe** for **5 EP**.
- Buy **RNA** once for **10 EP**, adding **1 EP per second**.
- Buy **DNA Replication** once for **50 EP**, adding **3 EP per second**.

Either upgrade may be purchased first; both together produce **5 EP per second**.
There is no round deadline, prestige or later stage yet. Passive generation
stops while paused or closed; offline gains are not implemented.

The default keyboard shortcuts are **M** (tap), **1** (RNA), **2** (DNA), and
**Esc** (pause). Rebind the three game actions in **Settings > Controls**.
Buttons also support mouse, touch and keyboard/controller focus navigation.

## Saves

Every resource tick and successful action saves to `user://yacomio.cfg`.
The manifest declares this file so the shared **Saves** screen can back up,
restore or delete it without changing settings or another game's progress.
The Godot port starts fresh; it does not import the React prototype's
`localStorage` save.

A damaged or newer save is left untouched and gameplay is disabled with an
explanation. Back it up or delete it through the title screen's Saves menu
before starting again. Write failures are shown in-game rather than reported
as successful saves.

## Structure and checks

`game.gd` declares the module; `yacomio_options.gd` owns its bindings and upgrade
data; `evolution_state.gd` owns resource rules and persistence; `gameplay.tscn`
and `gameplay.gd` adapt them to the shared shell. Original vector art is in
`assets`, and the headless regression scripts are in `tests`. The silent,
captioned walkthrough is recorded from real inputs by `tools\tutorial_driver.gd`.

Run from `godot-base`:

```powershell
godot --headless --path . --import
godot --headless --path . --script res://games/yacomio/tests/evolution_state_test.gd -- --game=all
godot --headless --path . --script res://games/yacomio/tests/yacomio_scene_test.gd -- --game=all
```

The scene suite also runs windowed to check actual layout and input:

```powershell
godot --path . --script res://games/yacomio/tests/yacomio_scene_test.gd -- --game=all
```

On Windows, callers that need an exit code from Godot's GUI executable should
use `Start-Process -NoNewWindow -Wait -PassThru` and check `.ExitCode`.
The parent project provides **Windows - YaComio (standalone)** and
**Web - YaComio (standalone)** export presets with the `yacomio` feature tag and
a stable, separate `DeskCanSaw Games/YaComio` save directory.

To re-record the walkthrough after changing visuals or captions, run the shared
recorder from `godot-base` (requires FFmpeg):

```powershell
pwsh tools\record_tutorials.ps1 -Godot godot -Games yacomio
```

## Roadmap (not implemented)

The original design continues through photosynthesis and light energy,
multicellular life and Biological Complexity Points, terrestrial biodiversity,
and human intelligence and civilization. Offline progress, milestone events
and evolutionary-leap prestige remain future work, not features of this port.

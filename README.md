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

## Grow a world

Solo, untimed evolution crosses five eras with **24 one-time upgrades**:

| Era | New resources and adaptations |
|---|---|
| Microbial Beginnings | EP; RNA, DNA and membranes |
| Photosynthesis | Light Energy; chloroplasts and algae |
| Complex Life | Biological Complexity Points (BCP); sponges, jellyfish and fish |
| Terrestrial Ecosystems | Biodiversity Points (BP); plants, insects, dinosaurs and mammals |
| Human Civilization | Intelligence Points (IP), Culture and Population; tools, agriculture, science and civilization |

Start at **0 EP**, producing **1 EP/s** and gathering **5 EP** per tap.
RNA costs **10 EP** and adds **1 EP/s**; DNA costs **50 EP** and adds **3 EP/s**.
Either strand may be bought first. Both together still produce **5 EP/s**.
Membranes need both, cost **100 EP**, and add another **5 EP/s**.
Later eras raise base production and tap strength; purchased upgrades remain
productive. Unbought optional upgrades remain available after their era.

Each Evolve gate displays its resource costs, required upgrades and event.
Evolution is always a player action, never an automatic offline purchase.
The original procedural 3D diorama grows with the same upgrades you buy.
This is a playful timeline, not a literal biological simulation.

Daylight lasts **60 simulated seconds**, followed by **60 seconds of night**.
Light production rests at night; other resources continue. Three events occur
at most once per timeline: **Cambrian Bloom** temporarily doubles EP/BCP,
**Changing World** briefly halves BP before rewarding adaptation without
destroying anything, and **Golden Age** doubles all production for 120 seconds.

## Away time and evolutionary leaps

Returning to the colony grants **unlimited elapsed-away resource production**
at the saved rates, integrating day/night and any running event's expiry and
reward. It never buys upgrades, changes eras or earns cosmetic tokens.
Paused time and the finish-visit journal do not produce resources.
An interrupted suspended session has an unknown away interval, which is
explicitly reported and not counted. A backwards clock grants nothing.

After establishing Civilization, an optional, confirmed **evolutionary leap**
restarts at microbes. Every completed timeline adds **+25% permanent production**:
`1 + 0.25 * leaps`, not a compounding multiplier. Resources, upgrades, events and
fractional production reset; earned tokens, cosmetics and all twelve permanent
achievements remain. Taps also improve, rounded to whole EP.

Individual counters safely stop at **1 quadrillion (1P)**; there is no offline
time cap. Resource spending or a leap frees resource storage, but the lifetime
active-EP/token counter keeps its ceiling.

## Store, Gallery, intro and journal

Earn **one Spore Token per 100 actually generated active EP**, including taps
and active passive production. Offline gains award none. The shared **Store**
has two free defaults and six paid cosmetics across colony colour and habitat;
no item changes production. Purchases and equipment survive leaps.

The wallet is derived from saved lifetime active EP minus owned cosmetic costs.
Model-first saving makes reconciliation idempotent across interrupted saves,
and **catalogue prices must remain permanent**. Inconsistent wallet data is
reported rather than silently overwritten.

The shared **Gallery** offers nine free, orbitable original-model exhibits,
including late-era life; opening it requires no progress. The five-card
**intro** is player-paced with Next, Done, Skip and Escape, and writes no
progress. Both reuse the actual gameplay models, as do store previews.

**Finish visit** opens shared results and an evolution journal with generated
EP, production, resources, era, upgrades, tokens and leaps. **Continue colony**
resumes without resetting progress. The exported share image freezes the
finished colony's appearance. Its QR opens **DeskCanSaw's website**, not a
public colony record or online leaderboard.

Default controls: **M** gather, **1** RNA, **2** DNA, **3** membranes, **E** evolve,
**J** finish visit, **Esc** pause. Rebind game actions in **Settings > Controls**.
All purchases, events and leaps have mouse/touch and focus-navigation buttons.
Portrait places the colony above scrollable actions; landscape places it beside
them. Reduced motion parks the original 3D colony without changing production.

## Saves

Every resource tick and successful action saves to `user://yacomio.cfg`.
The manifest declares this file so the shared **Saves** screen can back up,
restore or delete it without changing settings or another game's progress.
Native version-1 saves migrate without losing EP or RNA/DNA ownership.
They receive no invented historical tokens or offline gains, because they have
no timestamp. Browser-prototype `localStorage` saves are not imported.

A damaged or newer save is left untouched and gameplay is disabled with an
explanation. Back it up or delete it through the title screen's Saves menu
before starting again. Write failures are shown in-game rather than reported
as successful saves.

## Structure and checks

`game.gd` declares shared integrations; `yacomio_options.gd` owns progression,
bindings and catalogue data; `evolution_state.gd` owns the pure rules and saves;
`token_bank.gd` reconciles cosmetics through public Store APIs. `gameplay.tscn`
and `gameplay.gd` adapt the model to the shared shell. `colony_models.gd` builds
original primitive geometry; `colony_view.gd` presents it through an isolated
Compatibility viewport for gameplay, intro, gallery, store and frozen shares.
No sibling game assets or runtime logic are imported.

The silent, captioned walkthrough earns RNA, DNA and membranes and reaches
photosynthesis through real inputs, not injected resources or synthetic scores.

Run from `godot-base`:

```powershell
godot --headless --path . --import
godot --headless --path . --script res://games/yacomio/tests/evolution_state_test.gd -- --game=all
godot --headless --path . --script res://games/yacomio/tests/yacomio_scene_test.gd -- --game=all
```

The scene suite also runs windowed to check actual layout and input:

```powershell
godot --path . --script res://games/yacomio/tests/yacomio_scene_test.gd -- --game=all
godot --path . --script res://games/yacomio/tests/yacomio_view_test.gd -- --game=all
```

The state suite covers progression, gates, events, unlimited offline catch-up,
fractional prestige, numeric ceilings, migration and damaged-save refusal.
The scene suite drives actual input through a completed civilization,
confirmed/cancelled prestige, cosmetics, journal, reload and read-only menus.
The rendered suite **requires a real graphics window** and checks actual
geometry, visible rasterized exhibits/cosmetics, intro, reduced motion, shared
PNG rendering and phone-to-ultrawide layouts. `--artifacts=<directory>` optionally
saves screenshots. Progress fixtures restore only this game's data; isolated
`APPDATA`/`XDG_DATA_HOME` profiles are still recommended.

On Windows, callers that need an exit code from Godot's GUI executable should
use `Start-Process -NoNewWindow -Wait -PassThru` and check `.ExitCode`.
The parent project provides **Windows - YaComio (standalone)** and
**Web - YaComio (standalone)** export presets with the `yacomio` feature tag and
a stable, separate `DeskCanSaw Games/YaComio` save directory.

To re-record the walkthrough after changing visuals or captions, run the shared
recorder from `godot-base` (requires FFmpeg):

```powershell
pwsh tools\record_tutorials.ps1 -Godot godot -Games yacomio -Variants solo
```

Physical controller/touch hardware and human pacing/balance review remain
separate checks; automated input and desktop window sizes do not replace them.

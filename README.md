# Blade // Clan Duel — Godot 4.3+

A brand-new 2.5D samurai platform fighter foundation, written in **GDScript for Godot 4.3 or newer**. It is a native Godot project; the earlier Unity-specific prototype has been removed.

## Open and run

1. Install **Godot 4.3+ Standard** (no .NET build required).
2. In Godot Project Manager choose **Import**, select this repository folder, and open `project.godot`.
3. Press **F6** for the current scene or **F5** to run the project. The main menu is the configured startup scene.

The repository now contains a playable local-versus/training prototype with procedural dojo/fighter visuals, four character resources, 60 move resources, hit/hurtbox debug, CPU dummy controls, camera framing, HUD, best-of-three stocks, and sudden death. The attached reference sheets are preserved under `assets/sprite_sheets/`; the runtime characters are deliberately simple readable stand-ins, ready to replace with animated sprites or 3D character scenes.

## Controls

- **Player 1 keyboard:** WASD move/DI, Space jump, J attack, U + attack for a smash, K special (hold to charge Hayato’s signature), L tech.
- **Player 2 keyboard:** Arrow keys, Numpad 0 jump, Numpad 1 attack, Numpad 4 + attack for a smash, Numpad 2 special, Numpad 3 tech.
- **Gamepads:** first connected pad drives P1, second pad drives P2. Left stick, A jump, X attack, right shoulder smash, B special, Y tech.
- **Escape:** pause/resume in versus. Training exposes damage inputs, dummy behavior, hitbox toggle, and reset controls on screen.

## Project layout

- `scripts/core/` — reusable fighter state, stats/move/character Resources, controller and centralized hit resolution.
- `scripts/MatchManager.gd`, `InputManager.gd`, `Camera.gd` — local match orchestration, keyboard/gamepad reading and dual-player soft camera.
- `scripts/stage/` — dojo stage collision and drawn art.
- `scripts/ui/` — main menu, HUD, pause/results panels and training controls.
- `scenes/` — runnable main menu, match, training, fighter and dojo scenes.
- `resources/characters/` — four Character Resources plus individual stat Resources.
- `resources/moves/` — 15 frame-data moves per fighter (ground, air, smash and three specials).
- `assets/sprite_sheets/` — user-provided visual reference sheets.

## Adding content

A fighter is a `Character` Resource with `CharacterStats`, a `PackedScene`, a move array and a signature move. A new move is a `MoveData` Resource with `HitboxData` entries; startup/active/recovery and per-hitbox frame windows drive when the corresponding `Area2D` collider is enabled. Generic logic remains in `FighterController.gd`—do not add character branches there. See [`BUILD.md`](BUILD.md) for the Editor workflow and known first-build limitations.

## Notes

- Target physics rate is **60 Hz**. Values in `CharacterStats` use pixels/second and move assets use frames at 60 FPS.
- Combat uses percent, weight-scaled knockback, DI, hitstop, tech windows, ledge grabs and blast zones.
- Fighter art and audio streams are intentionally replaceable. The project has sound-stream hooks, but no sound recordings or finished sprite animations are bundled.
- Godot Editor isn't installed in the authoring sandbox, so the project was statically parsed/linted but not run or packaged here. Open it in Godot to perform the final engine import and test on your machine.

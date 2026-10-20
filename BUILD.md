# First run and content-authoring guide

## First launch

1. Install Godot **4.3 or later** (Standard version).
2. Godot Project Manager → **Import** → choose the repository folder containing `project.godot`.
3. Open it and wait for the first asset scan, then press **F5**. The startup scene is `scenes/MainMenu.tscn`.
4. In the roster rows, use `‹` / `›` to select fighters. **Start Versus** enters a 3-stock, best-of-3 local match on the dojo. **Training Dojo** puts P2 into a configurable dummy mode.

No third-party plug-ins are required. The stage and fighter stand-ins draw their visuals in GDScript, so the match runs without imported art files. The six JPEGs in `assets/sprite_sheets/` are references for the later animation pass, not yet sliced into runtime sprite frames.

## How systems fit together

- `CharacterStats.gd`, `HitboxData.gd`, `MoveData.gd`, `Character.gd` are Godot Resources. The 4 roster `.tres` assets each reference 15 move `.tres` assets and one stat `.tres`.
- `FighterController.gd` is generic: it reads a character resource, buffers inputs for seven simulation frames, resolves states, movement, hitstop, DI, techs, ledges and stocks. It contains no character-specific move branches.
- Move resources are expressed in 60 Hz frames. Each hitbox can define its own active interval. The controller toggles the fighter's `HitboxArea/CollisionShape2D` for the active frames; `HitManager.gd` routes the actual opposing-fighter contact and reads damage/launch data from the same resource.
- `MatchManager.gd` keeps round/match state, stock respawns, timeouts and sudden death. `Camera.gd` soft-follows both fighters; `HUD.gd` owns the onscreen readouts, pause/results and training panel.
- `DojoStage.gd` creates collision for the main floor and two raised platforms. Blast boundaries are managed in the match script.

## Adding an attack

1. In the FileSystem dock duplicate a move resource in `resources/moves/` and rename it.
2. Set `move_name`, `input_command`, category, startup/active/recovery frames, optional charge fields, and `HitboxData` fields. `charge_frames` makes a move wait for the held Special button to release or reach its cap; charge multipliers scale damage/knockback without mutating shared Resource data. The controller expects command labels `Jab`, `ForwardTilt`, `UpTilt`, `DownTilt`, `ForwardSmash`, `UpSmash`, `DownSmash`, `NeutralAir`, `ForwardAir`, `BackAir`, `UpAir`, `DownAir`, `SpecialNeutral`, `SpecialSide`, or `SpecialDown`.
3. Add the new resource to the appropriate `Character.moves` array and update an input mapping/selection flow only if it is a new command category.
4. Turn on the training hitbox toggle to inspect the volume. Frames are tuned at 60 Hz.

The Dual-Wield Ronin's signature rush is the example multi-hit: two light hits in separate frame windows and a stronger launcher on the final interval.

## Adding a character

1. Duplicate a stats resource under `resources/characters/` and tune walk speed, air control, jump, gravity, weight, tech timing and ledge timing.
2. Duplicate a roster's 15 move resources and give the new fighter distinctive frame data and hitbox geometry.
3. Create a new `Character` Resource. Assign a fighter `PackedScene`, stats, all moves, signature, identity, color and weapon label.
4. Add the resource to `MatchManager.gd`'s `CHARACTERS` array. Menu selection uses that roster array. There is no character-specific branch in the fighter controller.
5. Replace `scenes/Fighter.tscn` or assign a new scene with a `CharacterBody2D` root, `FighterController.gd`, capsule `CollisionShape2D`, and the `HitboxArea` child nodes. Keep the fighter's origin at foot level (positive Y is down).

## Replacing the stand-in artwork

Import a sprite sheet (or a 3D render/sprite sequence) and slice it in Godot's Import/Atlas settings or the Sprite2D SpriteFrames editor. Replace the procedural `_draw()` presentation in `FighterController.gd` with a child `AnimatedSprite2D` or a separate visual node and assign Idle/Walk/Jump/Fall/Hurt/Attack animations. Keep hitbox frame timing in `MoveData` aligned with the chosen attack animation. Add audio streams to the exported swing/hit/jump/KO fields to use the built-in sound hooks.

## Limits of this foundation

This is an early playable scaffolding rather than a finished commercial fighter: assets are procedural stand-ins, moves are data-tuned rather than fully animation-polished, and balancing/edge-case testing (especially ledge interactions, hitstun DI, controller variants and end-of-round transitions) still needs to happen in Godot on the target hardware. The current sandbox did not have Godot installed, so it could not run the engine, import the project, or make an export build.

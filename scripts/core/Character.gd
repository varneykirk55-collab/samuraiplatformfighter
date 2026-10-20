class_name Character
extends Resource

## Roster resource: visuals, stats, and moves; no fighter-specific controller code.
@export_group("Identity")
@export var display_name: String = "New Fighter"
@export var character_id: String = "fighter_01"
@export var player_color: Color = Color.WHITE
@export var weapon_label: String = "Katana"
@export_group("Visual tuning")
@export var weapon_length: float = 76.0
@export_range(2.0, 10.0) var weapon_thickness: float = 4.0
@export var offhand_weapon_length: float = 0.0
@export var weapon_is_polearm: bool = false
@export_group("Scenes")
@export var player_scene: PackedScene
@export var dummy_scene: PackedScene
@export_group("Stats & Moves")
@export var stats: CharacterStats
@export var moves: Array[Resource] = []
@export var signature_move: MoveData
@export_group("Balance")
@export_range(0.5, 2.0) var damage_multiplier: float = 1.0
@export_range(1, 5) var starting_stocks: int = 3

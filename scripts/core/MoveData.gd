class_name MoveData
extends Resource

## Frame data is authored at 60 frames per second. Add moves with .tres resources.
@export_group("Identity")
@export var move_name: String = "New Move"
@export_enum("Jab", "Tilt", "Smash", "Aerial", "Special") var category: int = 0
@export var is_signature: bool = false
@export var input_command: String = "Attack"
@export_group("Frame data (60 FPS)")
@export_range(1, 120) var startup_frames: int = 5
@export_range(1, 120) var active_frames: int = 4
@export_range(0, 240) var recovery_frames: int = 12
@export var cancelable_on_hit: bool = false
@export_range(0, 180) var charge_frames: int = 0
@export_range(1.0, 3.0) var charge_damage_multiplier: float = 1.0
@export_range(1.0, 3.0) var charge_knockback_multiplier: float = 1.0
@export_group("Hitboxes")
@export var hitboxes: Array[HitboxData] = []
@export_group("Movement")
@export var dash_velocity: float = 0.0
@export var launch_velocity: float = 0.0
@export var ignore_gravity: bool = false
@export_group("Flags")
@export var usable_in_air: bool = true
@export var usable_from_ledge: bool = false
@export var face_target_on_start: bool = false


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


func total_seconds() -> float:
	return float(total_frames()) / 60.0

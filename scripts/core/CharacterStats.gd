class_name CharacterStats
extends Resource

## Per-character movement and defensive tuning, expressed in pixels/seconds.
@export_group("Movement")
@export var walk_speed: float = 300.0
@export var air_acceleration: float = 850.0
@export var max_air_speed: float = 430.0
@export var ground_friction: float = 1800.0
@export var jump_velocity: float = -650.0
@export_range(1, 3) var max_jumps: int = 2
@export var fall_gravity: float = 1700.0
@export var fast_fall_gravity: float = 2400.0
@export var max_fall_speed: float = 1050.0
@export_group("Weight & defense")
@export_range(0.5, 2.0) var weight: float = 1.0
@export var hurtbox_radius: float = 26.0
@export var tech_window: float = 0.12
@export var ledge_grab_distance: float = 54.0
@export var ledge_hold_time: float = 1.5

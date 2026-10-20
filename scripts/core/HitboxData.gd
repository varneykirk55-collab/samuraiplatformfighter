class_name HitboxData
extends Resource

## One frame-scheduled damage volume, configured entirely as resource data.
const SHAPE_CIRCLE: int = 0
const SHAPE_RECTANGLE: int = 1

@export var hitbox_name: String = "Hitbox"
@export var size: Vector2 = Vector2(74.0, 48.0)
@export var offset: Vector2 = Vector2(54.0, -24.0)
@export_enum("Circle:0", "Rectangle:1") var shape: int = SHAPE_RECTANGLE
@export var damage: float = 5.0
@export var knockback_base: float = 180.0
@export var knockback_scaling: float = 3.0
@export_range(-180.0, 180.0) var knockback_angle: float = 45.0
@export var fixed_angle: bool = false
@export var can_tech: bool = true
@export var hitstop: float = 0.07
@export var shake_intensity: float = 1.0
@export_range(0, 240) var active_start_frame: int = 0
@export_range(-1, 240) var active_end_frame: int = -1

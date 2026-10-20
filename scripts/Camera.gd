extends Node

## Soft follow + zoom framing, constrained to the dojo view; shake is hit-driven.
var follow_speed := 4.0
var min_zoom := 0.78
var max_zoom := 1.12
var _shake_time := 0.0
var _shake_strength := 0.0


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if (
		cam == null
		or not is_instance_valid(MatchManager.fighter1)
		or not is_instance_valid(MatchManager.fighter2)
	):
		return
	var a := MatchManager.fighter1.global_position
	var b := MatchManager.fighter2.global_position
	var center := (a + b) * 0.5 + Vector2(0, -15)
	var target_zoom := lerpf(max_zoom, min_zoom, clampf(absf(a.x - b.x) / 1000.0, 0.0, 1.0))
	cam.global_position = cam.global_position.lerp(center, 1.0 - exp(-follow_speed * delta))
	cam.zoom = cam.zoom.lerp(Vector2.ONE * target_zoom, 1.0 - exp(-follow_speed * delta))
	if _shake_time > 0.0:
		cam.offset = (
			Vector2(
				randf_range(-_shake_strength, _shake_strength),
				randf_range(-_shake_strength, _shake_strength)
			)
			* (_shake_time / 0.12)
		)
		_shake_time = maxf(0.0, _shake_time - delta)
	else:
		cam.offset = Vector2.ZERO
		_shake_strength = 0.0
	cam.global_position.x = clampf(cam.global_position.x, -210.0, 210.0)
	cam.global_position.y = clampf(cam.global_position.y, -140.0, 60.0)


func shake(amount: float) -> void:
	_shake_strength = clampf(amount * 2.2, 1.0, 12.0)
	_shake_time = 0.12

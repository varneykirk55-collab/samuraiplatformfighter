extends Node2D


func _ready() -> void:
	call_deferred("_begin")


func _begin() -> void:
	MatchManager.begin_round()
	var camera := $Camera2D
	camera.enabled = true

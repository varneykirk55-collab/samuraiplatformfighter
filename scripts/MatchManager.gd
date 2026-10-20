extends Node

## Owns local versus/training flow, stocks, timer, rounds and tie sudden death.
signal match_state_changed
signal round_ended(winner_index: int)
signal match_ended(winner_index: int)

const MATCH_SCENE := preload("res://scenes/Match.tscn")
const TRAINING_SCENE := preload("res://scenes/Training.tscn")
const CHARACTERS := [
	preload("res://resources/characters/Katana.tres"),
	preload("res://resources/characters/Naginata.tres"),
	preload("res://resources/characters/DualWield.tres"),
	preload("res://resources/characters/Nodachi.tres")
]

var character_indices := [0, 3]
var fighter1: FighterController
var fighter2: FighterController
var training_mode := false
var paused := false
var match_over := false
var sudden_death := false
var round_number := 1
var p1_round_wins := 0
var p2_round_wins := 0
var best_of := 3
var round_time_limit := 180.0
var timer := 180.0
var stocks_per_round := 3
var round_reset_pending := false


func _process(delta: float) -> void:
	if paused or match_over or training_mode or round_reset_pending or sudden_death:
		return
	timer -= delta
	if timer <= 0.0:
		timer = 0.0
		_on_timer_expired()
		match_state_changed.emit()


func start_versus() -> void:
	_reset_session()
	training_mode = false
	get_tree().change_scene_to_packed(MATCH_SCENE)


func start_training() -> void:
	_reset_session()
	training_mode = true
	get_tree().change_scene_to_packed(TRAINING_SCENE)


func _reset_session() -> void:
	get_tree().paused = false
	paused = false
	match_over = false
	sudden_death = false
	round_number = 1
	p1_round_wins = 0
	p2_round_wins = 0
	round_reset_pending = false
	fighter1 = null
	fighter2 = null


func begin_round() -> void:
	paused = false
	match_over = false
	sudden_death = false
	timer = 0.0 if sudden_death else round_time_limit
	fighter1 = _spawn_fighter(0, Vector2(-330, -60), 1, false)
	fighter2 = _spawn_fighter(1, Vector2(330, -60), -1, training_mode)
	if training_mode:
		fighter2.stocks = 99
		fighter2.percent = 0.0
	match_state_changed.emit()


func _spawn_fighter(slot: int, pos: Vector2, face: int, dummy: bool) -> FighterController:
	var old := fighter1 if slot == 0 else fighter2
	if is_instance_valid(old):
		old.queue_free()
	var data: Character = CHARACTERS[character_indices[slot] % CHARACTERS.size()]
	var scene := data.player_scene
	var fighter: FighterController = (
		scene.instantiate() if scene else preload("res://scenes/Fighter.tscn").instantiate()
	)
	fighter.character = data
	fighter.player_index = slot
	fighter.is_dummy = dummy
	fighter.facing = face
	fighter.global_position = pos
	fighter.stocks = 99 if training_mode else data.starting_stocks
	get_tree().current_scene.add_child(fighter)
	if slot == 0:
		fighter1 = fighter
	else:
		fighter2 = fighter
	return fighter


func get_opponent(fighter: FighterController) -> FighterController:
	if fighter == fighter1:
		return fighter2
	if fighter == fighter2:
		return fighter1
	return null


func on_fighter_ko(fighter: FighterController) -> void:
	if training_mode:
		get_tree().create_timer(0.8).timeout.connect(
			func():
				if is_instance_valid(fighter):
					fighter.respawn(
						Vector2(330, -60) if fighter == fighter2 else Vector2(-330, -60)
					)
		)
		return
	if fighter.stocks <= 0:
		_finish_round(1 if fighter == fighter2 else 2)
	else:
		get_tree().create_timer(1.1).timeout.connect(
			func():
				if not match_over and is_instance_valid(fighter):
					fighter.respawn(
						Vector2(-330, -60) if fighter == fighter1 else Vector2(330, -60)
					)
					match_state_changed.emit()
		)
	match_state_changed.emit()


func _on_timer_expired() -> void:
	if fighter1 == null or fighter2 == null:
		return
	if fighter1.stocks > fighter2.stocks:
		_finish_round(1)
	elif fighter2.stocks > fighter1.stocks:
		_finish_round(2)
	elif not sudden_death:
		sudden_death = true
		timer = 0.0
		for fighter in [fighter1, fighter2]:
			fighter.stocks = 1
			fighter.percent = 150.0
			fighter.stocks_changed.emit(fighter)
			fighter.percent_changed.emit(fighter)
		match_state_changed.emit()


func _finish_round(winner: int) -> void:
	if round_reset_pending or match_over:
		return
	round_reset_pending = true
	if winner == 1:
		p1_round_wins += 1
	else:
		p2_round_wins += 1
	round_ended.emit(winner)
	var wins_needed := int(best_of / 2) + 1
	if p1_round_wins >= wins_needed or p2_round_wins >= wins_needed:
		match_over = true
		match_ended.emit(1 if p1_round_wins > p2_round_wins else 2)
		match_state_changed.emit()
		return
	get_tree().create_timer(2.0).timeout.connect(
		func():
			round_number += 1
			if is_instance_valid(fighter1):
				fighter1.queue_free()
			if is_instance_valid(fighter2):
				fighter2.queue_free()
			round_reset_pending = false
			begin_round()
	)


func is_beyond_blast_zone(pos: Vector2) -> bool:
	return pos.x < -1120 or pos.x > 1120 or pos.y > 760 or pos.y < -900


func toggle_pause() -> void:
	if training_mode or match_over or not is_instance_valid(fighter1):
		return
	paused = not paused
	get_tree().paused = paused
	match_state_changed.emit()


func reset_training() -> void:
	if not training_mode:
		return
	for fighter in [fighter1, fighter2]:
		if is_instance_valid(fighter):
			fighter.global_position = (
				Vector2(-330, -60) if fighter == fighter1 else Vector2(330, -60)
			)
			fighter.velocity = Vector2.ZERO
			fighter.active_move = null
			fighter._charge_move = null
			fighter._set_hitbox_area(null)
			fighter.percent = 0.0
			fighter._set_state(FighterState.State.IDLE)
			fighter.percent_changed.emit(fighter)

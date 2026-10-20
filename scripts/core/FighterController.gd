class_name FighterController
extends CharacterBody2D

## Generic fighter runtime. All character balance/move properties are Resources.
signal percent_changed(fighter: FighterController)
signal stocks_changed(fighter: FighterController)
signal state_changed(fighter: FighterController, new_state: int)
signal hit_connected(attacker: FighterController, defender: FighterController, data: HitboxData)

@export var character: Character
@export var player_index: int = 0
@export var is_dummy: bool = false
@export_enum("Stand", "Walk", "Jump") var dummy_behavior: int = 0
@export var show_debug: bool = false
@export var swing_sfx: AudioStream
@export var hit_sfx: AudioStream
@export var jump_sfx: AudioStream
@export var ko_sfx: AudioStream

var current_state: int = FighterState.State.IDLE
var facing: int = FighterState.Facing.RIGHT
var percent: float = 0.0
var stocks: int = 3
var jumps_remaining: int = 2
var active_move: MoveData
var move_frame := 0
var stun_time := 0.0
var hitstop_time := 0.0
var tech_window := 0.0
var invulnerability := 0.0
var ledge_time := 0.0
var input_direction := Vector2.ZERO
var special_held := false
var buffered_attack := false
var buffered_special := false
var buffered_jump := false
var buffered_smash := false
var input_buffer_frames := 7
var _charge_move: MoveData
var _charge_frames_held := 0
var _charge_power := 0.0
var _buffer_attack := 0
var _buffer_special := 0
var _buffer_jump := 0
var _buffer_smash := 0
var _hit_this_move := false
var _hitbox_hit_ids: Dictionary = {}
var _dummy_clock := 0.0
var _hurtbox_radius := 28.0
var _hitboxes: Array[HitboxData] = []


func _ready() -> void:
	add_to_group("fighters")
	var hit_shape := get_node_or_null("HitboxArea/CollisionShape2D") as CollisionShape2D
	if hit_shape and hit_shape.shape:
		hit_shape.shape = hit_shape.shape.duplicate()
	if character and character.stats:
		jumps_remaining = character.stats.max_jumps
		_hurtbox_radius = character.stats.hurtbox_radius
		stocks = character.starting_stocks
	queue_redraw()


func _physics_process(delta: float) -> void:
	if current_state == FighterState.State.DEAD:
		return
	if hitstop_time > 0.0:
		hitstop_time -= delta
		if hitstop_time <= 0.0:
			_set_state(FighterState.State.HITSTUN if stun_time > 0.0 else _air_ground_state())
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	tech_window = maxf(0.0, tech_window - delta)
	if current_state == FighterState.State.LEDGE:
		_process_ledge()
		return
	if current_state == FighterState.State.CHARGE:
		_update_charge()
	elif current_state in [FighterState.State.HITSTUN, FighterState.State.KNOCKBACK]:
		stun_time -= delta
		# DI: hold a direction during hitstun to slightly curve the launch trajectory.
		if not is_on_floor():
			velocity.x += input_direction.x * 260.0 * delta
			velocity.y += input_direction.y * 180.0 * delta
		if stun_time <= 0.0:
			_set_state(_air_ground_state())
	elif current_state in [FighterState.State.TECH, FighterState.State.GET_UP]:
		stun_time -= delta
		if stun_time <= 0.0:
			_set_state(FighterState.State.IDLE if is_on_floor() else FighterState.State.FALL)
	else:
		_handle_action_buffers()
		_handle_movement(delta)
	_handle_attack()
	if not is_on_floor() and not (active_move and active_move.ignore_gravity):
		var gravity := character.stats.fall_gravity if character and character.stats else 1700.0
		if input_direction.y > 0.65:
			gravity = character.stats.fast_fall_gravity if character and character.stats else 2400.0
		var max_fall := character.stats.max_fall_speed if character and character.stats else 1100.0
		velocity.y = minf(velocity.y + gravity * delta, max_fall)
	move_and_slide()
	_check_landing_and_tech()
	_check_ledge_grab()
	if MatchManager.is_beyond_blast_zone(global_position):
		lose_stock()
	queue_redraw()


func submit_input(
	direction: Vector2,
	attack: bool,
	special: bool,
	jump: bool,
	smash: bool = false,
	hold_special: bool = false
) -> void:
	input_direction = direction.limit_length(1.0)
	special_held = hold_special
	if attack:
		_buffer_attack = input_buffer_frames
	if special:
		_buffer_special = input_buffer_frames
	if jump:
		_buffer_jump = input_buffer_frames
	if smash:
		_buffer_smash = input_buffer_frames
	_buffer_attack = maxi(0, _buffer_attack - 1)
	_buffer_special = maxi(0, _buffer_special - 1)
	_buffer_jump = maxi(0, _buffer_jump - 1)
	_buffer_smash = maxi(0, _buffer_smash - 1)
	buffered_attack = _buffer_attack > 0
	buffered_special = _buffer_special > 0
	buffered_jump = _buffer_jump > 0
	buffered_smash = _buffer_smash > 0


func _handle_action_buffers() -> void:
	# Priority: specials > attacks (including smash) > jump.
	if buffered_special:
		var special_move := _select_move(true)
		if special_move:
			if special_move.charge_frames > 0 and special_held:
				_charge_move = special_move
				_charge_frames_held = 0
				_charge_power = 0.0
				_set_state(FighterState.State.CHARGE)
			else:
				_start_move(special_move)
			_consume_buffers()
			return
	if buffered_attack:
		var attack_move := _select_move(false, buffered_smash)
		if attack_move:
			_start_move(attack_move)
			_consume_buffers()
			return
	if buffered_jump and (is_on_floor() or jumps_remaining > 0):
		velocity.y = character.stats.jump_velocity if character and character.stats else -650.0
		jumps_remaining -= 1
		_set_state(FighterState.State.JUMP)
		_play_sfx(jump_sfx)
		_consume_buffers()


func _update_charge() -> void:
	if _charge_move == null:
		_set_state(_air_ground_state())
		return
	_charge_frames_held += 1
	var charge_limit := maxi(1, _charge_move.charge_frames)
	if not special_held or _charge_frames_held >= charge_limit:
		var move := _charge_move
		var power := clampf(float(_charge_frames_held) / float(charge_limit), 0.0, 1.0)
		_charge_move = null
		_start_move(move, power)


func _select_move(special: bool, smash: bool = false) -> MoveData:
	if character == null:
		return null
	var wanted := ""
	if special:
		if input_direction.y < -0.6:
			wanted = "SpecialUp"
		elif input_direction.y > 0.6:
			wanted = "SpecialDown"
		elif absf(input_direction.x) > 0.25:
			wanted = "SpecialSide"
		else:
			wanted = "SpecialNeutral"
	else:
		if not is_on_floor() and absf(input_direction.x) > 0.5:
			wanted = "ForwardAir" if input_direction.x * facing > 0 else "BackAir"
		elif not is_on_floor() and input_direction.y < -0.5:
			wanted = "UpAir"
		elif not is_on_floor() and input_direction.y > 0.5:
			wanted = "DownAir"
		elif is_on_floor() and smash:
			if input_direction.y < -0.5:
				wanted = "UpSmash"
			elif input_direction.y > 0.5:
				wanted = "DownSmash"
			else:
				wanted = "ForwardSmash"
		elif is_on_floor() and absf(input_direction.x) > 0.6:
			wanted = "ForwardTilt"
		elif is_on_floor() and input_direction.y < -0.5:
			wanted = "UpTilt"
		elif is_on_floor() and input_direction.y > 0.5:
			wanted = "DownTilt"
		else:
			wanted = "Jab"
	for resource in character.moves:
		var move := resource as MoveData
		if move and (move.input_command == wanted or move.move_name == wanted):
			return move
	return character.signature_move if special else null


func _start_move(move: MoveData, charge_power: float = 0.0) -> void:
	if (
		current_state
		in [FighterState.State.HITSTUN, FighterState.State.KNOCKBACK, FighterState.State.DEAD]
	):
		return
	if not is_on_floor() and not move.usable_in_air:
		return
	active_move = move
	_charge_power = clampf(charge_power, 0.0, 1.0)
	move_frame = 0
	_hit_this_move = false
	_hitbox_hit_ids.clear()
	_hitboxes = move.hitboxes
	if move.launch_velocity != 0.0:
		velocity.y = move.launch_velocity
	if move.face_target_on_start:
		facing = 1 if global_position.x < _get_opponent_x() else -1
	_set_state(FighterState.State.ATTACK)
	_play_character_animation("attack")
	_play_sfx(swing_sfx)


func _handle_attack() -> void:
	if current_state != FighterState.State.ATTACK or active_move == null:
		_set_hitbox_area(null)
		return
	move_frame += 1
	if (
		active_move.dash_velocity != 0.0
		and move_frame <= active_move.startup_frames + active_move.active_frames
	):
		velocity.x = active_move.dash_velocity * facing
	if active_move.ignore_gravity:
		velocity.y = 0.0
	var active_data: HitboxData
	var active_phase := (
		move_frame >= active_move.startup_frames
		and move_frame < active_move.startup_frames + active_move.active_frames
	)
	if active_phase:
		for data in _hitboxes:
			if data == null:
				continue
			var frame_start := (
				data.active_start_frame
				if data.active_start_frame > 0
				else active_move.startup_frames
			)
			var frame_end := (
				data.active_end_frame
				if data.active_end_frame >= 0
				else active_move.startup_frames + active_move.active_frames
			)
			if move_frame >= frame_start and move_frame < frame_end:
				active_data = data
				HitManager.try_hit(self, data)
	_set_hitbox_area(active_data)
	if move_frame >= active_move.total_frames():
		_set_hitbox_area(null)
		active_move = null
		_charge_power = 0.0
		_set_state(_air_ground_state())


func _set_hitbox_area(data: HitboxData) -> void:
	var area := get_node_or_null("HitboxArea") as Area2D
	var shape_node := get_node_or_null("HitboxArea/CollisionShape2D") as CollisionShape2D
	if area == null or shape_node == null:
		return
	if data == null:
		area.set_deferred("monitoring", false)
		shape_node.set_deferred("disabled", true)
		return
	area.position = Vector2(data.offset.x * facing, data.offset.y)
	if data.shape == HitboxData.SHAPE_CIRCLE:
		var circle := shape_node.shape as CircleShape2D
		if circle == null:
			circle = CircleShape2D.new()
			shape_node.shape = circle
		circle.radius = maxf(data.size.x, data.size.y) * 0.5
	else:
		var rectangle := shape_node.shape as RectangleShape2D
		if rectangle == null:
			rectangle = RectangleShape2D.new()
			shape_node.shape = rectangle
		rectangle.size = data.size
	shape_node.set_deferred("disabled", false)
	area.set_deferred("monitoring", true)


func apply_hit(attacker: FighterController, data: HitboxData) -> void:
	if invulnerability > 0.0 or current_state == FighterState.State.DEAD:
		return
	var source_move := attacker.active_move
	var damage_scale := source_move.charge_damage_multiplier if source_move else 1.0
	var knockback_scale := source_move.charge_knockback_multiplier if source_move else 1.0
	percent += (
		data.damage
		* lerpf(1.0, damage_scale, attacker._charge_power)
		* (character.damage_multiplier if character else 1.0)
	)
	percent_changed.emit(self)
	var angle := deg_to_rad(data.knockback_angle)
	var growth := (
		(data.knockback_base + percent * data.knockback_scaling)
		* lerpf(1.0, knockback_scale, attacker._charge_power)
	)
	var weight := character.stats.weight if character and character.stats else 1.0
	var launch := (
		Vector2(cos(angle) * growth * attacker.facing, -sin(angle) * growth) / maxf(0.5, weight)
	)
	if data.fixed_angle:
		launch = Vector2(0.0, -growth / maxf(0.5, weight))
	velocity = launch
	stun_time = clampf(growth / 1400.0, 0.12, 1.25)
	tech_window = character.stats.tech_window if character and character.stats else 0.12
	_set_hitbox_area(null)
	_set_state(FighterState.State.KNOCKBACK if growth > 360.0 else FighterState.State.HITSTUN)
	attacker.hitstop_time = maxf(attacker.hitstop_time, data.hitstop)
	hitstop_time = maxf(hitstop_time, data.hitstop)
	attacker.hit_connected.emit(attacker, self, data)
	_play_character_animation("hurt")
	_play_sfx(hit_sfx)
	if data.shake_intensity > 0.0:
		FightCamera.shake(data.shake_intensity)


func _handle_movement(delta: float) -> void:
	if current_state in [FighterState.State.ATTACK, FighterState.State.CHARGE]:
		return
	if is_dummy:
		_dummy_clock += delta
		input_direction = (
			Vector2(sin(_dummy_clock * 0.7) * 0.25, 0.0) if dummy_behavior == 1 else Vector2.ZERO
		)
		if dummy_behavior == 2 and is_on_floor() and int(_dummy_clock * 2.0) % 4 == 0:
			_buffer_jump = 2
			buffered_jump = true
	var speed := character.stats.walk_speed if character and character.stats else 300.0
	if is_on_floor():
		if absf(input_direction.x) > 0.15:
			velocity.x = input_direction.x * speed
			_set_state(FighterState.State.WALK)
			_play_character_animation("walk")
		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				(
					(character.stats.ground_friction if character and character.stats else 1800.0)
					* delta
				)
			)
			if (
				current_state
				not in [
					FighterState.State.ATTACK,
					FighterState.State.HITSTUN,
					FighterState.State.KNOCKBACK
				]
			):
				_set_state(FighterState.State.IDLE)
				_play_character_animation("idle")
	else:
		var accel := character.stats.air_acceleration if character and character.stats else 850.0
		var max_speed := character.stats.max_air_speed if character and character.stats else 430.0
		velocity.x = move_toward(velocity.x, input_direction.x * max_speed, accel * delta)
		_set_state(FighterState.State.JUMP if velocity.y < 0.0 else FighterState.State.FALL)
		_play_character_animation("jump" if velocity.y < 0.0 else "fall")


func _check_landing_and_tech() -> void:
	if is_on_floor():
		jumps_remaining = character.stats.max_jumps if character and character.stats else 2
		if (
			current_state in [FighterState.State.HITSTUN, FighterState.State.KNOCKBACK]
			and tech_window > 0.0
			and InputManager.is_shield_pressed(player_index)
		):
			velocity = Vector2.ZERO
			_set_state(FighterState.State.TECH)
			stun_time = 0.18
			invulnerability = 0.35
			_play_character_animation("tech")
	elif is_on_wall() and tech_window > 0.0 and InputManager.is_shield_pressed(player_index):
		velocity = Vector2.ZERO
		_set_state(FighterState.State.TECH)
		stun_time = 0.18
		invulnerability = 0.3


func _check_ledge_grab() -> void:
	if (
		is_on_floor()
		or velocity.y < 0.0
		or current_state in [FighterState.State.ATTACK, FighterState.State.LEDGE]
	):
		return
	for ledge in get_tree().get_nodes_in_group("ledges"):
		var distance := (
			character.stats.ledge_grab_distance if character and character.stats else 54.0
		)
		if (
			global_position.distance_to(ledge.global_position) < distance
			and ledge.global_position.y >= global_position.y - 45.0
		):
			global_position = ledge.global_position + Vector2(0, 18)
			ledge_time = character.stats.ledge_hold_time if character and character.stats else 1.5
			_set_state(FighterState.State.LEDGE)
			return


func _process_ledge() -> void:
	ledge_time -= get_physics_process_delta_time()
	velocity = Vector2.ZERO
	if ledge_time <= 0.0 or buffered_jump or buffered_attack:
		global_position.y -= 26.0
		velocity = Vector2(150.0 * facing, -390.0)
		invulnerability = 0.55
		_set_state(FighterState.State.JUMP)
	_consume_buffers()


func lose_stock() -> void:
	if current_state == FighterState.State.DEAD:
		return
	stocks -= 1
	stocks_changed.emit(self)
	_play_sfx(ko_sfx)
	_set_hitbox_area(null)
	_set_state(FighterState.State.DEAD)
	velocity = Vector2.ZERO
	MatchManager.on_fighter_ko(self)


func respawn(at_position: Vector2) -> void:
	global_position = at_position
	active_move = null
	_charge_move = null
	_charge_power = 0.0
	_hitbox_hit_ids.clear()
	_set_hitbox_area(null)
	percent = 0.0
	invulnerability = 2.0
	jumps_remaining = character.stats.max_jumps if character and character.stats else 2
	_set_state(FighterState.State.IDLE)
	percent_changed.emit(self)


func _air_ground_state() -> int:
	return FighterState.State.IDLE if is_on_floor() else FighterState.State.FALL


func _consume_buffers() -> void:
	_buffer_attack = 0
	_buffer_special = 0
	_buffer_jump = 0
	_buffer_smash = 0
	buffered_attack = false
	buffered_special = false
	buffered_jump = false
	buffered_smash = false


func _set_state(state: int) -> void:
	if current_state == state:
		return
	current_state = state
	state_changed.emit(self, state)


func _get_opponent_x() -> float:
	var opponent := MatchManager.get_opponent(self)
	return opponent.global_position.x if opponent else global_position.x + facing


func _play_character_animation(animation_name: String) -> void:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)


func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := get_node_or_null("SFX") as AudioStreamPlayer2D
	if player:
		player.stream = stream
		player.play()


func _draw() -> void:
	var accent := character.player_color if character else Color(0.75, 0.17, 0.12)
	var tint := accent
	if current_state in [FighterState.State.HITSTUN, FighterState.State.KNOCKBACK]:
		tint = Color("e78968")
	elif invulnerability > 0.0 and int(Time.get_ticks_msec() / 90) % 2 == 0:
		tint = Color(0.65, 0.68, 0.72)
	var body_shift := Vector2.ZERO
	if current_state == FighterState.State.JUMP:
		body_shift.y = -5.0
	elif current_state == FighterState.State.FALL:
		body_shift.y = 5.0
	elif current_state in [FighterState.State.HITSTUN, FighterState.State.KNOCKBACK]:
		body_shift.x = -6.0 * facing
	var walk_phase := (
		sin(Time.get_ticks_msec() * 0.012) * 8.0
		if current_state == FighterState.State.WALK
		else 0.0
	)
	draw_circle(body_shift + Vector2(0, -70), 13, Color(0.80, 0.66, 0.51))
	draw_rect(Rect2(body_shift + Vector2(-15, -57), Vector2(30, 34)), tint)
	draw_colored_polygon(
		PackedVector2Array(
			[
				body_shift + Vector2(-13, -23),
				body_shift + Vector2(13, -23),
				body_shift + Vector2(18, 0),
				body_shift + Vector2(-17, 0)
			]
		),
		tint.darkened(0.22)
	)
	var arm := Vector2(22 * facing, -39)
	if current_state == FighterState.State.JUMP:
		arm = Vector2(16 * facing, -61)
	elif current_state == FighterState.State.FALL:
		arm = Vector2(12 * facing, -23)
	elif current_state == FighterState.State.ATTACK:
		arm = Vector2(22 * facing, -39)
	else:
		arm = Vector2(15 * facing, -30)
	draw_line(Vector2(7 * facing, -48), arm, tint.lightened(0.12), 8)
	draw_line(Vector2(-8, -3), Vector2(-12 - walk_phase, 0), Color(0.14, 0.12, 0.12), 7)
	draw_line(Vector2(8, -3), Vector2(13 + walk_phase, 0), Color(0.14, 0.12, 0.12), 7)
	var start := arm + Vector2(3 * facing, 0)
	var length := character.weapon_length if character else 76.0
	var thickness := character.weapon_thickness if character else 4.0
	var end := start + Vector2(length * facing, -8)
	if character and character.weapon_is_polearm:
		draw_line(start, end, Color(0.44, 0.28, 0.17), thickness)
		draw_line(end, end + Vector2(17 * facing, -3), Color(0.86, 0.87, 0.84), thickness)
	else:
		draw_line(start, end, Color(0.81, 0.82, 0.82), thickness)
		draw_line(start, start + Vector2(-12 * facing, 4), Color(0.42, 0.25, 0.13), 6)
	if character and character.offhand_weapon_length > 0.0:
		var offhand := Vector2(-8 * facing, -38)
		draw_line(
			offhand,
			offhand + Vector2(-character.offhand_weapon_length * facing, -23),
			Color(0.86, 0.87, 0.84),
			thickness
		)
	if current_state == FighterState.State.ATTACK:
		draw_arc(start, length * 0.72, -0.65, 0.75, 24, Color(0.94, 0.83, 0.66, 0.62), 3)
	if show_debug:
		draw_arc(Vector2(0, -38), _hurtbox_radius, 0, TAU, 32, Color(0.1, 0.8, 1.0, 0.8), 2)
		if active_move:
			for box in _hitboxes:
				var offset := Vector2(box.offset.x * facing, box.offset.y)
				draw_rect(
					Rect2(offset - box.size * 0.5, box.size), Color(1.0, 0.1, 0.1, 0.22), true
				)
				draw_rect(
					Rect2(offset - box.size * 0.5, box.size), Color(1.0, 0.1, 0.1, 0.85), false, 2
				)

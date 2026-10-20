extends Node

## Local 1v1 reader: WASD/J/K/Space/L vs arrows/numpad, plus up to two gamepads.
## Input is sampled at the 60 Hz physics rate and forwarded to each fighter's buffer.
var single_gamepad_player := 1  # For keyboard + one gamepad, 0 = P1 or 1 = P2.
var _previous: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	if _edge("pause", Input.is_key_pressed(KEY_ESCAPE)):
		MatchManager.toggle_pause()
	if get_tree().paused:
		return
	for slot in range(2):
		var fighter: FighterController = (
			MatchManager.fighter1 if slot == 0 else MatchManager.fighter2
		)
		if not is_instance_valid(fighter):
			continue
		var pad_id := _pad_for_slot(slot)
		if fighter.is_dummy:
			fighter.submit_input(Vector2.ZERO, false, false, false)
			continue
		var direction := _read_direction(slot, pad_id)
		var jump := _pressed(
			slot, "jump", KEY_SPACE if slot == 0 else KEY_KP_0, pad_id, JOY_BUTTON_A
		)
		var attack := _pressed(
			slot, "attack", KEY_J if slot == 0 else KEY_KP_1, pad_id, JOY_BUTTON_X
		)
		var special := _pressed(
			slot, "special", KEY_K if slot == 0 else KEY_KP_2, pad_id, JOY_BUTTON_B
		)
		var smash := _pressed(
			slot, "smash", KEY_U if slot == 0 else KEY_KP_4, pad_id, JOY_BUTTON_RIGHT_SHOULDER
		)
		var special_held := Input.is_key_pressed(KEY_K if slot == 0 else KEY_KP_2)
		if pad_id >= 0:
			special_held = special_held or Input.is_joy_button_pressed(pad_id, JOY_BUTTON_B)
		fighter.submit_input(direction, attack, special, jump, smash, special_held)


func is_shield_pressed(slot: int) -> bool:
	var pad_id := _pad_for_slot(slot)
	var key := KEY_L if slot == 0 else KEY_KP_3
	return (
		Input.is_key_pressed(key)
		or (pad_id >= 0 and Input.is_joy_button_pressed(pad_id, JOY_BUTTON_Y))
	)


func _pad_for_slot(slot: int) -> int:
	var pads := Input.get_connected_joypads()
	if pads.size() >= 2:
		return pads[slot]
	if pads.size() == 1 and slot == single_gamepad_player:
		return pads[0]
	return -1


func _read_direction(slot: int, pad_id: int) -> Vector2:
	var x := 0.0
	var y := 0.0
	if slot == 0:
		x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	else:
		x = float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
		y = float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))
	if pad_id >= 0:
		var ax := Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_Y)
		if absf(ax) > 0.2:
			x = ax
		if absf(ay) > 0.2:
			y = ay
	return Vector2(x, y).limit_length(1.0)


func _pressed(slot: int, name: String, key: Key, pad_id: int, button: JoyButton) -> bool:
	var held := Input.is_key_pressed(key)
	if pad_id >= 0:
		held = held or Input.is_joy_button_pressed(pad_id, button)
	return _edge("%s_%s" % [slot, name], held)


func _edge(name: String, held: bool) -> bool:
	var was_held: bool = _previous.get(name, false)
	_previous[name] = held
	return held and not was_held

extends Node


## Central hit routing. Combat is resolved once per hitbox activation so fighters don't
## need character-specific collision logic. FighterController owns move timing/data.
func try_hit(attacker: FighterController, data: HitboxData) -> void:
	if attacker == null or data == null or attacker._hitbox_hit_ids.has(data.get_instance_id()):
		return
	var defender: FighterController = MatchManager.get_opponent(attacker)
	if defender == null or defender.current_state == FighterState.State.DEAD:
		return
	var center := attacker.global_position + Vector2(data.offset.x * attacker.facing, data.offset.y)
	var target := defender.global_position + Vector2(0, -35)
	var hit := false
	if data.shape == 0:
		hit = (
			center.distance_to(target)
			<= maxf(data.size.x, data.size.y) * 0.5 + defender._hurtbox_radius
		)
	else:
		var local := target - center
		hit = (
			absf(local.x) <= data.size.x * 0.5 + defender._hurtbox_radius
			and absf(local.y) <= data.size.y * 0.5 + defender._hurtbox_radius
		)
	if hit:
		attacker._hitbox_hit_ids[data.get_instance_id()] = true
		attacker._hit_this_move = true
		defender.apply_hit(attacker, data)

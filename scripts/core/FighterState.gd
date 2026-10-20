class_name FighterState
extends RefCounted

## Generic fighter state IDs. Character-specific behaviour belongs in MoveData.
enum State {
	IDLE, WALK, JUMP, FALL, ATTACK, CHARGE, HITSTUN, KNOCKBACK, LEDGE, TECH, GET_UP, DEAD, HITSTOP
}
enum Facing { LEFT = -1, RIGHT = 1 }
enum MoveCategory { JAB, TILT, SMASH, AERIAL, SPECIAL }

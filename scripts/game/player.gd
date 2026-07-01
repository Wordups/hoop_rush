extends Node2D
class_name PlayerAvatar
## Placeholder player (option C). Movement, 8-dir facing, back-facing rest, depth scaling.
## Option B (real sprites) swaps the _draw() block for an AnimatedSprite2D driven by
## `facing` + `state` — nothing else changes.

@export var move_speed: float = 560.0

var move_dir: Vector2 = Vector2.ZERO      ## set by GameCourt's joystick
var facing_vec: Vector2 = Vector2.UP      ## UP = back-facing rest (player looks upcourt at hoop)
var bounds: Rect2 = Rect2(0, 0, 1080, 1920)
var state: String = "idle"                ## idle | run | shoot
var base_scale: float = 1.0

const DIR_NAMES := ["UP", "UP_RIGHT", "RIGHT", "DOWN_RIGHT", "DOWN", "DOWN_LEFT", "LEFT", "UP_LEFT"]

func _process(delta: float) -> void:
	var mag := clampf(move_dir.length(), 0.0, 1.0)
	if mag > 0.08 and state != "shoot":
		state = "run"
		var v := move_dir.normalized() * move_speed * mag
		position += v * delta
		position.x = clampf(position.x, bounds.position.x, bounds.end.x)
		position.y = clampf(position.y, bounds.position.y, bounds.end.y)
		facing_vec = move_dir.normalized()
	elif state != "shoot":
		state = "idle"          # rests back-facing (facing_vec stays UP-ish upcourt)
	_apply_depth()
	queue_redraw()

## smaller/further as the player moves upcourt (toward the hoop)
func _apply_depth() -> void:
	var t := clampf((position.y - bounds.position.y) / maxf(bounds.size.y, 1.0), 0.0, 1.0)
	scale = Vector2.ONE * (base_scale * lerpf(0.74, 1.08, t))

func facing_index() -> int:
	var ang := fposmod(rad_to_deg(atan2(facing_vec.x, -facing_vec.y)), 360.0)  # 0 = UP
	return int(round(ang / 45.0)) % 8

func _draw() -> void:
	# --- placeholder art (swap for AnimatedSprite2D in option B) ---
	var is_back := facing_index() == 0
	var jersey := Color(0.86, 0.24, 0.22)
	var skin := Color(0.86, 0.66, 0.5)
	# soft ground shadow
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, 46), 30, Color(0, 0, 0, 0.22))
	# legs
	draw_rect(Rect2(-16, 14, 12, 40), Color(0.15, 0.15, 0.18), true)
	draw_rect(Rect2(4, 14, 12, 40), Color(0.15, 0.15, 0.18), true)
	# torso (jersey)
	draw_rect(Rect2(-24, -34, 48, 54), jersey, true)
	# head — back of head if facing upcourt, face if turned toward camera
	draw_circle(Vector2(0, -50), 22, skin)
	if not is_back:
		draw_circle(Vector2(-7, -52), 3, Color.BLACK)
		draw_circle(Vector2(7, -52), 3, Color.BLACK)
	else:
		draw_circle(Vector2(0, -54), 12, Color(0.2, 0.14, 0.1))   # hair (back)
	# facing wedge (debug/juice — direction the player is heading)
	draw_line(Vector2(0, -8), facing_vec * 54 + Vector2(0, -8), Color(1, 1, 1, 0.35), 4)

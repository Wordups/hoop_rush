extends Node2D
class_name PlayerAvatar
## Real 8-directional avatar (option B). Movement, 8-dir facing, back-facing rest, depth
## scaling unchanged from the placeholder; _draw() now blits the directional sprite that
## matches facing_index() instead of drawing primitives. Sprites extracted from the
## commissioned player-model board (files/Player.png), one per DIR_NAMES entry.

@export var move_speed: float = 560.0

# dribble-move burst (fired by a stick flick)
const BURST_DUR := 0.22
const BURST_SPEED := 1240.0
var _burst_t: float = 0.0
var _burst_dir: Vector2 = Vector2.ZERO

var move_dir: Vector2 = Vector2.ZERO      ## set by GameCourt's dribble stick
var facing_vec: Vector2 = Vector2.UP      ## UP = back-facing rest (player looks upcourt at hoop)
var bounds: Rect2 = Rect2(0, 0, 1080, 1920)
var state: String = "idle"                ## idle | run | shoot
var base_scale: float = 1.0

const DIR_NAMES := ["UP", "UP_RIGHT", "RIGHT", "DOWN_RIGHT", "DOWN", "DOWN_LEFT", "LEFT", "UP_LEFT"]
## index-aligned with DIR_NAMES / facing_index(); 0 = back-facing (upcourt) rest
const SPRITE_PATHS := [
	"res://assets/player/00_up.png",
	"res://assets/player/01_up_right.png",
	"res://assets/player/02_right.png",
	"res://assets/player/03_down_right.png",
	"res://assets/player/04_down.png",
	"res://assets/player/05_down_left.png",
	"res://assets/player/06_left.png",
	"res://assets/player/07_up_left.png",
]
const FOOT_Y := 56.0                       ## local-space ground line; feet rest here

var _sprites: Array[Texture2D] = []

func _ready() -> void:
	for p in SPRITE_PATHS:
		_sprites.append(load(p) as Texture2D)

## quick size-up burst in a direction (called by the court on a stick flick)
func dribble_burst(dir: Vector2) -> void:
	if state == "shoot" or dir.length() < 0.3:
		return
	_burst_dir = dir.normalized()
	_burst_t = BURST_DUR


func _process(delta: float) -> void:
	# dribble-move burst overrides normal movement while it lasts
	if _burst_t > 0.0 and state != "shoot":
		_burst_t -= delta
		state = "run"
		position += _burst_dir * BURST_SPEED * delta
		position.x = clampf(position.x, bounds.position.x, bounds.end.x)
		position.y = clampf(position.y, bounds.position.y, bounds.end.y)
		facing_vec = _burst_dir
		_apply_depth()
		queue_redraw()
		return
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
	# soft ground shadow anchored at the feet
	draw_circle(Vector2(0, FOOT_Y - 6), 30, Color(0, 0, 0, 0.22))
	var idx := facing_index()
	if idx >= _sprites.size():
		return
	var tex := _sprites[idx]
	if tex == null:
		return
	# blit centered horizontally, feet resting on the local ground line
	var sz := tex.get_size()
	draw_texture(tex, Vector2(-sz.x * 0.5, FOOT_Y - sz.y))

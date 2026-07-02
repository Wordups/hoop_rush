extends Node
class_name BallCourtship
## §8 of CHARACTER_TDD: the ball is courted, never glued. During dribble states the ball is
## spring-driven toward the active hand target (it leads and lags, alive); on each floor
## contact it squashes (0.92y / 1.05xz, ~60ms). Outside dribble states, pure physics/flight
## owns it. Today the "hand target" is the procedural dribble point beside the placeholder
## rig; when hero23 lands, the target becomes the `ball_hand_L/R` bone and nothing else changes.

const SQUASH := Vector3(1.05, 0.92, 1.05)
const SQUASH_TIME := 0.06

var spring_k: float = 18.0          # spring stiffness toward the target (higher = tighter)

var _ball: Node3D
var _squash_tw: Tween


func bind(ball: Node3D) -> void:
	_ball = ball


## spring the ball toward `target` (already includes bounce height); call each frame in dribble
func court(target: Vector3, delta: float) -> void:
	if _ball == null:
		return
	var t := minf(spring_k * delta, 1.0)
	_ball.position = _ball.position.lerp(target, t)


## floor-contact compression; call on each dribble/physics bounce
func squash() -> void:
	if _ball == null:
		return
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	_ball.scale = SQUASH
	_squash_tw = _ball.create_tween()
	_squash_tw.tween_property(_ball, "scale", Vector3.ONE, SQUASH_TIME * 2.0)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

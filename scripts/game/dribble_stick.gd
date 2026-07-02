extends Control
class_name DribbleStick
## Small fixed on-screen analog stick (NBA-Live "dribble stick" flavor). Purely visual:
## GameCourt owns the touch input (so multitouch move + SHOOT keeps working) and pushes
## `knob` (px offset from center, already clamped) + `active` here each frame. A fast
## outward flick of the stick is detected court-side and fires a quick dribble-move burst.

const RADIUS := 120.0     ## default base ring radius (screen px)
const KNOB := 48.0        ## knob radius

var radius: float = RADIUS         ## live-tunable (TUNE panel)
var active: bool = false
var knob: Vector2 = Vector2.ZERO   ## offset from center, clamped to radius

func center() -> Vector2:
	return size * 0.5

func _draw() -> void:
	var c := center()
	# base: dim disc + rim ring + faint deadzone ring
	draw_circle(c, radius, Color(0, 0, 0, 0.26))
	draw_arc(c, radius, 0, TAU, 56, Color(1, 1, 1, 0.32), 4.0)
	draw_arc(c, radius * 0.42, 0, TAU, 40, Color(1, 1, 1, 0.12), 2.0)
	# knob — reddish when engaged (matches the jersey trim), pale when resting
	var kc := c + knob
	var col := Color(0.95, 0.34, 0.29, 0.92) if active else Color(1, 1, 1, 0.5)
	draw_circle(kc, KNOB, col)
	draw_arc(kc, KNOB, 0, TAU, 40, Color(1, 1, 1, 0.75), 3.0)

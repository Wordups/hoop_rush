extends Control
class_name ShotMeter
## The oscillating timing bar + green sweet-spot + power/charge fill.
## GameCourt sets `t`, `sweet`, `charge`, `active` and calls queue_redraw().

var active: bool = false
var t: float = 0.5        ## indicator position 0..1
var sweet: float = 0.22   ## sweet-spot fraction of the bar
var charge: float = 0.0   ## power 0..1

func _draw() -> void:
	if not active:
		return
	var w := size.x
	var h := size.y
	# bar track
	draw_rect(Rect2(0, h * 0.30, w, h * 0.34), Color(0, 0, 0, 0.6), true)
	# green sweet-spot (centered)
	var sw := clampf(sweet, 0.05, 0.92) * w
	draw_rect(Rect2(w * 0.5 - sw * 0.5, h * 0.30, sw, h * 0.34), Color(0.30, 0.90, 0.42, 0.9), true)
	# perfect center line
	draw_line(Vector2(w * 0.5, h * 0.12), Vector2(w * 0.5, h * 0.82), Color(1, 1, 1, 0.5), 2)
	# moving indicator
	var ix := clampf(t, 0.0, 1.0) * w
	draw_rect(Rect2(ix - 4, h * 0.06, 8, h * 0.82), Color(1, 0.92, 0.35), true)
	# power / charge fill
	draw_rect(Rect2(0, h * 0.72, w * clampf(charge, 0.0, 1.0), h * 0.14), Color(1, 0.55, 0.2, 0.95), true)

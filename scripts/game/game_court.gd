extends Node2D
## GameCourt — the home screen AND the Score Attack round (the court is alive on open).
## Builds everything in code so it's easy to validate + tune. Placeholder player, real court.
## Tunable layout constants up top — adjust in editor once the art framing feels right.

# ---- tunable layout (screen-space, 1080x1920 portrait) ----
const SCREEN := Vector2(1080, 1920)
const RIM := Vector2(540, 520)                     # where the hoop sits on screen
const PLAY_BOUNDS := Rect2(150, 780, 780, 940)     # roamable area (x,y,w,h)
const COURT_LEN := 1150.0                           # distance reference for zone bands

# ---- dribble stick (single small analog stick, NBA-Live feel) ----
const STICK_CENTER := Vector2(540, 1500)            # fixed base, horizontally centered, thumb zone
const STICK_RADIUS := 120.0                         # knob travel = base ring (keep == DribbleStick.RADIUS)
const STICK_ACTIVATE_R := 240.0                     # touch within this of center grabs the stick
const FLICK_SPEED := 2400.0                         # px/s drag velocity that triggers a dribble burst
const FLICK_COOLDOWN := 0.32

# ---- round rules ----
const ROUND_TIME := 60.0
const MAX_MISSES := 3
const CHARGE_RATE := 1.0 / 0.7
const POWER_THRESHOLD := 0.6
const METER_SPEED := 1.65

# ---- state ----
var state: String = "ready"          # ready | playing | shooting | results
var time_left: float = ROUND_TIME
var score: int = 0
var makes: int = 0
var misses: int = 0
var streak: int = 0
var coins_earned: int = 0

# shot-in-progress
var charge: float = 0.0
var meter_time: float = 0.0
var cur_zone: int = ShotMath.Zone.MID

# ball flight (drawn in _draw)
var ball_active: bool = false
var ball_pos: Vector2 = Vector2.ZERO

# dribble stick
var joy_active: bool = false
var joy_index: int = -1
var stick: DribbleStick
var _flick_cd: float = 0.0

# nodes
var player: PlayerAvatar
var meter: ShotMeter
var lbl_score: Label
var lbl_timer: Label
var lbl_streak: Label
var lbl_misses: Label
var lbl_grade: Label
var lbl_center: Label
var results_panel: Control
var lbl_results: Label
var shoot_btn: Button


func _ready() -> void:
	_build_court()
	_build_player()
	_build_hud()
	_enter_ready()


# ---------- build ----------
func _build_court() -> void:
	var cam := Camera2D.new()
	cam.position = SCREEN * 0.5
	add_child(cam)
	cam.make_current()

	var tex := load("res://assets/court_street.png") as Texture2D
	var bg := Sprite2D.new()
	bg.texture = tex
	bg.centered = true
	bg.position = SCREEN * 0.5
	if tex:
		# cover-fit: fill the screen, crop overflow (framing is tunable later)
		var s := maxf(SCREEN.x / tex.get_width(), SCREEN.y / tex.get_height())
		bg.scale = Vector2(s, s)
	bg.z_index = -10
	add_child(bg)

	# rim marker (debug dot; real hoop is in the art)
	var rim := Node2D.new()
	rim.position = RIM
	add_child(rim)


func _build_player() -> void:
	player = PlayerAvatar.new()
	player.bounds = PLAY_BOUNDS
	player.position = Vector2(PLAY_BOUNDS.position.x + PLAY_BOUNDS.size.x * 0.5, PLAY_BOUNDS.end.y - 60)
	player.z_index = 5
	add_child(player)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	lbl_score = _mk_label(hud, "0", 100, Vector2(0, 70), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_timer = _mk_label(hud, "60", 64, Vector2(-40, 60), 1000, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_streak = _mk_label(hud, "", 44, Vector2(40, 60), 600, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_misses = _mk_label(hud, "", 44, Vector2(40, 130), 600, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_grade = _mk_label(hud, "", 72, Vector2(0, 380), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_grade.modulate.a = 0.0
	lbl_center = _mk_label(hud, "", 70, Vector2(0, 900), 1080, HORIZONTAL_ALIGNMENT_CENTER)

	stick = DribbleStick.new()
	stick.size = Vector2(STICK_RADIUS * 2.0, STICK_RADIUS * 2.0)
	stick.position = STICK_CENTER - Vector2(STICK_RADIUS, STICK_RADIUS)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE   # court owns the touch input
	hud.add_child(stick)

	meter = ShotMeter.new()
	meter.position = Vector2(140, 1600)
	meter.size = Vector2(800, 120)
	meter.active = false
	hud.add_child(meter)

	shoot_btn = Button.new()
	shoot_btn.text = "SHOOT"
	shoot_btn.add_theme_font_size_override("font_size", 56)
	shoot_btn.position = Vector2(660, 1730)
	shoot_btn.size = Vector2(360, 150)
	shoot_btn.button_down.connect(_on_shoot_down)
	shoot_btn.button_up.connect(_on_shoot_up)
	hud.add_child(shoot_btn)

	# results panel
	results_panel = Control.new()
	results_panel.position = Vector2.ZERO
	results_panel.size = SCREEN
	results_panel.visible = false
	hud.add_child(results_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.size = SCREEN
	results_panel.add_child(dim)
	lbl_results = _mk_label(results_panel, "", 60, Vector2(0, 500), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.add_theme_font_size_override("font_size", 60)
	again.position = Vector2(290, 1300)
	again.size = Vector2(500, 160)
	again.pressed.connect(_start_game)
	results_panel.add_child(again)


func _mk_label(parent: Node, txt: String, fs: int, pos: Vector2, width: float, align: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fs)
	l.position = pos
	l.size = Vector2(width, fs + 20)
	l.horizontal_alignment = align
	parent.add_child(l)
	return l


# ---------- state flow ----------
func _enter_ready() -> void:
	state = "ready"
	lbl_center.text = "TAP TO START"
	results_panel.visible = false
	meter.active = false


func _start_game() -> void:
	score = 0; makes = 0; misses = 0; streak = 0; coins_earned = 0
	time_left = ROUND_TIME
	state = "playing"
	lbl_center.text = ""
	results_panel.visible = false
	_refresh_hud()


func _end_game() -> void:
	state = "results"
	meter.active = false
	player.state = "idle"
	# rewards
	var lvl: int = int(SaveManager.data.get("level", 1))
	var bonus := ShotMath.round_bonus(makes, GameManager.coin_mult(0))
	coins_earned += bonus
	var xp_earned := makes * 12 + score * 2
	SaveManager.data["coins"] = int(SaveManager.data.get("coins", 0)) + coins_earned
	SaveManager.data["best_score"] = maxi(int(SaveManager.data.get("best_score", 0)), score)
	_award_xp(xp_earned)
	SaveManager.save_game()
	# panel
	lbl_results.text = "TIME!\n\nScore  %d\nMakes  %d\nBest  %d\n\n+%d coins\n+%d XP\nLevel %d" % [
		score, makes, int(SaveManager.data.get("best_score", 0)),
		coins_earned, xp_earned, int(SaveManager.data.get("level", 1))
	]
	results_panel.visible = true


func _award_xp(amount: int) -> void:
	var lvl: int = int(SaveManager.data.get("level", 1))
	var xp: int = int(SaveManager.data.get("xp", 0)) + amount
	while xp >= GameManager.xp_to_next(lvl):
		xp -= GameManager.xp_to_next(lvl)
		lvl += 1
	SaveManager.data["level"] = lvl
	SaveManager.data["xp"] = xp


# ---------- loop ----------
func _process(delta: float) -> void:
	_flick_cd = maxf(_flick_cd - delta, 0.0)
	if state == "playing":
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_end_game()
		lbl_timer.text = str(int(ceil(time_left)))
	elif state == "shooting":
		charge = minf(charge + CHARGE_RATE * delta, 1.0)
		meter_time += delta
		meter.t = absf(fmod(meter_time * METER_SPEED, 2.0) - 1.0)   # triangle 0..1
		meter.charge = charge
		var power := charge > POWER_THRESHOLD
		meter.sweet = ShotMath.sweet_spot(cur_zone, power)
		meter.queue_redraw()


# ---------- shooting ----------
func _on_shoot_down() -> void:
	if state != "playing":
		if state == "ready":
			_start_game()
		return
	state = "shooting"
	charge = 0.0
	meter_time = 0.0
	player.state = "shoot"
	_release_stick()
	# zone from current distance to rim
	var dist := player.position.distance_to(RIM)
	cur_zone = ShotMath.zone_for_distance(dist, COURT_LEN)
	meter.active = true
	meter.sweet = ShotMath.sweet_spot(cur_zone, false)


func _on_shoot_up() -> void:
	if state != "shooting":
		return
	var power := charge > POWER_THRESHOLD
	var accuracy := absf(meter.t - 0.5)
	var side := meter.t - 0.5
	var sweet := ShotMath.sweet_spot(cur_zone, power)
	var res := ShotMath.resolve(cur_zone, accuracy, sweet, side)
	meter.active = false
	player.state = "idle"
	state = "playing"
	_apply_shot(res, power)


func _apply_shot(res: Dictionary, power: bool) -> void:
	_fly_ball(res.made)
	if res.made:
		makes += 1
		streak += 1
		var on_fire := streak >= 3
		var pts: int = res.points
		if on_fire:
			pts *= 2
		score += pts
		coins_earned += ShotMath.make_reward(int(SaveManager.data.get("level", 1)), GameManager.coin_mult(0), res.points, power, on_fire)
		_popup_grade("%s  %s!" % [res.zone_name, res.grade], Color(0.4, 1, 0.5))
	else:
		misses += 1
		streak = 0
		_popup_grade(res.grade, Color(1, 0.5, 0.45))
		if misses >= MAX_MISSES:
			_end_game()
	_refresh_hud()


func _fly_ball(made: bool) -> void:
	ball_active = true
	ball_pos = player.position + Vector2(0, -80)
	var target := RIM if made else RIM + Vector2(randf_range(-90, 90), 40)
	var tw := create_tween()
	tw.tween_method(_set_ball_pos, ball_pos, target, 0.42).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_ball_done)

func _set_ball_pos(p: Vector2) -> void:
	ball_pos = p
	queue_redraw()

func _ball_done() -> void:
	ball_active = false
	queue_redraw()


func _popup_grade(txt: String, col: Color) -> void:
	lbl_grade.text = txt
	lbl_grade.modulate = col
	lbl_grade.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(lbl_grade, "modulate:a", 0.0, 0.5)


func _refresh_hud() -> void:
	lbl_score.text = str(score)
	lbl_streak.text = ("🔥 x%d" % streak) if streak >= 3 else (("x%d" % streak) if streak > 0 else "")
	lbl_misses.text = "✗".repeat(misses)


# ---------- draw (ball) ----------
func _draw() -> void:
	if ball_active:
		draw_circle(ball_pos, 22, Color(0.95, 0.5, 0.2))
		draw_arc(ball_pos, 22, 0, TAU, 24, Color(0.2, 0.1, 0.05), 3.0)


# ---------- dribble stick input ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if state == "ready":
				_start_game()
				return
			# grab the stick only if the touch lands on/near it (leaves the rest of the
			# screen free for the SHOOT button + multitouch)
			if state == "playing" and not joy_active and t.position.distance_to(STICK_CENTER) <= STICK_ACTIVATE_R:
				joy_active = true
				joy_index = t.index
				_update_stick(t.position)
		elif t.index == joy_index:
			_release_stick()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if joy_active and d.index == joy_index and player:
			_update_stick(d.position)
			# fast outward flick = NBA-Live dribble move (a quick size-up burst)
			if _flick_cd <= 0.0 and d.velocity.length() >= FLICK_SPEED:
				player.dribble_burst(d.velocity.normalized())
				_flick_cd = FLICK_COOLDOWN


func _update_stick(touch_pos: Vector2) -> void:
	var off: Vector2 = touch_pos - STICK_CENTER
	if off.length() > STICK_RADIUS:
		off = off.normalized() * STICK_RADIUS
	if player:
		player.move_dir = off / STICK_RADIUS
	stick.knob = off
	stick.active = true
	stick.queue_redraw()


func _release_stick() -> void:
	joy_active = false
	joy_index = -1
	if player:
		player.move_dir = Vector2.ZERO
	if stick:
		stick.knob = Vector2.ZERO
		stick.active = false
		stick.queue_redraw()

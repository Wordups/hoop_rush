extends Node3D
class_name Court3D
## The 3D street-court Score Attack (2.5D: real 3D court, billboard sprite player).
## ONE analog stick, bottom-center, does everything (NBA Live dribble-stick grammar):
##   push up/diagonals  -> analog move (up attacks the basket)
##   fast flick         -> dribble-move burst (size-up) in that direction
##   quick tap DOWN     -> step-back (space-maker; widens the next shot's sweet spot)
##   pull DOWN + hold   -> shot charge: meter appears, pull depth = power, release fires
## Scoring/zones/rewards reuse ShotMath + SaveManager/GameManager (same loop as 2D).

# ---- court dims (metres); hoop end is -Z ----
const COURT_W := 15.0
const COURT_D := 15.0
const RIM_H := 3.05
const RIM_POS := Vector3(0, RIM_H, -6.9)            # ball target (rim center)
const PLAY_X := 6.6                                  # |x| bound
const PLAY_Z_MIN := -5.6                             # closest to hoop
const PLAY_Z_MAX := 6.8                              # far end (half-court line)
const COURT_LEN_M := 13.5                            # zone normalization (rim -> far baseline)

# ---- movement ----
const MOVE_SPEED := 5.4                              # m/s at full stick
const BURST_SPEED := 12.5                            # dribble-move burst m/s
const BURST_DUR := 0.22
const FLICK_SPEED := 2400.0                          # px/s stick velocity = flick
const FLICK_COOLDOWN := 0.32

# ---- one-stick shot grammar ----
const STICK_CENTER := Vector2(540, 1560)
const STICK_RADIUS := 120.0                          # keep == DribbleStick.RADIUS
const STICK_ACTIVATE_R := 260.0
const DOWN_CONE_DEG := 42.0                          # within this of straight down = shot territory
const DOWN_MAG := 0.55                               # min pull to count
const CHARGE_HOLD := 0.18                            # held-down time that flips tap->charge
const POWER_PULL := 0.92                             # pull depth at release >= this = power shot
const STEPBACK_WINDOW := 1.2                         # s after step-back that the shot bonus lasts
const STEPBACK_SPEED := 10.0
const METER_SPEED := 1.65

# ---- round rules (same as 2D) ----
const ROUND_TIME := 60.0
const MAX_MISSES := 3

# ---- state ----
var state: String = "ready"                          # ready | playing | charging | results
var time_left: float = ROUND_TIME
var score: int = 0
var makes: int = 0
var misses: int = 0
var streak: int = 0
var coins_earned: int = 0

# stick
var joy_active: bool = false
var joy_index: int = -1
var _move_dir: Vector2 = Vector2.ZERO                # stick-space, y+ = down-screen
var _down_since: float = -1.0                        # when the knob entered the down cone
var _flick_cd: float = 0.0
var _stepback_until: float = -10.0

# shot-in-progress
var meter_time: float = 0.0
var pull_depth: float = 0.0
var cur_zone: int = ShotMath.Zone.MID
var _was_stepback: bool = false

# player (fully 3D, KayKit placeholder rig — swap mesh for the #23 later, keep the rig contract)
var player: Node3D
var anim: AnimationPlayer
var _cur_anim: String = ""
var facing_vec: Vector2 = Vector2(0, -1)             # court-space (x, z); (0,-1) faces the hoop
var _burst_t: float = 0.0
var _burst_dir: Vector2 = Vector2.ZERO
var _move_mag: float = 0.0

# ball
var ball: MeshInstance3D

# HUD
var stick: DribbleStick
var meter: ShotMeter
var lbl_score: Label
var lbl_timer: Label
var lbl_streak: Label
var lbl_misses: Label
var lbl_grade: Label
var lbl_center: Label
var results_panel: Control
var lbl_results: Label


func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_backdrop()
	_build_hoop()
	_build_player()
	_build_ball()
	_build_camera()
	_build_hud()
	_enter_ready()
	if "--shot" in OS.get_cmdline_user_args():
		_capture_and_quit()


## dev-only: render a few frames then save a screenshot to user:// and quit.
func _capture_and_quit() -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot.png")
	get_tree().quit()


# ---------- build ----------
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.35, 0.28, 0.5)
	mat.sky_horizon_color = Color(0.9, 0.5, 0.35)
	mat.ground_horizon_color = Color(0.2, 0.16, 0.2)
	mat.ground_bottom_color = Color(0.08, 0.07, 0.1)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -46, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.85, 0.7)
	sun.shadow_enabled = true
	add_child(sun)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(COURT_W, COURT_D)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/court_3d_floor.png") as Texture2D
	mat.roughness = 0.75
	mi.material_override = mat
	add_child(mi)


## distant dusk-city wall (hoop-free skyline stitched from the hero art)
func _build_backdrop() -> void:
	var tex := load("res://assets/backdrop_city.png") as Texture2D
	var H := 7.2
	var aspect := float(tex.get_width()) / float(tex.get_height())
	var quad := QuadMesh.new()
	quad.size = Vector2(H * aspect, H)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = Vector3(0, H * 0.5 - 0.15, (COURT_D * -0.5) - 1.4)
	add_child(mi)


## the real hoop from the hero art, alpha-cut, at true scale + a 3D pole
func _build_hoop() -> void:
	var tex := load("res://assets/hoop.png") as Texture2D
	var hoop := Sprite3D.new()
	hoop.texture = tex
	hoop.shaded = false
	# board is ~150px of the 164px crop; regulation board = 1.83 m wide
	var px_size := 1.83 / 150.0
	hoop.pixel_size = px_size
	# rim circle sits ~100px down the 126px crop; place so the rim lands at RIM_H
	var rim_off_px := 100.0 - 126.0 * 0.5           # rim offset below texture center
	hoop.position = Vector3(0, RIM_H + rim_off_px * px_size, RIM_POS.z - 0.25)
	add_child(hoop)

	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07; pm.bottom_radius = 0.1; pm.height = RIM_H + 0.6
	pole.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.13, 0.13, 0.15)
	pole.material_override = pmat
	pole.position = Vector3(0, (RIM_H + 0.6) * 0.5, RIM_POS.z - 0.55)
	add_child(pole)


func _build_player() -> void:
	player = Node3D.new()
	player.position = Vector3(0, 0, 2.6)
	add_child(player)
	var scene := load("res://assets/models/player_placeholder.glb") as PackedScene
	var model := scene.instantiate() as Node3D
	player.add_child(model)
	# normalize to ~2m tall whatever the source units are
	var aabb := _combined_aabb(model)
	if aabb.size.y > 0.01:
		model.scale = Vector3.ONE * (2.0 / aabb.size.y)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play("Idle")


## play with cross-blend; loop locomotion, one-shot everything else
func _play(name: String, blend: float = 0.15) -> void:
	if anim == null or _cur_anim == name:
		return
	if not anim.has_animation(name):
		return
	_cur_anim = name
	anim.speed_scale = 1.0
	anim.play(name, blend)
	var a := anim.get_animation(name)
	if name in ["Idle", "Walking_A", "Running_A", "Running_Strafe_Left", "Running_Strafe_Right", "Jump_Idle"]:
		a.loop_mode = Animation.LOOP_LINEAR
	else:
		a.loop_mode = Animation.LOOP_NONE


func _build_ball() -> void:
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14; sm.height = 0.28
	ball.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.45, 0.15)
	mat.roughness = 0.5
	ball.material_override = mat
	ball.visible = false
	add_child(ball)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6.2, 9.4)
	cam.rotation_degrees = Vector3(-27, 0, 0)
	cam.fov = 55.0
	add_child(cam)
	cam.make_current()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	lbl_score = _mk_label(hud, "0", 100, Vector2(0, 70), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_timer = _mk_label(hud, "60", 64, Vector2(-40, 60), 1000, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_streak = _mk_label(hud, "", 44, Vector2(40, 60), 600, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_misses = _mk_label(hud, "", 44, Vector2(40, 130), 600, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_grade = _mk_label(hud, "", 72, Vector2(0, 380), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_grade.modulate.a = 0.0
	lbl_center = _mk_label(hud, "", 70, Vector2(0, 860), 1080, HORIZONTAL_ALIGNMENT_CENTER)

	stick = DribbleStick.new()
	stick.size = Vector2(STICK_RADIUS * 2.0, STICK_RADIUS * 2.0)
	stick.position = STICK_CENTER - Vector2(STICK_RADIUS, STICK_RADIUS)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stick)

	meter = ShotMeter.new()
	meter.position = Vector2(140, 1260)
	meter.size = Vector2(800, 120)
	meter.active = false
	hud.add_child(meter)

	results_panel = Control.new()
	results_panel.size = Vector2(1080, 1920)
	results_panel.visible = false
	hud.add_child(results_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.size = Vector2(1080, 1920)
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
	player.position = Vector3(0, player.position.y, 2.6)
	_refresh_hud()


func _end_game() -> void:
	state = "results"
	meter.active = false
	var bonus := ShotMath.round_bonus(makes, GameManager.coin_mult(0))
	coins_earned += bonus
	var xp_earned := makes * 12 + score * 2
	SaveManager.data["coins"] = int(SaveManager.data.get("coins", 0)) + coins_earned
	SaveManager.data["best_score"] = maxi(int(SaveManager.data.get("best_score", 0)), score)
	_award_xp(xp_earned)
	SaveManager.save_game()
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
			return
		lbl_timer.text = str(int(ceil(time_left)))
		_move_player(delta)
		# held pull-down long enough -> start the shot charge
		if _down_since >= 0.0 and _now() - _down_since >= CHARGE_HOLD:
			_begin_charge()
	elif state == "charging":
		meter_time += delta
		meter.t = absf(fmod(meter_time * METER_SPEED, 2.0) - 1.0)
		meter.charge = pull_depth
		meter.sweet = ShotMath.sweet_spot(cur_zone, pull_depth >= POWER_PULL, _was_stepback)
		meter.queue_redraw()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _move_player(delta: float) -> void:
	var pos := player.position
	_move_mag = 0.0
	if _burst_t > 0.0:
		_burst_t -= delta
		pos.x += _burst_dir.x * BURST_SPEED * delta
		pos.z += _burst_dir.y * BURST_SPEED * delta
		facing_vec = _burst_dir
	else:
		var mv := _move_dir
		# the down cone belongs to the shot grammar, not walking
		if _in_down_cone(mv):
			mv = Vector2.ZERO
		if mv.length() > 0.08:
			pos.x += mv.x * MOVE_SPEED * delta
			pos.z += mv.y * MOVE_SPEED * delta
			facing_vec = mv.normalized()
			_move_mag = clampf(mv.length(), 0.0, 1.0)
		elif state == "playing":
			facing_vec = Vector2(0, -1)      # rest facing the hoop
	pos.x = clampf(pos.x, -PLAY_X, PLAY_X)
	pos.z = clampf(pos.z, PLAY_Z_MIN, PLAY_Z_MAX)
	player.position = pos
	_update_anim()


const ONE_SHOTS := ["Throw", "Cheer", "Dodge_Forward", "Dodge_Backward", "Dodge_Left", "Dodge_Right"]

func _combined_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mi as MeshInstance3D).get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _update_anim() -> void:
	# face along facing_vec (court-space (x,z)); model front ends up toward -facing without the flip
	player.rotation.y = atan2(facing_vec.x, facing_vec.y)
	# let one-shots (dodges/throw/cheer) finish before locomotion takes back over
	if _cur_anim in ONE_SHOTS and anim and anim.is_playing():
		return
	if state == "charging":
		_play("Jump_Idle")
		return
	# locomotion: idle -> walk -> run by stick magnitude, speed-scaled inside the band
	if _move_mag < 0.08:
		_play("Idle")
	elif _move_mag < 0.62:
		_play("Walking_A")
		if anim:
			anim.speed_scale = 0.7 + _move_mag
	else:
		_play("Running_A")
		if anim:
			anim.speed_scale = 0.65 + _move_mag * 0.55


# ---------- one-stick input ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if state == "ready":
				_start_game()
				return
			if state in ["playing", "charging"] and not joy_active and t.position.distance_to(STICK_CENTER) <= STICK_ACTIVATE_R:
				joy_active = true
				joy_index = t.index
				_update_stick(t.position)
		elif t.index == joy_index:
			_on_stick_release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if joy_active and d.index == joy_index:
			_update_stick(d.position)
			# fast flick (not downward) = dribble-move burst
			if state == "playing" and _flick_cd <= 0.0 and d.velocity.length() >= FLICK_SPEED:
				var fdir := (d.velocity / d.velocity.length())
				if not _in_down_cone(fdir):
					_burst_dir = fdir
					_burst_t = BURST_DUR
					_flick_cd = FLICK_COOLDOWN
					_play(_dodge_for(fdir), 0.05)


func _update_stick(touch_pos: Vector2) -> void:
	var off := touch_pos - STICK_CENTER
	if off.length() > STICK_RADIUS:
		off = off.normalized() * STICK_RADIUS
	_move_dir = off / STICK_RADIUS
	stick.knob = off
	stick.active = true
	stick.queue_redraw()
	if state == "charging":
		pull_depth = maxf(pull_depth, _move_dir.length())
		return
	# down-cone tracking (tap -> step-back, hold -> charge)
	if _in_down_cone(_move_dir) and _move_dir.length() >= DOWN_MAG:
		if _down_since < 0.0:
			_down_since = _now()
	else:
		if _down_since >= 0.0 and _now() - _down_since < CHARGE_HOLD:
			_step_back()
		_down_since = -1.0


func _on_stick_release() -> void:
	joy_active = false
	joy_index = -1
	if state == "charging":
		_release_shot()
	elif _down_since >= 0.0 and _now() - _down_since < CHARGE_HOLD:
		_step_back()
	_down_since = -1.0
	_move_dir = Vector2.ZERO
	stick.knob = Vector2.ZERO
	stick.active = false
	stick.queue_redraw()


func _in_down_cone(v: Vector2) -> bool:
	if v.length() < 0.01:
		return false
	return absf(rad_to_deg(v.angle_to(Vector2.DOWN))) <= DOWN_CONE_DEG


# ---------- shot grammar ----------
## dodge anim matching a court-space burst direction (relative to the hoop, arcade-simple)
func _dodge_for(dir: Vector2) -> String:
	if dir.y < -0.45:
		return "Dodge_Forward"
	if dir.y > 0.45:
		return "Dodge_Backward"
	return "Dodge_Right" if dir.x > 0.0 else "Dodge_Left"


func _step_back() -> void:
	if state != "playing":
		return
	_burst_dir = Vector2(0, 1)                     # away from the hoop
	_burst_t = BURST_DUR
	_stepback_until = _now() + STEPBACK_WINDOW
	_flick_cd = FLICK_COOLDOWN
	_play("Dodge_Backward", 0.05)


func _begin_charge() -> void:
	state = "charging"
	_down_since = -1.0
	meter_time = 0.0
	pull_depth = _move_dir.length()
	_was_stepback = _now() <= _stepback_until
	var dist := Vector2(player.position.x - RIM_POS.x, player.position.z - RIM_POS.z).length()
	cur_zone = ShotMath.zone_for_distance(dist, COURT_LEN_M)
	meter.active = true
	meter.sweet = ShotMath.sweet_spot(cur_zone, false, _was_stepback)
	facing_vec = Vector2(0, -1)                    # square up to the hoop
	_update_anim()


func _release_shot() -> void:
	var power := pull_depth >= POWER_PULL
	var accuracy := absf(meter.t - 0.5)
	var side := meter.t - 0.5
	var sweet := ShotMath.sweet_spot(cur_zone, power, _was_stepback)
	var res := ShotMath.resolve(cur_zone, accuracy, sweet, side)
	meter.active = false
	state = "playing"
	_play("Throw", 0.05)
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
		var tag: String = res.zone_name
		if _was_stepback:
			tag = "STEP-BACK " + tag
		_popup_grade("%s  %s!" % [tag, res.grade], Color(0.4, 1, 0.5))
	else:
		misses += 1
		streak = 0
		_popup_grade(res.grade, Color(1, 0.5, 0.45))
		if misses >= MAX_MISSES:
			_end_game()
	_refresh_hud()


func _fly_ball(made: bool) -> void:
	ball.visible = true
	var start: Vector3 = player.position + Vector3(0, 1.2, 0)
	var target := RIM_POS if made else RIM_POS + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.3), randf_range(-0.2, 0.3))
	var arc := maxf(1.6, (RIM_POS.y - start.y) + 1.8)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		ball.position = start.lerp(target, t) + Vector3(0, arc * sin(PI * t), 0),
		0.0, 1.0, 0.55).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func() -> void:
		ball.visible = false
		if made and streak >= 3:
			_play("Cheer", 0.1))


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

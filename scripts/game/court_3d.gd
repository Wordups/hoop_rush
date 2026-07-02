extends Node3D
class_name Court3D
## The 3D street-court ladder game (2.5D: real 3D court, rigged GLB player).
## ONE analog stick, bottom-center, does everything (NBA Live dribble-stick grammar):
##   push up/diagonals  -> analog move (up attacks the basket)
##   fast flick         -> dribble-move burst (size-up) in that direction
##   quick tap DOWN     -> step-back (space-maker; widens the next shot's sweet spot)
##   pull DOWN + hold   -> shot charge: meter appears, pull depth = power, release fires
## Ladder + token economy (Royal-Match style, data/run_levels.json): first attempt free,
## retries cost tokens, clears award them; token packs bought with in-game coins only.
## Situational objectives: score targets, corner-threes, far-end spawns.

# ---- court dims (metres); hoop end is -Z ----
const COURT_W := 15.0
const COURT_D := 15.0
const RIM_H := 3.05
const RIM_POS := Vector3(0, RIM_H, -6.9)
const PLAY_X := 7.1                                  # full-court roam
const PLAY_Z_MIN := -6.4
const PLAY_Z_MAX := 7.1
const COURT_LEN_M := 13.5
const CORNER_X := 4.4                                # |x| beyond this AND z < CORNER_Z = corner
const CORNER_Z := -3.0

# ---- movement / grammar: tinker-able in the in-game TUNE panel, persisted to save ----
var MOVE_SPEED := 5.4
var BURST_SPEED := 12.5
const BURST_DUR := 0.22
var FLICK_SPEED := 2400.0
const FLICK_COOLDOWN := 0.32
const CHAR_HEIGHT := 2.6                             # big enough that moves read on phone

var STICK_CENTER := Vector2(540, 1620)
var STICK_RADIUS := 120.0
var DOWN_CONE_DEG := 42.0
const DOWN_MAG := 0.55
var CHARGE_HOLD := 0.18
const POWER_PULL := 0.92
const STEPBACK_WINDOW := 1.2
var METER_SPEED := 1.15
const SWEET_EASE := 1.35
var SHOOT_BUTTON := true                             # true: button shoots, stick is full-360 move
const BTN_CHARGE_RATE := 1.0 / 0.7                   # button mode: hold time -> power

## TUNE panel spec: [save_key, label, min, max, step]
const TUNABLES := [
	["move_speed", "MOVE SPEED", 3.0, 8.0, 0.1],
	["burst_speed", "BURST SPEED", 8.0, 18.0, 0.5],
	["flick_speed", "FLICK SENS (lower=easier)", 1200.0, 4000.0, 50.0],
	["down_cone", "SHOT CONE deg", 25.0, 60.0, 1.0],
	["charge_hold", "CHARGE HOLD s", 0.10, 0.35, 0.01],
	["meter_speed", "METER SPEED", 0.8, 1.8, 0.05],
	["stick_radius", "STICK SIZE", 90.0, 170.0, 5.0],
	["stick_y", "STICK HEIGHT", 1380.0, 1700.0, 10.0],
	["cam_height", "CAM HEIGHT", 4.2, 8.6, 0.1],
	["cam_dist", "CAM DISTANCE", 7.0, 13.0, 0.1],
	["cam_fov", "CAM FOV", 42.0, 62.0, 1.0],
]
const TUNE_DEFAULTS := {"move_speed": 5.4, "burst_speed": 12.5, "flick_speed": 2400.0,
	"down_cone": 42.0, "charge_hold": 0.18, "meter_speed": 1.15, "stick_radius": 120.0, "stick_y": 1620.0,
	"shoot_button": 1.0, "cam_height": 6.6, "cam_dist": 11.4, "cam_fov": 49.0}

func _tuning_get(k: String) -> float:
	var t: Dictionary = SaveManager.data.get("tuning", {})
	return float(t.get(k, float(TUNE_DEFAULTS[k])))

func _tuning_set(k: String, v: float) -> void:
	var t: Dictionary = SaveManager.data.get("tuning", {})
	t[k] = v
	SaveManager.data["tuning"] = t
	SaveManager.save_game()
	_apply_tuning()

func _apply_tuning() -> void:
	MOVE_SPEED = _tuning_get("move_speed")
	BURST_SPEED = _tuning_get("burst_speed")
	FLICK_SPEED = _tuning_get("flick_speed")
	DOWN_CONE_DEG = _tuning_get("down_cone")
	CHARGE_HOLD = _tuning_get("charge_hold")
	METER_SPEED = _tuning_get("meter_speed")
	STICK_RADIUS = _tuning_get("stick_radius")
	STICK_CENTER = Vector2(540, _tuning_get("stick_y"))
	SHOOT_BUTTON = _tuning_get("shoot_button") >= 0.5
	if btn_shoot:
		btn_shoot.visible = SHOOT_BUTTON
	CAM_BASE = Vector3(0, _tuning_get("cam_height"), _tuning_get("cam_dist"))
	if cam:
		cam.fov = _tuning_get("cam_fov")
	if stick:
		stick.radius = STICK_RADIUS
		stick.size = Vector2(STICK_RADIUS * 2.0, STICK_RADIUS * 2.0)
		stick.position = STICK_CENTER - Vector2(STICK_RADIUS, STICK_RADIUS)
		stick.queue_redraw()

func _stick_activate_r() -> float:
	return STICK_RADIUS * 2.2


## haptic buzz: native handhelds vibrate; web uses navigator.vibrate (Android — iOS Safari
## blocks the vibration API, so browser play on iPhone gets screen-shake feel instead;
## the native iOS export will buzz for real).
func _buzz(ms: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(%d)" % ms, true)
	else:
		Input.vibrate_handheld(ms)


var _shake_amp := 0.0

func _shake(amp: float) -> void:
	_shake_amp = maxf(_shake_amp, amp)

# ---- camera follow (height/dist/fov live in TUNE; pitch auto-aims) ----
var CAM_BASE := Vector3(0, 6.6, 11.4)
const CAM_AIM := Vector3(0, 2.5, -3.6)               # aim point: hoop upper third, player lower

# ---- ladder / economy (defs in data/run_levels.json) ----
var run_level: int = 1
var level_target: int = 8
var level_time: float = 45.0
var level_misses: int = 5
var level_boss: bool = false
var level_obj_type: String = "score"                 # score | corner_threes
var level_obj_count: int = 0
var level_spawn: String = "center"                   # center | far
var obj_progress: int = 0
var level_attempts: int = 0

# ---- state ----
var state: String = "ready"                          # ready | playing | charging | results
var time_left: float = 45.0
var score: int = 0
var makes: int = 0
var misses: int = 0
var streak: int = 0
var coins_earned: int = 0

# stick
var joy_active: bool = false
var joy_index: int = -1
var _move_dir: Vector2 = Vector2.ZERO
var _down_since: float = -1.0
var _flick_cd: float = 0.0
var _stepback_until: float = -10.0

# shot-in-progress
var meter_time: float = 0.0
var pull_depth: float = 0.0
var cur_zone: int = ShotMath.Zone.MID
var _was_stepback: bool = false
var _shot_from_corner: bool = false
var _armed: bool = true                              # corner drills: re-arm by touching the far end

# player
var player: Node3D
var model: Node3D
var anim: AnimationPlayer
var _cur_anim: String = ""
var facing_vec: Vector2 = Vector2(0, -1)
var _burst_t: float = 0.0
var _burst_dir: Vector2 = Vector2.ZERO
var _move_mag: float = 0.0

# ball
var ball: MeshInstance3D
var ball_mat: StandardMaterial3D
var _ball_flying: bool = false
var _dribble_t: float = 0.0
var _dribble_side: float = 1.0                       # 1 = right hand, -1 = left
var _move_kind: String = ""                          # cross | push | behind ('' = none)
var _side_from: float = 1.0

# camera
var cam: Camera3D

# audio
var music: AudioStreamPlayer
var sfx_swish: AudioStreamPlayer
var sfx_rim: AudioStreamPlayer
var sfx_clear: AudioStreamPlayer
var sfx_fail: AudioStreamPlayer

# HUD
var stick: DribbleStick
var meter: ShotMeter
var lbl_score: Label
var lbl_timer: Label
var lbl_streak: Label
var lbl_misses: Label
var lbl_grade: Label
var cap_level: Label
var lbl_coins: Label
var lbl_tokens: Label
var _flash_rect: ColorRect
# cards / popups
var level_card: Control
var lbl_card_title: Label
var lbl_card_obj: Label
var lbl_card_ticket: Label
var fail_card: Control
var lbl_fail: Label
var btn_retry: Button
var win_card: Control
var lbl_win: Label
var pack_card: Control
var lbl_pack: Label
var btn_pack_get: Button
var style_card: Control
var tune_card: Control
var btn_shoot: Button

const JERSEY_COLORS: Array[Color] = [Color(1, 1, 1), Color(0.55, 0.65, 1.4), Color(1.3, 0.6, 0.6), Color(0.65, 1.35, 0.75)]
const JERSEY_NAMES := ["CLASSIC", "ICE", "HEAT", "LUCKY"]
const BALL_COLORS: Array[Color] = [Color(0.9, 0.45, 0.15), Color(0.85, 0.2, 0.2), Color(0.5, 0.3, 0.9), Color(0.95, 0.85, 0.3)]
const BALL_NAMES := ["STREET", "CRIMSON", "GALAXY", "GOLD"]


func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_backdrop()
	_build_hoop()
	_build_player()
	_build_ball()
	_build_camera()
	_build_hud()
	_build_audio()
	_apply_appearance()
	_apply_tuning()
	_enter_ready()
	if "--shot" in OS.get_cmdline_user_args():
		if "--play" in OS.get_cmdline_user_args():
			_start_attempt()
		_capture_and_quit()


## dev-only screenshot hook (`-- --shot`)
func _capture_and_quit() -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot.png")
	get_tree().quit()


# ---------- economy helpers ----------
func _eco() -> Dictionary:
	return DataManager.run_levels.get("economy", {}) if DataManager.run_levels is Dictionary else {}

func tokens() -> int:
	return int(SaveManager.data.get("tokens", int(_eco().get("start_tokens", 5))))

func set_tokens(v: int) -> void:
	SaveManager.data["tokens"] = maxi(v, 0)

func coins() -> int:
	return int(SaveManager.data.get("coins", 0))

func set_coins(v: int) -> void:
	SaveManager.data["coins"] = maxi(v, 0)


# ---------- build ----------
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.45, 0.22, 0.38)
	mat.sky_horizon_color = Color(0.98, 0.55, 0.3)
	mat.ground_horizon_color = Color(0.2, 0.16, 0.2)
	mat.ground_bottom_color = Color(0.08, 0.07, 0.1)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.5, 0.42)   # sunset bounce fill
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# grade: warmer, richer, one palette with the painting
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.03
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.18
	# low warm haze so the floor dissolves into the backdrop instead of butting against it
	env.fog_enabled = true
	env.fog_light_color = Color(0.93, 0.55, 0.38)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)

	# sun matched to the painted backdrop: low, upper-center, shadows raking toward camera
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-33, 180, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.69, 0.4)      # ~#ffb066
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38, 0, 0)
	fill.light_energy = 0.5
	fill.light_color = Color(1.0, 0.75, 0.6)
	fill.shadow_enabled = false
	add_child(fill)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(COURT_W, COURT_D)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/court_3d_floor.png") as Texture2D
	mat.albedo_color = Color(1.06, 0.98, 0.9)   # slight warm cast on top of the repaint
	mat.roughness = 0.72
	mi.material_override = mat
	add_child(mi)


func _build_backdrop() -> void:
	var tex := load("res://assets/backdrop_city.png") as Texture2D
	var H := 9.8
	var aspect := float(tex.get_width()) / float(tex.get_height())
	var quad := QuadMesh.new()
	quad.size = Vector2(H * aspect, H)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	mi.material_override = mat
	mi.position = Vector3(0, H * 0.5 - 0.15, (COURT_D * -0.5) - 1.4)
	add_child(mi)

	# soft painted haze strip along the far court edge (seam blend)
	var hz := QuadMesh.new()
	hz.size = Vector2(COURT_W + 4.0, 2.4)
	var hmi := MeshInstance3D.new()
	hmi.mesh = hz
	var hmat := StandardMaterial3D.new()
	hmat.albedo_texture = load("res://assets/fx/haze_strip.png") as Texture2D
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	hmat.disable_fog = true
	hmi.material_override = hmat
	hmi.rotation_degrees = Vector3(12, 0, 0)
	hmi.position = Vector3(0, 1.05, (COURT_D * -0.5) + 0.35)
	add_child(hmi)


func _build_hoop() -> void:
	var tex := load("res://assets/hoop.png") as Texture2D
	var hoop := Sprite3D.new()
	hoop.texture = tex
	hoop.shaded = false
	var px_size := 1.83 / 150.0
	hoop.pixel_size = px_size
	var rim_off_px := 100.0 - 126.0 * 0.5
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
	player.position = Vector3(0, 0, 1.4)
	add_child(player)
	var scene := load("res://assets/models/player_placeholder.glb") as PackedScene
	model = scene.instantiate() as Node3D
	player.add_child(model)
	var aabb := _combined_aabb(model)
	if aabb.size.y > 0.01:
		model.scale = Vector3.ONE * (CHAR_HEIGHT / aabb.size.y)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play("Idle")


func _combined_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mi as MeshInstance3D).get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _build_ball() -> void:
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.165; sm.height = 0.33
	ball.mesh = sm
	ball_mat = StandardMaterial3D.new()
	ball_mat.albedo_color = BALL_COLORS[0]
	ball_mat.roughness = 0.5
	ball.material_override = ball_mat
	ball.visible = false
	add_child(ball)


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.position = CAM_BASE
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	cam.look_at_from_position(CAM_BASE, CAM_AIM)


func _build_audio() -> void:
	music = _mk_audio("res://assets/audio/music_loop.wav", -11.0)
	music.finished.connect(music.play)
	music.play()
	sfx_swish = _mk_audio("res://assets/audio/sfx_swish.wav", -3.0)
	sfx_rim = _mk_audio("res://assets/audio/sfx_rim.wav", -5.0)
	sfx_clear = _mk_audio("res://assets/audio/sfx_clear.wav", -3.0)
	sfx_fail = _mk_audio("res://assets/audio/sfx_fail.wav", -5.0)


func _mk_audio(path: String, db: float) -> AudioStreamPlayer:
	var pl := AudioStreamPlayer.new()
	pl.stream = load(path)
	pl.volume_db = db
	add_child(pl)
	return pl


# ---------- HUD ----------
func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	# top-left: coins pill + [+]
	var coin_pill := _mk_pill(hud, Vector2(30, 40), Vector2(330, 92))
	_mk_icon(coin_pill, "res://assets/ui/interim/icon_coin.png", Vector2(12, 12), Vector2(68, 68))
	lbl_coins = _mk_label(coin_pill, "0", 44, Vector2(88, 18), 160, HORIZONTAL_ALIGNMENT_LEFT)
	var plus := Button.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 52)
	_style_btn(plus, Color(0.2, 0.55, 0.95))
	plus.position = Vector2(248, 10)
	plus.size = Vector2(72, 72)
	plus.pressed.connect(_open_pack)
	coin_pill.add_child(plus)

	# top-right: tokens pill
	var tok_pill := _mk_pill(hud, Vector2(770, 40), Vector2(280, 92))
	# TEMP art: poker-chip slice, tagged for replacement (Design Bible: no casino visuals)
	_mk_icon(tok_pill, "res://assets/ui/interim/icon_token_TEMP_REPLACE.png", Vector2(12, 12), Vector2(68, 68))
	lbl_tokens = _mk_label(tok_pill, "5", 44, Vector2(88, 18), 160, HORIZONTAL_ALIGNMENT_LEFT)

	# top-center scoreboard
	var board := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.85)
	sb.border_color = Color(0.95, 0.34, 0.29)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	board.add_theme_stylebox_override("panel", sb)
	board.position = Vector2(350, 150)
	board.size = Vector2(380, 140)
	hud.add_child(board)
	cap_level = _mk_label(board, "LVL 1", 26, Vector2(28, 12), 150, HORIZONTAL_ALIGNMENT_LEFT)
	cap_level.modulate = Color(1, 1, 1, 0.55)
	lbl_score = _mk_label(board, "0/8", 50, Vector2(28, 48), 170, HORIZONTAL_ALIGNMENT_LEFT)
	var divider := ColorRect.new()
	divider.color = Color(1, 1, 1, 0.18)
	divider.position = Vector2(206, 22)
	divider.size = Vector2(3, 96)
	board.add_child(divider)
	var cap_time := _mk_label(board, "TIME", 26, Vector2(225, 12), 125, HORIZONTAL_ALIGNMENT_RIGHT)
	cap_time.modulate = Color(1, 1, 1, 0.55)
	lbl_timer = _mk_label(board, "45", 50, Vector2(225, 48), 125, HORIZONTAL_ALIGNMENT_RIGHT)

	lbl_streak = _mk_label(hud, "", 44, Vector2(40, 170), 600, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_misses = _mk_label(hud, "", 44, Vector2(40, 236), 600, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_grade = _mk_label(hud, "", 72, Vector2(0, 380), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_grade.modulate.a = 0.0

	stick = DribbleStick.new()
	stick.size = Vector2(STICK_RADIUS * 2.0, STICK_RADIUS * 2.0)
	stick.position = STICK_CENTER - Vector2(STICK_RADIUS, STICK_RADIUS)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stick)

	# round SHOOT button, bottom-right (button mode)
	btn_shoot = Button.new()
	btn_shoot.text = "SHOOT"
	btn_shoot.add_theme_font_size_override("font_size", 44)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.85, 0.25, 0.2, 0.9)
	ssb.set_corner_radius_all(110)
	btn_shoot.add_theme_stylebox_override("normal", ssb)
	var ssb2 := ssb.duplicate()
	ssb2.bg_color = Color(1.0, 0.4, 0.3, 0.95)
	btn_shoot.add_theme_stylebox_override("pressed", ssb2)
	btn_shoot.add_theme_stylebox_override("hover", ssb2)
	btn_shoot.position = Vector2(800, 1470)
	btn_shoot.size = Vector2(220, 220)
	btn_shoot.button_down.connect(_on_shoot_btn_down)
	btn_shoot.button_up.connect(_on_shoot_btn_up)
	hud.add_child(btn_shoot)

	meter = ShotMeter.new()
	meter.position = Vector2(390, 1300)
	meter.size = Vector2(300, 64)
	meter.active = false
	hud.add_child(meter)

	_flash_rect = ColorRect.new()
	_flash_rect.size = Vector2(1080, 1920)
	_flash_rect.visible = false
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_flash_rect)

	# ---- level card (Royal-Match style) ----
	level_card = _mk_card(hud)
	_mk_icon(level_card, "res://assets/ui/interim/ui_logo_lockup.png", Vector2(360, 300), Vector2(360, 250))
	lbl_card_title = _mk_label(level_card, "LEVEL 1", 92, Vector2(0, 580), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_card_obj = _mk_label(level_card, "", 52, Vector2(0, 730), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	var play := _mk_card_btn(level_card, "PLAY", Color(0.86, 0.55, 0.12), Vector2(290, 1080), Vector2(500, 150), 64)
	play.pressed.connect(_on_play_pressed)
	# primary CTA breathes (Design Bible: menus breathe)
	play.pivot_offset = play.size * 0.5
	var breathe := create_tween().set_loops()
	breathe.tween_property(play, "scale", Vector2.ONE * 1.018, 1.5).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(play, "scale", Vector2.ONE, 1.5).set_trans(Tween.TRANS_SINE)
	var style := _mk_card_btn(level_card, "STYLE", Color(0.55, 0.35, 0.9), Vector2(150, 1280), Vector2(370, 150))
	style.pressed.connect(_open_style)
	var tune := _mk_card_btn(level_card, "TUNE", Color(0.13, 0.52, 0.48), Vector2(560, 1280), Vector2(370, 150))
	tune.pressed.connect(_open_tune)
	lbl_card_ticket = _mk_label(level_card, "", 40, Vector2(0, 1480), 1080, HORIZONTAL_ALIGNMENT_CENTER)

	# ---- fail card ----
	fail_card = _mk_card(hud)
	lbl_fail = _mk_label(fail_card, "", 56, Vector2(0, 560), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	btn_retry = _mk_card_btn(fail_card, "RETRY (1 TOKEN)", Color(0.85, 0.25, 0.2), Vector2(290, 1080))
	btn_retry.pressed.connect(_on_retry_pressed)
	var giveup := _mk_card_btn(fail_card, "BACK", Color(0.35, 0.35, 0.42), Vector2(290, 1280))
	giveup.pressed.connect(func() -> void: _enter_ready())

	# ---- win card ----
	win_card = _mk_card(hud)
	lbl_win = _mk_label(win_card, "", 56, Vector2(0, 540), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	var nxt := _mk_card_btn(win_card, "NEXT LEVEL", Color(0.25, 0.75, 0.3), Vector2(290, 1180))
	nxt.pressed.connect(func() -> void: _enter_ready())

	# ---- token pack popup ----
	pack_card = _mk_card(hud)
	lbl_pack = _mk_label(pack_card, "", 52, Vector2(0, 620), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	btn_pack_get = _mk_card_btn(pack_card, "GET PACK", Color(0.25, 0.75, 0.3), Vector2(290, 1080))
	btn_pack_get.pressed.connect(_buy_pack)
	var pclose := _mk_card_btn(pack_card, "CLOSE", Color(0.35, 0.35, 0.42), Vector2(290, 1280))
	pclose.pressed.connect(func() -> void:
		pack_card.visible = false
		_enter_ready())

	# ---- style card ----
	style_card = _mk_card(hud)
	_mk_label(style_card, "YOUR STYLE", 72, Vector2(0, 480), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	var jl := _mk_label(style_card, "JERSEY TINT", 40, Vector2(0, 640), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	jl.modulate = Color(1, 1, 1, 0.6)
	for i in range(JERSEY_COLORS.size()):
		var b := _mk_card_btn(style_card, JERSEY_NAMES[i], JERSEY_COLORS[i] * 0.55, Vector2(80 + i * 240, 720), Vector2(220, 110), 36)
		b.pressed.connect(_pick_jersey.bind(i))
	var bl := _mk_label(style_card, "BALL", 40, Vector2(0, 920), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	bl.modulate = Color(1, 1, 1, 0.6)
	for i in range(BALL_COLORS.size()):
		var b2 := _mk_card_btn(style_card, BALL_NAMES[i], BALL_COLORS[i] * 0.7, Vector2(80 + i * 240, 1000), Vector2(220, 110), 36)
		b2.pressed.connect(_pick_ball.bind(i))
	var done := _mk_card_btn(style_card, "DONE", Color(0.25, 0.75, 0.3), Vector2(290, 1280))
	done.pressed.connect(func() -> void: _enter_ready())

	# ---- tune card (live analog tinkering, persisted) ----
	tune_card = _mk_card(hud)
	_mk_label(tune_card, "TUNE THE FEEL", 64, Vector2(0, 450), 1080, HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(TUNABLES.size()):
		var spec: Array = TUNABLES[i]
		var y := 560 + i * 92
		var lab := _mk_label(tune_card, str(spec[1]), 30, Vector2(90, y), 520, HORIZONTAL_ALIGNMENT_LEFT)
		lab.modulate = Color(1, 1, 1, 0.75)
		var val := _mk_label(tune_card, "", 30, Vector2(840, y), 150, HORIZONTAL_ALIGNMENT_RIGHT)
		var sl := HSlider.new()
		sl.min_value = float(spec[2])
		sl.max_value = float(spec[3])
		sl.step = float(spec[4])
		sl.value = _tuning_get(str(spec[0]))
		sl.position = Vector2(90, y + 42)
		sl.size = Vector2(900, 40)
		val.text = str(sl.value)
		var key := str(spec[0])
		var stp := float(spec[4])
		sl.value_changed.connect(func(v: float) -> void:
			val.text = str(snappedf(v, stp))
			_tuning_set(key, v))
		tune_card.add_child(sl)
	var tmode := _mk_card_btn(tune_card, "", Color(0.2, 0.55, 0.95), Vector2(120, 1330 - 130), Vector2(760, 100), 38)
	var upd_mode := func() -> void:
		tmode.text = "SHOT: BUTTON  (stick = 360 move)" if SHOOT_BUTTON else "SHOT: STICK PULL-DOWN"
	upd_mode.call()
	tmode.pressed.connect(func() -> void:
		_tuning_set("shoot_button", 0.0 if SHOOT_BUTTON else 1.0)
		upd_mode.call())
	var treset := _mk_card_btn(tune_card, "RESET", Color(0.35, 0.35, 0.42), Vector2(120, 1350), Vector2(320, 120), 44)
	treset.pressed.connect(func() -> void:
		SaveManager.data["tuning"] = {}
		SaveManager.save_game()
		_apply_tuning())
	var tdone := _mk_card_btn(tune_card, "DONE", Color(0.25, 0.75, 0.3), Vector2(560, 1350), Vector2(320, 120), 44)
	tdone.pressed.connect(func() -> void: _enter_ready())


func _mk_pill(parent: Node, pos: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.8)
	sb.set_corner_radius_all(46)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = sz
	parent.add_child(p)
	return p


func _mk_dot(parent: Node, col: Color, pos: Vector2, r: float) -> Panel:
	var d := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	d.add_theme_stylebox_override("panel", sb)
	d.position = pos - Vector2(r, r) * 0.5 - Vector2(8, 0)
	d.size = Vector2(r * 2, r * 2) * 0.9
	parent.add_child(d)
	return d


func _mk_card(hud: CanvasLayer) -> Control:
	var c := Control.new()
	c.size = Vector2(1080, 1920)
	c.visible = false
	hud.add_child(c)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.05, 0.86)
	dim.size = Vector2(1080, 1920)
	c.add_child(dim)
	var card := Panel.new()
	# painted concrete panel from the sliced kit (tiled so the interim res stays crisp);
	# flat fallback if the slice is missing
	if ResourceLoader.exists("res://assets/ui/interim/ui_panel_dark.png"):
		var sbt := StyleBoxTexture.new()
		sbt.texture = load("res://assets/ui/interim/ui_panel_dark.png")
		sbt.set_texture_margin_all(22.0)
		sbt.modulate_color = Color(1.06, 1.02, 0.98)
		card.add_theme_stylebox_override("panel", sbt)
	else:
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.07, 0.07, 0.11, 0.98)
		csb.border_color = Color(0.95, 0.34, 0.29)
		csb.set_border_width_all(5)
		csb.set_corner_radius_all(26)
		card.add_theme_stylebox_override("panel", csb)
	card.position = Vector2(60, 420)
	card.size = Vector2(960, 1120)
	c.add_child(card)
	return c


func _mk_card_btn(parent: Control, txt: String, col: Color, pos: Vector2, sz: Vector2 = Vector2(500, 150), fs: int = 56) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", fs)
	_style_btn(b, col)
	b.position = pos
	b.size = sz
	b.pivot_offset = sz * 0.5
	b.button_down.connect(func() -> void:
		AudioManager.play("button_press")
		b.scale = Vector2.ONE * 1.08
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	parent.add_child(b)
	return b


func _style_btn(b: Button, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(20)
	b.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate()
	sb2.bg_color = col.lightened(0.2)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("hover", sb2)


func _mk_icon(parent: Node, path: String, pos: Vector2, sz: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = pos
	tr.size = sz
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


## switch a button to a painted plank variation (interim planks carry baked text)
func _plank(b: Button, variation: StringName, keep_text: bool = false) -> void:
	for st in ["normal", "pressed", "hover"]:
		b.remove_theme_stylebox_override(st)
	b.theme_type_variation = variation
	if not keep_text:
		b.text = ""


## Design Bible: nothing appears at full opacity on frame one
func _show_card(c: Control) -> void:
	_hide_cards()
	c.visible = true
	c.modulate.a = 0.0
	var kids := c.get_children()
	var panel: Control = kids[1] if kids.size() > 1 else null
	var tw := create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.14)
	if panel is Control:
		var end_y: float = (panel as Control).position.y
		(panel as Control).position.y = end_y + 46.0
		tw.tween_property(panel, "position:y", end_y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	AudioManager.play("panel_open")


## coins scatter-fly to the coin pill on award
func _coin_scatter(count: int) -> void:
	var hud := lbl_coins.get_parent().get_parent()   # pill -> CanvasLayer
	var target: Vector2 = Vector2(60, 60)
	for i in range(count):
		var c := _mk_icon(hud, "res://assets/ui/interim/icon_coin.png",
			Vector2(540, 980) + Vector2(randf_range(-140, 140), randf_range(-60, 60)), Vector2(56, 56))
		var tw := create_tween()
		tw.tween_interval(0.04 * i)
		tw.tween_property(c, "position", target, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)
	var tw2 := create_tween()
	tw2.tween_interval(0.04 * count + 0.5)
	tw2.tween_callback(_refresh_hud)


func _mk_label(parent: Node, txt: String, fs: int, pos: Vector2, width: float, align: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(int(fs / 7.0), 4))
	l.position = pos
	l.size = Vector2(width, fs + 20)
	l.horizontal_alignment = align
	parent.add_child(l)
	return l


# ---------- ladder defs ----------
func _load_level_def(n: int) -> void:
	run_level = n
	var cfg = DataManager.run_levels
	var authored: Array = cfg.get("levels", []) if cfg is Dictionary else []
	var d: Dictionary = {}
	if n <= authored.size() and n >= 1:
		d = authored[n - 1]
	else:
		var beyond: Dictionary = cfg.get("beyond", {}) if cfg is Dictionary else {}
		var last: Dictionary = authored.back() if authored.size() > 0 else {"target": 48, "time": 36, "level": 10}
		var over := n - int(last.get("level", 10))
		d = {
			"target": int(round(float(last.get("target", 48)) * pow(float(beyond.get("target_growth", 1.12)), over))),
			"time": maxf(float(beyond.get("time_floor", 26)), float(last.get("time", 36)) + over * float(beyond.get("time_step", -1))),
			"misses": int(beyond.get("misses", 3)),
			"boss": n % 5 == 0,
		}
		if n % int(beyond.get("corner_every", 7)) == 0:
			d["objective"] = {"type": "corner_threes", "count": 2 + int(n / 14.0)}
		if n % int(beyond.get("far_every", 4)) == 0:
			d["spawn"] = "far"
	level_target = int(d.get("target", 8))
	level_time = float(d.get("time", 45))
	level_misses = int(d.get("misses", 3))
	level_boss = bool(d.get("boss", false))
	level_spawn = str(d.get("spawn", "center"))
	var obj: Dictionary = d.get("objective", {})
	level_obj_type = str(obj.get("type", "score"))
	level_obj_count = int(obj.get("count", 0))
	_armed = true


func _objective_text() -> String:
	if level_obj_type == "corner_threes":
		var t := "SINK %d CORNER 3s" % level_obj_count
		t += "\ntouch the FAR END between shots"
		return t + "\nin %ds" % int(level_time)
	var t2 := "%d PTS in %ds" % [level_target, int(level_time)]
	if level_spawn == "far":
		t2 += "\nstart at the FAR END"
	return t2


# ---------- state flow ----------
func _hide_cards() -> void:
	for c in [level_card, fail_card, win_card, pack_card, style_card, tune_card]:
		if c:
			c.visible = false


func _enter_ready() -> void:
	state = "ready"
	_load_level_def(int(SaveManager.data.get("run_level", 1)))
	level_attempts = int(SaveManager.data.get("level_attempts", 0))
	_hide_cards()
	meter.active = false
	lbl_card_title.text = "LEVEL %d%s" % [run_level, "  👑" if level_boss else ""]
	lbl_card_obj.text = _objective_text()
	var cost := int(_eco().get("retry_cost", 1))
	lbl_card_ticket.text = "FREE PLAY" if level_attempts == 0 else "costs %d token%s — you have %d" % [cost, "s" if cost > 1 else "", tokens()]
	_show_card(level_card)
	_refresh_hud()


func _on_play_pressed() -> void:
	var cost := int(_eco().get("retry_cost", 1))
	if level_attempts > 0:
		if tokens() < cost:
			_open_pack()
			return
		set_tokens(tokens() - cost)
	_start_attempt()


func _on_retry_pressed() -> void:
	var cost := int(_eco().get("retry_cost", 1))
	if tokens() < cost:
		_open_pack()
		return
	set_tokens(tokens() - cost)
	_start_attempt()


func _start_attempt() -> void:
	level_attempts += 1
	SaveManager.data["level_attempts"] = level_attempts
	SaveManager.save_game()
	score = 0; makes = 0; misses = 0; streak = 0; coins_earned = 0
	obj_progress = 0
	_armed = true
	time_left = level_time
	state = "playing"
	_hide_cards()
	var z := PLAY_Z_MAX - 0.4 if level_spawn == "far" else 1.4
	player.position = Vector3(0, 0, z)
	_refresh_hud()


func _win_level() -> void:
	state = "results"
	meter.active = false
	sfx_clear.play()
	_buzz(120)
	_flash(Color(0.5, 1, 0.6, 0.18))
	_play("Cheer", 0.1)
	var rw: Dictionary = DataManager.run_levels.get("rewards", {}) if DataManager.run_levels is Dictionary else {}
	var mult := float(rw.get("boss_mult", 2.0)) if level_boss else 1.0
	var coin_gain := int(round((50 + 15 * run_level) * mult)) + coins_earned
	var xp_earned := int(round((30 + 8 * run_level + makes * 4) * mult))
	var tok_gain := int(_eco().get("clear_tokens", 2)) + (int(_eco().get("boss_bonus_tokens", 1)) if level_boss else 0)
	set_coins(coins() + coin_gain)
	set_tokens(tokens() + tok_gain)
	SaveManager.data["run_level"] = run_level + 1
	SaveManager.data["level_attempts"] = 0
	_award_xp(xp_earned)
	SaveManager.save_game()
	lbl_win.text = "LEVEL %d CLEARED!%s\n\n+%d coins\n+%d tokens\n+%d XP" % [
		run_level, ("  👑" if level_boss else ""), coin_gain, tok_gain, xp_earned]
	_show_card(win_card)
	AudioManager.play("reward_claim")
	_coin_scatter(8)
	_refresh_hud()


func _fail_level(reason: String) -> void:
	state = "results"
	meter.active = false
	sfx_fail.play()
	_buzz(250)
	_shake(0.2)
	set_coins(coins() + coins_earned)
	SaveManager.save_game()
	var prog := ""
	if level_obj_type == "corner_threes":
		prog = "%d/%d corner 3s" % [obj_progress, level_obj_count]
	else:
		prog = "%d/%d" % [score, level_target]
	lbl_fail.text = "%s\n\nLEVEL %d\n%s\n\nRun it back?" % [reason, run_level, prog]
	var cost := int(_eco().get("retry_cost", 1))
	btn_retry.text = "RETRY (%d TOKEN)" % cost
	_show_card(fail_card)
	_refresh_hud()


func _open_pack() -> void:
	var e := _eco()
	var pc := int(e.get("pack_cost_coins", 400))
	var pt := int(e.get("pack_tokens", 5))
	lbl_pack.text = "TOKEN PACK\n\n%d tokens\nfor %d coins\n\nyou have %d coins" % [pt, pc, coins()]
	btn_pack_get.disabled = coins() < pc
	btn_pack_get.text = "GET PACK" if coins() >= pc else "NEED %d COINS" % pc
	_show_card(pack_card)


func _buy_pack() -> void:
	var e := _eco()
	var pc := int(e.get("pack_cost_coins", 400))
	if coins() < pc:
		return
	set_coins(coins() - pc)
	set_tokens(tokens() + int(e.get("pack_tokens", 5)))
	SaveManager.save_game()
	_flash(Color(1, 0.85, 0.3, 0.15))
	_enter_ready()


func _open_style() -> void:
	AudioManager.play("cosmetic")
	_show_card(style_card)


func _open_tune() -> void:
	_show_card(tune_card)


func _pick_jersey(i: int) -> void:
	var ap: Dictionary = SaveManager.data.get("appearance", {})
	ap["jersey"] = i
	SaveManager.data["appearance"] = ap
	SaveManager.save_game()
	_apply_appearance()


func _pick_ball(i: int) -> void:
	var ap: Dictionary = SaveManager.data.get("appearance", {})
	ap["ball"] = i
	SaveManager.data["appearance"] = ap
	SaveManager.save_game()
	_apply_appearance()


## placeholder-tier customization: tint the whole rig + ball color.
## The real CreateLegend swaps AppearanceProfile layers on the shared rig (ID addendum).
func _apply_appearance() -> void:
	var ap: Dictionary = SaveManager.data.get("appearance", {})
	var j := clampi(int(ap.get("jersey", 0)), 0, JERSEY_COLORS.size() - 1)
	var b := clampi(int(ap.get("ball", 0)), 0, BALL_COLORS.size() - 1)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var mesh := m.mesh
		if mesh == null:
			continue
		for s in range(mesh.get_surface_count()):
			var src := m.get_active_material(s)
			if src is StandardMaterial3D:
				var dup := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.albedo_color = JERSEY_COLORS[j]
				m.set_surface_override_material(s, dup)
	ball_mat.albedo_color = BALL_COLORS[b]


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
	_update_ball(delta)
	_follow_camera(delta)
	if state == "playing":
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_fail_level("TIME'S UP!")
			return
		lbl_timer.text = str(int(ceil(time_left)))
		lbl_timer.modulate = Color(1, 0.35, 0.3) if time_left <= 10.0 else Color(1, 1, 1)
		_move_player(delta)
		if not SHOOT_BUTTON and _down_since >= 0.0 and _now() - _down_since >= CHARGE_HOLD:
			_begin_charge()
	elif state == "charging":
		meter_time += delta
		meter.t = absf(fmod(meter_time * METER_SPEED, 2.0) - 1.0)
		if SHOOT_BUTTON:
			pull_depth = minf(pull_depth + BTN_CHARGE_RATE * delta, 1.0)
		meter.charge = pull_depth
		meter.sweet = minf(ShotMath.sweet_spot(cur_zone, pull_depth >= POWER_PULL, _was_stepback) * SWEET_EASE, 0.92)
		meter.queue_redraw()


func _follow_camera(delta: float) -> void:
	var target := CAM_BASE + Vector3(player.position.x * 0.42, 0, clampf((player.position.z - 1.4) * 0.30, -2.0, 2.0))
	if _shake_amp > 0.005:
		target += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake_amp
		_shake_amp *= pow(0.001, delta)      # fast decay
	cam.position = cam.position.lerp(target, minf(8.0 * delta, 1.0))
	# pitch auto-aims: hoop stays upper third whatever height/dist TUNE picks
	var aim := CAM_AIM + Vector3(player.position.x * 0.2, 0, 0)
	cam.look_at(aim)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## ball follows the player like a live dribble; held at the chest while charging
func _update_ball(delta: float) -> void:
	if _ball_flying:
		return
	if state not in ["playing", "charging"]:
		ball.visible = false
		return
	ball.visible = true
	var f3 := Vector3(facing_vec.x, 0, facing_vec.y)
	var right := Vector3(-facing_vec.y, 0, facing_vec.x)
	if state == "charging":
		var target: Vector3 = player.position + f3 * 0.28 + Vector3(0, 1.9, 0)
		ball.position = ball.position.lerp(target, minf(14.0 * delta, 1.0))
		return
	# mid-burst: choreograph the move (the ball sells it)
	if _burst_t > 0.0 and _move_kind != "":
		var t := 1.0 - _burst_t / BURST_DUR
		var from_off := right * 0.42 * _side_from
		var to_off := right * 0.42 * _dribble_side
		var off := from_off.lerp(to_off, t)
		var y := 0.6
		match _move_kind:
			"cross":
				y = 0.62 - 0.5 * sin(PI * t)          # low, snappy V-cross
			"behind":
				y = 0.55 + 0.3 * sin(PI * t)          # wraps at waist height
				off += f3 * -0.42 * sin(PI * t)       # swings behind the body
			"push":
				off = from_off + f3 * (0.9 * sin(PI * t))
				y = 0.5 - 0.35 * sin(PI * t)
		var b: Vector3 = player.position + off
		ball.position = Vector3(b.x, maxf(y, 0.12), b.z)
		return
	_move_kind = ""
	_dribble_t += delta * (5.0 + 5.0 * _move_mag)
	var bounce := absf(sin(_dribble_t)) * 0.85
	var base: Vector3 = player.position + right * 0.42 * _dribble_side + f3 * 0.12
	ball.position = Vector3(base.x, 0.14 + bounce, base.z)


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
		if _in_down_cone(mv):
			mv = Vector2.ZERO
		if mv.length() > 0.08:
			pos.x += mv.x * MOVE_SPEED * delta
			pos.z += mv.y * MOVE_SPEED * delta
			facing_vec = mv.normalized()
			_move_mag = clampf(mv.length(), 0.0, 1.0)
		elif state == "playing":
			facing_vec = Vector2(0, -1)
	pos.x = clampf(pos.x, -PLAY_X, PLAY_X)
	pos.z = clampf(pos.z, PLAY_Z_MIN, PLAY_Z_MAX)
	player.position = pos
	# corner-drill re-arm: touch the far end
	if level_obj_type == "corner_threes" and not _armed and pos.z >= PLAY_Z_MAX - 0.7:
		_armed = true
		_buzz(25)
		_flash(Color(0.4, 0.9, 1.0, 0.12))
		_popup_grade("ARMED — GO!", Color(0.4, 0.9, 1.0))
		_refresh_hud()
	_update_anim()


const ONE_SHOTS := ["Throw", "Cheer", "Dodge_Forward", "Dodge_Backward", "Dodge_Left", "Dodge_Right"]

func _update_anim() -> void:
	player.rotation.y = atan2(facing_vec.x, facing_vec.y)
	if _cur_anim in ONE_SHOTS and anim and anim.is_playing():
		return
	if state == "charging":
		_play("Jump_Start", 0.1)
		if anim:
			anim.speed_scale = 0.5      # slow gather; holds the loaded pose at the end
		return
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


func _on_shoot_btn_down() -> void:
	if state != "playing":
		return
	_buzz(10)
	pull_depth = 0.0
	_begin_charge()


func _on_shoot_btn_up() -> void:
	if state == "charging":
		_release_shot()


# ---------- one-stick input ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if state in ["playing", "charging"] and not joy_active and t.position.distance_to(STICK_CENTER) <= _stick_activate_r():
				joy_active = true
				joy_index = t.index
				_update_stick(t.position)
		elif t.index == joy_index:
			_on_stick_release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if joy_active and d.index == joy_index:
			_update_stick(d.position)
			if state == "playing" and _flick_cd <= 0.0 and d.velocity.length() >= FLICK_SPEED:
				var fdir := (d.velocity / d.velocity.length())
				if not _in_down_cone(fdir):
					_burst_dir = fdir
					_burst_t = BURST_DUR
					_flick_cd = FLICK_COOLDOWN
					_buzz(15)
					# classify the basketball move: lateral = crossover,
					# back = behind-the-back, forward = speed push
					_side_from = _dribble_side
					if absf(fdir.x) >= absf(fdir.y):
						_move_kind = "cross"
						_dribble_side = -_dribble_side
					elif fdir.y > 0.45:
						_move_kind = "behind"
						_dribble_side = -_dribble_side
						_stepback_until = _now() + STEPBACK_WINDOW
					else:
						_move_kind = "push"
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
		if not SHOOT_BUTTON:
			pull_depth = maxf(pull_depth, _move_dir.length())
		return
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
	if state == "charging" and not SHOOT_BUTTON:
		_release_shot()
	elif _down_since >= 0.0 and _now() - _down_since < CHARGE_HOLD:
		_step_back()
	_down_since = -1.0
	_move_dir = Vector2.ZERO
	stick.knob = Vector2.ZERO
	stick.active = false
	stick.queue_redraw()


func _in_down_cone(v: Vector2) -> bool:
	if SHOOT_BUTTON:
		return false             # button mode: stick is full-360 locomotion
	if v.length() < 0.01:
		return false
	return absf(rad_to_deg(v.angle_to(Vector2.DOWN))) <= DOWN_CONE_DEG


# ---------- shot grammar ----------
func _dodge_for(dir: Vector2) -> String:
	if dir.y < -0.45:
		return "Dodge_Forward"
	if dir.y > 0.45:
		return "Dodge_Backward"
	return "Dodge_Right" if dir.x > 0.0 else "Dodge_Left"


func _step_back() -> void:
	if state != "playing":
		return
	_burst_dir = Vector2(0, 1)
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
	_shot_from_corner = absf(player.position.x) > CORNER_X and player.position.z < CORNER_Z
	var dist := Vector2(player.position.x - RIM_POS.x, player.position.z - RIM_POS.z).length()
	cur_zone = ShotMath.zone_for_distance(dist, COURT_LEN_M)
	meter.active = true
	meter.sweet = minf(ShotMath.sweet_spot(cur_zone, false, _was_stepback) * SWEET_EASE, 0.92)
	facing_vec = Vector2(0, -1)
	_update_anim()


func _release_shot() -> void:
	var power := pull_depth >= POWER_PULL
	var accuracy := absf(meter.t - 0.5)
	var side := meter.t - 0.5
	var sweet := minf(ShotMath.sweet_spot(cur_zone, power, _was_stepback) * SWEET_EASE, 0.92)
	var res := ShotMath.resolve(cur_zone, accuracy, sweet, side)
	meter.active = false
	state = "playing"
	_play("Throw", 0.05)
	if anim:
		anim.speed_scale = 1.3
	# rise-and-release: hop the whole rig
	var tw := create_tween()
	tw.tween_property(player, "position:y", 0.6, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_apply_shot(res, power)


func _apply_shot(res: Dictionary, power: bool) -> void:
	_fly_ball(res.made)
	var was_armed := _armed
	if level_obj_type == "corner_threes":
		_armed = false          # every shot disarms; touch the far end to re-arm
	if res.made:
		sfx_swish.play()
		_buzz(30)
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
		if cur_zone == ShotMath.Zone.THREE and _shot_from_corner and (level_obj_type != "corner_threes" or was_armed):
			obj_progress += 1
			tag = "CORNER " + tag
		elif cur_zone == ShotMath.Zone.THREE and _shot_from_corner and not was_armed:
			tag = "NOT ARMED — " + tag
		_popup_grade("%s  %s!" % [tag, res.grade], Color(0.4, 1, 0.5))
		if _objective_met():
			_refresh_hud()
			_win_level()
			return
	else:
		sfx_rim.play()
		_buzz(70)
		_shake(0.12)
		misses += 1
		streak = 0
		_popup_grade(res.grade, Color(1, 0.5, 0.45))
		if misses >= level_misses:
			_refresh_hud()
			_fail_level("OUT OF MISSES!")
			return
	_refresh_hud()


func _objective_met() -> bool:
	if level_obj_type == "corner_threes":
		return obj_progress >= level_obj_count
	return score >= level_target


# ---------- ball flight + physics ----------
func _fly_ball(made: bool) -> void:
	_ball_flying = true
	ball.visible = true
	var start: Vector3 = player.position + Vector3(0, 2.3, 0)
	var target := RIM_POS if made else RIM_POS + Vector3(randf_range(-0.55, 0.55), randf_range(0.05, 0.3), randf_range(-0.15, 0.3))
	var arc := maxf(1.6, (RIM_POS.y - start.y) + 1.8)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		ball.position = start.lerp(target, t) + Vector3(0, arc * sin(PI * t), 0),
		0.0, 1.0, 0.55).set_trans(Tween.TRANS_LINEAR)
	if made:
		# drop through the net, then dampened floor bounces back into the dribble
		tw.tween_property(ball, "position", RIM_POS + Vector3(0, -1.1, 0.1), 0.18)
		tw.tween_callback(func() -> void:
			_bounce_ball(RIM_POS + Vector3(0, -1.1, 0.1), Vector3(randf_range(-0.4, 0.4), 0, randf_range(0.6, 1.2)), 0.5, 2))
	else:
		# clank off the rim: bounce away with dampened hops
		tw.tween_callback(func() -> void:
			var dir := Vector3(randf_range(-1.0, 1.0), 0, randf_range(0.6, 1.6)).normalized()
			_bounce_ball(ball.position, dir * randf_range(1.6, 2.6), 1.1, 3))


## dampened parabolic hops from `from` with horizontal velocity `vel`; first apex `h`
func _bounce_ball(from: Vector3, vel: Vector3, h: float, hops: int) -> void:
	var tw := create_tween()
	var p := from
	var height := h
	for i in range(hops):
		var dur := clampf(0.16 + height * 0.22, 0.15, 0.5)
		var land := p + vel * dur
		land.x = clampf(land.x, -COURT_W * 0.5, COURT_W * 0.5)
		land.z = clampf(land.z, -COURT_D * 0.5, COURT_D * 0.5)
		land.y = 0.14
		var start := p
		var apex := height
		tw.tween_method(func(t: float) -> void:
			ball.position = start.lerp(land, t) + Vector3(0, apex * sin(PI * t), 0),
			0.0, 1.0, dur)
		p = land
		vel *= 0.55
		height *= 0.42
	tw.tween_callback(func() -> void: _ball_flying = false)


# ---------- FX ----------
func _popup_grade(txt: String, col: Color) -> void:
	var perfect := "PERFECT" in txt
	lbl_grade.text = txt
	lbl_grade.modulate = Color(1.0, 0.85, 0.25) if perfect else col
	lbl_grade.modulate.a = 1.0
	lbl_grade.pivot_offset = lbl_grade.size * 0.5
	lbl_grade.scale = Vector2.ONE * (1.65 if perfect else 1.35)
	lbl_grade.position.y = 380
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl_grade, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl_grade, "position:y", 330.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_interval(0.35)
	tw.chain().tween_property(lbl_grade, "modulate:a", 0.0, 0.4)
	if perfect:
		_flash(Color(1, 0.95, 0.6, 0.16))
	lbl_score.pivot_offset = lbl_score.size * 0.5
	lbl_score.scale = Vector2.ONE * 1.35
	create_tween().tween_property(lbl_score, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash(col: Color) -> void:
	if _flash_rect == null:
		return
	_flash_rect.color = col
	_flash_rect.visible = true
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, 0.28)
	tw.tween_callback(func() -> void: _flash_rect.visible = false)


func _refresh_hud() -> void:
	cap_level.text = "LVL %d%s" % [run_level, " 👑" if level_boss else ""]
	if level_obj_type == "corner_threes":
		var arm_tag := "" if _armed else " >FAR"
		lbl_score.text = "%d/%d 🎯%s" % [obj_progress, level_obj_count, arm_tag]
		lbl_score.modulate = Color(0.45, 1, 0.55) if obj_progress >= level_obj_count else (Color(1, 1, 1) if _armed else Color(1, 0.75, 0.4))
	else:
		lbl_score.text = "%d/%d" % [score, level_target]
		lbl_score.modulate = Color(0.45, 1, 0.55) if score >= level_target else Color(1, 1, 1)
	lbl_timer.text = str(int(ceil(time_left)))
	lbl_coins.text = str(coins() + (coins_earned if state in ["playing", "charging"] else 0))
	lbl_tokens.text = str(tokens())
	if streak >= 3:
		lbl_streak.text = "🔥 ON FIRE ×2"
		lbl_streak.modulate = Color(1.0, 0.6, 0.15)
		lbl_streak.pivot_offset = Vector2(0, lbl_streak.size.y * 0.5)
		lbl_streak.scale = Vector2.ONE * 1.25
		create_tween().tween_property(lbl_streak, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lbl_streak.modulate = Color(1, 1, 1)
		lbl_streak.text = ("x%d" % streak) if streak > 0 else ""
	lbl_misses.text = "✗".repeat(misses) + "•".repeat(maxi(level_misses - misses, 0))

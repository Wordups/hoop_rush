extends RefCounted
class_name ShotMath
## Pure shot resolution — no scene dependencies, so it's unit-testable headless.
## Ports the "reference math to port verbatim" block from HOOP_RUSH_BUILD_BRIEF.md.

enum Zone { DUNK, LAYUP, MID, THREE }

const SWEET_BASE := {
	Zone.DUNK: 0.50,
	Zone.LAYUP: 0.34,
	Zone.MID: 0.22,
	Zone.THREE: 0.16,
}
const ZONE_POINTS := {
	Zone.DUNK: 2,
	Zone.LAYUP: 2,
	Zone.MID: 2,
	Zone.THREE: 3,
}
const ZONE_NAMES := {
	Zone.DUNK: "DUNK",
	Zone.LAYUP: "LAYUP",
	Zone.MID: "MID",
	Zone.THREE: "THREE",
}

## normalized distance (0 at rim, 1 at far baseline) -> zone
static func zone_for_distance(dist: float, court_len: float) -> int:
	var t := clampf(dist / maxf(court_len, 1.0), 0.0, 1.0)
	if t < 0.12:
		return Zone.DUNK
	elif t < 0.36:
		return Zone.LAYUP
	elif t < 0.62:
		return Zone.MID
	return Zone.THREE

## sweet-spot as a fraction of the timing bar, with modifiers, clamped 0.05..0.92
static func sweet_spot(zone: int, power_shot: bool, stepback: bool = false, deadeye_pct: float = 0.0) -> float:
	var s: float = SWEET_BASE[zone]
	if stepback:
		s *= 1.7          # Ankle Breaker maxed (plain step-back = 1.35 once badges exist)
	s += deadeye_pct      # Deadeye badge widens the window
	if power_shot:
		s *= 0.85         # tighter window, bigger reward
	return clampf(s, 0.05, 0.92)

## Resolve a release. `accuracy` = |indicator - center|, range 0..0.5.
## `side` < 0 means released early (left of center), > 0 late.
## Returns { made:bool, grade:String, points:int }.
static func resolve(zone: int, accuracy: float, sweet: float, side: float) -> Dictionary:
	var half := sweet * 0.5
	var made := accuracy <= half
	var grade := ""
	if made:
		if accuracy <= half * 0.30:
			grade = "PERFECT"
		elif accuracy <= half * 0.65:
			grade = "GREAT"
		else:
			grade = "GOOD"
	else:
		grade = "EARLY" if side < 0.0 else "LATE"
	return {
		"made": made,
		"grade": grade,
		"points": ZONE_POINTS[zone],
		"zone_name": ZONE_NAMES[zone],
	}

## Coin reward for a make (brief formula).
static func make_reward(level: int, coin_mult: float, points: int, power_shot: bool, on_fire: bool) -> int:
	var r := (8.0 + level * 1.4) * coin_mult * (points / 2.0)
	if power_shot:
		r *= 1.3
	if on_fire:
		r *= 2.0
	return int(round(r))

static func round_bonus(makes: int, coin_mult: float) -> int:
	return int(round(makes * 4.0 * coin_mult))

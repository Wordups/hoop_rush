extends Node
## GameManager (autoload) — top-level glue + shared progression math.
## Holds the live AppearanceProfile and the XP curve every other system reads.

var appearance: AppearanceProfile

func _ready() -> void:
	# rebuild the live look from save (customizer or photo — GameManager doesn't care which)
	appearance = AppearanceProfile.from_dict(SaveManager.data.get("appearance", {}))
	print("[GameManager] ready — level %s, coins %s, playstyle '%s'" % [
		str(SaveManager.data.get("level", 1)),
		str(SaveManager.data.get("coins", 0)),
		str(SaveManager.data.get("playstyle", "")),
	])

func save_appearance() -> void:
	SaveManager.data["appearance"] = appearance.to_dict()
	SaveManager.save_game()

# ---- progression math (verbatim from the build brief) ----

func xp_to_next(level: int) -> int:
	return int(round(100.0 * pow(float(level), 1.35)))

func level_up_cost(level: int) -> int:
	return int(round(40.0 * pow(1.18, float(level - 1))))   # shop coins — does NOT grant XP/milestones

func refill_cost(n: int) -> int:
	return int(round(20.0 * pow(1.12, float(n))))

func coin_mult(tier: int) -> float:
	return 1.0 + tier * 0.25

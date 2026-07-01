extends Node
## SaveManager (autoload) — persists player state to user://save.json.
## Everything that must survive a relaunch lives here.

const SAVE_PATH := "user://save.json"
var data: Dictionary = {}

func _ready() -> void:
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _default_save()
		save_game()
		print("[SaveManager] new save created")
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	data = parsed if parsed is Dictionary else _default_save()
	# forward-compat: merge any keys added since this save was written
	var defaults := _default_save()
	for k in defaults.keys():
		if not data.has(k):
			data[k] = defaults[k]
	print("[SaveManager] loaded save (level %s)" % str(data.get("level", 1)))

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] could not open %s for write" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _default_save() -> Dictionary:
	return {
		"version": 1,
		"level": 1,
		"xp": 0,
		"coins": 0,
		"arcade_tokens": 3,
		"energy": 5,
		"best_score": 0,
		"longest_streak": 0,
		"playstyle": "",          # Shooter / Slasher / Playmaker / Dunker
		"home_court": "",
		"appearance": {},         # AppearanceProfile.to_dict()
		"consent": {              # photo/biometric gate (COPPA/BIPA/GDPR-K)
			"given": false,
			"timestamp": 0,
			"age_ok": false,
		},
		"cosmetics_unlocked": [],
		"cosmetics_equipped": {},
		"badges": {},
		"emotes": {},
		"poster_params": {},
	}

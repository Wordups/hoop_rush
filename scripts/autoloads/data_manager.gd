extends Node
## DataManager (autoload) — loads every res://data/*.json on boot.
## Read-only game data. Managers read from here; nobody writes back.

var badges
var courts
var emotes
var events
var levels
var rewards
var shop_items
var cosmetics   ## ID addendum — authored later; loads as empty until data/cosmetics.json exists

func _ready() -> void:
	badges = _load("badges")
	courts = _load("courts")
	emotes = _load("emotes")
	events = _load("events")
	levels = _load("levels")
	rewards = _load("rewards")
	shop_items = _load("shop_items")
	cosmetics = _load("cosmetics")
	print("[DataManager] data loaded")

func _load(file_name: String):
	var path := "res://data/%s.json" % file_name
	if not FileAccess.file_exists(path):
		push_warning("[DataManager] missing %s (ok if not authored yet)" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_error("[DataManager] failed to parse %s" % path)
		return {}
	return parsed

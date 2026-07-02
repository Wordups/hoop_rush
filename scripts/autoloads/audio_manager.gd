extends Node
## AudioManager (autoload) — the one seam every menu/world sound goes through.
## Real painted-world sounds (Design Bible wire map) are TODO stubs: drop wavs into
## assets/audio/ with the mapped names and they start playing without code changes.

## Design-Bible event -> file map. Missing files fall back to `fallback` (or silence).
const WIRE := {
	"panel_open":   {"file": "sfx_paint_swipe",     "fallback": "sfx_ui_open"},    # TODO real paint swipe
	"button_press": {"file": "sfx_boombox_click",   "fallback": "sfx_ui_click"},   # TODO boombox click
	"nav_bounce":   {"file": "sfx_ball_bounce_ui",  "fallback": "sfx_ui_click"},   # TODO basketball bounce
	"reward_claim": {"file": "sfx_chain_net",       "fallback": "sfx_clear"},      # TODO chain net
	"cosmetic":     {"file": "sfx_spray_can",       "fallback": "sfx_ui_open"},    # TODO spray can
	"level_clear":  {"file": "sfx_crowd",           "fallback": "sfx_clear"},      # TODO crowd swell
	"back":         {"file": "sfx_cassette_rewind", "fallback": "sfx_ui_click"},   # TODO cassette rewind
}

var _players: Dictionary = {}

func _ready() -> void:
	for event in WIRE:
		var spec: Dictionary = WIRE[event]
		var path := "res://assets/audio/%s.wav" % spec["file"]
		if not ResourceLoader.exists(path):
			path = "res://assets/audio/%s.wav" % spec["fallback"]
		if not ResourceLoader.exists(path):
			continue
		var pl := AudioStreamPlayer.new()
		pl.stream = load(path)
		pl.volume_db = -6.0
		add_child(pl)
		_players[event] = pl

func play(event: String) -> void:
	var pl: AudioStreamPlayer = _players.get(event)
	if pl:
		pl.play()

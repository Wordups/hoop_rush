extends Resource
class_name AppearanceProfile
## The single source of truth for how a player LOOKS.
## Drives the shared rig's appearance layer only — never a new rigged character.
## Identical whether it came from the manual customizer or the (optional) photo path.

@export var skin_tone: int = 2      ## index into the skin palette
@export var face_style: int = 0
@export var hair_style: int = 0
@export var hair_color: int = 0
@export var body_build: int = 1     ## 0 = slim, 1 = normal, 2 = heavy

## equipped cosmetics by slot (cosmetic ids from data/cosmetics.json)
@export var slot_top: String = "tee_default"
@export var slot_sleeve: String = ""
@export var slot_chain: String = ""
@export var slot_shoes: String = "shoes_default"
@export var slot_entrance: String = ""

## where this look came from — for analytics + regenerate UX. never the raw photo.
@export var source: String = "customizer"   ## "customizer" | "photo"

func to_dict() -> Dictionary:
	return {
		"skin_tone": skin_tone,
		"face_style": face_style,
		"hair_style": hair_style,
		"hair_color": hair_color,
		"body_build": body_build,
		"slot_top": slot_top,
		"slot_sleeve": slot_sleeve,
		"slot_chain": slot_chain,
		"slot_shoes": slot_shoes,
		"slot_entrance": slot_entrance,
		"source": source,
	}

static func from_dict(d: Dictionary) -> AppearanceProfile:
	var p := AppearanceProfile.new()
	if d == null or d.is_empty():
		return p
	p.skin_tone = int(d.get("skin_tone", p.skin_tone))
	p.face_style = int(d.get("face_style", p.face_style))
	p.hair_style = int(d.get("hair_style", p.hair_style))
	p.hair_color = int(d.get("hair_color", p.hair_color))
	p.body_build = int(d.get("body_build", p.body_build))
	p.slot_top = String(d.get("slot_top", p.slot_top))
	p.slot_sleeve = String(d.get("slot_sleeve", p.slot_sleeve))
	p.slot_chain = String(d.get("slot_chain", p.slot_chain))
	p.slot_shoes = String(d.get("slot_shoes", p.slot_shoes))
	p.slot_entrance = String(d.get("slot_entrance", p.slot_entrance))
	p.source = String(d.get("source", p.source))
	return p

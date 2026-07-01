# Hoop Rush — new-session kickoff / handoff

Paste the block below into a fresh Claude Code session (phone/cloud or desktop) to pick up cold.

---

You're picking up **Hoop Rush**, a Godot 4.7 iPhone basketball arcade game (GDScript, portrait 1080×1920, premium / no-ads). Repo: `Wordups/hoop_rush`. Local dev path: `C:\dev\AI GAMING\Hoop Rush`.

Read `files/HOOP_RUSH_BUILD_BRIEF.md` (base game, 5 phases) + the ID/avatar addendum. Everything is data-driven from `data/*.json` (badges, courts, emotes, events, levels, rewards, shop_items; cosmetics.json authored later).

**Current state — Phase 1 playable core DONE + validated headless:**
- `GameCourt` is the home screen (real court art `assets/court_street.png`); player is a **placeholder shape (option C)**.
- Full Score Attack loop: drag-joystick move · hold-to-charge SHOOT + oscillating timing meter · zone-by-distance (DUNK/LAYUP/MID/THREE) · Perfect/Great/Good grading · streak → on-fire ×2 · 60s round · 3-miss end · results with coins + XP + **level-up**, persisted to `user://save.json`.
- Autoloads: `DataManager`, `SaveManager`, `GameManager`. Shot math (verbatim from brief) in `scripts/game/shot_math.gd`. `AppearanceProfile` resource (the ID foundation) already built in.
- `Player.png` (in files/) is a **style board, NOT a sprite sheet**.

**Validate (needs Godot 4.7 installed):** `godot --headless --path "<proj>" --quit-after 15` → catches parse errors. Play: `godot --path "<proj>"`.
⚠️ A **cloud/phone session can EDIT the code but cannot run Godot** (no engine in the cloud) — testing/validation is desktop-only.

**Tunable, needs visual eyes:** `RIM`, `PLAY_BOUNDS`, `COURT_LEN`, and the court cover-scale at the top of `scripts/game/game_court.gd` — the player isn't aligned to the painted hoop yet.

**ID non-negotiables:** default onboarding = no-camera customizer; photo path opt-in + age/consent-gated (COPPA/BIPA/GDPR-K); one shared rig + swappable `AppearanceProfile` layer (never a per-user rig); store derived appearance params, not raw selfies.

**Next:** tune framing from feel test → **option B (real player sprites)** → rest of Phase 1/2 (EconomyManager, DailyRewards, badges/emotes lockers, `CreateLegend` customizer = the ID addendum).

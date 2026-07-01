# HOOP RUSH — Claude Code Build Brief

Hand this entire file to **Claude Code** as the working brief. It turns the full design spec
into an execution-ordered plan, wired to the mock data files and the existing prototype.

## What you're given
- **Design spec** (the long PROJECT: HOOP RUSH doc) — source of truth for features, tone, rules.
- **Mock data files** (`data/*.json`): badges, emotes, events, rewards, levels, shop_items, courts.
  These are already authored — load them, don't invent new schemas without reason.
- **Working browser prototype** (`hoop-rush-2.html`) — proves the core shot loop (charge/release
  meter, zones, step-back, fire streak, dunk shatter, shop, badges). Use it as the gameplay-feel
  reference; port the math, fix its 3 known bugs (below).
- **Art assets**: one painted street court background + a player sprite sheet (turnaround, 8-dir
  movement, dribble/jumpshot/dunk). More courts/characters come later — keep everything data-driven.

## Stack (decided)
Godot 4.x · GDScript · iPhone-first portrait · 60fps · local save for prototype ·
FastAPI backend later (leaderboards/accounts) · **premium, no ads** · painted 2D.

## 3 prototype bugs to FIX, not copy
1. Resting player sprite faced the camera — use the **back-facing** sprite at rest (player faces
   the hoop upcourt). Front-facing idle is menu-only.
2. Camera was too tight / player oversized — set sane sprite-to-court scale with room to roam.
3. Instructional text overlapped the player — keep HUD/hints in safe zones, auto-fade hints.

---

## Architecture (autoload singletons)
Create these as Godot autoloads, one script each:
`GameManager, SaveManager, PlayerController, ShotController, ScoreManager, XPManager,
EconomyManager, BadgeManager, EmoteManager, EventManager, DailyRewardManager,
LeaderboardManager, AudioManager, UIManager`

Managers read the `data/*.json` files on boot. `SaveManager` persists to `user://save.json`.

## Scenes to create
`MainMenu, GameCourt, ResultsScreen, ShopScreen, BadgeLocker, EmoteLocker, DailyRewards,
EventsScreen, LeaderboardScreen, CourtCollection, StreetRadio, PlayerProfile, Settings`

The **court is the home screen** — GameCourt should feel alive the moment the app opens.

---

## Execution order (follow the spec's MVP phases)

### PHASE 1 — Playable core (do this first, ship-able slice)
1. Project scaffold: portrait 1080×1920, `canvas_items` stretch, safe-area margins, git init.
2. `GameCourt`: painted court sprite + `Camera2D` + `RimAnchor` marker on the rim. Data-driven
   via a `World` resource so courts swap (see `courts.json`).
3. `PlayerController`: drag-to-move virtual joystick, clamp to court bounds, 8-directional sprite
   selection, **back-facing rest pose**, slight depth scaling.
4. `ShotController`: hold-to-charge SHOOT button, oscillating timing meter + green sweet-spot,
   distance→zone (DUNK/LAYUP/MID/THREE), auto shot animation, ball arc tween, make/miss resolve.
   Shot grades: Perfect / Great / Good / Late / Early / Miss.
5. Score Attack mode: 60-second round, 3 misses ends early, streak multiplier, clutch bonus in
   final 10s, deep-shot bonus, perfect-release bonus.
6. `XPManager` + `ScoreManager`: XP from the sources in `levels.json`, curve
   `xp_to_next = round(100 * level^1.35)`, level-up flow. **No buying XP or levels.**
7. `SaveManager`: persist everything in the spec's save list.
8. Basic HUD: trophies, coins, basketball energy, arcade tokens, badge + settings buttons.

### PHASE 2 — Economy + return loop
9. `EconomyManager`: Coins, Arcade Tokens, Basketball Energy (regen over time).
10. Continue system: spend 1 Arcade Token to extend a failed run (extends play, never guarantees).
11. `DailyRewardManager` + `DailyRewards` scene: 7-day track from `rewards.json`, glowing claim UI.
12. `ShopScreen`: mock packs from `shop_items.json` (no real purchases). Add a `StoreKit` stub
    with a TODO for the chosen premium model.

### PHASE 3 — Identity + collections
13. `BadgeManager` + `BadgeLocker`: inventory, 4 equip slots (unlock L1/25/75/150), upgrade levels,
    badge XP, rarity — all from `badges.json`. No badge guarantees a make.
14. `EmoteManager` + `EmoteLocker`: from `emotes.json`, categories + unlock sources.
15. `CourtCollection`: courts + mastery objectives from `courts.json`.
16. `PlayerProfile`: the "flex screen" — level, XP bar, title, badge, banner, milestone trophies,
    equipped emotes/ball/jersey, rank, best score.

### PHASE 4 — Competition framework
17. `EventManager` + `EventsScreen`: Fourth of July Tournament from `events.json`, objective
    tracking, XP caps, event rewards + fireworks emote.
18. `LeaderboardManager` + `LeaderboardScreen`: placeholder for all board types (Global Level Race,
    Weekly/Season XP, High Score, Longest Streak, Event, Court Mastery, Friends).
19. **Milestone Topper framework**: first-to-milestone permanent rewards from `levels.json`
    (`milestones` + `topper_rules`). Local for prototype; structure for server validation later.
20. `ResultsScreen`: score, makes, perfects, longest streak, XP/coins earned, level + event
    progress, next-reward preview, and CTAs (Play Again, Continue w/ Token, Claim, Upgrade Badge,
    Leaderboard, Shop). `StreetRadio` placeholder menu + `AudioManager` with Apple Music stub.

### PHASE 5 — Ops layer (later, not gameplay)
21. Stand up the 10 dev/ops "AI agents" from the spec as **reporting/simulation scripts or docs**,
    not in-game systems: Game Design, Economy, Retention, Leaderboard Integrity, Content, QA,
    LiveOps, Marketing, Music, Player Coach. For the prototype, ship only the **Player Coach**
    placeholder: post-run coaching text ("You released slightly early.", "Your best zone is left
    wing three."). The rest can be markdown report templates to start.

---

## Reference math to port verbatim (from prototype + data files)
```
xp_to_next(level)   = round(100 * level^1.35)
levelUpCost(l)      = round(40  * 1.18^(l-1))     # shop, coins — does NOT grant XP/milestones
refillCost(n)       = round(20  * 1.12^n)
coinMult(tier)      = 1 + tier*0.25

sweet-spot base by zone: DUNK 0.50 · LAYUP 0.34 · MID 0.22 · THREE 0.16
  * step-back buff active: *1.7 (Ankle Breaker maxed) else *1.35
  * Deadeye badge: widen by its perfect_window_pct
  * power shot (held past threshold): *0.85   (tighter window, higher reward)
  clamp 0.05 .. 0.92

make reward = round((8 + level*1.4) * coinMult() * (points/2))
  * power shot: *1.3   * on fire (3+ streak): *2
round bonus = round(makes * 4 * coinMult())
```

## Non-negotiable product principles (enforce in code + copy)
- **Skill first.** Wins come from precision, not spend.
- **Tokens extend play, never guarantee a make or a leaderboard win.**
- **No XP or level purchases. No paid milestone skips.**
- **No gambling/casino language or visuals.** Use: Arcade Tokens, Coins, Trophies, Badges,
  Courts, Energy, Rewards.
- **Every run must visibly move something** (XP, badge, event, collection).

## Definition of done — prototype
All 20 prototype deliverables from the spec, playable on iPhone, one court, full loop with
persistent save, mock shop, daily rewards, badges, emotes, event + leaderboard placeholders,
results + profile screens, clean modular code ready for iOS export.

## Hardware note
iOS builds require a **Mac** (Xcode: signing + iOS export template). iPad Pro can't compile the
build. A base M-series MacBook Air / Mac mini is enough — you don't need a Pro.

## One decision still open (lock before Phase 2 shop work)
**Premium model:** paid-upfront app, or free with a single cosmetic IAP unlock? This changes how
the shop and progression gates are built. Everything else in this brief is settled.

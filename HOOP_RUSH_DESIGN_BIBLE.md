# HOOP RUSH — Design Bible

Transcribed from the locked art brief poster (`files/WOW.png`). That poster + the commissioned
court/character art (`files/Court.png`, `files/Player.png`) are the master style. Every screen,
panel, button, icon, and card should look like it was painted by the same hand.

## Design manifesto

Every screen should answer one question: **"Would this make someone want to screenshot it?"**
Nothing should feel disposable. Everything should feel collectible. Every menu should feel like
it belongs inside the world instead of floating on top of it.

Five feelings to hit: **IDENTITY** ("this is MY basketball player") · **PROGRESS** ("I'm closer
than yesterday") · **STATUS** ("I earned this") · **STYLE** ("I look different than everyone
else") · **COMPETITION** ("I need one more run").

## The visual rule

| Nothing should ever feel… | Everything should feel… |
|---|---|
| Corporate | Painted |
| Generic | Warm |
| Flat | Human |
| Mobile template | Athletic |
| Modern SaaS | Urban |
| Material Design | Confident |
| Default Godot | Premium |

**If it looks like it belongs in another game — reject it.**

## Master palette (pulled from the court art)

Sunset orange · magenta-pink · violet · deep purple · warm cream · teal · charcoal.
Warm sunset cast on everything; cream text (#f5e9d0-ish) with dark outlines.

## Art direction rules

- **Character**: never realistic, never anime, never cel-shaded plastic. Painted, slight brush
  texture, warm rim lighting, bold silhouettes, NBA Jam proportions.
- **Buttons**: should look touchable, not digital — like someone painted them on plywood and hung
  them on the fence.
- **Panels**: concrete, spray paint, tape, posters, street stickers, weathered.
- **Rewards**: every reward should glow. Players should WANT to tap it.
- **HARD RULE — currency**: arcade TOKENS only. **No poker chips, no casino visuals, ever.**

## Animation rules (all menus)

Buttons bounce (≈1.0→1.08→1.0, ~120ms) · cards slide+ease in · coins scatter-fly to the pill ·
XP fills with slight overshoot · graffiti sprays · confetti drifts · basketballs bounce ·
menus breathe (1–2% scale pulse, ~3s). **Nothing appears at full opacity on frame one** —
80–150ms fade/slide minimum.

## Audio rules (menu wire map)

Paint swipe (panel open) · basketball bounce (nav) · chain net (reward claim) · spray can
(cosmetic equip) · crowd (level clear) · boombox click (button press) · cassette rewind (back).
Until real sounds exist these are TODO stubs behind the AudioManager seam.

## UI kit — reusable pieces (build order)

1. UI kit (panel + buttons + pills + currency icons) — unlocks every screen at once
2. Poster/trading-card frame — the growth asset (bronze/silver/gold/legendary, 1200×1680)
3. PlayerProfile + DailyRewards backdrops — most-shared + retention
4. The rest of the screens

## Screens (one painted backdrop + layout per screen)

Main menu/home · results · shop · badge locker · emote locker · daily rewards · events ·
leaderboard · court collection · street radio · player profile · settings. Each shares the
sunset-court world (blurred court skyline behind menus) so the app feels like one place.

## Specs & delivery (for asset generation)

- Transparent PNG (UI/icons/cards); full-bleed painted backdrops can be JPG
- Design @3x for iPhone; portrait mobile base 1080×1920
- One subject per image; **blank button faces — no baked text**; empty card slots
- Every asset must read as the same painted hand as the court — warm sunset palette, painterly
  texture, hand-drawn outlines, graffiti/street accents. If a piece looks like flat vector
  mobile UI, reject and regenerate.
- Naming: `ui_panel_large.png`, `ui_btn_play.png`, `ui_btn_play_pressed.png`, `ui_pill_coins.png`,
  `icon_token.png`, `card_frame_gold.png`, `screen_results_bg.jpg`, …

## Integration flow (when art comes back)

1. Slice the kit into a Godot Theme resource so buttons/panels/pills restyle globally
2. Swap emoji currency for the painted icons
3. Composite the poster/card generator against the frame template (SubViewport → shareable image)
4. Build each screen against its painted backdrop

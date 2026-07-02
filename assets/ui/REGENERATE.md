# UI Asset Re-render Shopping List (Higgsfield session checklist)

Every asset in `assets/ui/interim/` is a **poster slice** — usable for layout, wrong for ship.
Regenerate each one individually to the specs below. Global rules (Design Bible):
same painted hand as the court art · warm sunset palette · painterly texture, hand-drawn
outlines, graffiti/street accents · **one subject per image** · **transparent background** ·
**@3x** (design for 1080×1920 portrait) · **blank button faces — NO baked text** · empty card
slots. If a result reads as flat vector mobile UI, reject and regenerate.

## 🚨 Priority: replace the poker chip

- [ ] `icon_token.png` — **arcade token**: brass/gold coin-like game token with a basketball or
  crown emboss, painted, chunky, street-arcade vibe. The current `icon_token_TEMP_REPLACE.png`
  is a **red/white poker chip** and violates the hard no-casino rule. 512×512.

## Buttons (blank planks — text is rendered by the game)

- [ ] `ui_btn_plank_gold.png` — primary (PLAY) painted plywood plank, gold/amber, idle. 900×260.
- [ ] `ui_btn_plank_gold_pressed.png` — same plank, pressed/darkened + slight squash. 900×260.
- [ ] `ui_btn_plank_purple.png` — secondary plank (STYLE). 900×260.
- [ ] `ui_btn_plank_teal.png` — secondary plank (TUNE). 900×260.
- [ ] `ui_btn_plank_red.png` — secondary plank (SHOP / destructive). 900×260.
- [ ] `ui_btn_plank_cream.png` — neutral plank (BACK / CLOSE). 900×260.

## Panels & pills

- [ ] `ui_panel_large.png` — weathered dark concrete/plywood card panel, spray-paint edge wear,
  subtle tape/sticker accents, big empty center. 1200×1500, 9-slice-friendly borders.
- [ ] `ui_panel_small.png` — same language, squarer. 900×700.
- [ ] `ui_pill.png` — HUD capsule, dark painted, empty (icon + number rendered by game). 520×140.

## Progress bar (separate pieces!)

- [ ] `ui_progress_track.png` — empty painted track, dark, slight inner shadow. 900×90.
- [ ] `ui_progress_fill.png` — gold/amber painted fill bar, slight glow, tileable middle. 880×70.

## Icons (512×512 each, painted, transparent)

- [ ] `icon_coin.png` — gold coin, basketball emboss
- [ ] `icon_trophy.png` — gold trophy
- [ ] `icon_ball.png` — painted basketball
- [ ] `icon_medal.png` — street medal/badge
- [ ] `icon_xp.png` — XP star/spray-paint star
- [ ] `icon_timer.png` — chunky stopwatch

## Trading-card frames (the growth asset)

- [ ] `card_frame_bronze.png` — 1200×1680, EMPTY center slot, painted bronze frame
- [ ] `card_frame_silver.png` — 1200×1680, empty slot, silver
- [ ] `card_frame_gold.png` — 1200×1680, empty slot, gold
- [ ] `card_frame_legendary.png` — 1200×1680, empty slot, purple/animated-feel glow

## Logo

- [ ] `ui_logo_lockup.png` — HOOP RUSH crown graffiti lockup on transparency, 1200×900.
  (Interim slice is decent; re-render mostly for resolution + clean alpha.)

## Audio (not image gen — record/source separately)

- [ ] paint swipe (panel open) · basketball bounce (nav) · chain net (reward) · spray can
  (cosmetic equip) · crowd swell (level clear) · boombox click (press) · cassette rewind (back).
  Stubs already exist behind `AudioManager` — drop files in `assets/audio/` with those names.

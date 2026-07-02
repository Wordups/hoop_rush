# HOOP RUSH — Hero Character Technical Design Document
**Character Department deliverable · Godot 4 · iPhone 60fps · Stylized-realism streetball**
*Status: production-ready plan. Supersedes nothing; extends MESH_SWAP.md into a full pipeline.*

---

## 0. North Star
One hero: male, athletic, brown skin, short textured curls, black/red #23 jersey with hoodie
influence, black shorts, white compression sleeve on the left leg, black/red shoes.
Stylized realism — NBA Live 16 locomotion feel, NBA Jam readability, Spider-Verse silhouette,
Arcane-adjacent painterly materials, sunset streetball palette. **Never** photoreal 2K, never
anime, never cel-plastic.

**The single highest priority is the BACK silhouette** — the player is viewed from behind ~95%
of gameplay. Hair shape, shoulder mass, jersey #23, leg sleeve, and shoes must identify the
player instantly from the rear at mobile resolution.

**Camera occupancy (correction to brief):** target **28–35% of frame height**, not 65%.
The locked B4 framing (hoop upper third, player lower third, mid-court cut) and the owner's
explicit "zoom out" feedback both contradict 65%. If composition changes later, it changes via
the TUNE sliders — the character is authored to read at 28–35%.

## 1. Character Production Plan (staged, honest for a solo+AI pipeline)
- **Stage A — Mesh (1 Higgsfield session):** multi-image→3D from the prepped turnaround views
  (`assets/character/reference/`), texturing + PBR + rigging enabled. Acceptance: heroic
  proportions per §3, clean back silhouette, painted texture (not glossy). Re-roll rather than fix.
- **Stage B — Rig hardening (½–1 day):** verify humanoid hierarchy (§5), fix skinning hotspots
  (shoulders, hips, hoodie collar), confirm Godot import.
- **Stage C — Tier-1 animation (1–2 days):** the 9 clips in §7 Tier 1, retargeted from
  Mixamo/library sources onto the master rig. Ships with the mesh swap.
- **Stage D — Tier-2/3 animation:** content drops post-swap (see roadmap §7).
- **Stage E — Avatar-template hardening:** lock the skeleton + UV layout as the master template
  for the future AI-avatar system (§13).

## 2. Modeling Workflow
- Source: AI generation (Higgsfield multi-image→3D) from the 5 keyed turnaround views.
- Target: **single skinned mesh**, 15–25k tris for the hero (mobile headroom for court + ball +
  FX). If generation returns higher, decimate with silhouette preservation (Blender: Decimate w/
  planar protection on face/hands, or Quad Remesher if available).
- Proportion pass in Blender (cheap lattice/proportional edit): +shoulder width ~8%, +arm length
  ~5%, +hand scale ~10%, +shoe scale ~12%. Small nudges — heroic, not cartoon.
- Separate material check: hoodie/jersey must not fuse into the neck in silhouette; carve the
  collar gap if the generator merged it.

## 3. Silhouette & Readability Spec
- Read test at 25% render scale (simulates iPhone at gameplay distance): hair mass, shoulder
  taper, #23 blob, sleeve contrast, shoe blocks must each read as distinct shapes.
- Value contrast: jersey darkest, skin mid, sleeve/sock lightest — the back reads as three value
  bands even in shadow.
- No thin free-floating elements (strings, tags) — they alias at mobile res and cost bones.

## 4. Material Workflow
- **One material, one atlas.** Single 2048 atlas (1024 on low-tier LOD/quality setting):
  body+head+hair+kit packed together. Layout in §15.
- StandardMaterial3D, stylized PBR: metallic 0, roughness 0.55–0.85 painterly variation baked
  into the roughness map (brush-noise), albedo carries the painted brushwork.
- Warm response: albedo authored slightly desaturated; the scene's sun/grade supplies the sunset
  warmth — do NOT bake orange light into the texture or it double-warms.
- Rim light: cheap fresnel emission (subtle, warm cream) via material rim parameters or a 10-line
  shader — this is the "Spider-Verse pop" against the dusk backdrop.
- Soft cel influence: OPTIONAL quantized-diffuse shader variant behind a quality toggle; ship
  standard PBR first, evaluate cel pass after the court screenshot test.

## 5. Rigging Workflow
- **Humanoid standard skeleton** (Mixamo-compatible naming): Hips→Spine→Spine1→Spine2→Neck→Head;
  Shoulder/Arm/ForeArm/Hand L+R (hands: 3-bone fingers max, thumb 3); UpLeg/Leg/Foot/ToeBase L+R.
  **~55–65 bones total.** No facial rig v1 (expressions via head/neck posing + timing).
- 2 extra utility bones: `ball_hand_R` and `ball_hand_L` (child of each hand) — the ball-constraint
  targets (§8). 1 `root` motion bone at origin.
- Skinning: max 4 influences/vertex (mobile), audit shoulders/hips/hoodie.
- **Retarget-ready is the contract:** this exact hierarchy is the master template every future
  AI-avatar inherits. Freeze it after Stage B; appearance changes never touch bones.

## 6. Recommended Software & Sources
- Mesh gen: Higgsfield multi-image→3D (+rigging flag). Fallback: single-image→3D from ¾ view.
- Cleanup/proportions/skin audit: **Blender** (free, GLB round-trips with Godot cleanly).
- Auto-rig fallback: Mixamo (upload → markers → rigged FBX → Blender → GLB).
- Animation sources: **Mixamo** (locomotion, jumps, celebrations — free), plus the rig provider's
  animation library for basketball-specific clips; hand-key touch-ups in Blender NLA.
- Compression/import: Godot 4 native GLB importer, animation compression ON.

## 7. Animation Pipeline — TIERED (the 36-clip list, staged for reality)
**Tier 1 — ships with the mesh swap (maps 1:1 to EXISTING game hookups; 9 clips):**
Idle, Idle-Dribble, Walk-Dribble, Run-Dribble, Crossover (L/R mirror), Behind-Back, Step-Back,
Gather→Jump-Shot, Celebrate. *(Existing events: idle/walk/run/dodge/throw/cheer — remap in the
AnimationTree, never rename game events.)*
**Tier 2 — first content drop (shot variety; 8):** Three-Pointer variant, Floater, Right/Left
Layup, Euro Step, One-Hand Dunk, Two-Hand Dunk, Landing.
**Tier 3 — style drops (12+):** Between-Legs, In&Out, Hesitation, Spin, Hop Step, Finger Roll,
Reverse Layup, Windmill, Tomahawk, Reverse Dunk, Defensive Slide, Flex/Point/Dance/Defeat/Victory.
**Philosophy on every clip:** anticipation → weight → follow-through → recovery. If a retargeted
clip feels robotic, fix timing (offset keys 2–4 frames) before touching poses.

## 8. Ball Handling — PROCEDURAL, not baked (correction to brief)
The build already has a physics basketball with dribble-follow. Keep it. Architecture:
- Ball remains a RigidBody; animations DO NOT contain a ball.
- Dribble clips author the hand path; the `ball_hand_*` bones expose the target.
- A small `BallCourtship` script: during dribble states, drive the ball toward the active hand
  target with a spring (lead the hand, never snap); on bounce, brief non-uniform scale squash
  (0.92 y, 1.05 xz, 60ms) for compression; outside dribble states, pure physics.
- Result: synchronized but alive — the exact "never glued to the hand" feel the brief demands,
  and shot/pass physics stay untouched.

## 9. Locomotion & BlendTree Architecture
```
AnimationTree (root: BlendTree)
├─ Locomotion: BlendSpace1D (param: speed 0..1)
│    idle(0) — walk(0.35) — run(0.7) — sprint(1.0)      [dribble variants via a 2nd BlendSpace
│                                                        selected by has_ball]
├─ UpperBody override layer (Blend2 + filter: spine2/arms/head)
│    → gather/shoot, celebrations play over locomotion legs
├─ OneShot slots: crossover, behind_back, step_back, dunk_*, layup_*  (interrupt rules §10)
└─ Root motion: OFF for locomotion (controller-driven), ON for dunk/layup travel clips
```
Speed param fed from stick magnitude (already implemented). Upper/lower split is the layer
filter — one tree, no duplicate states.

## 10. State Machine (gameplay states, drives the tree)
```
            ┌────────────── stick ──────────────┐
 IDLE ⇄ LOCOMOTE ── flickL/R ──► CROSSOVER ─┐
   │        │                                │ (auto-chain window 200ms)
   │        ├── flickDown ──► BEHIND_BACK ───┤──► back to LOCOMOTE
   │        └── flickBack ──► STEP_BACK ─────┘        │
   │                                                  ▼
   └── hold SHOOT ──► GATHER ──► (release) ──► SHOT_[jump|floater|layup|dunk by zone]
                                              ──► LANDING ──► (made? CELEBRATE) ──► LOCOMOTE
```
**Street Stick contract:** every move exits into LOCOMOTE with a 200ms chain window that accepts
the next flick — combos are a state-machine property, not special-case code. QuarterCircle→Spin
reserves a Tier-3 slot; the input parser ships now, the clip later.

## 11. Godot Integration Strategy
1. GLB → `assets/character/hero23/` (mesh+rig+Tier-1 clips in one file, or clips as sibling GLBs
   sharing the skeleton).
2. Apply existing 2.6m auto-scale; feet-on-floor check.
3. Build the AnimationTree per §9; remap existing events (dodge→crossover etc.).
4. `BallCourtship` script on the ball, targets = `ball_hand_*` bones.
5. Material check: metallic 0, painterly roughness; rim fresnel on.
6. B4 camera framing MUST be live first (already shipped).
7. Verify loop: headless-validate → export → deploy → screenshot. Acceptance: back-view screenshot
   on the warmed court passes the Design Bible test.

## 12. Performance & Optimization Checklist
☐ Single skinned mesh ≤25k tris ☐ 1 material / 1 atlas (2048→1024 quality tier)
☐ ≤4 bone influences/vertex ☐ ~55–65 bones ☐ Animation compression on import
☐ No per-frame material param writes ☐ Shadow: hero casts, cheap blob under ball
☐ LOD: **skip LOD v1** — one hero at fixed camera distance never LODs; revisit only when
multiple avatars share a court (Friends mode) ☐ 60fps on iPhone 12-class as the floor

## 13. Future AI-Avatar Template Contract
This rig IS the master template. Locked after Stage B: bone hierarchy + names, UV atlas layout,
material slot count, animation clip names. The avatar system generates ONLY: albedo/roughness
textures + bounded morph deltas (face/hair/build) on the same topology. Every scanned player
inherits every animation forever. Any future change to the skeleton is a versioned migration,
not an edit.

## 14. Risks & Mitigation
| Risk | Mitigation |
|---|---|
| Gen mesh has phantom geometry (sheet bleed) | Re-roll with solo-isolated views (documented in MESH_SWAP.md) |
| Gen rig deforms badly at shoulders | Mixamo re-rig fallback; worst case manual weight pass on 4 hotspots |
| Retargeted anims feel robotic | Timing-offset pass first; hand-key only the top 3 clips (idle-dribble, gather-shoot, crossover) |
| 36-clip scope creep | Tier gates are hard: Tier 1 ships, Tiers 2–3 are LiveOps content |
| Texture reads plastic in-engine | Roughness brush-noise + rim fresnel; never fix by adding lights |
| Camera/scale mismatch on swap | B4 framing is a hard prerequisite (shipped) |

## 15. Naming Conventions & Folder Structure
```
assets/character/
  hero23/
    hero23_mesh.glb            # mesh + skeleton + Tier1 clips
    hero23_albedo.png          # 2048 atlas  (layout: head/hair top-left, torso top-right,
    hero23_roughness.png       #              legs bottom-left, arms/hands/shoes bottom-right)
    anims/
      anim_idle.glb  anim_idle_dribble.glb  anim_walk_dribble.glb  anim_run_dribble.glb
      anim_crossover.glb  anim_behind_back.glb  anim_stepback.glb
      anim_gather_shoot.glb  anim_celebrate.glb
  reference/                   # (already populated — turnarounds + hero backview)
scripts/character/
  ball_courtship.gd  hero_anim_controller.gd
```
Clips: `anim_<verb>[_<variant>]`. Bones: Mixamo-standard + `ball_hand_L/R` + `root`.
Materials: `mat_hero23`. Never rename after Stage B lock (§13).

## 16. Timeline (solo + AI pipeline, honest)
- Day 0 (credits land): Stage A mesh gen + accept/re-roll — **half a day**
- Day 0–1: Stage B rig hardening — **half–1 day**
- Day 1–2: Tier-1 retarget + BallCourtship + integration + deploy — **1–2 days**
- Week 2+: Tier 2 as the first content drop; Tier 3 rides the LiveOps calendar.
**Playable hero in-game: ~3 days from credits landing.** The 36-clip full set: a season, by design.

---

## Implementation log (Claude Code)
- 2026-07-01: TDD committed. Shipped ahead of credits: §15 folder structure, §8 BallCourtship
  (spring-follow + bounce squash, running against the placeholder rig today), §10 combo chain
  window (200ms, replaces the flick cooldown that blocked combos), §0 camera occupancy re-tuned
  toward 28–35%.

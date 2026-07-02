# MESH_SWAP.md — #23 Character: `player model.png` → 3D → Godot

The plan for the moment Higgsfield credits recharge. Inputs are already prepped in
`assets/character/reference/` (sliced + alpha-keyed from `player model.png`):
`turnaround_front / front34 / side / back34 / back` (900px, transparent) and
`style_hero_backview.jpg` (vibe reference).

## Step 1 — Generate the mesh (Higgsfield)
- Use **multi-image → 3D** (better geometric accuracy than single-image): feed 2–4 views of the
  SAME subject. Recommended set: `turnaround_front`, `turnaround_side`, `turnaround_back`
  (+ `front34` if a 4th slot helps).
- Enable **texturing + PBR**. Enable **rigging** at generation time if offered — a rigged GLB out
  of the gate skips Mixamo entirely.
- Known input caveat: slight neighbor-figure bleed at view edges (overlapping shoes on the sheet).
  If the mesh picks up phantom geometry, regenerate using single-subject isolation first, or
  re-render one clean isolated view per angle and re-run.
- Art-direction acceptance (Design Bible): painted look, NBA-Jam-ish proportions, black/red #23
  kit, bold silhouette. Never realistic, never anime, never cel-shaded plastic. Reject and re-roll
  rather than "fix later" — the mesh is the hero asset.

## Step 2 — Rig + animations
- If Higgsfield returned an UNRIGGED mesh: run its 3D-rigging pass on the GLB (or Mixamo
  auto-rig fallback: upload GLB/FBX, place markers, download rigged).
- Animation set needed (match current KayKit hookups so code changes are near-zero):
  `idle, walk, run, dodge_left/right (crossover), throw (jumpshot), cheer` — plus wishlist:
  `dribble_loop, dunk, stepback`. Source from the rig provider's animation library or Mixamo
  basketball/locomotion clips; retarget onto the rig.
- Keep the skeleton humanoid-standard so future anim swaps are drop-in.

## Step 3 — Godot import + drop-in swap
1. Import GLB into `assets/character/hero23/`. Godot 4 imports GLB natively; check materials
   came in as StandardMaterial3D with the painted texture (fix metallic=0, roughness high if it
   imports shiny — painted look, not plastic).
2. **Scale to 2.6m** exactly like the KayKit placeholder (existing auto-scale code should apply —
   verify feet on floor, no hover).
3. Point the existing locomotion blend (idle/walk/run off stick magnitude) at the new
   `AnimationPlayer`/`AnimationTree`. Map: dodge→crossover flicks, throw→shoot release,
   cheer→make celebration. Names differ from KayKit's — remap in the AnimationTree, don't rename
   game events.
4. Rotation-to-heading and camera follow are character-agnostic — should just work.

## Step 4 — Verify (existing loop)
- Headless-validate → export → deploy → screenshot-verify.
- Framing check: B4 camera pass MUST already be live (hoop upper third, player lower third) or
  the hero reads tiny — do not ship the swap against the old framing.
- The screenshot test: does #23 standing on the warmed court look like ONE painting with the
  backdrop? That's the acceptance bar.

## Fallback ladder (if generation disappoints)
1. Re-roll with cleaner isolated views (re-render each turnaround angle solo).
2. Single-image → 3D from `turnaround_front34` alone (sometimes beats multi-view on stylized art).
3. Keep KayKit rig one more cycle and swap only the TEXTURE vibe (recolor to black/red #23 kit)
   as a stopgap — identity beats fidelity for now.

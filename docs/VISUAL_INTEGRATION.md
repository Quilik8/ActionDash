# ActionDash visual integration

This is the first playable visual build. Gameplay remains authoritative; imported animation and VFX only represent existing state.

## Runtime mapping

- Player: the in-place humanoid contained in `UAL1_Standard.glb`. `player_visuals.gd` selects `Idle`, `Jog_Fwd`, `Sprint`, `Jump_Start`, `Jump`, `Jump_Land`, `Punch_Cross`, and `Spell_Simple_Shoot`. The model turns toward horizontal velocity, but never applies root motion.
- Ground basic: Skeleton, using Idle, Running, and Death; calibrated to roughly 1.8 m tall.
- Ground variant: Slime, using Idle, Walk, and Death; calibrated to roughly 1.5 m tall. It shares territorial behavior with Skeleton.
- Ground heavy: Spider, using Idle, Walk, and Death. It is roughly 3.8 m wide, appears at a low ratio, and has 4 HP while retaining the same lightweight behavior.
- Flying enemy: Bat, using Flying, Hit, and Death; roughly 2.2 m tall including its wing motion.
- Boss: Dragon, using Flying, Hit, and Death; roughly 8.6 m tall. The existing body hit zone, weak point, vulnerability, HP, and damage rules remain authoritative.

Ground distribution is deterministic per phase: mostly Skeleton, approximately one Slime per three ground spawns and one Spider per ten. Pooled ground instances can swap presentation when reactivated.

## Connected VFX

- Melee: existing logical-radius ring plus Brackeys `slash_02_a` billboard and a short punch animation. A short action lock prevents the animation from restarting for every enemy in a multi-hit.
- Landing: existing radius-scaled disc plus `circle_03_a` and `Jump_Land`.
- SUPER: aura, `trace_03_a` particles, progressive particle amount, Sprint animation, and the existing speed-dependent camera FOV. The old box-shaped speed arrow is intentionally disabled.
- Energy sphere: emissive mesh and trail plus `magic_02_a` particles and a pulsing `light_02_a` halo. Each shot resolves the current camera ray at click time; very close hits are extended along that same ray to prevent third-person parallax from sending the sphere sideways or backward. Damage, size, contact margin, penetration, cooldown, and lifetime remain unchanged.
- Enemy death: the available Death clip, a short `smoke_04_a` flash, and scale-down. The death signal is emitted after roughly half a second, then the existing spawner deactivates and returns regular enemies to the pool.

## Provisional city

`city_visuals.gd` creates nine flat road/plaza surfaces, 30 playable-edge buildings with one simple box collider each, and 28 low-detail skyline buildings outside the playable limits without collision. The result preserves the full 300 x 240 movement area and keeps three long north/south routes, three long east/west routes, and open plazas. Existing ramps and elevated platforms remain as simple gameplay geometry.

Lighting uses one unshadowed directional light and ambient environment lighting for Compatibility renderer performance. Phase-time deterioration still changes the sky/light color.

## Known provisional decisions

- Imported FBX node transforms already contain unit conversion. Runtime scale is deliberately small (`0.36` Skeleton, `0.75` Slime, `0.65` Spider, `0.42` Bat, `1.8` Dragon) and remains independent from damage detection.
- UAL1 contains 43 clips although only eight are used; trimming the library is deferred.
- Skeleton is the best horde model (one material). Bat has six materials and Spider has 59 bones, so both should be monitored before raising simultaneous counts toward 120-200.
- The Dragon weak point remains an emissive sphere so the mechanic stays readable.
- Roads, plazas, ramps, platforms, collision shapes, aim marker, and debug overlay still use simple generated geometry. They are intentional placeholders.
- The supplied Quaternius monster folders contained no dedicated license file; provenance remains documented in `assets/ASSET_INVENTORY.md` and must be confirmed before release.

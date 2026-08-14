# ActionDash asset inventory

Inventory date: 2026-08-13  
Read-only source: `C:\Users\jp_va\Desktop\Nueva carpeta (2)\assets actiondash`

Only selected runtime assets were copied. Original packs, duplicate interchange formats, previews, macOS metadata and source `.blend` files remain untouched in the download folder.

## Packs and selected formats

| Pack/family | Formats found | Selected | Project location | License trace |
|---|---|---|---|---|
| Kenney City Kit Commercial 2.1 | GLB, FBX, OBJ/MTL, PNG textures, HTML documentation | 41 GLB + required `Textures/colormap.png` | `assets/environment/city/kenney_city_kit_commercial/` | CC0; copied to `assets/_licenses/kenney_city_kit_commercial/` |
| Quaternius LowPoly Animated Monsters | FBX, OBJ/MTL, Blend, PNG/JPG previews | 4 animated FBX | `assets/enemies/quaternius_lowpoly_monsters/` | No dedicated license file present in supplied folder; provenance note retained |
| Quaternius Animated Easy Enemies | FBX, OBJ/MTL, Blend, PNG preview | 6 animated FBX | `assets/enemies/quaternius_easy_animated/` | No dedicated license file present in supplied folder; provenance note retained |
| Quaternius Universal Animation Library | GLB and FBX, root-motion and in-place variants, PNG setup guide, TXT docs | In-place `UAL1_Standard.glb` | `assets/animations/quaternius_ual1/` | CC0; license, README and Godot setup copied |
| Quaternius Universal Animation Library 2 | GLB and FBX, root-motion and in-place variants; female mannequin also Blend | In-place `UAL2_Standard.glb` + `Mannequin_F.glb` | `assets/animations/quaternius_ual2/` | CC0; license, README and setup docs copied |
| Brackeys VFX Bundle | PNG particle textures, PNG pre-drawn spritesheets, TGA flipbooks, TXT license | 10 alpha particles, 7 pre-drawn sheets, 2 flipbooks | `assets/vfx/brackeys/` | CC0; license and credits copied |

No packaged Godot project was found in these downloads. Blender was not installed or used.

## Environment catalogue

All 41 City Kit GLBs were selected because the complete GLB family is only about 3.6 MB and contains no duplicate formats inside the project:

- 14 detailed buildings: `building-a` through `building-n`.
- 5 skyscrapers: `building-skyscraper-a` through `building-skyscraper-e`.
- 6 facade/prop details: two awnings, two overhangs and two parasols.
- 16 low-detail buildings, including two wide variants.

The pack contains buildings, facade modules, roof forms embedded in the buildings and small commercial props. It does **not** contain separate road, sidewalk or street-furniture model families, so those categories cannot yet be evaluated from this download.

Complexity reported by the supplied Kenney overview:

- Detailed assets: approximately 76 to 8,485 vertices each.
- Low-detail buildings: approximately 84 to 476 vertices each.
- One imported scene per object, no skeleton and no animations.
- `building-j` is the heaviest individual city model (~8,485 vertices, 0.42 MB), still reasonable for environment use.

## Monster catalogue and preliminary classification

Godot import inspection was performed on every FBX:

| Model | Tentative role | Flying | Meshes / vertices | Materials | Skeleton / animations | Preliminary performance note |
|---|---|---:|---:|---:|---|---|
| Bat | Flying basic | Yes | 2 / ~2,330 | 6 | 28 bones / 5 | Geometry light; material count is higher than ideal for very large hordes |
| Dragon | Flying large / possible boss | Yes | 2 / ~2,970 | 6 | 33 bones / 5 | Good special/boss candidate; avoid mass spawning without material consolidation |
| Skeleton | Ground basic | No | 1 / ~2,105 | 1 | 17 bones / 5 | Best horde candidate in the monster pack |
| Slime | Small ground basic | No | 1 / ~2,912 | 2 | 16 bones / 4 | Good horde candidate |
| Frog | Small ground / jumper | No | 1 / ~9,840 | 4 | 41 bones / 4 | Visually useful but relatively heavy for mass hordes |
| Rat | Small ground basic | No | 1 / ~8,008 | 2 | 42 bones / 6 | Moderate-heavy geometry/skeleton for its role |
| Snake | Ground normal | No | 1 / ~3,258 | 7 | 20 bones / 4 | Geometry acceptable; seven materials are poor for large counts |
| Snake Angry | Ground normal / variant | No | 1 / ~3,450 | 7 | 20 bones / 4 | Same material concern as Snake |
| Spider | Heavy ground / special | No | 1 / ~5,467 | 2 | 59 bones / 5 | High bone count; better as limited heavy enemy |
| Wasp | Flying basic | Yes | 1 / ~7,472 | 4 | 39 bones / 3 | Clear flying candidate, but heavier than Bat for mass spawning |

Animation sets found:

- Bat: Attack, Attack2, Death, Flying, Hit.
- Dragon: Attack, Attack2, Death, Flying, Hit.
- Skeleton: Attack, Death, Idle, Running, Spawn.
- Slime: Attack, Death, Idle, Walk.
- Frog: Attack, Death, Idle, Jump.
- Rat: Attack, Death, Idle, Jump, Run, Walk.
- Snake / Snake Angry: Attack, Idle, Jump, Walk.
- Spider: Attack, Death, Idle, Jump, Walk.
- Wasp: Attack, Death, Flying.

The imported FBX units are very small (~0.01–0.07 m bounds), so `asset_lab_enemies.tscn` applies a non-destructive `50×` exhibit scale. Final gameplay integration will need deliberate scale and collider calibration.

## Humanoid animation libraries

UAL1 and UAL2 each import as:

- 1 skinned mesh (~8,546 vertices);
- 2 material surfaces;
- 1 skeleton with 65 bones;
- 1 AnimationPlayer with 43 animations.

The two libraries have identical ordered bone-name lists. The female mannequin also has the same 65-bone rig (but intentionally contains no animations), confirming direct compatibility between all three references. UAL1 and UAL2 clips can be shared directly on this rig. Retargeting to a future humanoid should be straightforward in Godot if that character maps cleanly to this humanoid skeleton; no retargeting was performed here.

Most relevant clips found:

- UAL1: `Idle`, `Walk`, `Sprint`, `Jump_Start`, `Jump`, `Jump_Land`, `Roll`, `Punch_Jab`, `Punch_Cross`, `Sword_Attack`, `Death01`.
- UAL2: `Melee_Hook`, `Melee_Hook_Rec`, `NinjaJump_Start`, `NinjaJump_Idle`, `NinjaJump_Land`, `Shield_Dash`, `Sword_Dash`, plus several idle and carry locomotion clips.

Root-motion GLBs and all FBX duplicates were intentionally not copied. The two animation GLBs are the largest selected individual assets (~7.7 MB each); acceptable for evaluation, but their full 43-clip libraries should be trimmed when a final player animation set is chosen. The female mannequin is ~25,636 vertices and is reference-only, not recommended as a horde asset.

## VFX selection

Selected alpha particle textures:

- `circle_03_a`, `flare_01_a`, `light_02_a`, `magic_02_a`, `muzzle_03_a`;
- `slash_02_a`, `smoke_04_a`, `spark_03_a`, `trace_03_a`, `twirl_02_a`.

Selected pre-drawn sheets:

- `big_hit`, `charge`, `electric_ring`, `impact_white`, `lightstreaks`, `vortex`, `wavy_blue`.

Selected 8×8 flipbooks:

- `explosion_smoke_01_8x8.tga`;
- `fire_01_8x8.tga`.

Potential mappings: `magic/light/charge` for energy sphere, `slash/big_hit` for melee, `spark/impact_white` for kinetic hits, `circle/electric_ring` for landing, `trace/lightstreaks` for super-speed and `smoke` for enemy death. The lab uses six lightweight GPU particle demonstrations plus the two animated flipbooks. None replaces gameplay VFX.

The TGA flipbooks are 4 MB and 3 MB. They are the heaviest VFX files selected; all other unused flipbooks and duplicate opaque particle variants were excluded.

## Laboratory scenes

- `scenes/dev/asset_lab_environment.tscn`: all 41 city models arranged in seven-column rows.
- `scenes/dev/asset_lab_enemies.tscn`: all 10 monsters, with flying candidates elevated and default Idle/Flying playback.
- `scenes/dev/animation_lab.tscn`: UAL1, UAL2 and female same-rig reference.
- `scenes/dev/vfx_lab.tscn`: six particle demonstrations and two animated flipbooks.

Controls shared by labs: WASF moves the camera, Q/E descends/ascends, Shift accelerates and MMB looks around. Enemy and humanoid animation labs use Left/Right to cycle available clips.

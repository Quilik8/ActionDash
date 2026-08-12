# Technical rules for ActionDash

- Use Godot `4.7.1` and GDScript exclusively.
- Keep the project lightweight and compatible with a Lenovo G50 laptop with AMD A8.
- Prefer the `gl_compatibility` renderer unless a measured need proves otherwise.
- Do not add external assets, plugins, frameworks, or dependencies without explicit justification.
- Keep scenes and scripts small, clear, and easy to validate.
- Keep gameplay responsibilities separated into Player, Camera, Projectile, Enemy,
  EnemySpawner, and ProximityDamage scripts.
- Enemies must remain non-physical for the MVP: no collision bodies, navigation,
  pushing, contact damage, or enemy-to-enemy physics.
- MVP movement controls are WASF: W forward, A left, S backward, F right.
- Do not include `.godot/`, imports, logs, or other generated artifacts in Git.
- After relevant changes, run a lightweight headless Godot validation before continuing.

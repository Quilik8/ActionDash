# Consolidación de gameplay 3D

Estado validado en Godot 4.7.1. Esta iteración consolida sistemas existentes; no añade escenario, dirección visual ni contenido nuevo.

## Movimiento único

- Ya no existen los modos NORMAL/SUPER ni un toggle de movimiento.
- `Q` no está registrada en el `InputMap` y queda libre para uso futuro.
- El movimiento base usa WASF relativo a cámara, órbita con MMB, velocidad inicial `18.0`, máxima `36.0`, aceleración `34.0` y respuesta de giro `12.0`.
- Al recibir dirección, el Player entra inmediatamente a `18.0` y acelera rápidamente hasta la máxima. Al soltar toda dirección, la velocidad horizontal pasa a cero en el siguiente tick físico.
- Los upgrades existentes de `max_speed` y `acceleration` modifican directamente este movimiento único y su restauración base fue verificada.
- Cámara, FOV, trail, daño melee y knockback leen velocidad horizontal real. No dependen de estados SUPER ni cinéticos.

## Aterrizaje normal

Se retiró por completo el Landing Attack ofensivo: no hay consulta de enemigos, daño, knockback, radio, cooldown, señal ofensiva ni stats exportados. El aterrizaje conserva `Jump_Land`, ocho partículas pequeñas de polvo y un shake muy ligero (`0.045`, `0.08 s`). El catálogo actual no contenía cartas ni upgrades de Landing, por lo que no hubo reemplazos.

## Diagnóstico y corrección del jitter

El probe previo a la corrección, a `36.0 u/s`, midió una ruta física estable (`Y span 0`, deriva lateral `0`) y una ruta visible escalonada: `70/119` muestras repetidas seguidas de saltos de `0.6000 m`. No hay root motion ni otro script escribiendo la posición global del Player; `player.gd` es el único responsable del movimiento del cuerpo y `player_visuals.gd` sólo gira el modelo.

La causa era el desfase entre `CharacterBody3D`, actualizado a ticks físicos, y modelo/cámara consumidos desde `_process`, con interpolación física global desactivada. La corrección activa `physics/common/physics_interpolation`, fuerza interpolación ON en Player, OFF en el CameraRig controlado por `_process`, y hace que la cámara siga `get_global_transform_interpolated()`. Los teleports de recuperación y stress resetean el historial de interpolación.

La validación posterior cubre inicio, aceleración, máxima, giro, salto/aterrizaje, parada y reinicio. En máxima, el cuerpo conserva `Y span < 0.001` y deriva lateral `< 0.001`; la ruta render interpolada queda por debajo de `0.4 m` por muestra, eliminando el salto visible de `0.6 m` sin reducir velocidad ni enmascarar la causa con smoothing extra.

## Limpieza focalizada

- Eliminados estados, señales, InputMap dinámico, exports y ramas NORMAL/SUPER.
- Eliminados stats legacy sin consumidores: `momentum` y alias `kinetic_max_bonus`.
- Eliminado todo el pipeline ofensivo de Landing y sus cuatro jets de VFX.
- Renombrado `SuperSpeedParticles` a `SpeedTrailParticles` y `LandingDebrisParticles` a `LandingDustParticles`.
- `ProximityDamage` sólo procesa mientras existe cooldown melee; `RangedPower` sólo procesa mientras existe cooldown ranged.
- Debug reducido a velocidad actual/máxima, velocidad inicial, aceleración, FPS/frame time, enemigos y núcleo.
- No se hizo refactor masivo. Permanecen separados Player, Camera, Projectile, Enemy, EnemySpawner y ProximityDamage.

## Regresiones preservadas

La suite headless moderada `scripts/dev/rework_validation.gd` devuelve `CONSOLIDATION_VALIDATION_OK` y mantiene melee terrestre/aéreo, knockback dependiente de velocidad real, ranged guiado de uno a tres objetivos, mezcla suelo–Bat, weak point, pooling, LOD0/1/2, avance al núcleo, daño al núcleo y derrota. No se ejecutó el stress de 200 enemigos por límite explícito de esta iteración.

Deuda diferida: la prueba visual interactiva en hardware AMD sigue siendo recomendable para confirmar percepción final del encuadre y MMB; no bloquea la validación estructural y dinámica headless. El fallback AMD/ANGLE puede emitir un warning de driver, pero no apareció un error de proyecto en esta consolidación.

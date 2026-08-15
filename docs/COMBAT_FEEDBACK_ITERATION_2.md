# ActionDash — combate, LOD y ranged guiado

> Registro histórico. La consolidación vigente elimina SUPER y el Landing Attack ofensivo; consultar `docs/GAMEPLAY_CONSOLIDATION.md`.

Fecha: 2026-08-14
Motor: Godot 4.7.1, `gl_compatibility`

## Melee y muertes

`LMB` consume su cooldown y emite `melee_hit` incluso sin objetivos. En vacío solo reproduce el punch y el feedback visual; no aplica daño, no crea objetivo artificial y no mueve al Player. Con objetivo conserva la selección asistida terrestre y aérea, el daño y el knockback.

El knockback letal de melee es independiente del no letal: parte de `30.0` y llega a `75.0` cuando la velocidad pasa de NORMAL a SUPER máxima. La duración y el impulso vertical siguen siendo parámetros separados. El proyectil tiene su propia reacción letal moderada (`24.0`) para no mezclar balance de RMB con el golpe manual.

Los enemigos conservan escala completa durante el Death clip, humo, giro y lanzamiento. El spawner solo los devuelve al pool cuando termina esa reacción; no hay interpolación de escala hacia un modelo pequeño.

## Landing Attack

La lógica permanece fija: mínimo de aire/caída, radio `5.0`, daño `1.4`, knockback radial y cooldown existentes. La señal también se emite sin enemigos para que un aterrizaje válido no quede visualmente mudo.

El feedback se compone de polvo de humo, fragmentos con gravedad y cuatro jets direccionales con cantidades bajas, posiciones ligeramente descentradas y direcciones distintas. No usa esfera, anillo, disco ni shockwave circular limpia. El shake de cámara es breve y ligero (`0.14`, `0.12 s`).

## LOD de enemigos

Cada enemigo terrestre y Bat conserva lógica, grupos, spawn y objetivo, pero cambia la representación por distancia:

- `LOD0`: hasta la distancia detallada; modelo FBX, AnimationPlayer y VFX de hit/death.
- `LOD1`: distancia media; proxy estático de silueta por especie, sin AnimationPlayer activo y con lógica escalonada.
- `LOD2`: distancia lejana; `MultiMesh` por especie y transform barato, sin esqueleto ni VFX innecesario.

Las especies del spawner son Skeleton, Slime, Spider y Bat. Los proxies son meshes de cajas/siluetas o blob de bajo detalle con materiales propios; no se reutiliza el cilindro rojo genérico. Las transiciones tienen histéresis de `3.0` unidades y los lotes lejanos se actualizan cada `0.1 s`.

## RMB: esfera guiada y cadena

RMB conserva su cooldown independiente y dispara una esfera de tamaño visual `1.1`, con trail, halo energético, flash de lanzamiento y flash breve al cambiar de objetivo. La adquisición inicial se hace una vez con la dirección del cursor, un cono de `6.0` unidades y distancia de disparo; no busca detrás del Player ni exige apuntado pixel-perfect.

Después de cada impacto, la esfera registra el ID alcanzado, busca una sola vez el enemigo distinto más cercano dentro de `chain_search_radius = 12.0`, redirige de forma arcade y continúa hasta un máximo de tres objetivos. Puede encadenar enemigos terrestres y aéreos, no genera AoE y no ejecuta una consulta global por frame. Si no existe el siguiente objetivo, termina normalmente.

El weak point del boss se evalúa antes del cuerpo y recibe prioridad cuando la línea del cursor pasa intencionalmente por él. Así un enemigo normal cercano no roba un disparo deliberadamente dirigido al weak point; un disparo que no pasa por el weak point sigue pudiendo adquirir el cuerpo del boss mediante la misma selección direccional.

## Validación

`scripts/dev/rework_validation.gd` verifica movimiento WASF/SUPER preservado, melee con y sin objetivo, caso aéreo con Bat, valores 30/75, escala durante muerte, Landing Attack, pooling, LOD0/1/2 para suelo y Bat, ranged de uno/dos/tres/más de tres, mezcla suelo–Bat–suelo, weak point del boss y derrota del núcleo. La ejecución headless final devuelve `REWORK_VALIDATION_OK`.

El debug de cadena (`debug_chain_targeting`) existe como export temporal y está desactivado en la escena normal. No se repitió un stress test masivo de 200 enemigos porque la solicitud pide priorizar la validación funcional y mantener el proyecto ligero.

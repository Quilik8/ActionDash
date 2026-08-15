# Mining MVP 2D

Primer prototipo funcional de minería lateral para Godot 4.7.1. Su objetivo es probar perforación por movimiento, carga por peso, expulsión LIFO, depósito y transición con la run 3D. No define todavía arte, economía final ni el loop Wave/Mine/Wave.

## Escena y arquitectura

- Escena: `res://scenes/mining/mining_mvp.tscn`.
- `MiningTerrain`: grid lógico de `40 x 36` celdas dibujado por un solo `Node2D`; no crea un nodo por bloque.
- `MiningMech`: cabeza/taladro y cinco segmentos dibujados como placeholders. El cuerpo sigue un historial corto de posiciones, sin IK ni física compleja.
- `LooseOre`: instancia ligera únicamente para ores extraídos o expulsados.
- `RunSession`: autoload mínimo que conserva `extracted_value`, cantidades por ore, seed y las escenas alternadas.
- Configuración: `resources/mining/mining_mvp_config.tres`, con Resources separados para bloques y ores.

Al cambiar de sección, una escena queda fuera del árbol y la otra pasa a ser `current_scene`. No se renderizan ni procesan 2D y 3D simultáneamente. Mantener ambas instancias cacheadas preserva exactamente fase, enemigos, túneles y ores sueltos; serializar y descargar completamente esas escenas queda diferido hasta conocer el loop definitivo.

## Controles

- WASF: mover el meca y perforar al mantener dirección contra terreno.
- `E`: expulsar una unidad, siempre LAST IN → FIRST OUT.
- `M` en superficie 3D: entrar temporalmente al Mining MVP.
- `M` dentro de la zona azul superior: depositar cargo y regresar a la misma escena 3D.

## Perforación y bloques

El controlador prueba la celda frente al taladro. Si está vacía, mueve la cabeza; si está ocupada, aplica `drill_power * delta`. Al agotar la dureza, la celda se vacía y el meca puede avanzar manteniendo la misma dirección.

Configuración actual:

- SOIL: dureza `6` — aproximadamente `0.5 s` con potencia `12`.
- COMPACT_SOIL: dureza `12` — aproximadamente `1.0 s`.
- ORE_BLOCK: dureza `16` — aproximadamente `1.33 s`.
- ROCK: dureza `24` — aproximadamente `2.0 s`.

El feedback usa shake local de cabeza, barra de progreso y cuatro fragmentos transitorios del color del bloque. No se añadieron sonidos ni assets externos.

## Capas y generación

Seed de prueba por defecto: `814271`, almacenada en `RunSession.mining_seed`. La misma seed reproduce el mismo grid y las mismas vetas.

- Layer 1: filas `0–17`; 68% soil, 22% compact soil, 10% rock y 6 vetas. Garantiza Voltrita y Keronita.
- Layer 2: filas `18–35`; 30% soil, 42% compact soil, 28% rock y 8 vetas. Garantiza Voltrita, Keronita y al menos una veta de Nexalita.

Las vetas son caminatas cardinales pequeñas de `2–4` celdas. Después de generar se abre una entrada de cinco celdas de ancho y cuatro filas de alto. Layer 2 cambia composición y distribución de ores; no multiplica globalmente el HP.

## Ores provisionales

- VOLTRITA: valor `8`, peso `1`, común, color cian.
- KERONITA: valor `24`, peso `2`, menos común, color violeta.
- NEXALITA: valor `70`, peso `3`, rara y garantizada sólo en Layer 2, color naranja.

Al romper ORE_BLOCK aparece un `LooseOre`. Si cabe, se absorbe automáticamente. Si el peso restante no alcanza, permanece físicamente en el túnel para recogerlo después.

## Carga, velocidad y LIFO

Capacidad máxima: `60`. El inventario es `Array[StringName]` y conserva cada unidad en orden exacto. `pop_back()` implementa la expulsión LIFO; el ore aparece detrás del meca en la celda vacía más cercana, espera `0.65 s` para impedir reabsorción instantánea y luego vuelve a ser recuperable.

Estados configurables actuales:

- EMPTY: carga `0`.
- LIGHT: `>0` hasta `45%`.
- HEAVY: `>45%` y `<100%`.
- FULL: `100%`.

La velocidad es `base_speed * (1 - 0.32 * load_ratio)`. Con base `150`, EMPTY usa `150`, 33% usa `134`, 67% usa `118` y FULL usa `102`; el regreso lleno conserva 68% de la velocidad base.

La UI provisional muestra profundidad/capa, carga, estado, velocidad, valor del cargo, valor extraído de la run, seed, avisos y progreso de perforación.

## Depósito y persistencia

En la zona superior, `M` deposita únicamente la pila interna. `RunSession.deposit_items()` incrementa `run_resources[ore_id]` y `extracted_value`, y después el meca vacía peso y orden. Los ores expulsados o bloqueados que permanecen abajo no cuentan como extraídos.

La mina cacheada se reutiliza al entrar por segunda vez: no regenera bloques, no duplica cargo y conserva objetos sueltos. La escena 3D también es la misma instancia, por lo que fase, tiempo, núcleo, enemigos, cartas y upgrades no se reinician.

## Validación

`scripts/dev/mining_validation.gd` comprueba generación repetible, composiciones, garantías, clusters, durezas, perforación continua, avance, LIFO Nexalita/Keronita/Voltrita, reabsorción, EMPTY/LIGHT/HEAVY/FULL, velocidades, ore bloqueado por capacidad, depósito sin duplicación y dos transiciones 3D↔2D. Resultado esperado: `MINING_MVP_VALIDATION_OK`.

La regresión 3D existente permanece en `scripts/dev/rework_validation.gd` y devuelve `CONSOLIDATION_VALIDATION_OK`.

## Optimización de rendimiento

La primera versión tenía tres costes sostenidos innecesarios: `MiningMVP` consultaba el grupo global de ores en cada tick físico, la profundidad de la UI se escribía en cada tick y `MiningMech` llamaba `queue_redraw()` aunque estuviera quieto. Ahora el MVP mantiene una lista local de `LooseOre`, desactiva su `_physics_process` cuando no existen ores pendientes, actualiza profundidad sólo cuando cambia la celda y redibuja el meca sólo mientras perfora.

El terreno dejó de emitir cientos de primitivas Canvas por bloque. Se genera una sola `ImageTexture` de aproximadamente `480×456` píxeles, escalada 2× con filtrado nearest en un único `Sprite2D`; sólo se actualizan las celdas dañadas y la subida de textura se agrupa al final del frame. Esto reduce draw calls, memoria transferida y trabajo de Canvas en el AMD A8 sin cambiar la grid lógica ni el gameplay.

La validación `MINING_MVP_VALIDATION_OK` continúa pasando después de la optimización. Godot MCP sólo conserva el warning del driver AMD que fuerza ANGLE; no hay warnings nuevos de GDScript.

## Deliberadamente pospuesto

Cartas y upgrades de mina, tienda, árbol nuevo, metaprogresión, múltiples mecas, arte final de serpiente, minerales visibles en segmentos, dron, timer de oleada, loop Wave/Mine/Wave, final de expedición, endless mode, audio final, terreno infinito y serialización completa para descargar de memoria ambas escenas.

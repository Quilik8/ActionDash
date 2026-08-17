# Hybrid Loop MVP

Iteración de flujo para Godot 4.7.1. Comprueba la alternancia mínima:

`PREPARACIÓN → MINERÍA → DEFENSA → RECOMPENSA → PREPARACIÓN`.

Cada ciclo comienza con `150` segundos (`2:30`) de gracia. El contador vive en
`RunSession`, continúa avanzando dentro de Mining y no permite spawns durante
la preparación. Al llegar a cero, Mining vuelve automáticamente a la misma
superficie 3D, muestra el aviso de oleada y activa la defensa con el tiempo
normal de la fase. Al completar la oleada y elegir carta comienza otra gracia
de `2:30`.

## Arquitectura de estados

`RunSession` (`scripts/run_state.gd`) es el autoload y fuente única del estado
macro mediante `PhaseState`:

- `PREPARATION`: superficie 3D segura, sin enemigos activos y con el contador
  de gracia activo.
- `MINING`: escena 2D activa; la superficie queda fuera del árbol.
- `DEFENSE`: superficie 3D activa y una única oleada preparada.
- `REWARD`: oleada detenida, gameplay pausado y tres cartas visibles.
- `DEFEAT`: derrota 3D existente.

`PhaseController` sigue siendo el dueño de spawns, detección real de final de
oleada y selección de cartas. Sólo refleja ese estado central para conservar
sus APIs de diagnóstico. `transition_in_progress` bloquea entradas dobles.

Al iniciar la run se limpian recursos y referencia de minería, se restaura el
Player y la cúpula, y el estado queda en `PREPARATION` durante `2:30`; no se
inicia una oleada ni se generan enemigos.
`RunSession` conserva `wave_number`, `extracted_value`, `run_resources`,
`selected_card_id`, `mining_seed`, `dome_integrity` y
`dome_maximum_integrity`.

## Superficie y entrada a Mining

`MiningMVPEntry` sólo muestra `BAJAR A LA MINA [E]` dentro de una zona cómoda
alrededor de la cúpula. Durante `PREPARATION`, `E` abre `¿BAJAR A LA MINA?`
con `BAJAR` y `CANCELAR`. La confirmación llama a `RunSession.enter_mining()`.

La transición retira la superficie del árbol, instancia Mining una sola vez si
es necesario y la hace escena actual. No quedan enemigos, Player, cámara ni
AudioListener 3D procesando mientras Mining está activa.

## Persistencia y carga

La escena `mining_mvp.tscn` se cachea fuera del árbol; no se regenera entre
ciclos ni se serializa cada frame. Se conserva exactamente la instancia con:

- `MiningTerrain.generation_seed` y la grid procedural existente.
- arrays de bloques, ores, health y visibilidad `HIDDEN/EXPOSED/EXCAVATED`.
- bloques rotos, túneles, profundidad/capa y descubrimientos.
- la lista local de `LooseOre` y su posición/retardo de recolección.
- la carga/orden LIFO del único `MiningMech`.

Al regresar, el `RunSession` sigue conservando seed, recursos depositados y
valor extraído. El depósito usa una única llamada a `deposit_items()` y luego
vacía la carga del meca; los ores que quedaron físicamente abajo no se cuentan
como extraídos ni se destruyen.

## Base minera

La entrada superior tiene dos zonas lógicas legibles:

- `MEJORAS [X]`: sólo abre dentro de la zona izquierda. Muestra valor y
  cantidades depositadas, con el texto `TIENDA: POSPUESTA`; emite el hook
  `upgrades_requested` para una futura tienda.
- `REGRESAR A SUPERFICIE [E]`: salida central y zona derecha. Durante la gracia
  deposita la carga y vuelve a la superficie sin iniciar todavía la oleada.

Al confirmar el regreso se deposita la carga si el meca está en la salida y se
retira Mining del árbol. Si la gracia vence mientras se está minando, la
transición automática conserva el cargo del meca y restaura la misma superficie
antes de llamar a `PhaseController.begin_defense()`.

## Defensa, oleada y cartas

La oleada comienza de forma diferida tras restaurar la superficie; el Player y
la UI ya están disponibles antes de llamar a `EnemySpawner.start_phase()`. El
HUD muestra el aviso `OLEADA X` y después el tiempo normal de la fase. Durante
`DEFENSE` la interacción de Mining no existe
porque la escena 2D está fuera del árbol; no se puede bajar mientras atacan
los enemigos.

El final usa la señal real `EnemySpawner.enemy_defeated` y el contador existente.
Cuando llega a cero, el spawner se limpia, la cúpula conserva su integridad
actual y se pasa a `REWARD`. El árbol de cartas existente genera exactamente
tres opciones. La pausa del árbol evita movimiento, daño a la cúpula y avance
temporal mientras se lee.

Al elegir una carta se aplica al Player, se guarda `selected_card_id`, se
avanza a la siguiente configuración de fase y se vuelve a `PREPARATION` con una
nueva gracia de `2:30`, sin iniciar automáticamente la oleada siguiente. La
skill tree antigua queda fuera
de este loop para que la decisión sea una sola carta y el siguiente ciclo pueda
volver a Mining.

## Rendimiento y optimizaciones preservadas

No se reescribió `MiningMech`: sigue siendo una entidad única con historial,
segmentos persistentes y un solo `_physics_process`. `MiningTerrain` mantiene
los chunks fijos `8 x 9`, la actualización incremental de chunks sucios y la
visibilidad cardinal. No se añadieron nodos por celda, procesos por segmento,
físicas individuales ni snapshots continuos.

Sólo la escena actual está dentro del árbol: retirar la otra detiene su física,
animaciones y generación sin mantener dos juegos corriendo. La memoria usada
por la mina es su instancia cacheada, a cambio de no reconstruir ni perder el
estado de exploración.

## Validación

- `scripts/dev/mining_validation.gd` → `MINING_MVP_VALIDATION_OK`.
- `scripts/dev/rework_validation.gd` → `CONSOLIDATION_VALIDATION_OK`.
- `scripts/dev/hybrid_loop_validation.gd` → `HYBRID_LOOP_MVP_VALIDATION_OK`.

La validación híbrida comprueba dos ciclos consecutivos, la misma instancia de
mina, seed/grid/túnel persistentes, depósito sin duplicación, estado seguro
inicial, confirmaciones `E`, `MEJORAS` restringido por zona, oleadas, tres
cartas, pausa de recompensa, transición de vuelta a `PREPARATION` y ausencia
de enemigos sobrantes tras cada recompensa.

La comprobación headless de la escena principal no produjo errores de proyecto.
El warning anterior de Godot sobre el directorio temporal global se evita usando
`.tmp-godot` local durante las validaciones; no se detectaron warnings nuevos de
GDScript. La validación visual interactiva en el Lenovo/AMD sigue siendo
recomendable para percepción de UI y cámara.

## Pospuesto deliberadamente

Quedan fuera: upgrades reales mediante ores, tienda, recompensas aleatorias en
Mining, eject/rework de ores, metaprogresión,
nuevos mecas o robots, objetivo profundo, endless, arte final y serialización
completa a disco. La integridad de la cúpula mantiene el comportamiento actual:
el daño persiste porque se conserva la misma instancia 3D; no se añade
regeneración automática.

# Mining Exploration Iteration

Iteración de exploración sobre el MVP existente de Godot 4.7.1. No reimplementa movimiento, perforación, carga, LIFO ni transición 3D/2D.

## Arquitectura preservada

- `MiningMech` sigue siendo una entidad única con historial de posiciones, cinco segmentos persistentes y un único `_physics_process`.
- El movimiento continúa usando WASF, perforación por contacto, velocidad base `150` y penalización progresiva por carga.
- `MiningTerrain` mantiene arrays lógicos de bloques, ores y health. El render usa chunks fijos de `8 x 9` celdas, no nodos por bloque.
- `MiningMVP` mantiene la lista local de `LooseOre`, el procesamiento desactivado cuando no hay objetos pendientes y la UI actualizada por eventos/cambio de celda.

## Visibilidad

Cada celda tiene uno de estos estados persistentes:

- `HIDDEN`: sólido no explorado; se pinta oscuro y no muestra bloque ni ore.
- `EXPOSED`: sólido que limita cardinalmente con un túnel; muestra material y ore contenido.
- `EXCAVATED`: celda perforada; permanece como túnel conocido.

La entrada inicial se marca como `EXCAVATED`. Cada rotura marca la celda como `EXCAVATED` y revisa únicamente sus cuatro vecinos cardinales. Un vecino sólido pasa a `EXPOSED`; un vecino ya vacío permanece `EXCAVATED`. No se usan diagonales, raycasts masivos, fog-of-war temporal ni recorrido completo por frame.

Los cambios de visibilidad marcan los chunks afectados. Cada chunk repinta su imagen pequeña y actualiza sólo su `ImageTexture`; no se vuelve a subir el mapa completo. Esto conserva la optimización medida del render AMD/ANGLE.

## Descubrimiento y economía

Un ore sólo se revela cuando su `ORE_BLOCK` pasa de `HIDDEN` a `EXPOSED`. El evento produce un aviso breve y no actúa como radar. Una vez expuesto, el material permanece visible aunque la serpiente se aleje. Al romperlo, sigue funcionando el `LooseOre`, absorción, capacidad, expulsión LIFO y reabsorción existentes.

## Composición procedural

Layer 1 conserva predominio de soil y recibe pockets compactos pequeños. Layer 2 combina más compact soil, roca, pockets blandos, pockets compactos y bandas parciales de roca. Las vetas se generan como caminatas cardinales, con conteo y tamaño por ore:

- Voltrita: frecuente, vetas pequeñas/medias y preferencia Layer 1.
- Keronita: más presente en Layer 2, vetas pequeñas/medias.
- Nexalita: vetas pequeñas/medias exclusivamente en Layer 2.

Las capas mantienen identidades estadísticas y visuales diferentes sin añadir cavernas complejas, generación infinita ni nuevos sistemas de progresión.

## Validación

`scripts/dev/mining_validation.gd` mantiene las regresiones del MVP y añade:

- ore oculto no visible al inicio;
- no revelado por excavación diagonal;
- revelado al abrir un vecino cardinal;
- identidad y feedback del ore descubierto;
- persistencia visible al alejarse.

La regresión 3D se mantiene en `scripts/dev/rework_validation.gd`. Tienda, scanner, upgrades, cartas, metaprogresión, nuevos mecas, timer de oleada, endless mode y loop Wave/Mine/Wave siguen pospuestos.

## Rendimiento observado

La prueba MCP con Godot 4.7.1 sobre AMD R5 usando ANGLE registró aproximadamente `58 FPS` en reposo, `60 FPS` durante perforación y `59 FPS` moviéndose. La escena usa `20` chunks fijos; no se añadieron procesos por segmento, por bloque ni loops globales en `_process()`.

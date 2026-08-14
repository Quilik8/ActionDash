# Estado del rework 3D de ActionDash

## Loop jugable actual

La sección 3D funciona ahora como una defensa provisional. El jugador protege un núcleo central con 1000 puntos de integridad mientras intercepta grupos que llegan desde los cuatro sectores del perímetro. La integridad en cero provoca derrota; el temporizador continúa mostrando el tiempo de fase, pero ya no derrota al jugador al llegar a cero.

No se inició minería 2D, dron, metaprogresión ni ramas nuevas.

## Movimiento

- NORMAL (`Q` apagado): velocidad horizontal fija de 18 con input y parada inmediata sin input.
- SUPER (`Q` encendido): modo preparado persistente. El primer input parte como mínimo a velocidad 18, acelera a 34 unidades por segundo al cuadrado hasta 36 y permite giros arcade con respuesta configurable de 12.
- Soltar todas las direcciones pone la velocidad horizontal en cero inmediatamente sin apagar SUPER. El siguiente input vuelve a acelerar.
- El movimiento sigue siendo relativo a cámara y MMB conserva la órbita.
- La cámara usa velocidad real, no el booleano SUPER: interpola de FOV 70 a 82 y amplía la distancia hasta 1.35x entre velocidad NORMAL y máxima.

## Combate

El clic izquierdo ya no dispara la esfera. Ejecuta un melee manual únicamente cuando encuentra un objetivo válido. Busca en radio 5.2, acepta hasta 4.5 unidades verticales, permite asistencia trasera solo a menos de 2.2, puntúa distancia y alineación, y elige inicialmente un objetivo. La dirección sigue la velocidad del jugador o, estando quieto, la dirección horizontal de la cámara.

El daño de proximidad automático fue retirado. El componente conserva la detección desacoplada y solo actualiza cooldowns. El melee expone daño, radio, número máximo de objetivos y knockback como parámetros independientes.

El daño melee escala de 1x a 2x entre velocidad 18 y 36 mediante una curva de exponente 1.25. El knockback usa otra curva independiente:

`fuerza = 8 + progreso_velocidad^1.2 * 20`

Por tanto, un golpe NORMAL aplica fuerza 8 y uno a velocidad máxima aplica fuerza 28. La dirección combina 68% de dirección de ataque y 32% radial. La duración base es 0.52 s y el impulso vertical 3.2. Enemigos terrestres, voladores y jefe usan trayectorias controladas sin `RigidBody3D`; el jefe conserva solo 20% de la fuerza.

Los enemigos básicos pueden morir de un golpe, pero completan una reacción breve de muerte/knockback antes de volver al pool.

## Landing Attack

El Landing Attack normal sigue siendo automático y no requiere clic. Requiere al menos 0.25 s en el aire y caída de velocidad 2. Su radio es fijo en 5, daño 1.4, knockback radial 9, duración 0.42 s e impulso vertical 2.2.

No existe una variante gigante vinculada a velocidad máxima y su radio no escala con SUPER.

## Escenario y defensa

La superficie jugable es un rectángulo abierto de 220 x 420. Muros, calles y edificios se redistribuyeron para dejar un corredor longitudinal y recorridos largos; se reutilizan los assets provisionales existentes.

El `ProtectedCore` está en el centro, tiene colisión, representación energética, integridad configurable y radio de aproximación. El HUD y debug muestran su integridad.

Los spawns se agrupan en sectores norte, este, sur y oeste. Enemigos terrestres y voladores usan dos etapas baratas: waypoint intermedio con separación de carril y aproximación perimetral al núcleo. Solo atacan al llegar. El jefe avanza hasta su radio de ataque. No se añadió NavigationMesh ni colisión enemigo-enemigo.

## Rendimiento y sistemas conservados

Se mantienen pooling, LOD detallado/simplificado, lotes `MultiMesh`, lógica distante escalonada y reciclaje de instancias. El knockback es una velocidad temporal por enemigo y no crea cuerpos físicos. En esta iteración no se repitió el stress test de 200 enemigos, según el alcance solicitado.

La infraestructura de esfera continúa en `RangedPower`, proyectil, pool y sockets/VFX de la escena para habilidades futuras, pero está desconectada del clic, su proceso físico está desactivado y sus cartas/rama no aparecen en la selección activa. Los nodos visuales antiguos `MuzzleFlash` y `KineticWave` permanecen ocultos sin actualización por frame. La detección antes llamada proximidad se reutiliza exclusivamente para melee y Landing Attack.

## Extensión futura y límites

Los modificadores existentes pueden ajustar daño, radio, objetivos y fuerza de knockback sin unirlos entre sí. Los tipos de impacto viajan como `StringName`, lo que permite efectos secundarios futuros sin construir todavía un framework grande.

Antes de integrar el futuro loop 2D habrá que definir cómo persisten integridad, fases y upgrades entre secciones, y decidir si el temporizador pasa a controlar oleadas o solo puntuación. La debilidad del jefe todavía referencia el proyectil dormido y deberá rediseñarse cuando se defina su combate definitivo.

## Validación breve

`scripts/dev/rework_validation.gd` comprueba en headless: NORMAL fijo/parada, toggle y persistencia SUPER, aceleración y reinicio de dirección, retorno a NORMAL, ausencia de daño por proximidad, melee por clic, diferencia de knockback, Landing Attack fijo/radial y derrota por integridad cero. No genera hordas ni ejecuta un stress test.

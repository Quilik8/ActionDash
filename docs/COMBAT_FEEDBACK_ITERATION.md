# Iteración de feedback de combate 3D

## Inputs

- LMB / `melee_attack`: un golpe por pulsación, cooldown 0.28 s.
- RMB / `ranged_attack`: una esfera de energía, cooldown 3.5 s independiente.
- Q conserva el toggle NORMAL/SUPER; Space conserva el salto.

## Melee y selección

El melee terrestre usa 5.2 unidades horizontales y 2.0 verticales: no incluye automáticamente enemigos claramente elevados. En el aire usa un volumen lógico tipo cápsula/cono frontal de 7.2 horizontales y 6.5 verticales, con asistencia cercana. No crea lock-on ni teletransporta al jugador.

Los objetivos válidos se puntúan por distancia, altura y alineación con la dirección de movimiento/cámara. Se elige uno por defecto (`maximum_targets = 1`), priorizando el más cercano y frontal dentro del volumen.

## Reacciones y pooling

El daño no letal conserva el daño separado del knockback: fuerza 8 normal a 28 en SUPER, duración 0.52 s e impulso vertical 3.2. La muerte usa 15 a 45 de fuerza según velocidad, duración 0.75 s e impulso vertical 6.0. Esto produce una diferencia visible entre un golpe normal y uno a velocidad máxima.

Las trayectorias se simulan con velocidad artificial, arrastre y gravedad simplificada. No se usan `RigidBody3D`. Las instancias muertas dejan el grupo de gameplay, reproducen su reacción y vuelven al pool; al reactivarse se restauran HP, transform, animación, velocidad, estado y visibilidad.

## Ranged

La esfera mantiene tamaño visual `1.1`, margen de contacto `0.14`, trail y halo energético, pero ahora adquiere un primer objetivo por la dirección del cursor y encadena hasta tres enemigos distintos dentro de `chain_search_radius = 12.0`. La búsqueda ocurre al adquirir y al impactar, no en cada frame; no hay explosión ni AoE radial. El weak point del boss tiene prioridad cuando la línea del cursor pasa por él.

## SUPER y Landing Attack

Se eliminó el `KineticAura` esférico. El trail direccional `SuperSpeedParticles`, FOV y distancia dinámica de cámara se conservan.

Landing Attack sigue requiriendo salto/caída válidos y conserva radio 5.0, daño 1.4 y knockback radial. Se eliminaron la esfera, el anillo y cualquier disco genérico de aterrizaje. El feedback es una composición de polvo, fragmentos y cuatro jets direccionales, además de `Jump_Land`, reacción física de los enemigos y shake discreto de cámara.

## Defensa y validación

La integridad provisional de `ProtectedCore` sube de 1000 a 4000; el daño enemigo no se redujo. La UI conserva su formato y muestra el nuevo máximo.

La validación headless `scripts/dev/rework_validation.gd` cubre movimiento preservado, melee con y sin objetivo, caso aéreo con Bat, knockback letal 30–75, muertes sin shrink, Landing Attack, pooling, LOD0/1/2, cadenas ranged de 1/2/3/más de 3, mezcla suelo–Bat–suelo y weak point del boss. El único warning de hardware observado es el fallback del driver AMD a ANGLE.

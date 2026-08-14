# Estado del rework 3D de ActionDash

## Loop jugable actual

La sección 3D funciona ahora como una defensa provisional. El jugador protege un núcleo central con 4000 puntos de integridad mientras intercepta grupos que llegan desde los cuatro sectores del perímetro. La integridad en cero provoca derrota; el temporizador continúa mostrando el tiempo de fase, pero ya no derrota al jugador al llegar a cero.

No se inició minería 2D, dron, metaprogresión ni ramas nuevas.

## Movimiento

- NORMAL (`Q` apagado): velocidad horizontal fija de 18 con input y parada inmediata sin input.
- SUPER (`Q` encendido): modo preparado persistente. El primer input parte como mínimo a velocidad 18, acelera a 34 unidades por segundo al cuadrado hasta 36 y permite giros arcade con respuesta configurable de 12.
- Soltar todas las direcciones pone la velocidad horizontal en cero inmediatamente sin apagar SUPER. El siguiente input vuelve a acelerar.
- El movimiento sigue siendo relativo a cámara y MMB conserva la órbita.
- La cámara usa velocidad real, no el booleano SUPER: interpola de FOV 70 a 82 y amplía la distancia hasta 1.35x entre velocidad NORMAL y máxima.

## Combate

LMB (`melee_attack`) ejecuta un melee manual y RMB (`ranged_attack`) lanza la esfera de energía. El melee terrestre busca en radio horizontal 5.2 con alcance vertical 2.0; el melee aéreo usa un volumen horizontal de 7.2, alcance vertical 6.5, cono frontal permisivo y asistencia cercana. Puntúa distancia, altura y alineación, y elige inicialmente un objetivo. La dirección sigue la velocidad del jugador o, estando quieto, la dirección horizontal de la cámara.

El daño de proximidad automático fue retirado. El componente conserva la detección desacoplada y solo actualiza cooldowns. El melee expone daño, radio, número máximo de objetivos y knockback como parámetros independientes.

El daño melee escala de 1x a 2x entre velocidad 18 y 36 mediante una curva de exponente 1.25. El knockback no letal usa otra curva independiente:

`fuerza = 8 + progreso_velocidad^1.2 * 20`

Por tanto, un golpe NORMAL aplica fuerza 8 y uno a velocidad máxima aplica fuerza 28. La muerte usa un perfil separado de 15 a 45 de fuerza, duración 0.75 s e impulso vertical 6.0; la dirección combina 68% de dirección de ataque y 32% radial. Enemigos terrestres, voladores y jefe usan trayectorias controladas sin `RigidBody3D`; el jefe conserva solo 20% de la fuerza.

Los enemigos básicos pueden morir de un golpe, pero completan una reacción breve de muerte/knockback antes de volver al pool.

## Landing Attack

El Landing Attack normal sigue siendo automático y no requiere clic. Requiere al menos 0.25 s en el aire y caída de velocidad 2. Su radio es fijo en 5, daño 1.4, knockback radial 9, duración 0.42 s e impulso vertical 2.2.

No existe una variante gigante vinculada a velocidad máxima y su radio no escala con SUPER. Los supervivientes reciben desplazamiento, animación Hit y spark reutilizado; las muertes muestran humo, giro y trayectoria a escala completa antes del reciclaje.

## Escenario y defensa

La superficie jugable es un rectángulo abierto de 220 x 420. Muros, calles y edificios se redistribuyeron para dejar un corredor longitudinal y recorridos largos; se reutilizan los assets provisionales existentes.

El `ProtectedCore` está en el centro, tiene colisión, representación energética, integridad configurable y radio de aproximación. El HUD y debug muestran su integridad.

Los spawns se agrupan en sectores norte, este, sur y oeste. Enemigos terrestres y voladores usan dos etapas baratas: waypoint intermedio con separación de carril y aproximación perimetral al núcleo. Solo atacan al llegar. El jefe avanza hasta su radio de ataque. No se añadió NavigationMesh ni colisión enemigo-enemigo.

## Rendimiento y sistemas conservados

Se mantienen pooling, `LOD0` detallado, `LOD1` medio estático y `LOD2` lejano por lotes `MultiMesh`, lógica distante escalonada y reciclaje de instancias. Los proxies se separan por Skeleton, Slime, Spider y Bat; no hay cilindro rojo compartido ni esqueletos animados masivos a distancia. El knockback es una velocidad temporal por enemigo y no crea cuerpos físicos. En esta iteración no se repitió el stress test de 200 enemigos, según el alcance solicitado.

La esfera usa `RangedPower` con cooldown independiente, tamaño visual exportado 1.1 y margen de contacto 0.14. Adquiere por cursor y cono, homing arcade y encadena hasta tres instancias registradas dentro de 12 unidades; no explota ni genera AoE radial. El weak point del boss gana prioridad si el cursor lo apunta intencionalmente. Se eliminó por completo el aura esférica de SUPER; se conserva `SuperSpeedParticles` y el encuadre dinámico de cámara.

## Extensión futura y límites

Los modificadores existentes pueden ajustar daño, radio, objetivos y fuerza de knockback sin unirlos entre sí. Los tipos de impacto viajan como `StringName`, lo que permite efectos secundarios futuros sin construir todavía un framework grande.

Antes de integrar el futuro loop 2D habrá que definir cómo persisten integridad, fases y upgrades entre secciones, y decidir si el temporizador pasa a controlar oleadas o solo puntuación.

## Validación breve

`scripts/dev/rework_validation.gd` comprueba en headless: NORMAL fijo/parada, toggle y persistencia SUPER, aceleración y reinicio de dirección, retorno a NORMAL, ausencia de daño por proximidad, melee con y sin objetivo, melee aéreo contra Bat, knockback letal 30–75, Landing Attack, muerte a escala completa, LOD0/1/2, cadenas ranged de 1/2/3/más de 3, mezcla suelo–Bat–suelo, weak point, reciclaje/reutilización del pool y derrota por integridad cero.

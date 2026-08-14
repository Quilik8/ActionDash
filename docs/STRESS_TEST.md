# Prueba de resistencia

Escenario reproducible: `res://scenes/dev/stress_test.tscn`

## Medición del 13 de agosto de 2026

- Equipo: Lenovo G50, AMD A8 y AMD Radeon R5.
- Renderizador: Godot Compatibility mediante ANGLE, 1280 x 720.
- Referencia normal: 22 enemigos activos, el máximo simultáneo de la fase 2.
- Carga máxima probada: 200 enemigos activos, 9,1 veces la referencia normal.
- Efectos forzados: supervelocidad, partículas de velocidad, aura cinética, melee, onda cinética, impacto de caída, fogonazo, esferas de energía y flecha hacia enemigos.
- El daño se desactiva solo en el laboratorio para conservar los 200 enemigos durante toda la medición.
- La cámara gira a 45 grados por segundo mientras el jugador corre, para recorrer el mapa y cambiar continuamente la vista.

| Carga | Duración | Giro | Recorrido | FPS promedio | Tiempo por cuadro | Mínimo en 0,5 s | Muestras >= 30 FPS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 22 enemigos | 8,3 s | 371,1 grados | 297,0 m | 59,3 | 16,88 ms | 55,8 FPS | 100 % |
| 200 enemigos | 30,1 s | 1.355,0 grados | 1.084,2 m | 52,3 | 19,14 ms | 33,8 FPS | 100 % |

La composición de los 200 enemigos permaneció estable: 99 esqueletos, 49 slimes, 16 arañas y 36 murciélagos. No hubo reinicios de ruta y todos los efectos se confirmaron activos al terminar.

Antes de optimizar, la prueba corta con 200 enemigos promedió 10,0 FPS y bajó a 8,2 FPS. El resultado final usa animación completa cerca del jugador, lógica distante menos frecuente, suspensión de modelos fuera de cámara y `MultiMesh` para agrupar los LOD lejanos. La cámara también suaviza por separado su punto de mira y evita atravesar edificios.

Conclusión: el objetivo de 200 enemigos simultáneos a un mínimo de 30 FPS quedó superado en este equipo. La prueba final promedió 52,3 FPS y su peor intervalo de medio segundo fue 33,8 FPS.

## Repetir la prueba

Ejecutar desde la raíz del proyecto:

```powershell
& 'C:\Users\jp_va\Desktop\Godot\Godot_v4.7.1-stable_win64_console.exe' --path 'C:\Users\jp_va\Desktop\ActionDash' --audio-driver Dummy --resolution 1280x720 res://scenes/dev/stress_test.tscn
```

La prueba calienta cada carga durante 4 segundos, mide 22 enemigos durante 8 segundos y 200 enemigos durante 30 segundos. Al terminar, imprime `STRESS_STAGE` y `STRESS_TEST_RESULT` en JSON y se cierra automáticamente.

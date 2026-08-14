# Prueba de resistencia

Escenario reproducible: `res://scenes/dev/stress_test.tscn`

## Medición del 13 de agosto de 2026

- Equipo: Lenovo G50, AMD A8 y AMD Radeon R5.
- Renderizador: Godot Compatibility mediante ANGLE, 1280 x 720.
- Referencia normal: 22 enemigos activos, el máximo simultáneo de la fase 2.
- Carga máxima probada: 100 enemigos activos, 4,5 veces la referencia normal.
- Efectos forzados durante toda la medición: supervelocidad, partículas de velocidad, aura cinética, melee, onda cinética, impacto de caída, fogonazo de disparo, esferas de energía y flecha hacia enemigos.
- El daño por proximidad se desactiva solo en el laboratorio para conservar una población estable.

| Carga | FPS promedio | Tiempo por cuadro | Mínimo en 0,5 s |
| --- | ---: | ---: | ---: |
| 22 enemigos | 56,7 | 17,65 ms | 51,4 FPS |
| 100 enemigos | 35,9 | 27,89 ms | 26,3 FPS |

La carga de 100 enemigos retuvo el 63,3 % del rendimiento de referencia. Su composición fue: 50 esqueletos, 24 slimes, 8 arañas y 18 murciélagos.

Conclusión: 100 enemigos simultáneos funcionan en este equipo con todos los efectos activados. La experiencia permanece jugable para una prueba extrema, aunque ya no sostiene 60 FPS y presenta caídas breves hacia 26 FPS. Esta cifra es el máximo probado, no necesariamente el punto de fallo absoluto. Una primera ejecución con cachés frías puede sufrir tirones adicionales mientras se preparan modelos y shaders.

## Repetir la prueba

Ejecutar desde la raíz del proyecto:

```powershell
& 'C:\Users\jp_va\Desktop\Godot\Godot_v4.7.1-stable_win64_console.exe' --path 'C:\Users\jp_va\Desktop\ActionDash' --audio-driver Dummy --resolution 1280x720 res://scenes/dev/stress_test.tscn
```

Al terminar, la consola imprime `STRESS_STAGE` para cada carga y un resumen `STRESS_TEST_RESULT` en JSON. El escenario se cierra automáticamente.

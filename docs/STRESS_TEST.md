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

| Carga | Aparición | Duración | Giro | Enemigos movidos | Recorrido medio enemigo | FPS promedio | Mínimo en 0,5 s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 22 enemigos | 61,3 ms | 8,1 s | 365,3 grados | 22 de 22 | 18,8 m | 58,5 | 54,1 FPS |
| 200 enemigos | 465,0 ms | 30,1 s | 1.355,1 grados | 200 de 200 | 46,4 m | 54,8 | 35,4 FPS |

La composición de los 200 enemigos permaneció estable: 99 esqueletos, 49 slimes, 16 arañas y 36 murciélagos. No hubo reinicios de ruta, el 100 % de las muestras quedó sobre 30 FPS y todos los efectos se confirmaron activos. Al terminar, 56 enemigos estaban en conducta de asalto a edificios.

Antes de optimizar, la prueba corta con 200 enemigos promedió 10,0 FPS y bajó a 8,2 FPS. El resultado final usa animación completa cerca del jugador, lógica distante menos frecuente, suspensión de modelos fuera de cámara y `MultiMesh` para agrupar los LOD lejanos. La cámara también suaviza por separado su punto de mira y evita atravesar edificios.

La aparición usa carga diferida: el LOD ligero se muestra inmediatamente y el FBX animado solo se prepara cuando el enemigo entra en el radio cercano. Los enemigos terrestres se desplazan entre edificios, atacan al alcanzar su perímetro y luego eligen otro objetivo; los voladores orbitan las construcciones.

Conclusión: el objetivo de 200 enemigos simultáneos a un mínimo de 30 FPS quedó superado en este equipo. La prueba final con todos los enemigos en movimiento promedió 54,8 FPS y su peor intervalo de medio segundo fue 35,4 FPS.

## Repetir la prueba

Ejecutar desde la raíz del proyecto:

```powershell
& 'C:\Users\jp_va\Desktop\Godot\Godot_v4.7.1-stable_win64_console.exe' --path 'C:\Users\jp_va\Desktop\ActionDash' --audio-driver Dummy --resolution 1280x720 res://scenes/dev/stress_test.tscn
```

La prueba calienta cada carga durante 4 segundos, mide 22 enemigos durante 8 segundos y 200 enemigos durante 30 segundos. Al terminar, imprime `STRESS_STAGE` y `STRESS_TEST_RESULT` en JSON y se cierra automáticamente.

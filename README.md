# ActionDash

MVP jugable 3D de ActionDash en Godot 4.7.1 con GDScript.

## Estado

Este MVP contiene solamente un playground provisional para probar movimiento,
camara, disparo, enemigos y dano por proximidad. La escena diagnostica original
se conserva aparte en `res://scenes/diagnostic.tscn`.

## Ejecutar localmente

Abrir el proyecto en Godot y ejecutar la escena principal:
`res://scenes/gameplay/playground.tscn`.

Controles del MVP:

- `W`: avanzar
- `A`: moverse a la izquierda
- `S`: retroceder
- `F`: moverse a la derecha
- `Space`: saltar
- clic izquierdo: disparar hacia el cursor

El renderer usa `gl_compatibility` para mantener bajo el coste de ejecucion en
hardware antiguo o de gama media-baja.

## Godot MCP para Codex

La configuracion especifica del proyecto esta en `.codex/config.toml`. Usa
`npx.cmd` con `@coding-solo/godot-mcp@0.1.1` y la ruta local detectada mediante
`GODOT_PATH`.

Para no depender de la carpeta temporal global de Windows durante las
comprobaciones del editor, el MCP usa `.codex/runtime-temp` como `TEMP`/`TMP`.
Su contenido esta excluido de Git.

Tras abrir una nueva sesion o reiniciar el cliente local, se puede comprobar con:

```powershell
codex mcp list
```

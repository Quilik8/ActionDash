# ActionDash

MVP híbrido jugable 3D/2D de ActionDash en Godot 4.7.1 con GDScript.

## Estado

El playground 3D y la escena Mining MVP alternan mediante un loop provisional
`PREPARACIÓN → MINERÍA → DEFENSA → RECOMPENSA`. La escena diagnostica original
se conserva aparte en `res://scenes/diagnostic.tscn`. El detalle del loop está en
`docs/HYBRID_LOOP_MVP.md`.

## Ejecutar localmente

Abrir el proyecto en Godot y ejecutar la escena principal:
`res://scenes/gameplay/playground.tscn`.

Controles del MVP:

- `W`: avanzar
- `A`: moverse a la izquierda
- `S`: retroceder
- `F`: moverse a la derecha
- `Space`: saltar
- clic izquierdo (LMB): ataque melee
- clic derecho (RMB): esfera de energía hacia el cursor

El renderer usa `gl_compatibility` para mantener bajo el coste de ejecucion en
hardware antiguo o de gama media-baja.

## Demo para compartir

La demo de Windows se exporta con `WASD` y `U`, mientras que el desarrollo
mantiene `WASF` y `X`. Consulta [docs/DEMO_WINDOWS.md](docs/DEMO_WINDOWS.md)
para generar el ZIP que se puede enviar sin instalar Godot.

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

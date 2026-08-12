# ActionDash

Bootstrap mínimo de un proyecto 3D en Godot 4.7.1 con GDScript.

## Estado

Este repositorio contiene únicamente la configuración inicial y una escena de diagnóstico. No incluye todavía mecánicas, personaje, enemigos, combate, UI, perks ni sistemas Roguelite.

## Requisitos detectados

- Godot `4.7.1.stable.official.a13da4feb`
- Node.js `v24.14.0`
- npm/npx `11.17.0`
- Git `2.50.1.windows.1`

## Ejecutar localmente

Abrir el proyecto en Godot y ejecutar la escena principal. La escena principal es `res://scenes/diagnostic.tscn` y solo contiene cámara, luz, suelo y un cubo de prueba.

El renderer inicial usa `gl_compatibility` para mantener bajo el coste de ejecución en hardware antiguo o de gama media-baja.

## Godot MCP para Codex

La configuración específica del proyecto está en `.codex/config.toml`. Usa `npx.cmd` con `@coding-solo/godot-mcp@0.1.1` y la ruta local detectada mediante `GODOT_PATH`.

Para no depender de la carpeta temporal global de Windows durante las comprobaciones del editor, el MCP usa `.codex/runtime-temp` como `TEMP`/`TMP`. Su contenido está excluido de Git.

Tras abrir una nueva sesión o reiniciar el cliente local, se puede comprobar con:

```powershell
codex mcp list
```

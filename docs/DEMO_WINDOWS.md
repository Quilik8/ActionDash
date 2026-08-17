# Demo Windows para compartir

El proyecto de desarrollo conserva los controles actuales `WASF` y `X`.
La build de demo usa un perfil de exportación separado con `WASD` y `U`:

- `W`, `A`, `S`, `D`: movimiento.
- `U`: mejoras en Mining.
- `E`: interacción.
- `Space`: salto.
- `Q`: expulsar ore.
- LMB/RMB: ataques 3D.

## Crear el paquete

No hace falta instalar Godot en el equipo del amigo. En el equipo de
desarrollo, desde la raíz del proyecto:

```powershell
& .\scripts\build_friend_demo.ps1 `
  -GodotPath "C:\ruta\a\Godot_v4.7.1-stable_win64_console.exe"
```

El paquete queda en:

`releases\ActionDash_Demo_WASD_U_Windows.zip`

Si Godot informa que no encuentra las plantillas de exportación, hay que
instalar las plantillas oficiales de Godot `4.7.1` en el editor antes de
repetir el comando.

Se debe enviar el ZIP completo. El amigo sólo necesita extraerlo y ejecutar
`ActionDash_Demo_WASD_U.exe`; no debe abrir una escena de Mining aislada.
Debe iniciar la demo desde el ejecutable principal.

La diferencia de controles se activa mediante la feature de exportación
`actiondash_demo`; no cambia `project.godot` ni los controles usados por `F6`
o `F5` durante el desarrollo.

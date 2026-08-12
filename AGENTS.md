# Reglas técnicas de ActionDash

- Usar Godot `4.7.1` y GDScript exclusivamente.
- Mantener el proyecto ligero y compatible con una laptop Lenovo G50 con AMD A8.
- Preferir el renderer `gl_compatibility` mientras no exista una necesidad comprobada de cambiarlo.
- No añadir assets, plugins, frameworks o dependencias externas sin justificación explícita.
- Mantener las escenas y scripts pequeños, claros y fáciles de verificar.
- No implementar gameplay, combate, UI, perks ni sistemas Roguelite durante el bootstrap.
- No incluir `.godot/`, imports, logs ni otros artefactos generados en Git.
- Después de cada cambio relevante, ejecutar una comprobación headless de Godot antes de continuar.

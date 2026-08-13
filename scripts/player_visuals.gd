class_name ActionDashPlayerVisuals
extends Node3D

@export var enable_temporary_vfx: bool = true

var _proximity_timer: float = 0.0
var _wave_timer: float = 0.0
var _landing_timer: float = 0.0
var _muzzle_timer: float = 0.0

@onready var _body: MeshInstance3D = $Model/Body
@onready var _kinetic_aura: MeshInstance3D = $VFX/KineticAura
@onready var _speed_trail: MeshInstance3D = $VFX/SpeedTrail
@onready var _proximity_flash: MeshInstance3D = $VFX/ProximityFlash
@onready var _wave_flash: MeshInstance3D = $VFX/KineticWave
@onready var _landing_flash: MeshInstance3D = $VFX/LandingImpact
@onready var _muzzle_flash: MeshInstance3D = $VFX/MuzzleFlash

func _ready() -> void:
	var player := get_parent() as ActionDashPlayer
	player.energy_attack_fired.connect(_on_energy_attack_fired)
	player.proximity_attack.connect(_on_proximity_attack)
	player.kinetic_wave.connect(_on_kinetic_wave)
	player.kinetic_state_changed.connect(_on_kinetic_state_changed)
	player.landing_attack.connect(_on_landing_attack)
	_hide_transient_vfx()

func _process(delta: float) -> void:
	_update_effect(_proximity_flash, "_proximity_timer", delta, 8.0)
	_update_effect(_wave_flash, "_wave_timer", delta, 7.0)
	_update_effect(_landing_flash, "_landing_timer", delta, 8.5)
	_update_effect(_muzzle_flash, "_muzzle_timer", delta, 9.0)

func _on_energy_attack_fired(origin: Vector3, _direction: Vector3) -> void:
	if not enable_temporary_vfx:
		return
	_muzzle_timer = 0.14
	_muzzle_flash.top_level = true
	_muzzle_flash.global_position = origin
	_show_effect(_muzzle_flash, 0.25)

func _on_proximity_attack(_position: Vector3, _targets_hit: int, multiplier: float) -> void:
	if not enable_temporary_vfx:
		return
	_proximity_timer = 0.16
	_show_effect(_proximity_flash, 0.55 + multiplier * 0.08)

func _on_kinetic_wave(_position: Vector3, _targets_hit: int) -> void:
	if not enable_temporary_vfx:
		return
	_wave_timer = 0.24
	_show_effect(_wave_flash, 0.4)

func _on_kinetic_state_changed(active: bool) -> void:
	_kinetic_aura.visible = enable_temporary_vfx and active
	_speed_trail.visible = enable_temporary_vfx and active
	_body.scale = Vector3.ONE * (1.04 if active and enable_temporary_vfx else 1.0)

func _on_landing_attack(_position: Vector3, _targets_hit: int, multiplier: float) -> void:
	if not enable_temporary_vfx:
		return
	_landing_timer = 0.28
	_show_effect(_landing_flash, 0.45 * multiplier)

func _show_effect(effect: MeshInstance3D, initial_scale: float) -> void:
	effect.visible = true
	effect.scale = Vector3.ONE * initial_scale

func _update_effect(effect: MeshInstance3D, timer_name: StringName, delta: float, growth: float) -> void:
	var remaining: float = get(timer_name)
	if remaining <= 0.0:
		return
	remaining = maxf(remaining - delta, 0.0)
	set(timer_name, remaining)
	effect.scale += Vector3.ONE * delta * growth
	if remaining <= 0.0:
		effect.visible = false

func _hide_transient_vfx() -> void:
	_kinetic_aura.visible = false
	_speed_trail.visible = false
	_proximity_flash.visible = false
	_wave_flash.visible = false
	_landing_flash.visible = false
	_muzzle_flash.visible = false

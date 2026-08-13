class_name ActionDashEnergyProjectileVisual
extends Node3D

var _launch_timer: float = 0.0

@onready var _visual_root: Node3D = $VisualRoot
@onready var _orb: MeshInstance3D = $VisualRoot/Orb
@onready var _trail: MeshInstance3D = $VisualRoot/Trail
@onready var _launch_flash: MeshInstance3D = $VFXRoot/LaunchFlash

func _ready() -> void:
	_launch_flash.visible = false

func configure_size(size: float) -> void:
	var safe_size := maxf(size, 0.05)
	_orb.scale = Vector3.ONE * safe_size
	_trail.scale = Vector3(safe_size * 0.75, safe_size * 0.75, safe_size * 2.8)
	_trail.position.z = safe_size * 2.1

func play_launch() -> void:
	_launch_timer = 0.12
	_launch_flash.visible = true
	_launch_flash.scale = Vector3.ONE * 0.2

func _process(delta: float) -> void:
	if _launch_timer > 0.0:
		_launch_timer = maxf(_launch_timer - delta, 0.0)
		_launch_flash.scale += Vector3.ONE * delta * 7.0
		if _launch_timer <= 0.0:
			_launch_flash.visible = false

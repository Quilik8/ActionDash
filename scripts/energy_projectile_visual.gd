class_name ActionDashEnergyProjectileVisual
extends Node3D

const MAGIC_TEXTURE := preload("res://assets/vfx/brackeys/particles/magic_02_a.png")
const LIGHT_TEXTURE := preload("res://assets/vfx/brackeys/particles/light_02_a.png")

var _launch_timer: float = 0.0
var _pulse_time: float = 0.0
var _visual_size: float = 1.0
var _energy_particles: GPUParticles3D
var _energy_halo: Sprite3D

@onready var _visual_root: Node3D = $VisualRoot
@onready var _orb: MeshInstance3D = $VisualRoot/Orb
@onready var _trail: MeshInstance3D = $VisualRoot/Trail
@onready var _launch_flash: MeshInstance3D = $VFXRoot/LaunchFlash

func _ready() -> void:
	_launch_flash.visible = false
	_create_energy_vfx()

func configure_size(size: float) -> void:
	var safe_size := maxf(size, 0.05)
	_visual_size = safe_size
	_orb.scale = Vector3.ONE * safe_size
	_trail.scale = Vector3(safe_size * 0.75, safe_size * 0.75, safe_size * 2.8)
	_trail.position.z = safe_size * 2.1
	if is_instance_valid(_energy_halo):
		_energy_halo.scale = Vector3.ONE * safe_size * 1.55
	if is_instance_valid(_energy_particles):
		_energy_particles.scale = Vector3.ONE * safe_size

func play_launch() -> void:
	_launch_timer = 0.12
	_launch_flash.visible = true
	_launch_flash.scale = Vector3.ONE * 0.2

func play_target_switch() -> void:
	_launch_timer = 0.09
	_launch_flash.visible = true
	_launch_flash.scale = Vector3.ONE * 0.14

func _process(delta: float) -> void:
	_pulse_time += delta
	if is_instance_valid(_energy_halo):
		var pulse := 1.0 + sin(_pulse_time * 11.0) * 0.08
		_energy_halo.scale = Vector3.ONE * _visual_size * 1.55 * pulse
		_energy_halo.rotation.z += delta * 1.8
	if _launch_timer > 0.0:
		_launch_timer = maxf(_launch_timer - delta, 0.0)
		_launch_flash.scale += Vector3.ONE * delta * 7.0
		if _launch_timer <= 0.0:
			_launch_flash.visible = false

func _create_energy_vfx() -> void:
	_energy_halo = Sprite3D.new()
	_energy_halo.name = "EnergyHalo"
	_energy_halo.texture = LIGHT_TEXTURE
	_energy_halo.pixel_size = 0.008
	_energy_halo.modulate = Color(0.45, 0.9, 1.0, 0.78)
	_energy_halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual_root.add_child(_energy_halo)

	_energy_particles = GPUParticles3D.new()
	_energy_particles.name = "EnergyParticles"
	_energy_particles.amount = 16
	_energy_particles.lifetime = 0.45
	_energy_particles.randomness = 0.5
	_energy_particles.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3.ONE * 8.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.65
	quad.orientation = PlaneMesh.FACE_Z
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(0.3, 0.85, 1.0, 0.82)
	material.albedo_texture = MAGIC_TEXTURE
	quad.material = material
	_energy_particles.draw_pass_1 = quad
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.75
	process_material.direction = Vector3(0, 0, 1)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 0.3
	process_material.initial_velocity_max = 1.2
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.25
	process_material.scale_max = 0.7
	_energy_particles.process_material = process_material
	_visual_root.add_child(_energy_particles)
	_energy_particles.emitting = true

extends Node3D

const DEMOS := [
	["Esfera / energía", "res://assets/vfx/brackeys/particles/magic_02_a.png", Color(0.2, 0.8, 1.0)],
	["Melee", "res://assets/vfx/brackeys/particles/slash_02_a.png", Color(0.7, 0.95, 1.0)],
	["Impacto cinético", "res://assets/vfx/brackeys/particles/spark_03_a.png", Color(0.2, 0.65, 1.0)],
	["Aterrizaje", "res://assets/vfx/brackeys/particles/circle_03_a.png", Color(1.0, 0.55, 0.15)],
	["Supervelocidad", "res://assets/vfx/brackeys/particles/trace_03_a.png", Color(0.15, 0.7, 1.0)],
	["Muerte enemigo", "res://assets/vfx/brackeys/particles/smoke_04_a.png", Color(0.55, 0.3, 0.65)],
]

var _flipbook_sprites: Array[Sprite3D] = []
var _flipbook_frames := [64, 64]
var _elapsed: float = 0.0

func _ready() -> void:
	for index in DEMOS.size():
		_create_particle_demo(index, DEMOS[index])
	_create_flipbook("Explosion + smoke", "res://assets/vfx/brackeys/flipbooks/explosion_smoke_01_8x8.tga", Vector3(-3.5, 1.8, -7.0), 8, 8)
	_create_flipbook("Fire", "res://assets/vfx/brackeys/flipbooks/fire_01_8x8.tga", Vector3(3.5, 1.8, -7.0), 8, 8)

func _process(delta: float) -> void:
	_elapsed += delta
	for index in _flipbook_sprites.size():
		_flipbook_sprites[index].frame = floori(_elapsed * 24.0) % _flipbook_frames[index]

func _create_particle_demo(index: int, definition: Array) -> void:
	var particles := GPUParticles3D.new()
	particles.name = String(definition[0]).validate_node_name()
	particles.position = Vector3((index % 3 - 1) * 5.0, 1.5, floori(float(index) / 3.0) * -5.0)
	particles.amount = 28
	particles.lifetime = 1.2
	particles.randomness = 0.45
	particles.visibility_aabb = AABB(Vector3(-4.0, -4.0, -4.0), Vector3.ONE * 8.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 1.4
	quad.orientation = PlaneMesh.FACE_Z
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = definition[2]
	material.albedo_texture = load(definition[1]) as Texture2D
	quad.material = material
	particles.draw_pass_1 = quad
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3.UP
	process_material.spread = 65.0
	process_material.initial_velocity_min = 1.0
	process_material.initial_velocity_max = 4.0
	process_material.gravity = Vector3(0.0, -1.5, 0.0)
	process_material.scale_min = 0.35
	process_material.scale_max = 1.1
	particles.process_material = process_material
	add_child(particles)
	particles.emitting = true
	_add_label(definition[0], particles.position + Vector3(0.0, 2.3, 0.0))

func _create_flipbook(caption: String, texture_path: String, sprite_position: Vector3, columns: int, rows: int) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = load(texture_path) as Texture2D
	sprite.position = sprite_position
	sprite.hframes = columns
	sprite.vframes = rows
	sprite.pixel_size = 0.004
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sprite)
	_flipbook_sprites.append(sprite)
	_add_label(caption, sprite_position + Vector3(0.0, 2.4, 0.0))

func _add_label(caption: String, label_position: Vector3) -> void:
	var label := Label3D.new()
	label.text = caption
	label.position = label_position
	label.font_size = 42
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

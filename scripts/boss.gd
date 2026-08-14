class_name ActionDashBoss
extends Node3D

signal damaged(amount: float, remaining_health: float)
signal died
signal weak_point_hit
signal vulnerability_changed(active: bool)

@export_category("Boss")
@export var max_health: float = 60.0
@export var resistant_damage_multiplier: float = 0.35
@export var vulnerable_melee_multiplier: float = 3.0
@export var vulnerability_duration: float = 6.0
@export var weak_point_radius: float = 1.44
@export var body_hit_radius: float = 4.2
@export var body_hit_height: float = 4.2

const DRAGON_SCENE := preload("res://assets/enemies/quaternius_lowpoly_monsters/Dragon.fbx")
const DEATH_TEXTURE := preload("res://assets/vfx/brackeys/particles/smoke_04_a.png")

var current_health: float
var _vulnerability_remaining: float = 0.0
var _defeated: bool = false
var _death_timer: float = 0.0
var _dragon: Node3D
var _animation_player: AnimationPlayer
var _death_vfx: Sprite3D
var _hit_timer: float = 0.0
var _current_animation: StringName

@onready var _weak_point: Marker3D = $Detection/WeakPointCenter
@onready var _vulnerability_aura: MeshInstance3D = $VisualRoot/VulnerabilityAura

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	add_to_group("bosses")
	_vulnerability_aura.visible = false
	$VisualRoot/Model/Body.visible = false
	_dragon = DRAGON_SCENE.instantiate() as Node3D
	_dragon.name = "AnimatedDragon"
	_dragon.scale = Vector3.ONE * 220.0
	_dragon.rotation_degrees.y = 180.0
	$VisualRoot/Model.add_child(_dragon)
	var players := _dragon.find_children("*", "AnimationPlayer", true, false)
	_animation_player = players[0] as AnimationPlayer if not players.is_empty() else null
	_create_death_vfx()
	_play_animation("Flying", 0.0, 0.8)

func initialize(home_position: Vector3) -> void:
	global_position = home_position

func _process(delta: float) -> void:
	if _defeated:
		_death_timer = maxf(_death_timer - delta, 0.0)
		$VisualRoot.scale = $VisualRoot.scale.lerp(Vector3.ONE * 0.7, 1.0 - exp(-4.0 * delta))
		if _death_timer <= 0.0:
			visible = false
			set_process(false)
			died.emit()
		return
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	if _hit_timer <= 0.0:
		_play_animation("Flying", 0.16, 0.8)
	if _vulnerability_remaining <= 0.0:
		return
	_vulnerability_remaining = maxf(_vulnerability_remaining - delta, 0.0)
	if _vulnerability_remaining <= 0.0:
		_vulnerability_aura.visible = false
		vulnerability_changed.emit(false)

func is_vulnerable() -> bool:
	return _vulnerability_remaining > 0.0

func get_vulnerability_remaining() -> float:
	return _vulnerability_remaining

func hit_weak_point(projectile_damage: float) -> void:
	if _defeated:
		return
	apply_damage(projectile_damage, &"ranged")
	_vulnerability_remaining = vulnerability_duration
	_vulnerability_aura.visible = true
	weak_point_hit.emit()
	vulnerability_changed.emit(true)

func apply_damage(amount: float, damage_type: StringName = &"generic") -> void:
	if _defeated:
		return
	var multiplier := resistant_damage_multiplier
	if damage_type == &"melee" and is_vulnerable():
		multiplier = vulnerable_melee_multiplier
	var applied_damage := amount * multiplier
	current_health -= applied_damage
	damaged.emit(applied_damage, maxf(current_health, 0.0))
	if current_health <= 0.0:
		_defeated = true
		remove_from_group("enemies")
		remove_from_group("bosses")
		_death_timer = 0.9
		_death_vfx.visible = true
		_play_animation("Death", 0.05, 1.5)
	elif _animation_player != null:
		_hit_timer = 0.18
		_play_animation("Hit", 0.04, 1.4)

func get_projectile_hit_position() -> Vector3:
	return global_position + Vector3.UP * body_hit_height

func get_projectile_hit_radius() -> float:
	return body_hit_radius

func get_projectile_hit_zone(segment_start: Vector3, segment_end: Vector3, projectile_radius: float) -> StringName:
	var weak_closest := Geometry3D.get_closest_point_to_segment(_weak_point.global_position, segment_start, segment_end)
	if weak_closest.distance_squared_to(_weak_point.global_position) <= pow(weak_point_radius + projectile_radius, 2.0):
		return &"weak_point"
	var body_center := get_projectile_hit_position()
	var body_closest := Geometry3D.get_closest_point_to_segment(body_center, segment_start, segment_end)
	if body_closest.distance_squared_to(body_center) <= pow(body_hit_radius + projectile_radius, 2.0):
		return &"body"
	return &"none"

func _play_animation(keyword: String, blend: float, speed: float) -> void:
	if _animation_player == null:
		return
	for animation in _animation_player.get_animation_list():
		if keyword.to_lower() in String(animation).to_lower():
			if _current_animation == animation and _animation_player.is_playing():
				return
			_current_animation = animation
			_animation_player.play(animation, blend, speed)
			return

func _create_death_vfx() -> void:
	_death_vfx = Sprite3D.new()
	_death_vfx.name = "BossDeathSmoke"
	_death_vfx.texture = DEATH_TEXTURE
	_death_vfx.pixel_size = 0.045
	_death_vfx.modulate = Color(0.75, 0.25, 0.18, 0.9)
	_death_vfx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_death_vfx.position.y = body_hit_height
	$VisualRoot.add_child(_death_vfx)
	_death_vfx.visible = false

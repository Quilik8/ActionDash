extends Node3D

const ENEMIES := [
	["Bat", "res://assets/enemies/quaternius_lowpoly_monsters/Bat.fbx", true, "volador"],
	["Dragon", "res://assets/enemies/quaternius_lowpoly_monsters/Dragon.fbx", true, "volador / boss"],
	["Skeleton", "res://assets/enemies/quaternius_lowpoly_monsters/Skeleton.fbx", false, "terrestre"],
	["Slime", "res://assets/enemies/quaternius_lowpoly_monsters/Slime.fbx", false, "terrestre pequeño"],
	["Frog", "res://assets/enemies/quaternius_easy_animated/Frog.fbx", false, "terrestre pequeño"],
	["Rat", "res://assets/enemies/quaternius_easy_animated/Rat.fbx", false, "terrestre pequeño"],
	["Snake", "res://assets/enemies/quaternius_easy_animated/Snake.fbx", false, "terrestre"],
	["Snake Angry", "res://assets/enemies/quaternius_easy_animated/Snake_angry.fbx", false, "terrestre"],
	["Spider", "res://assets/enemies/quaternius_easy_animated/Spider.fbx", false, "terrestre / pesado"],
	["Wasp", "res://assets/enemies/quaternius_easy_animated/Wasp.fbx", true, "volador"],
]

var _players: Array[AnimationPlayer] = []
var _labels: Array[Label3D] = []
var _animation_indices: Array[int] = []

func _ready() -> void:
	for index in ENEMIES.size():
		var definition: Array = ENEMIES[index]
		var packed := load(definition[1]) as PackedScene
		if packed == null:
			push_error("Enemy Lab: no se pudo cargar " + definition[1])
			continue
		var exhibit := Node3D.new()
		exhibit.name = String(definition[0]).validate_node_name()
		exhibit.position = Vector3((index % 5 - 2) * 8.0, 3.0 if definition[2] else 0.0, floori(float(index) / 5.0) * -10.0)
		exhibit.scale = Vector3.ONE * 50.0
		add_child(exhibit)
		var model := packed.instantiate()
		exhibit.add_child(model)
		var player := _find_animation_player(model)
		var label := _add_label(exhibit, "%s\n%s" % [definition[0], definition[3]])
		if player != null:
			_players.append(player)
			_labels.append(label)
			_animation_indices.append(_default_animation_index(player, bool(definition[2])))
			_play_current(_players.size() - 1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_cycle_animations(1)
	elif event.is_action_pressed("ui_left"):
		_cycle_animations(-1)

func _cycle_animations(direction: int) -> void:
	for index in _players.size():
		var names := _players[index].get_animation_list()
		if names.is_empty():
			continue
		_animation_indices[index] = posmod(_animation_indices[index] + direction, names.size())
		_play_current(index)

func _play_current(index: int) -> void:
	var names := _players[index].get_animation_list()
	if names.is_empty():
		return
	var animation_name: StringName = names[_animation_indices[index]]
	_players[index].play(animation_name)
	_labels[index].text = _labels[index].text.get_slice("\nAnim:", 0) + "\nAnim: " + String(animation_name).get_slice("|", 1)

func _default_animation_index(player: AnimationPlayer, flying: bool) -> int:
	var names := player.get_animation_list()
	var preferred := "flying" if flying else "idle"
	for index in names.size():
		if preferred in String(names[index]).to_lower():
			return index
	return 0

func _find_animation_player(root_node: Node) -> AnimationPlayer:
	var players := root_node.find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if not players.is_empty() else null

func _add_label(parent: Node3D, caption: String) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.position = Vector3(0.0, 0.08, 0.07)
	label.scale = Vector3.ONE * 0.02
	label.font_size = 38
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	return label

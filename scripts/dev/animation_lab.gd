extends Node3D

const LIBRARIES := [
	["UAL1 Standard", "res://assets/animations/quaternius_ual1/UAL1_Standard.glb"],
	["UAL2 Standard", "res://assets/animations/quaternius_ual2/UAL2_Standard.glb"],
	["Female reference (same rig)", "res://assets/animations/quaternius_ual2/Mannequin_F.glb"],
]

var _players: Array[AnimationPlayer] = []
var _labels: Array[Label3D] = []
var _indices: Array[int] = []

func _ready() -> void:
	for index in LIBRARIES.size():
		var definition: Array = LIBRARIES[index]
		var packed := load(definition[1]) as PackedScene
		if packed == null:
			push_error("Animation Lab: no se pudo cargar " + definition[1])
			continue
		var exhibit := Node3D.new()
		exhibit.position = Vector3((index - 1) * 4.0, 0.0, 0.0)
		add_child(exhibit)
		var model := packed.instantiate()
		exhibit.add_child(model)
		var label := _add_label(exhibit, definition[0])
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty():
			label.text += "\nSin animaciones (referencia de rig)"
			continue
		var player := players[0] as AnimationPlayer
		_players.append(player)
		_labels.append(label)
		_indices.append(_find_animation(player, "Idle"))
		_play_current(_players.size() - 1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_cycle(1)
	elif event.is_action_pressed("ui_left"):
		_cycle(-1)

func _cycle(direction: int) -> void:
	for index in _players.size():
		var names := _players[index].get_animation_list()
		_indices[index] = posmod(_indices[index] + direction, names.size())
		_play_current(index)

func _play_current(index: int) -> void:
	var name: StringName = _players[index].get_animation_list()[_indices[index]]
	_players[index].play(name)
	_labels[index].text = _labels[index].text.get_slice("\nAnim:", 0) + "\nAnim: " + String(name)

func _find_animation(player: AnimationPlayer, preferred: String) -> int:
	var names := player.get_animation_list()
	for index in names.size():
		if preferred.to_lower() in String(names[index]).to_lower():
			return index
	return 0

func _add_label(parent: Node3D, caption: String) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.position = Vector3(0.0, 2.4, 0.0)
	label.font_size = 42
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	return label

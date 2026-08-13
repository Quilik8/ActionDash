class_name ActionDashRunUI
extends CanvasLayer

signal card_selected(upgrade_id: StringName)
signal skill_selected(upgrade_id: StringName)
signal continue_requested
signal restart_requested

@onready var _phase_label: Label = $HUD/PhaseLabel
@onready var _enemy_label: Label = $HUD/EnemyLabel
@onready var _time_label: Label = $HUD/TimeLabel
@onready var _message_panel: PanelContainer = $Overlay/MessagePanel
@onready var _message_label: Label = $Overlay/MessagePanel/Message
@onready var _cards_panel: PanelContainer = $Overlay/CardsPanel
@onready var _cards_box: HBoxContainer = $Overlay/CardsPanel/Cards
@onready var _tree_panel: PanelContainer = $Overlay/TreePanel
@onready var _points_label: Label = $Overlay/TreePanel/TreeLayout/Points
@onready var _movement_box: VBoxContainer = $Overlay/TreePanel/TreeLayout/Branches/Movement
@onready var _melee_box: VBoxContainer = $Overlay/TreePanel/TreeLayout/Branches/Melee
@onready var _ranged_box: VBoxContainer = $Overlay/TreePanel/TreeLayout/Branches/Ranged
@onready var _continue_button: Button = $Overlay/TreePanel/TreeLayout/Continue
@onready var _restart_button: Button = $Overlay/Restart

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	hide_overlay()

func set_hud(phase_name: String, enemies_remaining: int, time_remaining: float) -> void:
	_phase_label.text = phase_name
	_enemy_label.text = "ENEMIGOS: %d" % enemies_remaining
	var seconds := maxi(ceili(time_remaining), 0)
	_time_label.text = "TIEMPO: %02d:%02d" % [floori(float(seconds) / 60.0), seconds % 60]

func hide_overlay() -> void:
	_message_panel.visible = false
	_cards_panel.visible = false
	_tree_panel.visible = false
	_restart_button.visible = false

func show_phase_complete(phase_name: String) -> void:
	hide_overlay()
	_message_panel.visible = true
	_message_label.text = "%s COMPLETADA" % phase_name

func show_cards(cards: Array[ActionDashRunUpgrade]) -> void:
	hide_overlay()
	_message_panel.visible = true
	_message_label.text = "ELIGE 1 CARTA"
	_cards_panel.visible = true
	_clear_children(_cards_box)
	for upgrade in cards:
		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 125)
		button.text = "%s\n\n%s" % [upgrade.title, upgrade.description]
		button.pressed.connect(func() -> void: card_selected.emit(upgrade.id))
		_cards_box.add_child(button)

func show_skill_tree(catalog: ActionDashUpgradeCatalog, points: int, purchased: Dictionary) -> void:
	hide_overlay()
	_tree_panel.visible = true
	_points_label.text = "PUNTOS DE RUN DISPONIBLES: %d" % points
	_build_branch(_movement_box, "MOVIMIENTO", catalog.movement_tree, points, purchased)
	_build_branch(_melee_box, "MELEE", catalog.melee_tree, points, purchased)
	_build_branch(_ranged_box, "PODER A DISTANCIA", catalog.ranged_tree, points, purchased)

func show_defeat() -> void:
	hide_overlay()
	_message_panel.visible = true
	_message_label.text = "DERROTA"
	_restart_button.visible = true

func show_macrozone_complete() -> void:
	hide_overlay()
	_message_panel.visible = true
	_message_label.text = "MACROZONA COMPLETADA"
	_restart_button.visible = true

func _build_branch(container: VBoxContainer, heading: String, upgrades: Array[ActionDashRunUpgrade], points: int, purchased: Dictionary) -> void:
	_clear_children(container)
	var label := Label.new()
	label.text = heading
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label)
	for upgrade in upgrades:
		var button := Button.new()
		var already_purchased := purchased.has(upgrade.id)
		button.text = "%s\n%s%s" % [upgrade.title, upgrade.description, "\nCOMPRADA" if already_purchased else ""]
		button.disabled = already_purchased or points <= 0
		button.pressed.connect(func() -> void: skill_selected.emit(upgrade.id))
		container.add_child(button)

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

extends Node3D

const CITY_ROOT := "res://assets/environment/city/kenney_city_kit_commercial/"
const CITY_MODELS := [
	"building-a.glb", "building-b.glb", "building-c.glb", "building-d.glb", "building-e.glb", "building-f.glb", "building-g.glb",
	"building-h.glb", "building-i.glb", "building-j.glb", "building-k.glb", "building-l.glb", "building-m.glb", "building-n.glb",
	"building-skyscraper-a.glb", "building-skyscraper-b.glb", "building-skyscraper-c.glb", "building-skyscraper-d.glb", "building-skyscraper-e.glb",
	"detail-awning.glb", "detail-awning-wide.glb", "detail-overhang.glb", "detail-overhang-wide.glb", "detail-parasol-a.glb", "detail-parasol-b.glb",
	"low-detail-building-a.glb", "low-detail-building-b.glb", "low-detail-building-c.glb", "low-detail-building-d.glb", "low-detail-building-e.glb",
	"low-detail-building-f.glb", "low-detail-building-g.glb", "low-detail-building-h.glb", "low-detail-building-i.glb", "low-detail-building-j.glb",
	"low-detail-building-k.glb", "low-detail-building-l.glb", "low-detail-building-m.glb", "low-detail-building-n.glb",
	"low-detail-building-wide-a.glb", "low-detail-building-wide-b.glb",
]

func _ready() -> void:
	for index in CITY_MODELS.size():
		var model_name: String = CITY_MODELS[index]
		var packed := load(CITY_ROOT + model_name) as PackedScene
		if packed == null:
			push_error("Asset Lab: no se pudo cargar " + model_name)
			continue
		var exhibit := Node3D.new()
		exhibit.name = model_name.get_basename().validate_node_name()
		exhibit.position = Vector3((index % 7 - 3) * 18.0, 0.0, floori(float(index) / 7.0) * -18.0)
		add_child(exhibit)
		exhibit.add_child(packed.instantiate())
		_add_label(exhibit, model_name.get_basename(), Vector3(0.0, 0.6, 5.5))

func _add_label(parent: Node3D, caption: String, label_position: Vector3) -> void:
	var label := Label3D.new()
	label.text = caption
	label.position = label_position
	label.font_size = 42
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)

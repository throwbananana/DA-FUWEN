class_name BoardFactory
extends RefCounted

const BoardNodeBaseScene := preload("res://scenes/board/nodes/BoardNodeBase.tscn")
const BoardNodeCampScene := preload("res://scenes/board/nodes/BoardNodeCamp.tscn")
const BoardNodeDojoScene := preload("res://scenes/board/nodes/BoardNodeDojo.tscn")
const BoardNodeEventScene := preload("res://scenes/board/nodes/BoardNodeEvent.tscn")
const BoardNodeHabitatScene := preload("res://scenes/board/nodes/BoardNodeHabitat.tscn")

const TYPE_SHORT := {
	"camp": "营",
	"bulletin": "告",
	"minigame": "游",
	"infirmary": "疗",
	"empty": "空",
	"environment": "境",
	"event": "事",
	"habitat": "居",
	"settlement": "聚",
	"dojo": "试",
	"anomaly": "异",
}

func create_node_actor(node_data: Dictionary, parent: Node) -> Button:
	var actor_scene := _scene_for_type(String(node_data.get("type", "")))
	var actor := actor_scene.instantiate() as Button
	if actor == null:
		return null
	actor.name = "Node_%d" % int(node_data.get("id", -1))
	if parent != null:
		parent.add_child(actor)
	actor.call("apply_definition", node_data, type_short(String(node_data.get("type", ""))))
	return actor

func type_short(type_id: String) -> String:
	return String(TYPE_SHORT.get(type_id, "?"))

func _scene_for_type(type_id: String) -> PackedScene:
	match type_id:
		"camp":
			return BoardNodeCampScene
		"dojo":
			return BoardNodeDojoScene
		"event":
			return BoardNodeEventScene
		"habitat":
			return BoardNodeHabitatScene
		_:
			return BoardNodeBaseScene

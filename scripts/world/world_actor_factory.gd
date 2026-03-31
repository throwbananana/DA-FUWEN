class_name WorldActorFactory
extends RefCounted

const NpcActorScene := preload("res://scenes/world/NpcActor.tscn")
const HabitatActorScene := preload("res://scenes/world/HabitatActor.tscn")

func create_npc_actor(parent: Node, definition: Dictionary, runtime_state: Dictionary = {}) -> Control:
	var actor := NpcActorScene.instantiate() as Control
	if actor == null:
		return null
	var npc_id := String(definition.get("id", "npc"))
	actor.name = "Npc_%s" % npc_id
	if parent != null:
		parent.add_child(actor)
	actor.call("apply_definition", definition)
	actor.call("apply_runtime", runtime_state)
	return actor

func create_habitat_actor(parent: Node, definition: Dictionary, runtime_state: Dictionary = {}) -> Control:
	var actor := HabitatActorScene.instantiate() as Control
	if actor == null:
		return null
	var habitat_id := String(definition.get("id", "habitat"))
	actor.name = "Habitat_%s" % habitat_id
	if parent != null:
		parent.add_child(actor)
	actor.call("apply_definition", definition)
	actor.call("apply_runtime", runtime_state)
	return actor

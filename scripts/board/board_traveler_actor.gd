class_name BoardTravelerActor
extends Control

@onready var glow_rect: ColorRect = $Glow
@onready var body_rect: ColorRect = $Body

var _base_size := Vector2(24, 24)
var _idle_tween: Tween

func configure_actor(actor_color: Color, base_size: Vector2) -> void:
	_base_size = base_size
	body_rect.color = actor_color
	glow_rect.color = Color(actor_color.r, actor_color.g, actor_color.b, 0.18)
	apply_scale_factor(1.0)

func apply_scale_factor(board_scale: float) -> void:
	var actual_size := _base_size * clampf(0.88 + board_scale * 0.12, 0.92, 1.0)
	size = actual_size
	body_rect.position = Vector2.ZERO
	body_rect.size = actual_size
	glow_rect.position = Vector2(-6, -6)
	glow_rect.size = actual_size + Vector2(12, 12)

func play_idle() -> void:
	stop_idle(false)
	_idle_tween = create_tween()
	_idle_tween.set_loops()
	_idle_tween.tween_property(self, "scale", Vector2(1.04, 0.96), 0.45)
	_idle_tween.tween_property(self, "scale", Vector2.ONE, 0.45)

func stop_idle(reset_pose: bool = true) -> void:
	if _idle_tween != null:
		_idle_tween.kill()
		_idle_tween = null
	if reset_pose:
		scale = Vector2.ONE

func reset_pose() -> void:
	scale = Vector2.ONE

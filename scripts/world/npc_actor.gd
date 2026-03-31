class_name NpcActor
extends Control

const BASE_SIZE := Vector2(112, 42)

var _definition: Dictionary = {}
var _highlighted := false
var _idle_enabled := false
var _pulse_time := 0.0

@onready var background: PanelContainer = $Background
@onready var portrait_label: Label = $ContentMargin/ContentVBox/HeaderRow/Portrait
@onready var name_label: Label = $ContentMargin/ContentVBox/HeaderRow/NameLabel
@onready var role_icon: Label = $ContentMargin/ContentVBox/HeaderRow/RoleIcon
@onready var intent_bubble: Label = $ContentMargin/ContentVBox/MetaRow/IntentBubble
@onready var quest_badge: Label = $ContentMargin/ContentVBox/MetaRow/Badges/QuestBadge
@onready var shop_badge: Label = $ContentMargin/ContentVBox/MetaRow/Badges/ShopBadge
@onready var talk_badge: Label = $ContentMargin/ContentVBox/MetaRow/Badges/TalkBadge

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_scale_factor(1.0)
	_apply_background_style()
	set_process(true)

func _process(delta: float) -> void:
	if not _idle_enabled or GameState.prefers_reduced_motion():
		if scale != Vector2.ONE:
			scale = Vector2.ONE
		return
	_pulse_time += delta
	var pulse := 1.0 + sin(_pulse_time * 2.2) * 0.03
	scale = Vector2(pulse, pulse)

func apply_definition(definition: Dictionary) -> void:
	_definition = definition.duplicate(true)
	var display_name := String(_definition.get("name", "访客"))
	var role := String(_definition.get("role", "resident"))
	portrait_label.text = _portrait_text(display_name)
	name_label.text = _short_name(display_name)
	role_icon.text = "旅" if role == "traveler" else "驻"
	talk_badge.visible = true
	shop_badge.visible = _has_any_tag(["trade", "shop", "parts", "stone"])
	quest_badge.visible = _has_any_tag(["rumor", "teaching", "dojo", "challenge", "observation", "journal"])
	if intent_bubble.text.is_empty():
		intent_bubble.text = _default_intent_text()
	_apply_background_style()

func apply_runtime(state: Dictionary) -> void:
	if state.is_empty():
		set_highlighted(false)
		intent_bubble.text = _default_intent_text()
		return
	intent_bubble.text = String(state.get("intent_text", _default_intent_text()))
	set_highlighted(bool(state.get("highlighted", false)))

func apply_scale_factor(scale_factor: float) -> void:
	var clamped := clampf(scale_factor, 0.72, 1.0)
	custom_minimum_size = BASE_SIZE * clamped
	size = custom_minimum_size
	pivot_offset = size * 0.5
	portrait_label.add_theme_font_size_override("font_size", int(round(12 * clamped)))
	name_label.add_theme_font_size_override("font_size", int(round(11 * clamped)))
	role_icon.add_theme_font_size_override("font_size", int(round(11 * clamped)))
	intent_bubble.add_theme_font_size_override("font_size", int(round(10 * clamped)))
	quest_badge.add_theme_font_size_override("font_size", int(round(10 * clamped)))
	shop_badge.add_theme_font_size_override("font_size", int(round(10 * clamped)))
	talk_badge.add_theme_font_size_override("font_size", int(round(10 * clamped)))

func set_highlighted(value: bool) -> void:
	if _highlighted == value:
		return
	_highlighted = value
	_apply_background_style()

func play_idle() -> void:
	_idle_enabled = true

func play_arrive() -> void:
	_idle_enabled = false
	scale = Vector2(0.92, 0.92)
	modulate = Color(1.0, 1.0, 1.0, 0.78)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
	tween.chain().tween_property(self, "scale", Vector2.ONE, 0.10)
	tween.tween_property(self, "modulate", Color.WHITE, 0.16)
	tween.finished.connect(play_idle, CONNECT_ONE_SHOT)

func _portrait_text(display_name: String) -> String:
	var normalized := display_name.strip_edges()
	if normalized.is_empty():
		return "访"
	var segments := normalized.split(" ", false)
	var portrait_source := segments[segments.size() - 1] if not segments.is_empty() else normalized
	return portrait_source.substr(0, 1)

func _short_name(display_name: String) -> String:
	var normalized := display_name.strip_edges()
	if normalized.is_empty():
		return "访客"
	var segments := normalized.split(" ", false)
	if not segments.is_empty():
		return String(segments[segments.size() - 1])
	return normalized

func _default_intent_text() -> String:
	var role := String(_definition.get("role", "resident"))
	return "来访中" if role == "traveler" else "驻点中"

func _has_any_tag(required_tags: Array[String]) -> bool:
	for raw_tag in Array(_definition.get("tags", [])):
		if required_tags.has(String(raw_tag)):
			return true
	return false

func _apply_background_style() -> void:
	if background == null:
		return
	var base_color := Color("203246") if _highlighted else Color("182634")
	var border_color := Color("fde68a") if _highlighted else Color("77c7ff")
	var panel := StyleBoxFlat.new()
	panel.bg_color = base_color
	panel.border_color = border_color
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.corner_radius_top_left = 10
	panel.corner_radius_top_right = 10
	panel.corner_radius_bottom_right = 10
	panel.corner_radius_bottom_left = 10
	panel.content_margin_left = 0
	panel.content_margin_top = 0
	panel.content_margin_right = 0
	panel.content_margin_bottom = 0
	background.add_theme_stylebox_override("panel", panel)
	portrait_label.add_theme_color_override("font_color", Color("f8fafc"))
	name_label.add_theme_color_override("font_color", Color("f8fafc"))
	role_icon.add_theme_color_override("font_color", border_color)
	intent_bubble.add_theme_color_override("font_color", Color("cbd5e1"))
	quest_badge.add_theme_color_override("font_color", Color("fde68a"))
	shop_badge.add_theme_color_override("font_color", Color("86efac"))
	talk_badge.add_theme_color_override("font_color", Color("93c5fd"))

class_name HabitatActor
extends PanelContainer

const TYPE_COLORS := {
	"habitat": Color("86efac"),
	"settlement": Color("fcd34d"),
	"dojo": Color("fb7185"),
	"anomaly": Color("c084fc"),
}

const TYPE_SHORT := {
	"habitat": "居",
	"settlement": "镇",
	"dojo": "试",
	"anomaly": "异",
}

const TYPE_NAMES := {
	"habitat": "栖居据点",
	"settlement": "补给据点",
	"dojo": "试炼地点",
	"anomaly": "异常区域",
}

var _definition: Dictionary = {}
var _accent := Color("86efac")

@onready var icon_label: Label = $Margin/ContentVBox/HeaderRow/IconLabel
@onready var name_label: Label = $Margin/ContentVBox/HeaderRow/NameLabel
@onready var type_label: Label = $Margin/ContentVBox/HeaderRow/TypeLabel
@onready var status_badge: Label = $Margin/ContentVBox/HeaderRow/StatusBadge
@onready var mood_label: Label = $Margin/ContentVBox/MoodLabel
@onready var meta_label: Label = $Margin/ContentVBox/MetaLabel
@onready var hook_label: Label = $Margin/ContentVBox/HookLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_apply_style(false, false)

func apply_definition(definition: Dictionary) -> void:
	_definition = definition.duplicate(true)
	if _definition.is_empty():
		clear_actor()
		return
	visible = true
	var type_id := String(_definition.get("type", "habitat"))
	_accent = TYPE_COLORS.get(type_id, Color("86efac"))
	icon_label.text = String(TYPE_SHORT.get(type_id, "点"))
	name_label.text = String(_definition.get("name", "未知地点"))
	type_label.text = String(TYPE_NAMES.get(type_id, type_id))
	mood_label.text = _build_mood_text()
	meta_label.text = _build_default_meta_text()
	hook_label.text = ""
	status_badge.visible = false
	status_badge.text = ""
	_apply_style(false, true)

func apply_runtime(state: Dictionary) -> void:
	if _definition.is_empty():
		clear_actor()
		return
	visible = true
	var status_text := String(state.get("status_text", ""))
	status_badge.text = status_text
	status_badge.visible = not status_text.is_empty()
	meta_label.text = String(state.get("meta_text", _build_default_meta_text()))
	hook_label.text = String(state.get("hook_text", ""))
	_apply_style(bool(state.get("current", false)), bool(state.get("unlocked", true)))

func clear_actor() -> void:
	visible = false
	_definition.clear()
	status_badge.text = ""
	hook_label.text = ""

func _build_mood_text() -> String:
	var tags: Array[String] = []
	for raw_tag in Array(_definition.get("mood_tags", [])):
		var text := String(raw_tag).strip_edges()
		if text.is_empty():
			continue
		tags.append(text)
	if tags.is_empty():
		return "气氛：暂无记录"
	return "气氛：%s" % " / ".join(tags.slice(0, 3))

func _build_default_meta_text() -> String:
	var parts: Array[String] = []
	var recommended_rank := int(_definition.get("recommended_rank", 0))
	if recommended_rank > 0:
		parts.append("推荐 %d 级" % recommended_rank)
	var actions := Array(_definition.get("visit_actions", []))
	if not actions.is_empty():
		parts.append("可做 %d 项" % actions.size())
	var biome := String(_definition.get("biome", ""))
	if not biome.is_empty():
		parts.append(biome)
	return " ｜ ".join(parts)

func _apply_style(is_current: bool, is_unlocked: bool) -> void:
	var bg_color := Color("152333") if is_unlocked else Color("1a1a24")
	if is_current:
		bg_color = bg_color.lerp(Color("24364b"), 0.55)
	var border_color := _accent if is_unlocked else Color("6b7280")
	if is_current:
		border_color = Color("fde68a")
	var panel := StyleBoxFlat.new()
	panel.bg_color = bg_color
	panel.border_color = border_color
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.corner_radius_top_left = 12
	panel.corner_radius_top_right = 12
	panel.corner_radius_bottom_right = 12
	panel.corner_radius_bottom_left = 12
	add_theme_stylebox_override("panel", panel)
	icon_label.add_theme_color_override("font_color", border_color)
	name_label.add_theme_color_override("font_color", Color("f8fafc"))
	type_label.add_theme_color_override("font_color", Color("cbd5e1"))
	status_badge.add_theme_color_override("font_color", Color("fde68a") if is_current else border_color)
	mood_label.add_theme_color_override("font_color", Color("dbeafe"))
	meta_label.add_theme_color_override("font_color", Color("cbd5e1"))
	hook_label.add_theme_color_override("font_color", Color("bfdbfe"))

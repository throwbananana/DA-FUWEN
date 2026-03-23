class_name StoryDirector
extends RefCounted

var _story_service
var _cutscene_service
var _cutscene_panel
var _play_dialogue_cutscene: Callable
var _is_modal_open: Callable
var _should_skip_cutscene_runtime: Callable
var _push_log: Callable

var _pending_beats: Array = []

func configure(
	story_service,
	cutscene_service,
	cutscene_panel,
	play_dialogue_cutscene: Callable,
	is_modal_open: Callable,
	should_skip_cutscene_runtime: Callable,
	push_log: Callable
) -> void:
	_story_service = story_service
	_cutscene_service = cutscene_service
	_cutscene_panel = cutscene_panel
	_play_dialogue_cutscene = play_dialogue_cutscene
	_is_modal_open = is_modal_open
	_should_skip_cutscene_runtime = should_skip_cutscene_runtime
	_push_log = push_log

func set_cutscene_panel(cutscene_panel) -> void:
	_cutscene_panel = cutscene_panel

func reset() -> void:
	_pending_beats.clear()

func queue_quest_story_beat(beat: Dictionary) -> void:
	if beat.is_empty():
		return
	var arc_id := String(beat.get("arc_id", ""))
	var beat_id := String(beat.get("id", ""))
	if arc_id.is_empty() or beat_id.is_empty():
		return
	if GameState.has_completed_story_arc(arc_id) or GameState.has_story_beat_seen(arc_id, beat_id):
		return
	for raw_existing in _pending_beats:
		var existing: Dictionary = Dictionary(raw_existing).duplicate(true)
		if String(existing.get("arc_id", "")) == arc_id and String(existing.get("id", "")) == beat_id:
			return
	_pending_beats.append(Dictionary(beat).duplicate(true))
	call_deferred("try_flush_pending_quest_story_beats")

func try_flush_pending_quest_story_beats() -> void:
	if _pending_beats.is_empty():
		return
	if _is_modal_open.is_valid() and bool(_is_modal_open.call()):
		return
	var beat: Dictionary = Dictionary(_pending_beats.pop_front()).duplicate(true)
	call_deferred("_play_story_beat_after_quest", beat)

func _play_story_beat_after_quest(beat: Dictionary) -> void:
	if beat.is_empty():
		try_flush_pending_quest_story_beats()
		return
	var arc_id := String(beat.get("arc_id", ""))
	var beat_id := String(beat.get("id", ""))
	if arc_id.is_empty() or beat_id.is_empty():
		try_flush_pending_quest_story_beats()
		return
	if GameState.has_completed_story_arc(arc_id) or GameState.has_story_beat_seen(arc_id, beat_id):
		try_flush_pending_quest_story_beats()
		return

	var dialogue_id := String(beat.get("dialogue_id", ""))
	var npc_id := String(beat.get("npc_id", ""))
	var dialogue: Dictionary = DataRepository.get_dialogue(dialogue_id)
	if dialogue.is_empty():
		_story_service.commit_story_beat(beat)
		try_flush_pending_quest_story_beats()
		return

	if _should_skip_runtime():
		_story_service.commit_story_beat(beat)
		_log_story_progress(dialogue, dialogue_id)
		try_flush_pending_quest_story_beats()
		return

	var runtime = _cutscene_service.build_dialogue_runtime(dialogue, npc_id)
	if runtime.is_empty():
		_story_service.commit_story_beat(beat)
		_log_story_progress(dialogue, dialogue_id)
		try_flush_pending_quest_story_beats()
		return

	await _play_dialogue_cutscene.call(runtime)
	if is_instance_valid(_cutscene_panel):
		_cutscene_panel.hide()
		_cutscene_panel.modulate.a = 1.0
	_story_service.commit_story_beat(beat)
	_log_story_progress(dialogue, dialogue_id)
	try_flush_pending_quest_story_beats()

func _should_skip_runtime() -> bool:
	return not _should_skip_cutscene_runtime.is_valid() or bool(_should_skip_cutscene_runtime.call())

func _log_story_progress(dialogue: Dictionary, dialogue_id: String) -> void:
	if not _push_log.is_valid():
		return
	_push_log.call("剧情推进：%s。" % String(dialogue.get("title", dialogue_id)))

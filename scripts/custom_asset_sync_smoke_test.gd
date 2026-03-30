extends SceneTree

const TEST_ASSET_ID := "ext_smoke_asset_sync"
const TEST_AUDIO_ASSET_ID := "ext_smoke_audio_sync"
const TEST_IMAGE_FILE_NAME := "smoke_sidecar_image.png"
const TEST_AUDIO_FILE_NAME := "smoke_sidecar_audio.wav"
const TEST_DATA_TARGET_KEY := "species_portrait:embercat_1"
const TEST_HABITAT_TARGET_KEY := "habitat_background:mist_moss_cave"
const TEST_CODEX_TARGET_KEY := "codex_illustration:codex_moss_puff"

var _original_manifest := ""
var _manifest_existed := false
var _test_file_path := ""
var _test_audio_file_path := ""
var _test_image_sidecar_path := ""
var _test_audio_sidecar_path := ""

func _initialize() -> void:
	_run_async.call_deferred()

func _run_async() -> void:
	var ok := await _run()
	quit(0 if ok else 1)

func _run() -> bool:
	var repo = _repo()
	if repo == null:
		push_error("custom_asset_sync_smoke_test: CustomAssetRepository autoload missing")
		return false
	var manifest_path := String(repo.get_external_manifest_path())
	var image_dir := String(repo.get_external_library_dir_path())
	var audio_dir := String(repo.get_external_library_dir_path("audio"))
	_test_file_path = image_dir.path_join(TEST_IMAGE_FILE_NAME)
	_test_audio_file_path = audio_dir.path_join(TEST_AUDIO_FILE_NAME)
	_test_image_sidecar_path = _test_file_path + ".asset.json"
	_test_audio_sidecar_path = _test_audio_file_path + ".asset.json"
	DirAccess.make_dir_absolute(image_dir)
	DirAccess.make_dir_absolute(audio_dir)
	_manifest_existed = FileAccess.file_exists(manifest_path)
	if _manifest_existed:
		_original_manifest = FileAccess.get_file_as_string(manifest_path)
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.3, 0.1, 1.0))
	if image.save_png(_test_file_path) != OK:
		push_error("custom_asset_sync_smoke_test: failed to write test image")
		_cleanup()
		return false
	var audio_file := FileAccess.open(_test_audio_file_path, FileAccess.WRITE)
	if audio_file == null:
		push_error("custom_asset_sync_smoke_test: failed to write test audio")
		_cleanup()
		return false
	audio_file.store_buffer(PackedByteArray([
		82, 73, 70, 70, 40, 0, 0, 0,
		87, 65, 86, 69,
		102, 109, 116, 32, 16, 0, 0, 0,
		1, 0, 1, 0,
		64, 31, 0, 0,
		64, 31, 0, 0,
		1, 0, 8, 0,
		100, 97, 116, 97, 4, 0, 0, 0,
		128, 128, 128, 128,
	]))
	audio_file.flush()
	audio_file = null
	var image_sidecar := {
		"id": TEST_ASSET_ID,
		"label": "smoke_asset",
		"bindings": ["main_menu_bg", "main_menu_logo"],
	}
	var audio_sidecar := {
		"id": TEST_AUDIO_ASSET_ID,
		"label": "smoke_audio",
		"bindings": ["main_menu_bgm", "battle_bgm", "ui_confirm_sfx"],
	}
	var image_sidecar_file := FileAccess.open(_test_image_sidecar_path, FileAccess.WRITE)
	if image_sidecar_file == null:
		push_error("custom_asset_sync_smoke_test: failed to write image sidecar")
		_cleanup()
		return false
	image_sidecar_file.store_string(JSON.stringify(image_sidecar, "\t"))
	image_sidecar_file.flush()
	image_sidecar_file = null
	var audio_sidecar_file := FileAccess.open(_test_audio_sidecar_path, FileAccess.WRITE)
	if audio_sidecar_file == null:
		push_error("custom_asset_sync_smoke_test: failed to write audio sidecar")
		_cleanup()
		return false
	audio_sidecar_file.store_string(JSON.stringify(audio_sidecar, "\t"))
	audio_sidecar_file.flush()
	audio_sidecar_file = null
	var manifest := {
		"assets": {},
		"bindings": {},
		"data_links": {
			TEST_DATA_TARGET_KEY: TEST_ASSET_ID,
			TEST_HABITAT_TARGET_KEY: TEST_ASSET_ID,
			TEST_CODEX_TARGET_KEY: TEST_ASSET_ID,
		},
	}
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		push_error("custom_asset_sync_smoke_test: failed to write external manifest")
		_cleanup()
		return false
	file.store_string(JSON.stringify(manifest, "\t"))
	file.flush()
	file = null
	var sync_result: Dictionary = repo.sync_external_library()
	var synced_total := int(sync_result.get("total", 0))
	if synced_total < 2:
		push_error("custom_asset_sync_smoke_test: sync returned too few assets")
		_cleanup()
		return false
	var image_info: Dictionary = repo.get_image(TEST_ASSET_ID)
	if image_info.is_empty():
		push_error("custom_asset_sync_smoke_test: test asset missing after sync")
		_cleanup()
		return false
	if String(image_info.get("label", "")) != "smoke_asset":
		push_error("custom_asset_sync_smoke_test: image sidecar label did not load")
		_cleanup()
		return false
	if String(repo.get_slot_binding("main_menu_bg")) != TEST_ASSET_ID:
		push_error("custom_asset_sync_smoke_test: main_menu_bg binding did not update")
		_cleanup()
		return false
	if String(repo.get_slot_binding("main_menu_logo")) != TEST_ASSET_ID:
		push_error("custom_asset_sync_smoke_test: main_menu_logo binding did not update")
		_cleanup()
		return false
	if String(repo.get_data_target_binding(TEST_DATA_TARGET_KEY)) != TEST_ASSET_ID:
		push_error("custom_asset_sync_smoke_test: data target binding did not update")
		_cleanup()
		return false
	var texture: Texture2D = repo.get_bound_texture("main_menu_bg")
	if texture == null:
		push_error("custom_asset_sync_smoke_test: bound texture could not be created")
		_cleanup()
		return false
	if repo.get_data_bound_texture(TEST_DATA_TARGET_KEY) == null:
		push_error("custom_asset_sync_smoke_test: data-bound texture could not be created")
		_cleanup()
		return false
	if repo.get_data_bound_texture(TEST_HABITAT_TARGET_KEY) == null:
		push_error("custom_asset_sync_smoke_test: habitat background texture could not be created")
		_cleanup()
		return false
	if repo.get_data_bound_texture(TEST_CODEX_TARGET_KEY) == null:
		push_error("custom_asset_sync_smoke_test: codex illustration texture could not be created")
		_cleanup()
		return false
	var audio_info: Dictionary = repo.get_asset(TEST_AUDIO_ASSET_ID)
	if audio_info.is_empty() or String(audio_info.get("kind", "")) != "audio":
		push_error("custom_asset_sync_smoke_test: audio asset missing after sync")
		_cleanup()
		return false
	if String(audio_info.get("label", "")) != "smoke_audio":
		push_error("custom_asset_sync_smoke_test: audio sidecar label did not load")
		_cleanup()
		return false
	if String(repo.get_slot_binding("main_menu_bgm")) != TEST_AUDIO_ASSET_ID:
		push_error("custom_asset_sync_smoke_test: main_menu_bgm binding did not update")
		_cleanup()
		return false
	if repo.get_bound_audio_stream("main_menu_bgm") == null:
		push_error("custom_asset_sync_smoke_test: bound audio stream could not be created")
		_cleanup()
		return false
	if String(repo.get_slot_binding("battle_bgm")) != TEST_AUDIO_ASSET_ID:
		push_error("custom_asset_sync_smoke_test: battle_bgm binding did not update")
		_cleanup()
		return false
	if repo.get_bound_audio_stream("battle_bgm") == null:
		push_error("custom_asset_sync_smoke_test: battle_bgm stream could not be created")
		_cleanup()
		return false
	if String(repo.get_slot_binding("ui_confirm_sfx")) != TEST_AUDIO_ASSET_ID:
		push_error("custom_asset_sync_smoke_test: ui_confirm_sfx binding did not update")
		_cleanup()
		return false
	if repo.get_bound_audio_stream("ui_confirm_sfx") == null:
		push_error("custom_asset_sync_smoke_test: ui_confirm_sfx stream could not be created")
		_cleanup()
		return false
	var audio_path := String(audio_info.get("path", ""))
	if audio_path.is_empty() or not FileAccess.file_exists(ProjectSettings.globalize_path(audio_path)):
		push_error("custom_asset_sync_smoke_test: audio asset file missing after sync")
		_cleanup()
		return false
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	var game_state = root.get_node_or_null("GameState")
	if game_state == null:
		push_error("custom_asset_sync_smoke_test: GameState autoload missing")
		scene.queue_free()
		_cleanup()
		return false
	if not game_state.revealed_codex_entries.has("codex_moss_puff"):
		game_state.revealed_codex_entries.append("codex_moss_puff")
		game_state.revealed_codex_entries.sort()
	scene.current_node_id = 1
	scene.current_visit_habitat_id = "mist_moss_cave"
	scene._update_map_hint()
	var node_preview: TextureRect = scene.get_node("RootMargin/MainVBox/ContentRow/BoardPanel/BoardVBox/NodeDetailCard/MarginContainer/VBoxContainer/NodeDetailPreviewRect")
	if node_preview.texture == null:
		push_error("custom_asset_sync_smoke_test: node detail preview did not pick up habitat background binding")
		scene.queue_free()
		_cleanup()
		return false
	var sections: Array = scene._build_system_sections()
	var found_codex_preview := false
	for raw_section in sections:
		var section: Dictionary = Dictionary(raw_section).duplicate(true)
		if String(section.get("id", "")) != "codex":
			continue
		found_codex_preview = section.get("preview_texture", null) != null
		break
	if not found_codex_preview:
		push_error("custom_asset_sync_smoke_test: codex system section did not expose a bound illustration preview")
		scene.queue_free()
		_cleanup()
		return false
	scene.queue_free()
	_cleanup()
	return true

func _cleanup() -> void:
	if not _test_file_path.is_empty():
		if FileAccess.file_exists(_test_file_path):
			DirAccess.remove_absolute(_test_file_path)
	if not _test_audio_file_path.is_empty():
		if FileAccess.file_exists(_test_audio_file_path):
			DirAccess.remove_absolute(_test_audio_file_path)
	if not _test_image_sidecar_path.is_empty():
		if FileAccess.file_exists(_test_image_sidecar_path):
			DirAccess.remove_absolute(_test_image_sidecar_path)
	if not _test_audio_sidecar_path.is_empty():
		if FileAccess.file_exists(_test_audio_sidecar_path):
			DirAccess.remove_absolute(_test_audio_sidecar_path)
	var repo = _repo()
	if repo == null:
		return
	var manifest_path := String(repo.get_external_manifest_path())
	if _manifest_existed:
		var file := FileAccess.open(manifest_path, FileAccess.WRITE)
		if file != null:
			file.store_string(_original_manifest)
			file.flush()
			file = null
	else:
		if FileAccess.file_exists(manifest_path):
			DirAccess.remove_absolute(manifest_path)
	repo.sync_external_library()

func _repo():
	return root.get_node_or_null("CustomAssetRepository")

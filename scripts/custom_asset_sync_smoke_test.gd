extends SceneTree

const TEST_ASSET_ID := "ext_smoke_asset_sync"
const TEST_FILE_NAME := TEST_ASSET_ID + ".png"

var _original_manifest := ""
var _manifest_existed := false
var _test_file_path := ""

func _initialize() -> void:
	if not _run():
		quit(1)
		return
	quit(0)

func _run() -> bool:
	var repo = _repo()
	if repo == null:
		push_error("custom_asset_sync_smoke_test: CustomAssetRepository autoload missing")
		return false
	var manifest_path := String(repo.get_external_manifest_path())
	var image_dir := String(repo.get_external_library_dir_path())
	_test_file_path = image_dir.path_join(TEST_FILE_NAME)
	DirAccess.make_dir_absolute(image_dir)
	_manifest_existed = FileAccess.file_exists(manifest_path)
	if _manifest_existed:
		_original_manifest = FileAccess.get_file_as_string(manifest_path)
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.3, 0.1, 1.0))
	if image.save_png(_test_file_path) != OK:
		push_error("custom_asset_sync_smoke_test: failed to write test image")
		_cleanup()
		return false
	var manifest := {
		"images": {
			TEST_ASSET_ID: {
				"id": TEST_ASSET_ID,
				"label": "smoke_asset",
				"filename": TEST_FILE_NAME,
			},
		},
		"bindings": {
			"main_menu_bg": TEST_ASSET_ID,
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
	if synced_total <= 0:
		push_error("custom_asset_sync_smoke_test: sync returned no images")
		_cleanup()
		return false
	var image_info: Dictionary = repo.get_image(TEST_ASSET_ID)
	if image_info.is_empty():
		push_error("custom_asset_sync_smoke_test: test asset missing after sync")
		_cleanup()
		return false
	if String(repo.get_slot_binding("main_menu_bg")) != TEST_ASSET_ID:
		push_error("custom_asset_sync_smoke_test: main_menu_bg binding did not update")
		_cleanup()
		return false
	var texture: Texture2D = repo.get_bound_texture("main_menu_bg")
	if texture == null:
		push_error("custom_asset_sync_smoke_test: bound texture could not be created")
		_cleanup()
		return false
	_cleanup()
	return true

func _cleanup() -> void:
	if not _test_file_path.is_empty():
		if FileAccess.file_exists(_test_file_path):
			DirAccess.remove_absolute(_test_file_path)
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

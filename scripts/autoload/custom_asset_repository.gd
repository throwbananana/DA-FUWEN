extends Node

const ROOT_DIR := "user://custom_assets"
const IMAGE_DIR := ROOT_DIR + "/images"
const MANIFEST_PATH := ROOT_DIR + "/manifest.json"

var manifest: Dictionary = _default_manifest()

func _ready() -> void:
	_ensure_dirs()
	_load_manifest()

func import_images(paths: PackedStringArray) -> Array[Dictionary]:
	_ensure_dirs()
	var results: Array[Dictionary] = []
	var images: Dictionary = manifest.get("images", {})
	for src_path in paths:
		var image := Image.load_from_file(src_path)
		if image.is_empty():
			results.append({
				"ok": false,
				"path": src_path,
				"message": "图片读取失败",
			})
			continue
		var safe_name := _sanitize_label(src_path)
		var asset_id := _make_asset_id(safe_name)
		var dest_path := IMAGE_DIR.path_join("%s.png" % asset_id)
		var save_err := image.save_png(dest_path)
		if save_err != OK:
			results.append({
				"ok": false,
				"path": src_path,
				"message": "保存到 user:// 失败",
			})
			continue
		images[asset_id] = {
			"id": asset_id,
			"label": safe_name,
			"path": dest_path,
			"width": image.get_width(),
			"height": image.get_height(),
			"imported_at": Time.get_unix_time_from_system(),
		}
		results.append({
			"ok": true,
			"id": asset_id,
			"path": dest_path,
			"label": safe_name,
			"width": image.get_width(),
			"height": image.get_height(),
		})
	manifest["images"] = images
	_save_manifest()
	return results

func list_images() -> Array:
	var rows: Array = manifest.get("images", {}).values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time := int(a.get("imported_at", 0))
		var b_time := int(b.get("imported_at", 0))
		if a_time != b_time:
			return a_time > b_time
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return rows

func get_image(asset_id: String) -> Dictionary:
	return Dictionary(manifest.get("images", {}).get(asset_id, {})).duplicate(true)

func get_image_count() -> int:
	return int(manifest.get("images", {}).size())

func bind_slot(slot_id: String, asset_id: String) -> void:
	if slot_id.is_empty():
		return
	var images: Dictionary = manifest.get("images", {})
	if not images.has(asset_id):
		return
	manifest["bindings"][slot_id] = asset_id
	_save_manifest()

func clear_slot(slot_id: String) -> void:
	if slot_id.is_empty():
		return
	manifest["bindings"].erase(slot_id)
	_save_manifest()

func get_slot_binding(slot_id: String) -> String:
	return String(manifest.get("bindings", {}).get(slot_id, ""))

func get_bound_texture(slot_id: String) -> Texture2D:
	var asset_id := get_slot_binding(slot_id)
	if asset_id.is_empty():
		return null
	return get_texture(asset_id)

func get_texture(asset_id: String) -> Texture2D:
	var image_info := get_image(asset_id)
	if image_info.is_empty():
		return null
	var image := Image.load_from_file(String(image_info.get("path", "")))
	if image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _default_manifest() -> Dictionary:
	return {
		"images": {},
		"bindings": {},
	}

func _ensure_dirs() -> void:
	DirAccess.make_dir_absolute(ROOT_DIR)
	DirAccess.make_dir_absolute(IMAGE_DIR)

func _load_manifest() -> void:
	manifest = _default_manifest()
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var raw := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	manifest = Dictionary(parsed).duplicate(true)
	if not manifest.has("images") or typeof(manifest.get("images", {})) != TYPE_DICTIONARY:
		manifest["images"] = {}
	if not manifest.has("bindings") or typeof(manifest.get("bindings", {})) != TYPE_DICTIONARY:
		manifest["bindings"] = {}

func _save_manifest() -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("CustomAssetRepository: failed to open manifest for write")
		return
	file.store_string(JSON.stringify(manifest, "\t"))

func _sanitize_label(src_path: String) -> String:
	var base_name := src_path.get_file().get_basename().validate_filename().strip_edges().to_lower()
	return base_name if not base_name.is_empty() else "image"

func _make_asset_id(safe_name: String) -> String:
	var seed := "%s_%d" % [safe_name, Time.get_unix_time_from_system()]
	var asset_id := seed
	var serial := 1
	while manifest.get("images", {}).has(asset_id):
		asset_id = "%s_%d" % [seed, serial]
		serial += 1
	return asset_id

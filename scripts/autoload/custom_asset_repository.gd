extends Node

const ROOT_DIR := "user://custom_assets"
const IMAGE_DIR := ROOT_DIR + "/images"
const MANIFEST_PATH := ROOT_DIR + "/manifest.json"
const EXTERNAL_LIBRARY_DIR := "res://external_assets"
const EXTERNAL_IMAGE_DIR_NAME := "images"
const EXTERNAL_MANIFEST_NAME := "manifest.json"
const EXTERNAL_SOURCE_PREFIX := "ext_"
const SOURCE_USER_IMPORT := "user_import"
const SOURCE_EXTERNAL_LIBRARY := "external_library"
const SUPPORTED_IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp"]

var manifest: Dictionary = _default_manifest()

func _ready() -> void:
	_ensure_dirs()
	_load_manifest()
	sync_external_library()

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
			"source": SOURCE_USER_IMPORT,
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

func sync_external_library() -> Dictionary:
	_ensure_dirs()
	var scan := _scan_external_library()
	var images: Dictionary = manifest.get("images", {})
	var synced_ids := {}
	var imported := 0
	var updated := 0
	var removed := 0
	var skipped := 0
	for row in scan.get("images", []):
		var image_info := Dictionary(row)
		var asset_id := String(image_info.get("id", ""))
		var source_path := String(image_info.get("source_path", ""))
		if asset_id.is_empty() or source_path.is_empty():
			skipped += 1
			continue
		var image := Image.load_from_file(source_path)
		if image.is_empty():
			skipped += 1
			continue
		var dest_path := IMAGE_DIR.path_join("%s.png" % asset_id)
		var save_err := image.save_png(dest_path)
		if save_err != OK:
			skipped += 1
			continue
		var existed := images.has(asset_id)
		images[asset_id] = {
			"id": asset_id,
			"label": String(image_info.get("label", asset_id)),
			"path": dest_path,
			"width": image.get_width(),
			"height": image.get_height(),
			"imported_at": Time.get_unix_time_from_system(),
			"source": SOURCE_EXTERNAL_LIBRARY,
			"source_path": source_path,
			"source_file": String(image_info.get("filename", "")),
		}
		synced_ids[asset_id] = true
		if existed:
			updated += 1
		else:
			imported += 1
	var stale_ids: Array[String] = []
	for key in images.keys():
		var asset_id := String(key)
		var image_info := Dictionary(images.get(asset_id, {}))
		if String(image_info.get("source", SOURCE_USER_IMPORT)) != SOURCE_EXTERNAL_LIBRARY:
			continue
		if synced_ids.has(asset_id):
			continue
		stale_ids.append(asset_id)
	for asset_id in stale_ids:
		var image_info := Dictionary(images.get(asset_id, {}))
		var cached_path := String(image_info.get("path", ""))
		if not cached_path.is_empty():
			var absolute_path := ProjectSettings.globalize_path(cached_path)
			if FileAccess.file_exists(absolute_path):
				DirAccess.remove_absolute(absolute_path)
		images.erase(asset_id)
		_clear_bindings_for_asset(asset_id)
		removed += 1
	manifest["images"] = images
	_apply_external_bindings(Dictionary(scan.get("bindings", {})), images)
	_save_manifest()
	return {
		"imported": imported,
		"updated": updated,
		"removed": removed,
		"skipped": skipped,
		"total": int(synced_ids.size()),
	}

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

func get_external_library_dir_path() -> String:
	return ProjectSettings.globalize_path(EXTERNAL_LIBRARY_DIR.path_join(EXTERNAL_IMAGE_DIR_NAME))

func get_external_manifest_path() -> String:
	return ProjectSettings.globalize_path(EXTERNAL_LIBRARY_DIR.path_join(EXTERNAL_MANIFEST_NAME))

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

func _scan_external_library() -> Dictionary:
	var result := {
		"images": [],
		"bindings": {},
	}
	var manifest_info := _read_external_manifest()
	var declared_images: Dictionary = manifest_info.get("images", {})
	result["bindings"] = Dictionary(manifest_info.get("bindings", {})).duplicate(true)
	var declared_by_file := {}
	for key in declared_images.keys():
		var declared := Dictionary(declared_images.get(key, {}))
		var filename := String(declared.get("filename", "")).get_file()
		if filename.is_empty():
			continue
		declared_by_file[filename.to_lower()] = {
			"id": _normalize_external_asset_id(String(declared.get("id", key)), filename),
			"label": String(declared.get("label", _sanitize_label(filename))),
		}
	var image_dir := get_external_library_dir_path()
	var dir := DirAccess.open(image_dir)
	if dir == null:
		return result
	var used_ids := {}
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not _is_supported_image_file(file_name):
			continue
		var external_info := Dictionary(declared_by_file.get(file_name.to_lower(), {}))
		var asset_id := String(external_info.get("id", ""))
		if asset_id.is_empty() or used_ids.has(asset_id):
			asset_id = _make_external_asset_id(file_name, used_ids)
		used_ids[asset_id] = true
		result["images"].append({
			"id": asset_id,
			"label": String(external_info.get("label", _sanitize_label(file_name))),
			"filename": file_name,
			"source_path": image_dir.path_join(file_name),
		})
	dir.list_dir_end()
	return result

func _read_external_manifest() -> Dictionary:
	var manifest_path := get_external_manifest_path()
	if not FileAccess.file_exists(manifest_path):
		return _default_manifest()
	var raw := FileAccess.get_file_as_string(manifest_path)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _default_manifest()
	var data := Dictionary(parsed).duplicate(true)
	if not data.has("images") or typeof(data.get("images", {})) != TYPE_DICTIONARY:
		data["images"] = {}
	if not data.has("bindings") or typeof(data.get("bindings", {})) != TYPE_DICTIONARY:
		data["bindings"] = {}
	return data

func _apply_external_bindings(external_bindings: Dictionary, images: Dictionary) -> void:
	var bindings: Dictionary = manifest.get("bindings", {})
	for slot_id in external_bindings.keys():
		var slot_name := String(slot_id)
		if slot_name.is_empty():
			continue
		var asset_id := String(external_bindings.get(slot_id, ""))
		if asset_id.is_empty():
			bindings.erase(slot_name)
		elif images.has(asset_id):
			bindings[slot_name] = asset_id
	manifest["bindings"] = bindings

func _clear_bindings_for_asset(asset_id: String) -> void:
	var bindings: Dictionary = manifest.get("bindings", {})
	var stale_slots: Array[String] = []
	for slot_id in bindings.keys():
		if String(bindings.get(slot_id, "")) == asset_id:
			stale_slots.append(String(slot_id))
	for slot_id in stale_slots:
		bindings.erase(slot_id)
	manifest["bindings"] = bindings

func _normalize_external_asset_id(asset_id: String, fallback_name: String) -> String:
	var safe_id := asset_id.validate_filename().strip_edges().to_lower()
	if safe_id.is_empty():
		safe_id = _sanitize_label(fallback_name)
	if not safe_id.begins_with(EXTERNAL_SOURCE_PREFIX):
		safe_id = EXTERNAL_SOURCE_PREFIX + safe_id
	return safe_id

func _make_external_asset_id(file_name: String, reserved_ids: Dictionary) -> String:
	var base_id := _normalize_external_asset_id(_sanitize_label(file_name), file_name)
	var asset_id := base_id
	var serial := 1
	while reserved_ids.has(asset_id):
		asset_id = "%s_%d" % [base_id, serial]
		serial += 1
	return asset_id

func _is_supported_image_file(file_name: String) -> bool:
	var ext := file_name.get_extension().to_lower()
	return SUPPORTED_IMAGE_EXTENSIONS.has(ext)

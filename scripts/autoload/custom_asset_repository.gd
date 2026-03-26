extends Node

const ROOT_DIR := "user://custom_assets"
const MANIFEST_PATH := ROOT_DIR + "/manifest.json"
const EXTERNAL_LIBRARY_DIR := "res://external_assets"
const EXTERNAL_MANIFEST_NAME := "manifest.json"
const EXTERNAL_ASSET_METADATA_SUFFIX := ".asset.json"
const EXTERNAL_SOURCE_PREFIX := "ext_"
const SOURCE_USER_IMPORT := "user_import"
const SOURCE_EXTERNAL_LIBRARY := "external_library"
const ASSET_KIND_DIR_NAMES := {
	"image": "images",
	"audio": "audio",
	"font": "fonts",
	"video": "video",
	"file": "files",
}
const SUPPORTED_ASSET_EXTENSIONS := {
	"image": ["png", "jpg", "jpeg", "webp", "bmp"],
	"audio": ["ogg", "wav", "mp3", "flac"],
	"font": ["ttf", "otf", "woff", "woff2"],
	"video": ["ogv", "webm", "mp4", "mov"],
	"file": ["json", "txt", "cfg", "csv", "tsv", "md", "bin"],
}
const SLOT_DEFINITIONS := {
	"app_icon": {
		"kind": "image",
		"label": "窗口图标（运行时）",
	},
	"main_menu_bg": {
		"kind": "image",
		"label": "主菜单背景",
	},
	"main_menu_logo": {
		"kind": "image",
		"label": "主菜单 Logo",
	},
	"main_menu_bgm": {
		"kind": "audio",
		"label": "主菜单音乐",
		"runtime_extensions": ["ogg", "wav", "mp3"],
	},
	"battle_bgm": {
		"kind": "audio",
		"label": "战斗音乐",
		"runtime_extensions": ["ogg", "wav", "mp3"],
	},
	"ui_confirm_sfx": {
		"kind": "audio",
		"label": "界面确认音效",
		"runtime_extensions": ["ogg", "wav", "mp3"],
	},
	"ui_font": {
		"kind": "font",
		"label": "界面字体",
	},
	"ui_style_config": {
		"kind": "file",
		"label": "界面样式配置",
		"runtime_extensions": ["json"],
	},
}

var manifest: Dictionary = _default_manifest()

func _ready() -> void:
	_ensure_dirs()
	_load_manifest()
	sync_external_library()

func import_assets(paths: PackedStringArray) -> Array[Dictionary]:
	_ensure_dirs()
	var results: Array[Dictionary] = []
	var assets: Dictionary = Dictionary(manifest.get("assets", {})).duplicate(true)
	for src_path in paths:
		var kind := _kind_for_extension(String(src_path).get_extension())
		if kind.is_empty():
			results.append({
				"ok": false,
				"path": src_path,
				"message": "素材格式暂不支持",
			})
			continue
		var safe_name := _sanitize_label(src_path)
		var asset_id := _make_asset_id(safe_name)
		var import_result := _import_asset_file(
			src_path,
			asset_id,
			safe_name,
			kind,
			SOURCE_USER_IMPORT,
			String(src_path).get_file()
		)
		if not bool(import_result.get("ok", false)):
			results.append(Dictionary(import_result).duplicate(true))
			continue
		var asset_entry: Dictionary = Dictionary(import_result.get("asset", {})).duplicate(true)
		assets[asset_id] = asset_entry
		results.append({
			"ok": true,
			"id": asset_id,
			"path": String(asset_entry.get("path", "")),
			"label": String(asset_entry.get("label", asset_id)),
			"kind": kind,
			"width": int(asset_entry.get("width", 0)),
			"height": int(asset_entry.get("height", 0)),
			"file_size": int(asset_entry.get("file_size", 0)),
		})
	manifest["assets"] = assets
	_save_manifest()
	return results

func import_images(paths: PackedStringArray) -> Array[Dictionary]:
	return import_assets(paths)

func sync_external_library() -> Dictionary:
	_ensure_dirs()
	var scan := _scan_external_library()
	var assets: Dictionary = Dictionary(manifest.get("assets", {})).duplicate(true)
	var synced_ids := {}
	var imported := 0
	var updated := 0
	var removed := 0
	var skipped := 0
	for row_value in scan.get("assets", []):
		var asset_info: Dictionary = Dictionary(row_value).duplicate(true)
		var asset_id := String(asset_info.get("id", ""))
		var label := String(asset_info.get("label", asset_id))
		var kind := String(asset_info.get("kind", ""))
		var source_path := String(asset_info.get("source_path", ""))
		var source_file := String(asset_info.get("filename", ""))
		if asset_id.is_empty() or kind.is_empty() or source_path.is_empty():
			skipped += 1
			continue
		var import_result := _import_asset_file(
			source_path,
			asset_id,
			label,
			kind,
			SOURCE_EXTERNAL_LIBRARY,
			source_file
		)
		if not bool(import_result.get("ok", false)):
			skipped += 1
			continue
		var existed := assets.has(asset_id)
		assets[asset_id] = Dictionary(import_result.get("asset", {})).duplicate(true)
		synced_ids[asset_id] = true
		if existed:
			updated += 1
		else:
			imported += 1
	var stale_ids: Array[String] = []
	for key in assets.keys():
		var asset_id := String(key)
		var asset_info: Dictionary = Dictionary(assets.get(asset_id, {})).duplicate(true)
		if String(asset_info.get("source", SOURCE_USER_IMPORT)) != SOURCE_EXTERNAL_LIBRARY:
			continue
		if synced_ids.has(asset_id):
			continue
		stale_ids.append(asset_id)
	for asset_id in stale_ids:
		_remove_cached_asset(Dictionary(assets.get(asset_id, {})).duplicate(true))
		assets.erase(asset_id)
		_clear_bindings_for_asset(asset_id)
		removed += 1
	manifest["assets"] = assets
	_apply_external_bindings(Dictionary(scan.get("bindings", {})).duplicate(true), assets)
	_save_manifest()
	return {
		"imported": imported,
		"updated": updated,
		"removed": removed,
		"skipped": skipped,
		"total": int(synced_ids.size()),
	}

func list_assets(kind: String = "") -> Array:
	var rows: Array = []
	for value in Dictionary(manifest.get("assets", {})).values():
		var row: Dictionary = Dictionary(value).duplicate(true)
		if not kind.is_empty() and String(row.get("kind", "")) != kind:
			continue
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time := int(a.get("imported_at", 0))
		var b_time := int(b.get("imported_at", 0))
		if a_time != b_time:
			return a_time > b_time
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return rows

func list_images() -> Array:
	return list_assets("image")

func get_asset(asset_id: String) -> Dictionary:
	return Dictionary(manifest.get("assets", {}).get(asset_id, {})).duplicate(true)

func get_image(asset_id: String) -> Dictionary:
	var asset := get_asset(asset_id)
	if String(asset.get("kind", "")) != "image":
		return {}
	return asset

func get_asset_count(kind: String = "") -> int:
	if kind.is_empty():
		return int(Dictionary(manifest.get("assets", {})).size())
	return list_assets(kind).size()

func get_image_count() -> int:
	return get_asset_count("image")

func get_asset_path(asset_id: String) -> String:
	return String(get_asset(asset_id).get("path", ""))

func get_asset_absolute_path(asset_id: String) -> String:
	var asset_path := get_asset_path(asset_id)
	if asset_path.is_empty():
		return ""
	return _globalize_path(asset_path)

func get_asset_kind(asset_id: String) -> String:
	return String(get_asset(asset_id).get("kind", ""))

func get_asset_kind_label(kind: String) -> String:
	match kind:
		"image":
			return "图片"
		"audio":
			return "音频"
		"font":
			return "字体"
		"video":
			return "视频"
		"file":
			return "文件"
		_:
			return "素材"

func get_slot_definitions() -> Dictionary:
	return Dictionary(SLOT_DEFINITIONS).duplicate(true)

func list_slot_ids(kind: String = "") -> Array[String]:
	var slot_ids: Array[String] = []
	for slot_id in SLOT_DEFINITIONS.keys():
		var slot_name := String(slot_id)
		if not kind.is_empty() and get_slot_kind(slot_name) != kind:
			continue
		slot_ids.append(slot_name)
	slot_ids.sort()
	return slot_ids

func get_slot_kind(slot_id: String) -> String:
	return String(Dictionary(SLOT_DEFINITIONS.get(slot_id, {})).get("kind", ""))

func get_slot_label(slot_id: String) -> String:
	return String(Dictionary(SLOT_DEFINITIONS.get(slot_id, {})).get("label", slot_id))

func get_asset_bindings(asset_id: String) -> Array[String]:
	var slot_ids: Array[String] = []
	for slot_id in Dictionary(manifest.get("bindings", {})).keys():
		if String(manifest.get("bindings", {}).get(slot_id, "")) == asset_id:
			slot_ids.append(String(slot_id))
	slot_ids.sort()
	return slot_ids

func get_supported_import_extensions() -> Array[String]:
	var extensions: Array[String] = []
	for kind in _ordered_kinds():
		for ext_value in Array(SUPPORTED_ASSET_EXTENSIONS.get(kind, [])):
			var ext := String(ext_value)
			if not extensions.has(ext):
				extensions.append(ext)
	return extensions

func get_import_dialog_filters() -> PackedStringArray:
	var filters := PackedStringArray()
	var all_patterns: Array[String] = []
	for kind in _ordered_kinds():
		var patterns: Array[String] = []
		for ext_value in Array(SUPPORTED_ASSET_EXTENSIONS.get(kind, [])):
			var ext := String(ext_value)
			patterns.append("*.%s" % ext)
			all_patterns.append("*.%s" % ext)
		if patterns.is_empty():
			continue
		filters.append("%s;%s" % [",".join(patterns), get_asset_kind_label(kind)])
	if not all_patterns.is_empty():
		filters.insert(0, "%s;支持的素材文件" % ",".join(all_patterns))
	return filters

func bind_slot(slot_id: String, asset_id: String) -> void:
	if slot_id.is_empty():
		return
	var asset := get_asset(asset_id)
	if asset.is_empty():
		return
	if not _asset_can_bind_to_slot(asset, slot_id):
		return
	var bindings: Dictionary = Dictionary(manifest.get("bindings", {})).duplicate(true)
	bindings[slot_id] = asset_id
	manifest["bindings"] = bindings
	_save_manifest()

func clear_slot(slot_id: String) -> void:
	if slot_id.is_empty():
		return
	var bindings: Dictionary = Dictionary(manifest.get("bindings", {})).duplicate(true)
	bindings.erase(slot_id)
	manifest["bindings"] = bindings
	_save_manifest()

func get_slot_binding(slot_id: String) -> String:
	return String(manifest.get("bindings", {}).get(slot_id, ""))

func get_bound_texture(slot_id: String) -> Texture2D:
	var asset_id := get_slot_binding(slot_id)
	if asset_id.is_empty():
		return null
	return get_texture(asset_id)

func get_bound_audio_stream(slot_id: String) -> AudioStream:
	var asset_id := get_slot_binding(slot_id)
	if asset_id.is_empty():
		return null
	return get_audio_stream(asset_id)

func get_bound_font(slot_id: String) -> FontFile:
	var asset_id := get_slot_binding(slot_id)
	if asset_id.is_empty():
		return null
	return get_font_file(asset_id)

func get_bound_file_text(slot_id: String) -> String:
	var asset_id := get_slot_binding(slot_id)
	if asset_id.is_empty():
		return ""
	return get_file_text(asset_id)

func get_texture(asset_id: String) -> Texture2D:
	var image_info := get_image(asset_id)
	if image_info.is_empty():
		return null
	var image := Image.load_from_file(String(image_info.get("path", "")))
	if image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func get_audio_stream(asset_id: String) -> AudioStream:
	var asset := get_asset(asset_id)
	if String(asset.get("kind", "")) != "audio":
		return null
	var absolute_path := get_asset_absolute_path(asset_id)
	if absolute_path.is_empty():
		return null
	var path_lower := absolute_path.to_lower()
	if path_lower.ends_with(".ogg"):
		var ogg_stream := AudioStreamOggVorbis.load_from_file(absolute_path)
		if ogg_stream != null:
			ogg_stream.loop = true
		return ogg_stream
	if path_lower.ends_with(".mp3"):
		var mp3_stream := AudioStreamMP3.load_from_file(absolute_path)
		if mp3_stream != null:
			mp3_stream.loop = true
		return mp3_stream
	if path_lower.ends_with(".wav"):
		var wav_stream := AudioStreamWAV.load_from_file(absolute_path)
		if wav_stream != null:
			wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return wav_stream
	return null

func get_font_file(asset_id: String) -> FontFile:
	var asset := get_asset(asset_id)
	if String(asset.get("kind", "")) != "font":
		return null
	var absolute_path := get_asset_absolute_path(asset_id)
	if absolute_path.is_empty():
		return null
	var path_lower := absolute_path.to_lower()
	var font_file := FontFile.new()
	if path_lower.ends_with(".ttf") or path_lower.ends_with(".otf") or path_lower.ends_with(".woff") or path_lower.ends_with(".woff2"):
		font_file.load_dynamic_font(absolute_path)
	else:
		return null
	if font_file.data.is_empty():
		return null
	return font_file

func get_file_text(asset_id: String) -> String:
	var asset := get_asset(asset_id)
	if String(asset.get("kind", "")) != "file":
		return ""
	var absolute_path := get_asset_absolute_path(asset_id)
	if absolute_path.is_empty():
		return ""
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

func get_external_library_dir_path(kind: String = "image") -> String:
	return ProjectSettings.globalize_path(EXTERNAL_LIBRARY_DIR.path_join(_dir_name_for_kind(kind)))

func get_external_manifest_path() -> String:
	return ProjectSettings.globalize_path(EXTERNAL_LIBRARY_DIR.path_join(EXTERNAL_MANIFEST_NAME))

func _default_manifest() -> Dictionary:
	return {
		"assets": {},
		"bindings": {},
	}

func _ensure_dirs() -> void:
	DirAccess.make_dir_absolute(ROOT_DIR)
	for kind in _ordered_kinds():
		DirAccess.make_dir_absolute(_user_dir_path(kind))

func _load_manifest() -> void:
	manifest = _default_manifest()
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var raw := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	manifest = _normalize_manifest(Dictionary(parsed).duplicate(true))

func _save_manifest() -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("CustomAssetRepository: failed to open manifest for write")
		return
	file.store_string(JSON.stringify(_normalize_manifest(Dictionary(manifest).duplicate(true)), "\t"))

func _normalize_manifest(data: Dictionary) -> Dictionary:
	var normalized := _default_manifest()
	var assets := {}
	if typeof(data.get("assets", {})) == TYPE_DICTIONARY:
		for key in Dictionary(data.get("assets", {})).keys():
			var asset := _normalize_asset_record(String(key), Dictionary(data.get("assets", {}).get(key, {})).duplicate(true), "")
			if asset.is_empty():
				continue
			assets[String(asset.get("id", ""))] = asset
	if typeof(data.get("images", {})) == TYPE_DICTIONARY:
		for key in Dictionary(data.get("images", {})).keys():
			var asset := _normalize_asset_record(String(key), Dictionary(data.get("images", {}).get(key, {})).duplicate(true), "image")
			if asset.is_empty():
				continue
			var asset_id := String(asset.get("id", ""))
			if not assets.has(asset_id):
				assets[asset_id] = asset
	normalized["assets"] = assets
	if typeof(data.get("bindings", {})) == TYPE_DICTIONARY:
		normalized["bindings"] = Dictionary(data.get("bindings", {})).duplicate(true)
	return normalized

func _normalize_asset_record(entry_key: String, raw_info: Dictionary, fallback_kind: String) -> Dictionary:
	var asset_id := String(raw_info.get("id", entry_key))
	if asset_id.is_empty():
		asset_id = entry_key
	if asset_id.is_empty():
		return {}
	var filename := String(raw_info.get("filename", "")).get_file()
	var original_ext := String(raw_info.get("original_ext", filename.get_extension())).to_lower()
	var kind := _normalize_asset_kind(String(raw_info.get("kind", fallback_kind)), filename)
	if kind.is_empty():
		kind = _kind_for_extension(original_ext)
	if kind.is_empty():
		return {}
	var folder := String(raw_info.get("folder", _dir_name_for_kind(kind)))
	if folder.is_empty():
		folder = _dir_name_for_kind(kind)
	var path := String(raw_info.get("path", ""))
	if path.is_empty() and not filename.is_empty():
		path = _user_dir_path(kind).path_join(filename)
	return {
		"id": asset_id,
		"kind": kind,
		"label": String(raw_info.get("label", _sanitize_label(filename if not filename.is_empty() else asset_id))),
		"filename": filename,
		"folder": folder,
		"path": path,
		"width": int(raw_info.get("width", 0)),
		"height": int(raw_info.get("height", 0)),
		"file_size": int(raw_info.get("file_size", 0)),
		"adapted": bool(raw_info.get("adapted", false)),
		"source": String(raw_info.get("source", SOURCE_USER_IMPORT)),
		"source_path": String(raw_info.get("source_path", "")),
		"source_file": String(raw_info.get("source_file", filename)),
		"original_file": String(raw_info.get("original_file", filename)),
		"original_ext": original_ext,
		"imported_at": int(raw_info.get("imported_at", Time.get_unix_time_from_system())),
	}

func _sanitize_label(src_path: String) -> String:
	var base_name := src_path.get_file().get_basename().validate_filename().strip_edges().to_lower()
	return base_name if not base_name.is_empty() else "asset"

func _make_asset_id(safe_name: String) -> String:
	var seed := "%s_%d" % [safe_name, Time.get_unix_time_from_system()]
	var asset_id := seed
	var serial := 1
	while Dictionary(manifest.get("assets", {})).has(asset_id):
		asset_id = "%s_%d" % [seed, serial]
		serial += 1
	return asset_id

func _import_asset_file(
	source_path: String,
	asset_id: String,
	label: String,
	kind: String,
	source: String,
	source_file: String
) -> Dictionary:
	if kind == "image":
		var image := Image.load_from_file(source_path)
		if image.is_empty():
			return {
				"ok": false,
				"path": source_path,
				"message": "图片读取失败",
			}
		var dest_file_name := "%s.png" % asset_id
		var dest_path := _user_dir_path(kind).path_join(dest_file_name)
		var save_err := image.save_png(dest_path)
		if save_err != OK:
			return {
				"ok": false,
				"path": source_path,
				"message": "保存到 user:// 失败",
			}
		var asset := _build_asset_entry(
			asset_id,
			label,
			kind,
			dest_file_name,
			dest_path,
			source,
			source_path,
			source_file,
			source_path.get_extension(),
			image.get_width(),
			image.get_height(),
			_get_file_size(_globalize_path(dest_path)),
			source_path.get_extension().to_lower() != "png"
		)
		return {
			"ok": true,
			"asset": asset,
		}
	var ext := source_path.get_extension().to_lower()
	var dest_file_name := "%s.%s" % [asset_id, ext]
	var dest_path := _user_dir_path(kind).path_join(dest_file_name)
	var copy_err := _copy_file(source_path, dest_path)
	if copy_err != OK:
		return {
			"ok": false,
			"path": source_path,
			"message": "复制到 user:// 失败",
		}
	var asset := _build_asset_entry(
		asset_id,
		label,
		kind,
		dest_file_name,
		dest_path,
		source,
		source_path,
		source_file,
		ext,
		0,
		0,
		_get_file_size(_globalize_path(dest_path)),
		false
	)
	return {
		"ok": true,
		"asset": asset,
	}

func _build_asset_entry(
	asset_id: String,
	label: String,
	kind: String,
	file_name: String,
	user_path: String,
	source: String,
	source_path: String,
	source_file: String,
	original_ext: String,
	width: int,
	height: int,
	file_size: int,
	adapted: bool
) -> Dictionary:
	return {
		"id": asset_id,
		"kind": kind,
		"label": label,
		"filename": file_name,
		"folder": _dir_name_for_kind(kind),
		"path": user_path,
		"width": width,
		"height": height,
		"file_size": file_size,
		"adapted": adapted,
		"source": source,
		"source_path": source_path,
		"source_file": source_file,
		"original_file": source_file,
		"original_ext": original_ext.to_lower(),
		"imported_at": Time.get_unix_time_from_system(),
	}

func _scan_external_library() -> Dictionary:
	var asset_rows: Array = []
	var result := {
		"assets": asset_rows,
		"bindings": {},
	}
	var manifest_info := _read_external_manifest()
	var declared_assets: Dictionary = Dictionary(manifest_info.get("assets", {})).duplicate(true)
	result["bindings"] = Dictionary(manifest_info.get("bindings", {})).duplicate(true)
	var declared_by_key := {}
	for key in declared_assets.keys():
		var declared := Dictionary(declared_assets.get(key, {})).duplicate(true)
		var kind := _normalize_asset_kind(String(declared.get("kind", "")), String(declared.get("filename", "")))
		var filename := String(declared.get("filename", "")).get_file()
		if kind.is_empty() or filename.is_empty():
			continue
		declared_by_key["%s::%s" % [kind, filename.to_lower()]] = {
			"id": _normalize_external_asset_id(String(declared.get("id", key)), filename),
			"label": String(declared.get("label", _sanitize_label(filename))),
			"kind": kind,
		}
	var used_ids := {}
	for kind in _ordered_kinds():
		var library_dir := get_external_library_dir_path(kind)
		var dir := DirAccess.open(library_dir)
		if dir == null:
			continue
		dir.list_dir_begin()
		while true:
			var file_name := dir.get_next()
			if file_name.is_empty():
				break
			if dir.current_is_dir() or not _is_supported_file_for_kind(file_name, kind):
				continue
			var manifest_key := "%s::%s" % [kind, file_name.to_lower()]
			var external_info := Dictionary(declared_by_key.get(manifest_key, {})).duplicate(true)
			var sidecar_info := _read_external_asset_sidecar(kind, file_name)
			var asset_id := String(sidecar_info.get("id", external_info.get("id", "")))
			if asset_id.is_empty() or used_ids.has(asset_id):
				asset_id = _make_external_asset_id(file_name, used_ids)
			used_ids[asset_id] = true
			if bool(sidecar_info.get("has_bindings", false)):
				for slot_id in Dictionary(result.get("bindings", {})).keys():
					if String(result["bindings"].get(slot_id, "")) == asset_id:
						result["bindings"].erase(slot_id)
				for slot_value in Array(sidecar_info.get("bindings", [])):
					var slot_id := String(slot_value)
					if not slot_id.is_empty():
						result["bindings"][slot_id] = asset_id
			asset_rows.append({
				"id": asset_id,
				"kind": kind,
				"label": String(sidecar_info.get("label", external_info.get("label", _sanitize_label(file_name)))),
				"filename": file_name,
				"source_path": library_dir.path_join(file_name),
			})
		dir.list_dir_end()
	result["assets"] = asset_rows
	return result

func _read_external_manifest() -> Dictionary:
	var manifest_path := get_external_manifest_path()
	if not FileAccess.file_exists(manifest_path):
		return _default_manifest()
	var raw := FileAccess.get_file_as_string(manifest_path)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _default_manifest()
	return _normalize_manifest(Dictionary(parsed).duplicate(true))

func _apply_external_bindings(external_bindings: Dictionary, assets: Dictionary) -> void:
	var bindings: Dictionary = Dictionary(manifest.get("bindings", {})).duplicate(true)
	for slot_id in external_bindings.keys():
		var slot_name := String(slot_id)
		if slot_name.is_empty():
			continue
		var asset_id := String(external_bindings.get(slot_id, ""))
		if asset_id.is_empty():
			bindings.erase(slot_name)
			continue
		var asset := Dictionary(assets.get(asset_id, {})).duplicate(true)
		if asset.is_empty():
			continue
		if not _asset_can_bind_to_slot(asset, slot_name):
			continue
		bindings[slot_name] = asset_id
	manifest["bindings"] = bindings

func _clear_bindings_for_asset(asset_id: String) -> void:
	var bindings: Dictionary = Dictionary(manifest.get("bindings", {})).duplicate(true)
	var stale_slots: Array[String] = []
	for slot_id in bindings.keys():
		if String(bindings.get(slot_id, "")) == asset_id:
			stale_slots.append(String(slot_id))
	for slot_id in stale_slots:
		bindings.erase(slot_id)
	manifest["bindings"] = bindings

func _remove_cached_asset(asset_info: Dictionary) -> void:
	var cached_path := String(asset_info.get("path", ""))
	if cached_path.is_empty():
		return
	var absolute_path := _globalize_path(cached_path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)

func _normalize_external_asset_id(asset_id: String, fallback_name: String) -> String:
	var safe_id := asset_id.validate_filename().strip_edges().to_lower()
	if safe_id.is_empty():
		safe_id = _sanitize_label(fallback_name)
	if not safe_id.begins_with(EXTERNAL_SOURCE_PREFIX):
		safe_id = EXTERNAL_SOURCE_PREFIX + safe_id
	return safe_id

func _external_asset_sidecar_path(kind: String, file_name: String) -> String:
	return get_external_library_dir_path(kind).path_join(file_name + EXTERNAL_ASSET_METADATA_SUFFIX)

func _read_external_asset_sidecar(kind: String, file_name: String) -> Dictionary:
	var sidecar_path := _external_asset_sidecar_path(kind, file_name)
	if not FileAccess.file_exists(sidecar_path):
		return {}
	var raw := FileAccess.get_file_as_string(sidecar_path)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data := Dictionary(parsed).duplicate(true)
	var sidecar := {}
	var raw_id := String(data.get("id", "")).strip_edges()
	if not raw_id.is_empty():
		sidecar["id"] = _normalize_external_asset_id(raw_id, file_name)
	var raw_label := String(data.get("label", "")).strip_edges()
	if not raw_label.is_empty():
		sidecar["label"] = raw_label
	var bindings: Array[String] = []
	var binding_value = data.get("bindings", data.get("binding", []))
	if typeof(binding_value) == TYPE_STRING:
		var slot_id := String(binding_value).strip_edges()
		if not slot_id.is_empty() and SLOT_DEFINITIONS.has(slot_id):
			bindings.append(slot_id)
	elif typeof(binding_value) == TYPE_ARRAY:
		for slot_value in Array(binding_value):
			var slot_id := String(slot_value).strip_edges()
			if not slot_id.is_empty() and SLOT_DEFINITIONS.has(slot_id):
				bindings.append(slot_id)
	sidecar["bindings"] = bindings
	sidecar["has_bindings"] = data.has("bindings") or data.has("binding")
	return sidecar

func _make_external_asset_id(file_name: String, reserved_ids: Dictionary) -> String:
	var base_id := _normalize_external_asset_id(_sanitize_label(file_name), file_name)
	var asset_id := base_id
	var serial := 1
	while reserved_ids.has(asset_id):
		asset_id = "%s_%d" % [base_id, serial]
		serial += 1
	return asset_id

func _copy_file(source_path: String, dest_path: String) -> int:
	return DirAccess.copy_absolute(_globalize_path(source_path), _globalize_path(dest_path))

func _globalize_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path

func _get_file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	return int(file.get_length())

func _user_dir_path(kind: String) -> String:
	return ROOT_DIR.path_join(_dir_name_for_kind(kind))

func _dir_name_for_kind(kind: String) -> String:
	return String(ASSET_KIND_DIR_NAMES.get(kind, "files"))

func _ordered_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for key in ASSET_KIND_DIR_NAMES.keys():
		kinds.append(String(key))
	kinds.sort()
	if kinds.has("image"):
		kinds.erase("image")
		kinds.insert(0, "image")
	return kinds

func _expected_slot_kind(slot_id: String) -> String:
	return get_slot_kind(slot_id)

func _asset_can_bind_to_slot(asset: Dictionary, slot_id: String) -> bool:
	if not SLOT_DEFINITIONS.has(slot_id):
		return false
	var expected_kind := _expected_slot_kind(slot_id)
	if not expected_kind.is_empty() and String(asset.get("kind", "")) != expected_kind:
		return false
	var runtime_extensions := Array(Dictionary(SLOT_DEFINITIONS.get(slot_id, {})).get("runtime_extensions", []))
	if runtime_extensions.is_empty():
		return true
	var ext := String(asset.get("original_ext", String(asset.get("filename", "")).get_extension())).trim_prefix(".").to_lower()
	return runtime_extensions.has(ext)

func _normalize_asset_kind(kind: String, file_name: String = "") -> String:
	var cleaned := kind.strip_edges().to_lower()
	if ASSET_KIND_DIR_NAMES.has(cleaned):
		return cleaned
	if not file_name.is_empty():
		return _kind_for_extension(file_name.get_extension())
	return ""

func _kind_for_extension(extension: String) -> String:
	var normalized_ext := extension.strip_edges().to_lower().trim_prefix(".")
	if normalized_ext.is_empty():
		return ""
	for kind in _ordered_kinds():
		if Array(SUPPORTED_ASSET_EXTENSIONS.get(kind, [])).has(normalized_ext):
			return kind
	return ""

func _is_supported_file_for_kind(file_name: String, kind: String) -> bool:
	if file_name.to_lower().ends_with(EXTERNAL_ASSET_METADATA_SUFFIX):
		return false
	var ext := file_name.get_extension().to_lower()
	return Array(SUPPORTED_ASSET_EXTENSIONS.get(kind, [])).has(ext)

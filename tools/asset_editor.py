from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime
from collections.abc import Iterable
from pathlib import Path
from tkinter import END, LEFT, PhotoImage, VERTICAL, W, filedialog, messagebox, StringVar, Tk
from tkinter import ttk

try:
    from PIL import Image as PILImage
    from PIL import ImageOps, ImageTk, UnidentifiedImageError
except ImportError:
    PILImage = None
    ImageOps = None
    ImageTk = None
    UnidentifiedImageError = OSError


PROJECT_ROOT = Path(__file__).resolve().parents[1]
EXTERNAL_ROOT = PROJECT_ROOT / "external_assets"
MANIFEST_PATH = EXTERNAL_ROOT / "manifest.json"
ASSET_METADATA_SUFFIX = ".asset.json"
SLOT_MAIN_MENU_BG = "main_menu_bg"
ASSET_KIND_LABELS = {
    "image": "图片",
    "audio": "音频",
    "font": "字体",
    "video": "视频",
    "file": "文件",
}
ASSET_KIND_DIRS = {
    "image": EXTERNAL_ROOT / "images",
    "audio": EXTERNAL_ROOT / "audio",
    "font": EXTERNAL_ROOT / "fonts",
    "video": EXTERNAL_ROOT / "video",
    "file": EXTERNAL_ROOT / "files",
}
RUNTIME_IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
ADAPTABLE_IMAGE_EXTENSIONS = {".gif", ".tif", ".tiff", ".tga", ".ico"}
SUPPORTED_EXTENSIONS_BY_KIND = {
    "image": RUNTIME_IMAGE_EXTENSIONS | (ADAPTABLE_IMAGE_EXTENSIONS if PILImage is not None else set()),
    "audio": {".ogg", ".wav", ".mp3", ".flac"},
    "font": {".ttf", ".otf", ".woff", ".woff2"},
    "video": {".ogv", ".webm", ".mp4", ".mov"},
    "file": {".json", ".txt", ".cfg", ".csv", ".tsv", ".md", ".bin"},
}
SUPPORTED_EXTENSIONS = {
    ext
    for extensions in SUPPORTED_EXTENSIONS_BY_KIND.values()
    for ext in extensions
}
SLOT_DEFINITIONS = {
    SLOT_MAIN_MENU_BG: {"label": "主菜单背景", "kind": "image"},
    "main_menu_logo": {"label": "主菜单 Logo", "kind": "image"},
    "main_menu_bgm": {"label": "主菜单音乐", "kind": "audio", "runtime_exts": {".ogg", ".wav", ".mp3"}},
    "battle_bgm": {"label": "战斗音乐", "kind": "audio", "runtime_exts": {".ogg", ".wav", ".mp3"}},
    "ui_confirm_sfx": {"label": "界面确认音效", "kind": "audio", "runtime_exts": {".ogg", ".wav", ".mp3"}},
    "ui_font": {"label": "界面字体", "kind": "font"},
}
VALID_SLOT_IDS = set(SLOT_DEFINITIONS.keys())


def ordered_kinds() -> list[str]:
    return ["image", "audio", "font", "video", "file"]


KIND_FILTER_OPTIONS = {
    "全部类型": "",
    **{ASSET_KIND_LABELS[kind]: kind for kind in ordered_kinds()},
}


def slot_label(slot_id: str) -> str:
    return str(SLOT_DEFINITIONS.get(slot_id, {}).get("label", slot_id))


def asset_original_suffix(info: dict) -> str:
    return str(info.get("original_ext", Path(str(info.get("filename", ""))).suffix.lower()) or "").lower()


def asset_can_bind_to_slot(info: dict, slot_id: str) -> bool:
    slot_def = SLOT_DEFINITIONS.get(slot_id, {})
    if not slot_def:
        return False
    kind = str(info.get("kind", "")).strip().lower()
    if str(slot_def.get("kind", "")) != kind:
        return False
    runtime_exts = slot_def.get("runtime_exts")
    if not runtime_exts:
        return True
    return asset_original_suffix(info) in set(runtime_exts)


def binding_options_for_asset(info: dict) -> dict[str, str]:
    options = {"不绑定": ""}
    for slot_id in SLOT_DEFINITIONS:
        if asset_can_bind_to_slot(info, slot_id):
            options[slot_label(slot_id)] = slot_id
    return options


def binding_labels_for_asset(asset_id: str, bindings: dict) -> list[str]:
    labels = [slot_label(slot_id) for slot_id, bound_id in bindings.items() if str(bound_id) == asset_id]
    return sorted(labels)


def asset_sort_key(asset_id: str, info: dict) -> tuple[int, int, str, str]:
    kind = str(info.get("kind", "file"))
    try:
        kind_index = ordered_kinds().index(kind)
    except ValueError:
        kind_index = len(ordered_kinds())
    updated_at = -int(info.get("updated_at", 0))
    label = str(info.get("label", asset_id)).lower()
    return (updated_at, kind_index, label, asset_id.lower())


def format_timestamp(timestamp: int | float, short: bool = False) -> str:
    if int(timestamp) <= 0:
        return ""
    fmt = "%Y-%m-%d %H:%M" if short else "%Y-%m-%d %H:%M:%S"
    return datetime.fromtimestamp(int(timestamp)).strftime(fmt)


def format_file_size(size: int) -> str:
    if size <= 0:
        return ""
    value = float(size)
    for unit in ("B", "KB", "MB", "GB"):
        if value < 1024.0 or unit == "GB":
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.1f} {unit}"
        value /= 1024.0
    return f"{size} B"


def format_dimensions(width: int, height: int) -> str:
    if width <= 0 or height <= 0:
        return ""
    return f"{width} x {height}"


def ensure_layout() -> None:
    EXTERNAL_ROOT.mkdir(parents=True, exist_ok=True)
    for directory in ASSET_KIND_DIRS.values():
        directory.mkdir(parents=True, exist_ok=True)
    if not MANIFEST_PATH.exists():
        save_manifest(default_manifest())


def default_manifest() -> dict:
    return {"assets": {}, "bindings": {}}


def sanitize_name(value: str) -> str:
    cleaned = "".join(ch.lower() if ch.isalnum() else "_" for ch in value.strip())
    while "__" in cleaned:
        cleaned = cleaned.replace("__", "_")
    cleaned = cleaned.strip("_")
    return cleaned or "asset"


def normalize_external_asset_id(value: str, fallback_name: str = "") -> str:
    candidate = sanitize_name(value or fallback_name)
    if not candidate.startswith("ext_"):
        candidate = f"ext_{candidate}"
    return candidate


def is_asset_metadata_file(path: Path) -> bool:
    return path.name.lower().endswith(ASSET_METADATA_SUFFIX)


def asset_metadata_path_for_file(path: Path) -> Path:
    return path.with_name(f"{path.name}{ASSET_METADATA_SUFFIX}")


def parse_binding_slots(raw_value) -> list[str]:
    slots: list[str] = []
    if isinstance(raw_value, str):
        candidate = raw_value.strip()
        if candidate:
            slots.append(candidate)
    elif isinstance(raw_value, Iterable):
        for item in raw_value:
            candidate = str(item).strip()
            if candidate:
                slots.append(candidate)
    return [slot_id for slot_id in slots if slot_id in VALID_SLOT_IDS]


def load_asset_metadata_sidecar(path: Path) -> dict:
    if not path.exists() or not path.is_file():
        return {}
    try:
        raw_data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(raw_data, dict):
        return {}
    raw_id = str(raw_data.get("id", "")).strip()
    bindings = parse_binding_slots(raw_data.get("bindings", raw_data.get("binding", [])))
    return {
        "id": normalize_external_asset_id(raw_id) if raw_id else "",
        "label": str(raw_data.get("label", "")).strip(),
        "bindings": bindings,
        "has_bindings": "bindings" in raw_data or "binding" in raw_data,
    }


def write_asset_metadata_sidecar(info: dict, bindings: dict) -> None:
    asset_path = asset_storage_path(info)
    if asset_path is None:
        return
    sidecar_path = asset_metadata_path_for_file(asset_path)
    asset_id = str(info.get("id", "")).strip()
    payload = {
        "id": asset_id,
        "label": str(info.get("label", asset_id)).strip() or asset_id,
    }
    binding_slots = sorted(slot_id for slot_id, bound_id in bindings.items() if str(bound_id) == asset_id)
    if binding_slots:
        payload["bindings"] = binding_slots
    sidecar_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def detect_asset_kind(path: Path) -> str:
    if is_asset_metadata_file(path):
        return ""
    suffix = path.suffix.lower()
    for kind in ordered_kinds():
        if suffix in SUPPORTED_EXTENSIONS_BY_KIND[kind]:
            return kind
    return ""


def normalize_asset_record(entry_id: str, raw_info: dict, fallback_kind: str = "") -> dict:
    asset_id = str(raw_info.get("id", entry_id)).strip() or entry_id
    filename = Path(str(raw_info.get("filename", ""))).name
    kind = str(raw_info.get("kind", fallback_kind)).strip().lower()
    if kind not in ASSET_KIND_DIRS:
        kind = detect_asset_kind(Path(filename)) if filename else fallback_kind
    if kind not in ASSET_KIND_DIRS:
        return {}
    folder = str(raw_info.get("folder", ASSET_KIND_DIRS[kind].name)).strip() or ASSET_KIND_DIRS[kind].name
    return {
        "id": asset_id,
        "kind": kind,
        "label": str(raw_info.get("label", sanitize_name(filename or asset_id))),
        "filename": filename,
        "folder": folder,
        "width": int(raw_info.get("width", 0)),
        "height": int(raw_info.get("height", 0)),
        "file_size": int(raw_info.get("file_size", 0)),
        "adapted": bool(raw_info.get("adapted", False)),
        "original_file": str(raw_info.get("original_file", filename)),
        "original_ext": str(raw_info.get("original_ext", Path(filename).suffix.lower())),
        "updated_at": int(raw_info.get("updated_at", time.time())),
    }


def migrate_manifest(data: dict) -> dict:
    normalized = default_manifest()
    assets: dict[str, dict] = {}
    if isinstance(data.get("assets"), dict):
        for key, raw_info in data["assets"].items():
            if not isinstance(raw_info, dict):
                continue
            asset = normalize_asset_record(str(key), dict(raw_info))
            if asset:
                assets[asset["id"]] = asset
    if isinstance(data.get("images"), dict):
        for key, raw_info in data["images"].items():
            if not isinstance(raw_info, dict):
                continue
            asset = normalize_asset_record(str(key), dict(raw_info), "image")
            if asset and asset["id"] not in assets:
                assets[asset["id"]] = asset
    normalized["assets"] = assets
    if isinstance(data.get("bindings"), dict):
        normalized["bindings"] = dict(data["bindings"])
    return normalized


def load_manifest() -> dict:
    ensure_layout()
    try:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        data = default_manifest()
    if not isinstance(data, dict):
        data = default_manifest()
    return migrate_manifest(data)


def save_manifest(data: dict) -> None:
    normalized = migrate_manifest(data)
    normalized["assets"] = dict(sorted(normalized["assets"].items(), key=lambda item: item[0]))
    normalized["bindings"] = dict(sorted(normalized["bindings"].items(), key=lambda item: item[0]))
    MANIFEST_PATH.write_text(json.dumps(normalized, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def make_asset_id(stem: str, used_ids: set[str]) -> str:
    base = f"ext_{sanitize_name(stem)}"
    asset_id = base
    serial = 1
    while asset_id in used_ids:
        asset_id = f"{base}_{serial}"
        serial += 1
    return asset_id


def asset_file_key(kind: str, filename: str) -> str:
    return f"{kind}::{filename.lower()}"


def referenced_files(assets: dict) -> set[str]:
    result: set[str] = set()
    for info in assets.values():
        if not isinstance(info, dict):
            continue
        kind = str(info.get("kind", "")).strip().lower()
        filename = str(info.get("filename", "")).strip()
        if kind and filename:
            result.add(asset_file_key(kind, filename))
    return result


def reconcile_manifest(data: dict) -> dict:
    normalized = migrate_manifest(data)
    original_assets = normalized.setdefault("assets", {})
    original_bindings = normalized.setdefault("bindings", {})
    existing_files: dict[str, dict[str, str]] = {}
    for kind in ordered_kinds():
        directory = ASSET_KIND_DIRS[kind]
        existing_files[kind] = {
            path.name.lower(): path.name
            for path in directory.iterdir()
            if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS_BY_KIND[kind]
        }
    assets: dict[str, dict] = {}
    bindings: dict[str, str] = {}
    declared_by_file: dict[str, dict] = {}
    for asset_id, info in original_assets.items():
        if not isinstance(info, dict):
            continue
        kind = str(info.get("kind", "")).strip().lower()
        filename = str(info.get("filename", "")).strip()
        if kind and filename:
            declared_by_file[asset_file_key(kind, filename)] = dict(info)
    used_ids: set[str] = set()
    remapped_ids: dict[str, str] = {}
    sidecar_bindings: dict[str, list[str]] = {}
    for kind in ordered_kinds():
        for lower_name, real_name in sorted(existing_files[kind].items()):
            file_path = ASSET_KIND_DIRS[kind] / real_name
            file_meta = inspect_asset_file(file_path, kind)
            file_key = asset_file_key(kind, real_name)
            declared = dict(declared_by_file.get(file_key, {}))
            sidecar = load_asset_metadata_sidecar(asset_metadata_path_for_file(file_path))
            requested_id = sidecar.get("id", "") or str(declared.get("id", "")).strip()
            asset_id = normalize_external_asset_id(requested_id, Path(real_name).stem) if requested_id else make_asset_id(Path(real_name).stem, used_ids)
            if asset_id in used_ids:
                asset_id = make_asset_id(Path(real_name).stem, used_ids)
            used_ids.add(asset_id)
            if declared:
                previous_id = str(declared.get("id", "")).strip()
                if previous_id and previous_id != asset_id:
                    remapped_ids[previous_id] = asset_id
            label = sidecar.get("label", "") or str(declared.get("label", sanitize_name(Path(real_name).stem)))
            assets[asset_id] = {
                "id": asset_id,
                "kind": kind,
                "label": label,
                "filename": real_name,
                "folder": ASSET_KIND_DIRS[kind].name,
                "width": int(file_meta.get("width", 0)),
                "height": int(file_meta.get("height", 0)),
                "file_size": int(file_meta.get("file_size", 0)),
                "adapted": bool(declared.get("adapted", False)),
                "original_file": str(declared.get("original_file", real_name) or real_name),
                "original_ext": str(declared.get("original_ext", Path(real_name).suffix.lower()) or Path(real_name).suffix.lower()),
                "updated_at": int(declared.get("updated_at", file_meta.get("updated_at", time.time()))),
            }
            if bool(sidecar.get("has_bindings", False)):
                sidecar_bindings[asset_id] = list(sidecar.get("bindings", []))
    for slot_id, bound_id in original_bindings.items():
        resolved_asset_id = remapped_ids.get(str(bound_id), str(bound_id))
        if resolved_asset_id in assets:
            bindings[str(slot_id)] = resolved_asset_id
    for asset_id, slot_ids in sidecar_bindings.items():
        for slot_id, bound_id in list(bindings.items()):
            if bound_id == asset_id:
                bindings.pop(slot_id, None)
        for slot_id in slot_ids:
            bindings[slot_id] = asset_id
    normalized["assets"] = assets
    normalized["bindings"] = bindings
    return normalized


def open_path(path: Path) -> None:
    try:
        if sys.platform.startswith("win"):
            os.startfile(path)  # type: ignore[attr-defined]
        elif sys.platform == "darwin":
            subprocess.Popen(["open", str(path)])
        else:
            subprocess.Popen(["xdg-open", str(path)])
    except OSError as exc:
        messagebox.showerror("打开失败", f"无法打开路径：\n{path}\n\n{exc}")


def supported_filetype_patterns() -> str:
    return " ".join(f"*{ext}" for ext in sorted(SUPPORTED_EXTENSIONS))


def filetype_patterns_for_kind(kind: str) -> str:
    return " ".join(f"*{ext}" for ext in sorted(SUPPORTED_EXTENSIONS_BY_KIND.get(kind, set())))


def supported_extension_labels() -> str:
    return " / ".join(ext.lstrip(".") for ext in sorted(SUPPORTED_EXTENSIONS))


def asset_storage_path(info: dict) -> Path | None:
    kind = str(info.get("kind", "")).strip().lower()
    filename = str(info.get("filename", "")).strip()
    if kind not in ASSET_KIND_DIRS or not filename:
        return None
    return ASSET_KIND_DIRS[kind] / filename


def inspect_asset_file(path: Path, kind: str) -> dict:
    try:
        stat = path.stat()
    except OSError:
        return {"width": 0, "height": 0, "file_size": 0, "updated_at": 0}
    metadata = {
        "width": 0,
        "height": 0,
        "file_size": stat.st_size,
        "updated_at": int(stat.st_mtime),
    }
    if kind != "image" or PILImage is None:
        return metadata
    try:
        with PILImage.open(path) as opened_image:
            if getattr(opened_image, "is_animated", False):
                opened_image.seek(0)
            metadata["width"], metadata["height"] = opened_image.size
    except (OSError, UnidentifiedImageError):
        pass
    return metadata


def is_runtime_library_path(path: Path) -> bool:
    try:
        resolved_path = path.resolve()
    except OSError:
        return False
    return any(resolved_path.parent == directory.resolve() for directory in ASSET_KIND_DIRS.values())


def collect_importable_files(paths: Iterable[Path]) -> list[Path]:
    collected: list[Path] = []
    seen: set[str] = set()
    for raw_path in paths:
        source = Path(raw_path)
        if not source.exists():
            continue
        if source.is_dir():
            for child in sorted(source.rglob("*")):
                if not child.is_file() or detect_asset_kind(child) == "":
                    continue
                resolved = str(child.resolve()).lower()
                if resolved in seen:
                    continue
                seen.add(resolved)
                collected.append(child)
            continue
        if not source.is_file() or detect_asset_kind(source) == "":
            continue
        resolved = str(source.resolve()).lower()
        if resolved in seen:
            continue
        seen.add(resolved)
        collected.append(source)
    return collected


def _copy_binary_asset(source: Path, asset_id: str, kind: str) -> dict:
    suffix = source.suffix.lower()
    dest_name = f"{asset_id}{suffix}"
    dest_path = ASSET_KIND_DIRS[kind] / dest_name
    shutil.copy2(source, dest_path)
    return {
        "filename": dest_name,
        "width": 0,
        "height": 0,
        "file_size": dest_path.stat().st_size,
        "adapted": False,
    }


def _normalize_image_with_pillow(source: Path, asset_id: str) -> dict:
    if PILImage is None:
        raise ValueError("当前 Python 环境缺少 Pillow，无法适配该图片格式。")
    dest_name = f"{asset_id}.png"
    dest_path = ASSET_KIND_DIRS["image"] / dest_name
    try:
        with PILImage.open(source) as opened_image:
            if getattr(opened_image, "is_animated", False):
                opened_image.seek(0)
            normalized = ImageOps.exif_transpose(opened_image) if ImageOps is not None else opened_image.copy()
            use_alpha = "A" in normalized.getbands() or normalized.info.get("transparency") is not None
            normalized = normalized.convert("RGBA" if use_alpha else "RGB")
            width, height = normalized.size
            normalized.save(dest_path, "PNG")
    except (OSError, ValueError, UnidentifiedImageError) as exc:
        raise ValueError(f"读取或转换失败：{exc}") from exc
    return {
        "filename": dest_name,
        "width": width,
        "height": height,
        "file_size": dest_path.stat().st_size,
        "adapted": source.suffix.lower() != ".png",
    }


def import_assets_into_manifest(data: dict, raw_paths: Iterable[Path]) -> tuple[int, list[str]]:
    normalized = reconcile_manifest(data)
    assets = normalized.setdefault("assets", {})
    bindings = normalized.setdefault("bindings", {})
    used_ids = set(assets.keys())
    imported = 0
    skipped: list[str] = []
    files = collect_importable_files(raw_paths)
    if not files:
        data.clear()
        data.update(normalized)
        return 0, ["没有找到可导入的素材文件。"]
    for source in files:
        kind = detect_asset_kind(source)
        if not kind:
            skipped.append(f"{source.name}: 不支持的格式")
            continue
        if is_runtime_library_path(source):
            skipped.append(f"{source.name}: 已在 external_assets 素材库中")
            continue
        source_sidecar = load_asset_metadata_sidecar(asset_metadata_path_for_file(source))
        requested_id = str(source_sidecar.get("id", "")).strip()
        asset_id = normalize_external_asset_id(requested_id, source.stem) if requested_id else make_asset_id(source.stem, used_ids)
        if asset_id in used_ids:
            asset_id = make_asset_id(source.stem, used_ids)
        used_ids.add(asset_id)
        try:
            if kind == "image":
                file_info = _normalize_image_with_pillow(source, asset_id) if PILImage is not None else _copy_binary_asset(source, asset_id, kind)
            else:
                file_info = _copy_binary_asset(source, asset_id, kind)
        except (OSError, shutil.Error, ValueError) as exc:
            skipped.append(f"{source.name}: {exc}")
            continue
        label = str(source_sidecar.get("label", "")).strip() or sanitize_name(source.stem)
        assets[asset_id] = {
            "id": asset_id,
            "kind": kind,
            "label": label,
            "filename": file_info["filename"],
            "folder": ASSET_KIND_DIRS[kind].name,
            "width": int(file_info.get("width", 0)),
            "height": int(file_info.get("height", 0)),
            "file_size": int(file_info.get("file_size", 0)),
            "original_file": source.name,
            "original_ext": source.suffix.lower(),
            "adapted": bool(file_info.get("adapted", False)),
            "updated_at": int(time.time()),
        }
        if bool(source_sidecar.get("has_bindings", False)):
            for slot_id, bound_id in list(bindings.items()):
                if bound_id == asset_id:
                    bindings.pop(slot_id, None)
            for slot_id in source_sidecar.get("bindings", []):
                bindings[slot_id] = asset_id
        write_asset_metadata_sidecar(assets[asset_id], bindings)
        imported += 1
    data.clear()
    data.update(normalized)
    return imported, skipped


def replace_asset_in_manifest(data: dict, asset_id: str, source: Path) -> tuple[bool, str]:
    normalized = reconcile_manifest(data)
    assets = normalized.setdefault("assets", {})
    bindings = normalized.setdefault("bindings", {})
    info = assets.get(asset_id)
    if not isinstance(info, dict):
        data.clear()
        data.update(normalized)
        return False, "素材不存在，无法替换。"
    if not source.exists() or not source.is_file():
        data.clear()
        data.update(normalized)
        return False, "替换源文件不存在。"
    kind = str(info.get("kind", "")).strip().lower()
    source_kind = detect_asset_kind(source)
    if source_kind != kind:
        data.clear()
        data.update(normalized)
        return False, f"替换文件类型不匹配：当前素材是 {ASSET_KIND_LABELS.get(kind, kind)}。"
    old_path = asset_storage_path(info)
    try:
        if old_path is not None and old_path.exists() and source.resolve() == old_path.resolve():
            data.clear()
            data.update(normalized)
            return False, "选择的就是当前素材文件，不需要替换。"
    except OSError:
        pass
    try:
        if kind == "image":
            file_info = _normalize_image_with_pillow(source, asset_id) if PILImage is not None else _copy_binary_asset(source, asset_id, kind)
        else:
            file_info = _copy_binary_asset(source, asset_id, kind)
    except (OSError, shutil.Error, ValueError) as exc:
        data.clear()
        data.update(normalized)
        return False, f"替换失败：{exc}"
    new_filename = str(file_info.get("filename", ""))
    if old_path is not None and old_path.exists() and old_path.name != new_filename:
        try:
            old_path.unlink()
        except OSError as exc:
            data.clear()
            data.update(normalized)
            return False, f"替换完成，但旧文件清理失败：{exc}"
    info["filename"] = new_filename
    info["folder"] = ASSET_KIND_DIRS[kind].name
    info["width"] = int(file_info.get("width", 0))
    info["height"] = int(file_info.get("height", 0))
    info["file_size"] = int(file_info.get("file_size", 0))
    info["original_file"] = source.name
    info["original_ext"] = source.suffix.lower()
    info["adapted"] = bool(file_info.get("adapted", False))
    info["updated_at"] = int(time.time())
    source_sidecar = load_asset_metadata_sidecar(asset_metadata_path_for_file(source))
    sidecar_label = str(source_sidecar.get("label", "")).strip()
    if sidecar_label:
        info["label"] = sidecar_label
    if bool(source_sidecar.get("has_bindings", False)):
        for slot_id, bound_id in list(bindings.items()):
            if bound_id == asset_id:
                bindings.pop(slot_id, None)
        for slot_id in source_sidecar.get("bindings", []):
            bindings[slot_id] = asset_id
    write_asset_metadata_sidecar(info, bindings)
    data.clear()
    data.update(normalized)
    return True, f"已用 {source.name} 替换素材 {asset_id}。"


class AssetEditor(Tk):
    def __init__(self) -> None:
        super().__init__()
        ensure_layout()
        self.title("DA-FUWEN 外置素材编辑器")
        self.geometry("1040x660")
        self.minsize(920, 580)

        self.manifest = reconcile_manifest(load_manifest())
        save_manifest(self.manifest)
        self.selected_asset_id: str | None = None
        self.asset_ids: list[str] = []

        self.asset_label_var = StringVar()
        self.asset_id_var = StringVar()
        self.asset_kind_var = StringVar()
        self.filename_var = StringVar()
        self.folder_var = StringVar()
        self.asset_path_var = StringVar()
        self.asset_dimensions_var = StringVar()
        self.asset_size_var = StringVar()
        self.asset_original_var = StringVar()
        self.asset_updated_var = StringVar()
        self.binding_var = StringVar(value="不绑定")
        self.filter_text_var = StringVar()
        self.kind_filter_var = StringVar(value="全部类型")
        self.status_var = StringVar(value="外置素材目录已就绪。")
        self.preview_image = None

        self._build_ui()
        self.filter_text_var.trace_add("write", lambda *_args: self.refresh_asset_list())
        self.kind_filter_var.trace_add("write", lambda *_args: self.refresh_asset_list())
        self.bind("<Control-f>", self.focus_search)
        self.refresh_asset_list()

    def _build_ui(self) -> None:
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

        top = ttk.Frame(self, padding=12)
        top.grid(row=0, column=0, sticky="nsew")
        top.columnconfigure(0, weight=1)

        ttk.Label(top, text="项目外置素材目录").grid(row=0, column=0, sticky=W)
        ttk.Label(top, text=str(EXTERNAL_ROOT), foreground="#4b5563").grid(row=1, column=0, sticky=W, pady=(4, 0))

        button_row = ttk.Frame(top)
        button_row.grid(row=0, column=1, rowspan=2, sticky="e")
        ttk.Button(button_row, text="打开素材总目录", command=lambda: open_path(EXTERNAL_ROOT)).pack(side=LEFT, padx=(0, 8))
        ttk.Button(button_row, text="添加素材文件", command=self.add_assets).pack(side=LEFT, padx=(0, 8))
        ttk.Button(button_row, text="导入素材文件夹", command=self.add_folder).pack(side=LEFT, padx=(0, 8))
        ttk.Button(button_row, text="刷新", command=self.reload_manifest).pack(side=LEFT)

        body = ttk.Panedwindow(self, orient="horizontal")
        body.grid(row=1, column=0, sticky="nsew", padx=12, pady=(0, 12))

        left = ttk.Frame(body, padding=12)
        left.columnconfigure(0, weight=1)
        left.rowconfigure(2, weight=1)
        body.add(left, weight=3)

        ttk.Label(left, text="素材列表").grid(row=0, column=0, sticky=W)
        filter_row = ttk.Frame(left)
        filter_row.grid(row=1, column=0, sticky="ew", pady=(8, 0))
        filter_row.columnconfigure(1, weight=1)

        ttk.Label(filter_row, text="筛选").grid(row=0, column=0, sticky=W)
        self.search_entry = ttk.Entry(filter_row, textvariable=self.filter_text_var)
        self.search_entry.grid(row=0, column=1, sticky="ew", padx=(8, 8))
        self.kind_filter_combo = ttk.Combobox(
            filter_row,
            textvariable=self.kind_filter_var,
            state="readonly",
            width=10,
            values=list(KIND_FILTER_OPTIONS.keys()),
        )
        self.kind_filter_combo.grid(row=0, column=2, sticky="e")
        ttk.Button(filter_row, text="清空", command=self.clear_filters).grid(row=0, column=3, sticky="e", padx=(8, 0))

        list_frame = ttk.Frame(left)
        list_frame.grid(row=2, column=0, sticky="nsew", pady=(8, 0))
        list_frame.columnconfigure(0, weight=1)
        list_frame.rowconfigure(0, weight=1)

        self.asset_listbox = ttk.Treeview(
            list_frame,
            columns=("kind", "label", "file", "binding", "updated"),
            show="headings",
            selectmode="browse",
        )
        self.asset_listbox.heading("kind", text="类型")
        self.asset_listbox.heading("label", text="标签")
        self.asset_listbox.heading("file", text="文件")
        self.asset_listbox.heading("binding", text="绑定")
        self.asset_listbox.heading("updated", text="更新时间")
        self.asset_listbox.column("kind", width=72, anchor="center")
        self.asset_listbox.column("label", width=180, anchor="w")
        self.asset_listbox.column("file", width=240, anchor="w")
        self.asset_listbox.column("binding", width=110, anchor="center")
        self.asset_listbox.column("updated", width=118, anchor="center")
        self.asset_listbox.grid(row=0, column=0, sticky="nsew")
        self.asset_listbox.bind("<<TreeviewSelect>>", self.on_asset_selected)
        self.asset_listbox.bind("<Double-1>", self.open_selected_asset_file)

        scrollbar = ttk.Scrollbar(list_frame, orient=VERTICAL, command=self.asset_listbox.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        self.asset_listbox.configure(yscrollcommand=scrollbar.set)

        left_buttons = ttk.Frame(left)
        left_buttons.grid(row=3, column=0, sticky=W, pady=(10, 0))
        self.remove_button = ttk.Button(left_buttons, text="删除选中素材", command=self.remove_selected_asset)
        self.remove_button.pack(side=LEFT)

        right = ttk.Frame(body, padding=12)
        right.columnconfigure(1, weight=1)
        body.add(right, weight=2)

        ttk.Label(right, text="素材详情").grid(row=0, column=0, columnspan=2, sticky=W)

        preview_frame = ttk.Frame(right, padding=10, relief="groove", borderwidth=1)
        preview_frame.grid(row=1, column=0, columnspan=2, sticky="ew", pady=(12, 0))
        preview_frame.columnconfigure(0, weight=1)
        ttk.Label(preview_frame, text="预览").grid(row=0, column=0, sticky=W)
        self.preview_label = ttk.Label(preview_frame, text="选中素材后，这里会显示图片预览或文件摘要。", anchor="center", justify="center")
        self.preview_label.grid(row=1, column=0, sticky="ew", pady=(8, 0))

        ttk.Label(right, text="素材 ID").grid(row=2, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_id_var, state="readonly").grid(row=2, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="素材类型").grid(row=3, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_kind_var, state="readonly").grid(row=3, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="文件名").grid(row=4, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.filename_var, state="readonly").grid(row=4, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="素材目录").grid(row=5, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.folder_var, state="readonly").grid(row=5, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="磁盘路径").grid(row=6, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_path_var, state="readonly").grid(row=6, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="分辨率").grid(row=7, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_dimensions_var, state="readonly").grid(row=7, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="文件大小").grid(row=8, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_size_var, state="readonly").grid(row=8, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="原始文件").grid(row=9, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_original_var, state="readonly").grid(row=9, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="更新时间").grid(row=10, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_updated_var, state="readonly").grid(row=10, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="显示标签").grid(row=11, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_label_var).grid(row=11, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="快捷绑定").grid(row=12, column=0, sticky=W, pady=(12, 0))
        self.binding_combo = ttk.Combobox(
            right,
            textvariable=self.binding_var,
            state="readonly",
            values=["不绑定"],
        )
        self.binding_combo.grid(row=12, column=1, sticky="ew", pady=(12, 0))

        help_text = (
            "说明:\n"
            f"1. 编辑器可导入 {supported_extension_labels()}。\n"
            "2. 图片会按需要适配成游戏稳定可读取的格式，其它素材会按原格式归档。\n"
            "3. 每个素材都可以有一个同目录的 .asset.json 对应配置文件，例如 hero.png.asset.json。\n"
            "4. 快捷绑定会按素材类型显示可用槽位，例如主菜单背景 / 主菜单音乐 / 界面字体。\n"
            "5. 选择文件夹时会递归扫描里面的可用素材并按类型归档到 external_assets。\n"
            "6. 选中素材后可替换原文件，保留当前素材 ID 和已有绑定关系。\n"
            "7. 游戏启动时会自动同步该目录；如果游戏已开着，重新打开设置页即可触发一次同步。"
        )
        ttk.Label(right, text=help_text, justify=LEFT, foreground="#4b5563").grid(
            row=13, column=0, columnspan=2, sticky="ew", pady=(18, 0)
        )

        action_row = ttk.Frame(right)
        action_row.grid(row=14, column=0, columnspan=2, sticky=W, pady=(18, 0))
        self.save_button = ttk.Button(action_row, text="保存修改", command=self.save_selected_asset)
        self.save_button.pack(side=LEFT, padx=(0, 8))
        self.open_file_button = ttk.Button(action_row, text="打开当前素材文件", command=self.open_selected_asset_file)
        self.open_file_button.pack(side=LEFT, padx=(0, 8))
        self.replace_button = ttk.Button(action_row, text="替换当前素材文件", command=self.replace_selected_asset)
        self.replace_button.pack(side=LEFT, padx=(0, 8))
        self.open_kind_button = ttk.Button(action_row, text="打开当前类型目录", command=self.open_selected_kind_folder)
        self.open_kind_button.pack(side=LEFT, padx=(0, 8))
        ttk.Button(action_row, text="重新读取目录", command=self.reload_manifest).pack(side=LEFT)

        status = ttk.Label(self, textvariable=self.status_var, padding=(12, 0, 12, 12), foreground="#374151")
        status.grid(row=2, column=0, sticky="ew")

    def _binding_label_for_asset(self, asset_id: str) -> str:
        labels = binding_labels_for_asset(asset_id, dict(self.manifest.get("bindings", {})))
        return " / ".join(labels)

    def _status_summary(self, visible_count: int | None = None) -> str:
        assets = self.manifest.get("assets", {})
        counts = []
        for kind in ordered_kinds():
            kind_count = sum(1 for info in assets.values() if isinstance(info, dict) and info.get("kind") == kind)
            if kind_count > 0:
                counts.append(f"{ASSET_KIND_LABELS[kind]} {kind_count}")
        detail = " ｜ ".join(counts) if counts else "还没有素材"
        if visible_count is not None and visible_count != len(assets):
            return f"当前显示 {visible_count}/{len(assets)} 个外置素材。{detail}"
        return f"当前共 {len(assets)} 个外置素材。{detail}"

    def _filtered_asset_ids(self) -> list[str]:
        assets = self.manifest.get("assets", {})
        keyword = self.filter_text_var.get().strip().lower()
        kind_filter = KIND_FILTER_OPTIONS.get(self.kind_filter_var.get(), "")
        filtered: list[tuple[str, dict]] = []
        for asset_id, info in assets.items():
            if not isinstance(info, dict):
                continue
            kind = str(info.get("kind", "")).strip().lower()
            if kind_filter and kind != kind_filter:
                continue
            haystack = " ".join(
                [
                    asset_id,
                    str(info.get("label", "")),
                    str(info.get("filename", "")),
                    str(info.get("original_file", "")),
                ]
            ).lower()
            if keyword and keyword not in haystack:
                continue
            filtered.append((asset_id, info))
        filtered.sort(key=lambda item: asset_sort_key(item[0], item[1]))
        return [asset_id for asset_id, _info in filtered]

    def _set_selected_actions_enabled(self, enabled: bool) -> None:
        state = "normal" if enabled else "disabled"
        self.remove_button.configure(state=state)
        self.save_button.configure(state=state)
        self.open_file_button.configure(state=state)
        self.replace_button.configure(state=state)
        self.open_kind_button.configure(state=state)

    def _clear_preview(self, text: str) -> None:
        self.preview_image = None
        self.preview_label.configure(image="", text=text)

    def _update_preview(self, asset_path: Path | None, kind: str) -> None:
        if asset_path is None or not asset_path.exists():
            self._clear_preview("当前素材文件不存在。")
            return
        if kind != "image":
            notes = {
                "audio": "音频素材不提供波形预览。\n可点击“打开当前素材文件”用系统默认程序查看。",
                "video": "视频素材不在编辑器内播放。\n可点击“打开当前素材文件”用系统默认程序查看。",
                "font": "字体素材不做字形预览。\n可双击左侧列表项或点击按钮打开文件。",
                "file": "数据文件不在此处展开内容。\n可双击左侧列表项或点击按钮打开文件。",
            }
            self._clear_preview(notes.get(kind, "当前素材没有可用预览。"))
            return
        if PILImage is not None and ImageTk is not None:
            try:
                with PILImage.open(asset_path) as opened_image:
                    if getattr(opened_image, "is_animated", False):
                        opened_image.seek(0)
                    preview = ImageOps.exif_transpose(opened_image) if ImageOps is not None else opened_image.copy()
                    preview = preview.convert("RGBA" if "A" in preview.getbands() else "RGB")
                    resampling = getattr(getattr(PILImage, "Resampling", PILImage), "LANCZOS", PILImage.LANCZOS)
                    preview.thumbnail((320, 220), resampling)
                    self.preview_image = ImageTk.PhotoImage(preview)
                    self.preview_label.configure(image=self.preview_image, text="")
                    return
            except (OSError, ValueError, UnidentifiedImageError):
                pass
        if asset_path.suffix.lower() == ".png":
            try:
                preview_image = PhotoImage(file=str(asset_path))
                width_ratio = max(1, (preview_image.width() + 319) // 320)
                height_ratio = max(1, (preview_image.height() + 219) // 220)
                scale = max(width_ratio, height_ratio)
                if scale > 1:
                    preview_image = preview_image.subsample(scale, scale)
                self.preview_image = preview_image
                self.preview_label.configure(image=self.preview_image, text="")
                return
            except Exception:
                pass
        self._clear_preview("当前环境无法预览该图片。\n如果安装了 Pillow，可获得更完整的图片预览能力。")

    def clear_filters(self) -> None:
        self.filter_text_var.set("")
        self.kind_filter_var.set("全部类型")
        self.search_entry.focus_set()

    def focus_search(self, _event=None) -> str:
        self.search_entry.focus_set()
        self.search_entry.selection_range(0, END)
        return "break"

    def refresh_asset_list(self) -> None:
        for item in self.asset_listbox.get_children():
            self.asset_listbox.delete(item)
        assets = self.manifest.get("assets", {})
        self.asset_ids = self._filtered_asset_ids()
        for asset_id in self.asset_ids:
            info = assets[asset_id]
            kind = str(info.get("kind", "file"))
            self.asset_listbox.insert(
                "",
                END,
                iid=asset_id,
                values=(
                    ASSET_KIND_LABELS.get(kind, kind),
                    info.get("label", asset_id),
                    info.get("filename", ""),
                    self._binding_label_for_asset(asset_id),
                    format_timestamp(int(info.get("updated_at", 0)), short=True),
                ),
            )
        if self.selected_asset_id in self.asset_ids:
            self.asset_listbox.selection_set(self.selected_asset_id)
            self.asset_listbox.focus(self.selected_asset_id)
            self.populate_editor(self.selected_asset_id)
        else:
            self.selected_asset_id = None
            self.populate_editor(None)
        self.status_var.set(self._status_summary(len(self.asset_ids)))

    def populate_editor(self, asset_id: str | None) -> None:
        if asset_id is None:
            self.asset_id_var.set("")
            self.asset_kind_var.set("")
            self.filename_var.set("")
            self.folder_var.set("")
            self.asset_path_var.set("")
            self.asset_dimensions_var.set("")
            self.asset_size_var.set("")
            self.asset_original_var.set("")
            self.asset_updated_var.set("")
            self.asset_label_var.set("")
            self.binding_var.set("不绑定")
            self.binding_combo.configure(values=["不绑定"])
            self.binding_combo.configure(state="disabled")
            self._set_selected_actions_enabled(False)
            self._clear_preview("选中素材后，这里会显示图片预览或文件摘要。")
            return
        info = self.manifest.get("assets", {}).get(asset_id, {})
        kind = str(info.get("kind", "file"))
        file_path = asset_storage_path(info)
        binding_options = binding_options_for_asset(dict(info))
        active_binding_labels = binding_labels_for_asset(asset_id, dict(self.manifest.get("bindings", {})))
        self.asset_id_var.set(asset_id)
        self.asset_kind_var.set(ASSET_KIND_LABELS.get(kind, kind))
        self.filename_var.set(str(info.get("filename", "")))
        self.folder_var.set(str(info.get("folder", ASSET_KIND_DIRS[kind].name)))
        self.asset_path_var.set(str(file_path) if file_path is not None else "")
        self.asset_dimensions_var.set(format_dimensions(int(info.get("width", 0)), int(info.get("height", 0))))
        self.asset_size_var.set(format_file_size(int(info.get("file_size", 0))))
        original_file = str(info.get("original_file", ""))
        if bool(info.get("adapted", False)) and original_file:
            original_file = f"{original_file} -> {info.get('filename', '')}"
        self.asset_original_var.set(original_file)
        self.asset_updated_var.set(format_timestamp(int(info.get("updated_at", 0))))
        self.asset_label_var.set(str(info.get("label", asset_id)))
        self.binding_combo.configure(values=list(binding_options.keys()))
        if len(binding_options) > 1:
            self.binding_var.set(active_binding_labels[0] if active_binding_labels else "不绑定")
            self.binding_combo.configure(state="readonly")
        else:
            self.binding_var.set("不绑定")
            self.binding_combo.configure(state="disabled")
        self._set_selected_actions_enabled(True)
        self._update_preview(file_path, kind)

    def on_asset_selected(self, _event=None) -> None:
        selection = self.asset_listbox.selection()
        self.selected_asset_id = selection[0] if selection else None
        self.populate_editor(self.selected_asset_id)

    def reload_manifest(self) -> None:
        self.manifest = reconcile_manifest(load_manifest())
        save_manifest(self.manifest)
        self.refresh_asset_list()
        self.status_var.set("已重新扫描 external_assets 下的素材目录。")

    def add_assets(self) -> None:
        paths = filedialog.askopenfilenames(
            title="选择要加入外置素材库的素材文件",
            filetypes=[("Supported Assets", supported_filetype_patterns())],
        )
        if not paths:
            return
        self._import_external_assets([Path(raw_path) for raw_path in paths], "素材文件")

    def add_folder(self) -> None:
        folder = filedialog.askdirectory(title="选择要批量导入的素材文件夹")
        if not folder:
            return
        self._import_external_assets([Path(folder)], "素材文件夹")

    def _import_external_assets(self, raw_paths: list[Path], source_label: str) -> None:
        imported, skipped = import_assets_into_manifest(self.manifest, raw_paths)
        save_manifest(self.manifest)
        self.reload_manifest()
        if skipped:
            messagebox.showwarning("部分文件未导入", "\n".join(skipped))
        if imported > 0:
            self.status_var.set(f"已从{source_label}导入 {imported} 个素材。")
            return
        self.status_var.set(f"没有从{source_label}导入任何素材。")

    def open_selected_asset_file(self, _event=None) -> None:
        if not self.selected_asset_id:
            messagebox.showinfo("未选择素材", "先在左侧列表中选择 1 个素材。")
            return
        info = self.manifest.get("assets", {}).get(self.selected_asset_id, {})
        file_path = asset_storage_path(info)
        if file_path is None or not file_path.exists():
            messagebox.showerror("文件不存在", "当前素材文件不存在，建议先重新读取目录。")
            return
        open_path(file_path)

    def replace_selected_asset(self) -> None:
        if not self.selected_asset_id:
            messagebox.showinfo("未选择素材", "先在左侧列表中选择 1 个素材。")
            return
        info = self.manifest.get("assets", {}).get(self.selected_asset_id, {})
        kind = str(info.get("kind", "")).strip().lower()
        if kind not in ASSET_KIND_DIRS:
            return
        path = filedialog.askopenfilename(
            title=f"选择新的{ASSET_KIND_LABELS.get(kind, kind)}文件",
            filetypes=[
                (f"{ASSET_KIND_LABELS.get(kind, kind)}文件", filetype_patterns_for_kind(kind)),
                ("所有文件", "*.*"),
            ],
        )
        if not path:
            return
        ok, message = replace_asset_in_manifest(self.manifest, self.selected_asset_id, Path(path))
        if ok:
            save_manifest(self.manifest)
            self.reload_manifest()
            self.status_var.set(message)
            return
        messagebox.showerror("替换失败", message)

    def save_selected_asset(self) -> None:
        if not self.selected_asset_id:
            messagebox.showinfo("未选择素材", "先在左侧列表中选择 1 个素材。")
            return
        assets = self.manifest.setdefault("assets", {})
        bindings = self.manifest.setdefault("bindings", {})
        info = assets.get(self.selected_asset_id)
        if not isinstance(info, dict):
            return
        info["label"] = self.asset_label_var.get().strip() or self.selected_asset_id
        info["updated_at"] = int(time.time())
        selected_slot_id = binding_options_for_asset(dict(info)).get(self.binding_var.get(), "")
        for slot_id, bound_id in list(bindings.items()):
            if bound_id == self.selected_asset_id and (not selected_slot_id or slot_id != selected_slot_id):
                bindings.pop(slot_id, None)
        if selected_slot_id:
            bindings[selected_slot_id] = self.selected_asset_id
        write_asset_metadata_sidecar(info, bindings)
        save_manifest(self.manifest)
        self.refresh_asset_list()
        self.status_var.set(f"已保存 {self.selected_asset_id} 的修改。")

    def open_selected_kind_folder(self) -> None:
        if not self.selected_asset_id:
            messagebox.showinfo("未选择素材", "先在左侧列表中选择 1 个素材。")
            return
        info = self.manifest.get("assets", {}).get(self.selected_asset_id, {})
        kind = str(info.get("kind", ""))
        if kind not in ASSET_KIND_DIRS:
            return
        open_path(ASSET_KIND_DIRS[kind])

    def remove_selected_asset(self) -> None:
        if not self.selected_asset_id:
            messagebox.showinfo("未选择素材", "先在左侧列表中选择 1 个素材。")
            return
        assets = self.manifest.setdefault("assets", {})
        bindings = self.manifest.setdefault("bindings", {})
        info = assets.get(self.selected_asset_id)
        if not isinstance(info, dict):
            return
        if not messagebox.askyesno("确认删除", f"确定删除素材 {self.selected_asset_id} 吗？"):
            return
        kind = str(info.get("kind", "file"))
        filename = str(info.get("filename", ""))
        if filename and kind in ASSET_KIND_DIRS:
            file_path = ASSET_KIND_DIRS[kind] / filename
            if file_path.exists():
                try:
                    file_path.unlink()
                except OSError as exc:
                    messagebox.showerror("删除失败", f"无法删除文件：\n{file_path}\n\n{exc}")
                    return
            sidecar_path = asset_metadata_path_for_file(file_path)
            if sidecar_path.exists():
                try:
                    sidecar_path.unlink()
                except OSError as exc:
                    messagebox.showerror("删除失败", f"无法删除素材配置：\n{sidecar_path}\n\n{exc}")
                    return
        assets.pop(self.selected_asset_id, None)
        for slot_id, bound_id in list(bindings.items()):
            if bound_id == self.selected_asset_id:
                bindings.pop(slot_id, None)
        removed_id = self.selected_asset_id
        self.selected_asset_id = None
        save_manifest(self.manifest)
        self.reload_manifest()
        self.status_var.set(f"已删除素材 {removed_id}。")


if __name__ == "__main__":
    app = AssetEditor()
    app.mainloop()

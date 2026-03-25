from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from collections.abc import Iterable
from pathlib import Path
from tkinter import END, LEFT, VERTICAL, W, filedialog, messagebox, StringVar, Tk
from tkinter import ttk

try:
    from PIL import Image as PILImage
    from PIL import ImageOps, UnidentifiedImageError
except ImportError:
    PILImage = None
    ImageOps = None
    UnidentifiedImageError = OSError


PROJECT_ROOT = Path(__file__).resolve().parents[1]
EXTERNAL_ROOT = PROJECT_ROOT / "external_assets"
MANIFEST_PATH = EXTERNAL_ROOT / "manifest.json"
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
BINDING_OPTIONS = {
    "不绑定": "",
    "主菜单背景": SLOT_MAIN_MENU_BG,
}


def ordered_kinds() -> list[str]:
    return ["image", "audio", "font", "video", "file"]


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


def detect_asset_kind(path: Path) -> str:
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
    assets = normalized.setdefault("assets", {})
    bindings = normalized.setdefault("bindings", {})
    used_ids = set(assets.keys())
    existing_files: dict[str, dict[str, str]] = {}
    for kind in ordered_kinds():
        directory = ASSET_KIND_DIRS[kind]
        existing_files[kind] = {
            path.name.lower(): path.name
            for path in directory.iterdir()
            if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS_BY_KIND[kind]
        }

    missing_ids = []
    for asset_id, info in list(assets.items()):
        if not isinstance(info, dict):
            missing_ids.append(asset_id)
            continue
        kind = str(info.get("kind", "")).strip().lower()
        filename = str(info.get("filename", "")).strip().lower()
        if kind not in existing_files or filename not in existing_files[kind]:
            missing_ids.append(asset_id)
    for asset_id in missing_ids:
        assets.pop(asset_id, None)
        for slot_id, bound_id in list(bindings.items()):
            if bound_id == asset_id:
                bindings.pop(slot_id, None)

    known_files = referenced_files(assets)
    for kind in ordered_kinds():
        for lower_name, real_name in sorted(existing_files[kind].items()):
            file_key = asset_file_key(kind, real_name)
            if file_key in known_files:
                continue
            asset_id = make_asset_id(Path(real_name).stem, used_ids)
            used_ids.add(asset_id)
            assets[asset_id] = {
                "id": asset_id,
                "kind": kind,
                "label": sanitize_name(Path(real_name).stem),
                "filename": real_name,
                "folder": ASSET_KIND_DIRS[kind].name,
                "updated_at": int(time.time()),
            }
    return normalized


def open_folder(path: Path) -> None:
    try:
        if sys.platform.startswith("win"):
            os.startfile(path)  # type: ignore[attr-defined]
        elif sys.platform == "darwin":
            subprocess.Popen(["open", str(path)])
        else:
            subprocess.Popen(["xdg-open", str(path)])
    except OSError as exc:
        messagebox.showerror("打开失败", f"无法打开目录：\n{path}\n\n{exc}")


def supported_filetype_patterns() -> str:
    return " ".join(f"*{ext}" for ext in sorted(SUPPORTED_EXTENSIONS))


def supported_extension_labels() -> str:
    return " / ".join(ext.lstrip(".") for ext in sorted(SUPPORTED_EXTENSIONS))


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
        assets[asset_id] = {
            "id": asset_id,
            "kind": kind,
            "label": sanitize_name(source.stem),
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
        imported += 1
    data.clear()
    data.update(normalized)
    return imported, skipped


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
        self.binding_var = StringVar(value="不绑定")
        self.status_var = StringVar(value="外置素材目录已就绪。")

        self._build_ui()
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
        ttk.Button(button_row, text="打开素材总目录", command=lambda: open_folder(EXTERNAL_ROOT)).pack(side=LEFT, padx=(0, 8))
        ttk.Button(button_row, text="添加素材文件", command=self.add_assets).pack(side=LEFT, padx=(0, 8))
        ttk.Button(button_row, text="导入素材文件夹", command=self.add_folder).pack(side=LEFT, padx=(0, 8))
        ttk.Button(button_row, text="刷新", command=self.reload_manifest).pack(side=LEFT)

        body = ttk.Panedwindow(self, orient="horizontal")
        body.grid(row=1, column=0, sticky="nsew", padx=12, pady=(0, 12))

        left = ttk.Frame(body, padding=12)
        left.columnconfigure(0, weight=1)
        left.rowconfigure(1, weight=1)
        body.add(left, weight=3)

        ttk.Label(left, text="素材列表").grid(row=0, column=0, sticky=W)
        list_frame = ttk.Frame(left)
        list_frame.grid(row=1, column=0, sticky="nsew", pady=(8, 0))
        list_frame.columnconfigure(0, weight=1)
        list_frame.rowconfigure(0, weight=1)

        self.asset_listbox = ttk.Treeview(
            list_frame,
            columns=("kind", "label", "file", "binding"),
            show="headings",
            selectmode="browse",
        )
        self.asset_listbox.heading("kind", text="类型")
        self.asset_listbox.heading("label", text="标签")
        self.asset_listbox.heading("file", text="文件")
        self.asset_listbox.heading("binding", text="绑定")
        self.asset_listbox.column("kind", width=72, anchor="center")
        self.asset_listbox.column("label", width=180, anchor="w")
        self.asset_listbox.column("file", width=260, anchor="w")
        self.asset_listbox.column("binding", width=90, anchor="center")
        self.asset_listbox.grid(row=0, column=0, sticky="nsew")
        self.asset_listbox.bind("<<TreeviewSelect>>", self.on_asset_selected)

        scrollbar = ttk.Scrollbar(list_frame, orient=VERTICAL, command=self.asset_listbox.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        self.asset_listbox.configure(yscrollcommand=scrollbar.set)

        left_buttons = ttk.Frame(left)
        left_buttons.grid(row=2, column=0, sticky=W, pady=(10, 0))
        ttk.Button(left_buttons, text="删除选中素材", command=self.remove_selected_asset).pack(side=LEFT)

        right = ttk.Frame(body, padding=12)
        right.columnconfigure(1, weight=1)
        body.add(right, weight=2)

        ttk.Label(right, text="素材详情").grid(row=0, column=0, columnspan=2, sticky=W)

        ttk.Label(right, text="素材 ID").grid(row=1, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_id_var, state="readonly").grid(row=1, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="素材类型").grid(row=2, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_kind_var, state="readonly").grid(row=2, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="文件名").grid(row=3, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.filename_var, state="readonly").grid(row=3, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="素材目录").grid(row=4, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.folder_var, state="readonly").grid(row=4, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="显示标签").grid(row=5, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_label_var).grid(row=5, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="快捷绑定").grid(row=6, column=0, sticky=W, pady=(12, 0))
        self.binding_combo = ttk.Combobox(
            right,
            textvariable=self.binding_var,
            state="readonly",
            values=list(BINDING_OPTIONS.keys()),
        )
        self.binding_combo.grid(row=6, column=1, sticky="ew", pady=(12, 0))

        help_text = (
            "说明:\n"
            f"1. 编辑器可导入 {supported_extension_labels()}。\n"
            "2. 图片会按需要适配成游戏稳定可读取的格式，其它素材会按原格式归档。\n"
            "3. 选择文件夹时会递归扫描里面的可用素材并按类型归档到 external_assets。\n"
            "4. 游戏启动时会自动同步该目录；如果游戏已开着，重新打开设置页即可触发一次同步。"
        )
        ttk.Label(right, text=help_text, justify=LEFT, foreground="#4b5563").grid(
            row=7, column=0, columnspan=2, sticky="ew", pady=(18, 0)
        )

        action_row = ttk.Frame(right)
        action_row.grid(row=8, column=0, columnspan=2, sticky=W, pady=(18, 0))
        ttk.Button(action_row, text="保存修改", command=self.save_selected_asset).pack(side=LEFT, padx=(0, 8))
        ttk.Button(action_row, text="打开当前类型目录", command=self.open_selected_kind_folder).pack(side=LEFT, padx=(0, 8))
        ttk.Button(action_row, text="重新读取目录", command=self.reload_manifest).pack(side=LEFT)

        status = ttk.Label(self, textvariable=self.status_var, padding=(12, 0, 12, 12), foreground="#374151")
        status.grid(row=2, column=0, sticky="ew")

    def _binding_label_for_asset(self, asset_id: str) -> str:
        if self.manifest.get("bindings", {}).get(SLOT_MAIN_MENU_BG) == asset_id:
            return "主菜单"
        return ""

    def _status_summary(self) -> str:
        assets = self.manifest.get("assets", {})
        counts = []
        for kind in ordered_kinds():
            kind_count = sum(1 for info in assets.values() if isinstance(info, dict) and info.get("kind") == kind)
            if kind_count > 0:
                counts.append(f"{ASSET_KIND_LABELS[kind]} {kind_count}")
        detail = " ｜ ".join(counts) if counts else "还没有素材"
        return f"当前共 {len(assets)} 个外置素材。{detail}"

    def refresh_asset_list(self) -> None:
        for item in self.asset_listbox.get_children():
            self.asset_listbox.delete(item)
        assets = self.manifest.get("assets", {})
        self.asset_ids = sorted(assets.keys())
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
                ),
            )
        if self.selected_asset_id in assets:
            self.asset_listbox.selection_set(self.selected_asset_id)
            self.asset_listbox.focus(self.selected_asset_id)
            self.populate_editor(self.selected_asset_id)
        else:
            self.selected_asset_id = None
            self.populate_editor(None)
        self.status_var.set(self._status_summary())

    def populate_editor(self, asset_id: str | None) -> None:
        if asset_id is None:
            self.asset_id_var.set("")
            self.asset_kind_var.set("")
            self.filename_var.set("")
            self.folder_var.set("")
            self.asset_label_var.set("")
            self.binding_var.set("不绑定")
            self.binding_combo.configure(state="disabled")
            return
        info = self.manifest.get("assets", {}).get(asset_id, {})
        kind = str(info.get("kind", "file"))
        self.asset_id_var.set(asset_id)
        self.asset_kind_var.set(ASSET_KIND_LABELS.get(kind, kind))
        self.filename_var.set(str(info.get("filename", "")))
        self.folder_var.set(str(info.get("folder", ASSET_KIND_DIRS[kind].name)))
        self.asset_label_var.set(str(info.get("label", asset_id)))
        binding_value = self.manifest.get("bindings", {}).get(SLOT_MAIN_MENU_BG, "")
        if kind == "image":
            self.binding_var.set("主菜单背景" if binding_value == asset_id else "不绑定")
            self.binding_combo.configure(state="readonly")
        else:
            self.binding_var.set("不绑定")
            self.binding_combo.configure(state="disabled")

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

    def save_selected_asset(self) -> None:
        if not self.selected_asset_id:
            messagebox.showinfo("未选择素材", "先在左侧列表中选择 1 个素材。")
            return
        assets = self.manifest.setdefault("assets", {})
        bindings = self.manifest.setdefault("bindings", {})
        info = assets.get(self.selected_asset_id)
        if not isinstance(info, dict):
            return
        kind = str(info.get("kind", "file"))
        info["label"] = self.asset_label_var.get().strip() or self.selected_asset_id
        info["updated_at"] = int(time.time())
        if kind == "image" and self.binding_var.get() == "主菜单背景":
            bindings[SLOT_MAIN_MENU_BG] = self.selected_asset_id
        elif bindings.get(SLOT_MAIN_MENU_BG) == self.selected_asset_id:
            bindings.pop(SLOT_MAIN_MENU_BG, None)
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
        open_folder(ASSET_KIND_DIRS[kind])

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
                file_path.unlink()
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

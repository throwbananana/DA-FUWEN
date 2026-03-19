from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from tkinter import BOTH, END, LEFT, RIGHT, VERTICAL, W, filedialog, messagebox, StringVar, Tk
from tkinter import ttk


PROJECT_ROOT = Path(__file__).resolve().parents[1]
EXTERNAL_ROOT = PROJECT_ROOT / "external_assets"
IMAGES_DIR = EXTERNAL_ROOT / "images"
MANIFEST_PATH = EXTERNAL_ROOT / "manifest.json"
SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
SLOT_MAIN_MENU_BG = "main_menu_bg"


def ensure_layout() -> None:
    IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    if not MANIFEST_PATH.exists():
        save_manifest(default_manifest())


def default_manifest() -> dict:
    return {"images": {}, "bindings": {}}


def load_manifest() -> dict:
    ensure_layout()
    try:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        data = default_manifest()
    if not isinstance(data, dict):
        data = default_manifest()
    if not isinstance(data.get("images"), dict):
        data["images"] = {}
    if not isinstance(data.get("bindings"), dict):
        data["bindings"] = {}
    return data


def save_manifest(data: dict) -> None:
    normalized = {
        "images": dict(sorted(data.get("images", {}).items(), key=lambda item: item[0])),
        "bindings": dict(sorted(data.get("bindings", {}).items(), key=lambda item: item[0])),
    }
    MANIFEST_PATH.write_text(json.dumps(normalized, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def sanitize_name(value: str) -> str:
    cleaned = "".join(ch.lower() if ch.isalnum() else "_" for ch in value.strip())
    while "__" in cleaned:
        cleaned = cleaned.replace("__", "_")
    cleaned = cleaned.strip("_")
    return cleaned or "image"


def make_asset_id(stem: str, used_ids: set[str]) -> str:
    base = f"ext_{sanitize_name(stem)}"
    asset_id = base
    serial = 1
    while asset_id in used_ids:
        asset_id = f"{base}_{serial}"
        serial += 1
    return asset_id


def referenced_files(images: dict) -> set[str]:
    result: set[str] = set()
    for info in images.values():
        if isinstance(info, dict):
            filename = str(info.get("filename", "")).strip()
            if filename:
                result.add(filename.lower())
    return result


def reconcile_manifest(data: dict) -> dict:
    images = data.setdefault("images", {})
    bindings = data.setdefault("bindings", {})
    used_ids = set(images.keys())
    existing_files = {
        path.name.lower(): path.name
        for path in IMAGES_DIR.iterdir()
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS
    }

    missing_ids = [
        asset_id
        for asset_id, info in images.items()
        if str(info.get("filename", "")).lower() not in existing_files
    ]
    for asset_id in missing_ids:
        images.pop(asset_id, None)
        for slot_id, bound_id in list(bindings.items()):
            if bound_id == asset_id:
                bindings.pop(slot_id, None)

    known_files = referenced_files(images)
    for lower_name, real_name in sorted(existing_files.items()):
        if lower_name in known_files:
            continue
        asset_id = make_asset_id(Path(real_name).stem, used_ids)
        used_ids.add(asset_id)
        images[asset_id] = {
            "id": asset_id,
            "label": sanitize_name(Path(real_name).stem),
            "filename": real_name,
            "updated_at": int(time.time()),
        }
    return data


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


class AssetEditor(Tk):
    def __init__(self) -> None:
        super().__init__()
        ensure_layout()
        self.title("DA-FUWEN 外置素材编辑器")
        self.geometry("960x620")
        self.minsize(880, 560)

        self.manifest = reconcile_manifest(load_manifest())
        save_manifest(self.manifest)
        self.selected_asset_id: str | None = None
        self.asset_ids: list[str] = []

        self.asset_label_var = StringVar()
        self.asset_id_var = StringVar()
        self.filename_var = StringVar()
        self.binding_var = StringVar()
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
        ttk.Label(top, text=str(IMAGES_DIR), foreground="#4b5563").grid(row=1, column=0, sticky=W, pady=(4, 0))

        button_row = ttk.Frame(top)
        button_row.grid(row=0, column=1, rowspan=2, sticky="e")
        ttk.Button(button_row, text="打开素材文件夹", command=lambda: open_folder(IMAGES_DIR)).pack(side=LEFT, padx=(0, 8))
        ttk.Button(button_row, text="添加图片", command=self.add_images).pack(side=LEFT, padx=(0, 8))
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
            columns=("label", "file", "binding"),
            show="headings",
            selectmode="browse",
        )
        self.asset_listbox.heading("label", text="标签")
        self.asset_listbox.heading("file", text="文件")
        self.asset_listbox.heading("binding", text="绑定")
        self.asset_listbox.column("label", width=180, anchor="w")
        self.asset_listbox.column("file", width=240, anchor="w")
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

        ttk.Label(right, text="文件名").grid(row=2, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.filename_var, state="readonly").grid(row=2, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="显示标签").grid(row=3, column=0, sticky=W, pady=(12, 0))
        ttk.Entry(right, textvariable=self.asset_label_var).grid(row=3, column=1, sticky="ew", pady=(12, 0))

        ttk.Label(right, text="快捷绑定").grid(row=4, column=0, sticky=W, pady=(12, 0))
        binding_combo = ttk.Combobox(
            right,
            textvariable=self.binding_var,
            state="readonly",
            values=["不绑定", "主菜单背景"],
        )
        binding_combo.grid(row=4, column=1, sticky="ew", pady=(12, 0))

        help_text = (
            "说明:\n"
            "1. 添加图片后会复制到 external_assets/images。\n"
            "2. 游戏启动时会自动同步该目录，不需要进入 Godot 编辑器导入。\n"
            "3. 如果游戏已开着，重新打开设置页即可触发一次同步。"
        )
        ttk.Label(right, text=help_text, justify=LEFT, foreground="#4b5563").grid(
            row=5, column=0, columnspan=2, sticky="ew", pady=(18, 0)
        )

        action_row = ttk.Frame(right)
        action_row.grid(row=6, column=0, columnspan=2, sticky=W, pady=(18, 0))
        ttk.Button(action_row, text="保存修改", command=self.save_selected_asset).pack(side=LEFT, padx=(0, 8))
        ttk.Button(action_row, text="重新读取目录", command=self.reload_manifest).pack(side=LEFT)

        status = ttk.Label(self, textvariable=self.status_var, padding=(12, 0, 12, 12), foreground="#374151")
        status.grid(row=2, column=0, sticky="ew")

    def refresh_asset_list(self) -> None:
        for item in self.asset_listbox.get_children():
            self.asset_listbox.delete(item)
        images = self.manifest.get("images", {})
        bindings = self.manifest.get("bindings", {})
        self.asset_ids = sorted(images.keys())
        for asset_id in self.asset_ids:
            info = images[asset_id]
            binding_text = "主菜单" if bindings.get(SLOT_MAIN_MENU_BG) == asset_id else ""
            self.asset_listbox.insert(
                "",
                END,
                iid=asset_id,
                values=(info.get("label", asset_id), info.get("filename", ""), binding_text),
            )
        if self.selected_asset_id in images:
            self.asset_listbox.selection_set(self.selected_asset_id)
            self.asset_listbox.focus(self.selected_asset_id)
            self.populate_editor(self.selected_asset_id)
        else:
            self.selected_asset_id = None
            self.populate_editor(None)
        self.status_var.set(f"当前共 {len(self.asset_ids)} 张外置素材。")

    def populate_editor(self, asset_id: str | None) -> None:
        if asset_id is None:
            self.asset_id_var.set("")
            self.filename_var.set("")
            self.asset_label_var.set("")
            self.binding_var.set("不绑定")
            return
        info = self.manifest.get("images", {}).get(asset_id, {})
        self.asset_id_var.set(asset_id)
        self.filename_var.set(str(info.get("filename", "")))
        self.asset_label_var.set(str(info.get("label", asset_id)))
        binding_value = self.manifest.get("bindings", {}).get(SLOT_MAIN_MENU_BG, "")
        self.binding_var.set("主菜单背景" if binding_value == asset_id else "不绑定")

    def on_asset_selected(self, _event=None) -> None:
        selection = self.asset_listbox.selection()
        self.selected_asset_id = selection[0] if selection else None
        self.populate_editor(self.selected_asset_id)

    def reload_manifest(self) -> None:
        self.manifest = reconcile_manifest(load_manifest())
        save_manifest(self.manifest)
        self.refresh_asset_list()
        self.status_var.set("已重新扫描 external_assets/images。")

    def add_images(self) -> None:
        paths = filedialog.askopenfilenames(
            title="选择要加入外置素材库的图片",
            filetypes=[("Image Files", "*.png *.jpg *.jpeg *.webp *.bmp")],
        )
        if not paths:
            return
        images = self.manifest.setdefault("images", {})
        used_ids = set(images.keys())
        imported = 0
        skipped: list[str] = []
        for raw_path in paths:
            source = Path(raw_path)
            if source.suffix.lower() not in SUPPORTED_EXTENSIONS:
                skipped.append(f"{source.name}: 不支持的格式")
                continue
            asset_id = make_asset_id(source.stem, used_ids)
            used_ids.add(asset_id)
            dest_name = f"{asset_id}{source.suffix.lower()}"
            dest_path = IMAGES_DIR / dest_name
            shutil.copy2(source, dest_path)
            images[asset_id] = {
                "id": asset_id,
                "label": sanitize_name(source.stem),
                "filename": dest_name,
                "updated_at": int(time.time()),
            }
            imported += 1
        save_manifest(self.manifest)
        self.reload_manifest()
        if skipped:
            messagebox.showwarning("部分文件未导入", "\n".join(skipped))
        if imported:
            self.status_var.set(f"已添加 {imported} 张图片到外置素材库。")

    def save_selected_asset(self) -> None:
        if not self.selected_asset_id:
            messagebox.showinfo("未选择素材", "先在左侧列表中选择 1 张素材。")
            return
        images = self.manifest.setdefault("images", {})
        bindings = self.manifest.setdefault("bindings", {})
        info = images.get(self.selected_asset_id)
        if not isinstance(info, dict):
            return
        new_label = self.asset_label_var.get().strip() or self.selected_asset_id
        info["label"] = new_label
        info["updated_at"] = int(time.time())
        if self.binding_var.get() == "主菜单背景":
            bindings[SLOT_MAIN_MENU_BG] = self.selected_asset_id
        elif bindings.get(SLOT_MAIN_MENU_BG) == self.selected_asset_id:
            bindings.pop(SLOT_MAIN_MENU_BG, None)
        save_manifest(self.manifest)
        self.refresh_asset_list()
        self.status_var.set(f"已保存 {self.selected_asset_id} 的修改。")

    def remove_selected_asset(self) -> None:
        if not self.selected_asset_id:
            messagebox.showinfo("未选择素材", "先在左侧列表中选择 1 张素材。")
            return
        images = self.manifest.setdefault("images", {})
        bindings = self.manifest.setdefault("bindings", {})
        info = images.get(self.selected_asset_id)
        if not isinstance(info, dict):
            return
        if not messagebox.askyesno("确认删除", f"确定删除素材 {self.selected_asset_id} 吗？"):
            return
        filename = str(info.get("filename", ""))
        if filename:
            file_path = IMAGES_DIR / filename
            if file_path.exists():
                file_path.unlink()
        images.pop(self.selected_asset_id, None)
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

# 外置素材目录

把要给游戏自动读取的图片放进 `external_assets/images/`。

- 支持格式：`png`、`jpg`、`jpeg`、`webp`、`bmp`
- 启动游戏时会自动同步到运行时素材仓库
- 如果游戏已经开着，重新打开一次“设置”即可触发同步
- 可以直接运行 `tools/launch_asset_editor.bat` 打开外置素材编辑器

编辑器会维护同目录下的 `manifest.json`，用于保存素材标签和绑定关系。

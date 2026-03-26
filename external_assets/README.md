# 外置素材目录

把要给游戏自动读取的素材放进对应目录，或者直接用外置素材编辑器导入。

- 素材目录：`images / audio / fonts / video / files`
- 外置编辑器支持导入：图片、音频、字体、视频和常用数据文件
- 图片支持：`png`、`jpg`、`jpeg`、`webp`、`bmp`、`gif`、`tif`、`tiff`、`tga`、`ico`
- 通过编辑器导入时，图片会自动适配成游戏可读取的素材文件
- 也支持整文件夹递归批量导入
- 编辑器支持关键词筛选、类型筛选、图片预览和元数据查看
- 可以直接替换当前素材文件，同时保留素材 ID 和已有绑定
- 双击素材列表项可直接打开文件
- 每个素材都可以带一个同目录的 `素材文件名.asset.json` 配置，例如 `hero.png.asset.json`
- sidecar json 当前支持 `id`、`label`、`bindings`
- `bindings` 当前可用槽位：`app_icon`、`main_menu_bg`、`main_menu_logo`、`main_menu_bgm`、`battle_bgm`、`ui_confirm_sfx`、`ui_font`、`ui_style_config`

- `ui_style_config` 绑定的是 JSON 文件，可覆盖主菜单遮罩 / 面板 / 标签等运行时界面样式
- `app_icon` 控制的是运行时窗口图标，不等同于导出产物的原生图标
- 可参考 `external_assets/files/ui_style.sample.json` 作为样式配置模板
- 启动游戏时会自动同步到运行时素材仓库
- 如果游戏已经开着，重新打开一次“设置”即可触发同步
- 可以直接运行 `tools/launch_asset_editor.bat` 打开外置素材编辑器

编辑器会维护同目录下的 `manifest.json`，用于保存素材标签和绑定关系。

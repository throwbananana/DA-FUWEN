# DA-FUWEN

`DA-FUWEN` 当前是一个可直接运行的 Godot 4.6 原型项目，不是“待接入的 JSON 升级包”。  
仓库主线实现围绕 `scenes/`、`scripts/`、`data/` 展开，核心体验是：

百回合四季远征 -> 掷骰与选路 -> 落点触发偶遇 / 建设 / 交谈 / 观察 / 试炼 -> 周结算 -> 季切换 -> 年度结算

项目窗口名仍为 `dafuwen`，主界面标题为“雾野养成原型”。

## 当前实现概览

- 4 季 × 25 回合的百回合远征结构
- 掷骰走格主循环，支持每周重掷、赛季修正点和锚定兜底
- 季节轮换、天气与时段变化，以及地区生态权重变化
- 区域棋盘推进、分叉路线与落点偶遇流程
- 固定 `2v2` 双打编成
- 背包容量随成长曲线提升，按“人口”而非传统格子计算
- 重复个体 `3 合 1` 升星，并支持场地 / 建筑 / 羁绊条件进化
- NPC 交谈、委托接取与完成结算
- 道馆挑战、阶位限制、首通奖励与开放联动
- 建筑看守、建筑共鸣、战前增益、落点增产与成长加成
- 节点偶遇牌堆、环境事件与轻量反重复权重
- 周目标、周结算、本局词缀和赛季高潮奖励
- 探索点与局内元成长解锁（同一运行会话内保留）
- MDA120 数据包已并入运行时读取流程，包括物种、建筑、技能、羁绊、进化链、遭遇表与成长曲线
- JSON 扩展包已补入运行时数据，任务表扩到 20 条，并新增事件、对话树、图鉴与百科条目

## 技术与运行环境

- 引擎：Godot `4.6`
- 主场景：`res://scenes/main.tscn`
- AutoLoad：
  - `DataRepository`：静态 JSON 表读取与查询
  - `GameState`：季节、库存、伙伴、地点、委托、道馆等运行时状态
- 额外依赖：无，当前仓库内容可直接在 Godot 中打开运行

## 快速开始

在项目根目录执行：

```powershell
godot --path .
```

如果本机 Godot 已加入环境变量，也可以直接用编辑器打开 [project.godot](G:\Users\123\Documents\GitHub\dafuwen\DA-FUWEN\project.godot)。

## 外置素材编辑器

项目现在内置了一个不依赖 Godot 编辑器的外置素材链路：

- 外置素材目录：`external_assets/images/`、`external_assets/audio/`、`external_assets/fonts/`、`external_assets/video/`、`external_assets/files/`
- 外置素材元数据：`external_assets/manifest.json`
- 外置编辑器启动脚本：`tools/launch_asset_editor.bat`
- 编辑器源码：`tools/asset_editor.py`

使用方式：

```powershell
tools\launch_asset_editor.bat
```

或直接把素材文件放进对应目录。  
外置编辑器支持导入图片、音频、字体、视频和常用数据文件；其中图片支持 `png`、`jpg`、`jpeg`、`webp`、`bmp`、`gif`、`tif`、`tiff`、`tga`、`ico`，并会在导入时自动适配成游戏可读取的格式；也支持整文件夹递归批量导入。  
如果是手动直拷到 `external_assets/` 下，建议按类型分别放到 `images / audio / fonts / video / files` 目录里。

游戏启动时会自动同步该目录；如果游戏已经在运行，重新打开一次开始菜单的“设置”页即可触发同步，不需要进入 Godot 编辑器执行导入。

## 基础回归

仓库内保留了多组无界面烟测脚本，适合在改动数据表或服务逻辑后快速验证：

```powershell
godot --headless --path . -s res://scripts/smoke_test.gd
godot --headless --path . -s res://scripts/season_upgrade_smoke_test.gd
godot --headless --path . -s res://scripts/bond_double_smoke_test.gd
godot --headless --path . -s res://scripts/mda120_upgrade_smoke_test.gd
godot --headless --path . -s res://scripts/json_expansion_smoke_test.gd
godot --headless --path . -s res://scripts/run_upgrade_smoke_test.gd
godot --headless --path . -s res://scripts/strategic_layer_smoke_test.gd
godot --headless --path . -s res://scripts/custom_asset_sync_smoke_test.gd
```

它们分别覆盖：

- 主场景可启动、可进入地点、可打开驻点总览
- 季节切换、生态权重变化、道馆首通奖励链
- 双打编成、背包人口、升星、羁绊与建筑战前增益
- MDA120 成长曲线、遭遇权重、访问共鸣与进化链
- 扩展任务、事件、对话树、图鉴和百科表已被 `DataRepository` 正常读取
- 百回合升级主循环：区域棋盘、周目标、重掷 / 修正 / 锚定、赛季奖励
- 策略层升级：节点主玩法收敛、遭遇失败后果、节点危险度与伏击队列
- 外置素材目录扫描、运行时同步和自定义背景绑定

## 主要目录

- [scenes/main.tscn](G:\Users\123\Documents\GitHub\dafuwen\DA-FUWEN\scenes\main.tscn)：主场景入口
- [scripts/main.gd](G:\Users\123\Documents\GitHub\dafuwen\DA-FUWEN\scripts\main.gd)：主循环、UI 刷新、偶遇与战斗面板调度
- [scripts/autoload/data_repository.gd](G:\Users\123\Documents\GitHub\dafuwen\DA-FUWEN\scripts\autoload\data_repository.gd)：静态表加载、并表与索引查询
- [scripts/autoload/game_state.gd](G:\Users\123\Documents\GitHub\dafuwen\DA-FUWEN\scripts\autoload\game_state.gd)：运行时状态、成长、解锁、库存和伙伴管理
- `scripts/services/`：地点访问、建设、NPC、遭遇、羁绊、道馆等服务层
- `scripts/*smoke_test.gd`：回归脚本
- `data/`：运行时实际读取的 JSON 数据源
- `docs/`：当前版本状态说明
- `DA_FUWEN_升级文档与JSON示例包/`、`DA_FUWEN_MDA_JSON_120包/`：上游参考资料与历史接入包
- `da_fuwen_json_expansion/`：已落地到 `data/` 的扩展数据源备份与参考补丁

## 核心数据文件

运行时会从 `data/` 读取并合并这些内容：

- `habitats.json` + `habitats_mda_expanded.json`
- `species.json` + `species_mda120.json`
- `building_blueprints.json` + `building_blueprints_mda.json`
- `encounter_tables.json` + `encounter_tables_mda.json`
- `season_rules.json`
- `habitat_unlock_rules.json`
- `dojo_definitions.json`
- `reward_tables.json`
- `board_regions.json`
- `weekly_objectives.json`
- `dice_modules.json`
- `run_modifiers.json`
- `season_boss_rules.json`
- `meta_progression.json`
- `quest_templates.json`
- `events.json`
- `dialogues.json`
- `codex_entries.json`
- `encyclopedia_entries.json`
- `npc_profiles.json`
- `items.json`
- `synergy_definitions_mda.json`
- `skill_library_mda.json`
- `evolution_chains_mda.json`
- `progression_curves_mda.json`

## 文档边界

- 当前项目说明以 [docs/current-project-status.md](G:\Users\123\Documents\GitHub\dafuwen\DA-FUWEN\docs\current-project-status.md) 和仓库代码为准。
- 如果升级包中的说明与当前实现冲突，以 `scripts/`、`data/`、`scenes/` 里的现状为准。
- 根目录 `.docx` 和两个历史数据包目录保留用于回溯需求，不作为当前实现的唯一依据。

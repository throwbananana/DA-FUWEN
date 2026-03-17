# DA-FUWEN

`DA-FUWEN` 当前是一个可直接运行的 Godot 4.6 原型项目，不是“待接入的 JSON 升级包”。  
仓库主线实现围绕 `scenes/`、`scripts/`、`data/` 展开，核心体验是：

营地准备 -> 选择已开放地点 -> 到点驻守 / 建设 / 交谈 / 观察 / 试炼 -> 回营记录 -> 推进季节轮换

项目窗口名仍为 `dafuwen`，主界面标题为“雾野养成原型”。

## 当前实现概览

- 季节轮换、天气与时段变化，以及地点开放链
- 棋盘式地图推进与地点拜访流程
- 固定 `2v2` 双打编成
- 背包容量随成长曲线提升，按“人口”而非传统格子计算
- 重复个体 `3 合 1` 升星，并支持场地 / 建筑 / 羁绊条件进化
- NPC 交谈、委托接取与完成结算
- 道馆挑战、阶位限制、首通奖励与开放联动
- 建筑驻守、建筑共鸣、战前增益、访问增产与成长加成
- MDA120 数据包已并入运行时读取流程，包括物种、建筑、技能、羁绊、进化链、遭遇表与成长曲线

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

## 基础回归

仓库内保留了 4 组无界面烟测脚本，适合在改动数据表或服务逻辑后快速验证：

```powershell
godot --headless --path . -s res://scripts/smoke_test.gd
godot --headless --path . -s res://scripts/season_upgrade_smoke_test.gd
godot --headless --path . -s res://scripts/bond_double_smoke_test.gd
godot --headless --path . -s res://scripts/mda120_upgrade_smoke_test.gd
```

它们分别覆盖：

- 主场景可启动、可进入地点、可打开驻点总览
- 季节切换、地点开放、道馆首通奖励链
- 双打编成、背包人口、升星、羁绊与建筑战前增益
- MDA120 成长曲线、遭遇权重、访问共鸣与进化链

## 主要目录

- [scenes/main.tscn](G:\Users\123\Documents\GitHub\dafuwen\DA-FUWEN\scenes\main.tscn)：主场景入口
- [scripts/main.gd](G:\Users\123\Documents\GitHub\dafuwen\DA-FUWEN\scripts\main.gd)：主循环、UI 刷新、拜访与战斗面板调度
- [scripts/autoload/data_repository.gd](G:\Users\123\Documents\GitHub\dafuwen\DA-FUWEN\scripts\autoload\data_repository.gd)：静态表加载、并表与索引查询
- [scripts/autoload/game_state.gd](G:\Users\123\Documents\GitHub\dafuwen\DA-FUWEN\scripts\autoload\game_state.gd)：运行时状态、成长、解锁、库存和伙伴管理
- `scripts/services/`：地点访问、建设、NPC、遭遇、羁绊、道馆等服务层
- `scripts/*smoke_test.gd`：回归脚本
- `data/`：运行时实际读取的 JSON 数据源
- `docs/`：当前版本状态说明
- `DA_FUWEN_升级文档与JSON示例包/`、`DA_FUWEN_MDA_JSON_120包/`：上游参考资料与历史接入包

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
- `quest_templates.json`
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

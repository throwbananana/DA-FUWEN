# DA-FUWEN

`DA-FUWEN` 是一个**可直接运行的 Godot 4.6 原型项目**。当前仓库已经不是“待接入的 JSON 升级包”，而是包含主场景、运行时脚本、静态数据、外置素材链路与大量烟测脚本的完整原型。项目入口为 `res://scenes/main.tscn`，窗口名为 `dafuwen`，核心运行依赖 `DataRepository` 与 `GameState` 两个 AutoLoad。  

## 项目定位

这个项目围绕“**四季 × 百回合远征**”展开，将掷骰走格、路线选择、落点事件、伙伴养成、建设收益、委托/NPC、道馆挑战与局内元成长串成一个完整循环：

> 百回合四季远征  
> → 掷骰与选路  
> → 落点触发偶遇 / 建设 / 交谈 / 观察 / 试炼  
> → 周结算  
> → 季切换  
> → 年度结算

如果你想快速理解项目，可以把它看成一个结合了以下要素的实验性原型：

- 大富翁式路线推进
- 怪物/伙伴养成与双打战斗编成
- 建筑、羁绊、天气、地区生态与季节规则叠加
- 局内解锁与局间元成长并行推进
- JSON 驱动的数据化内容扩展

---

## 当前功能概览

### 1. 主循环与策略层
- **4 季 × 25 回合**组成一局完整百回合远征
- 掷骰走格主循环支持：
  - 每周重掷
  - 赛季修正点
  - 锚定兜底
  - 分叉路线与落点决策
- 区域棋盘与节点推进已接入：
  - `board_regions.json`
  - `board_map_effects.json`
  - `board_threats.json`
  - `node_decks.json`
- 季节、天气、时段和地区生态权重会影响推进与遭遇
- 存在威胁、伏击、路线风险提示等策略层内容

### 2. 伙伴、成长与战斗
- 固定 **2v2 双打编成**
- 背包容量按“**人口/成长规则**”而不是传统格子数计算
- 重复个体支持 **3 合 1 升星**
- 进化支持多条件触发：
  - 场地
  - 建筑
  - 羁绊
  - 进化链规则
- 已接入成长曲线、技能库、羁绊/协同与进化链数据
- 存在宠物成长、育成/ nursery、伤病/ infirmary、战斗菜单等相关流程与烟测

### 3. 内容系统
- NPC 交谈、路线、委托接取与完成结算
- 道馆挑战、阶位限制、首通奖励与开放联动
- 建筑交互、建筑看守、建筑共鸣与落点增产
- 社交事件、故事弧线、剧情对话、过场面板
- 钓鱼点、钓鱼事件、钓鱼任务模板
- 商店、公告板、年终竞赛、公寓系统等扩展玩法
- 图鉴 / Codex / 百科条目已接入运行时数据读取

### 4. 局内解锁与元成长
- 周目标、周结算、本局词缀和赛季高潮奖励
- 元成长（Meta Progression）与探索点解锁
- 主界面已有与元成长相关的 UI / 报表 / 奖励验证烟测
- 同一运行会话内会保留部分局内成长性结果

### 5. 数据扩展能力
- `data/` 目录已成为实际运行时的数据源
- MDA 相关数据包已并入读取流程
- JSON 扩展包内容已落地到运行时数据与测试链路中
- 项目采用“**代码 + JSON 表驱动**”的方式扩展内容，而不是把所有逻辑硬编码在场景里

---

## 技术栈与运行环境

- **引擎**：Godot `4.6`
- **主场景**：`res://scenes/main.tscn`
- **AutoLoad**
  - `DataRepository`：静态 JSON 表读取、合并、索引与查询
  - `GameState`：季节、库存、伙伴、地点、委托、道馆等运行时状态
- **主要语言**
  - GDScript
  - Python（用于外置素材编辑器）
- **额外依赖**：当前仓库未显示必须安装的第三方运行时依赖；项目可直接由 Godot 打开运行

---

## 快速开始

### 1. 获取项目
```bash
git clone https://github.com/throwbananana/DA-FUWEN.git
cd DA-FUWEN
```

### 2. 运行项目
在项目根目录执行：

```bash
godot --path .
```

如果本机已经安装 Godot，并且系统已关联 `.godot`/项目文件，也可以直接用编辑器打开 `project.godot`。

### 3. 进入项目后的理解顺序
推荐按以下顺序熟悉：

1. `scenes/main.tscn`  
2. `scripts/main.gd`  
3. `scripts/autoload/data_repository.gd`  
4. `scripts/autoload/game_state.gd`  
5. `scripts/services/` 下各系统服务  
6. `data/` 下的 JSON 数据表  
7. `docs/current-project-status.md`

---

## 建议的阅读路径

如果你是第一次接触这个仓库，建议按角色来读：

### 想直接运行/试玩
先看：
- `README.md`
- `project.godot`
- `scenes/main.tscn`

### 想理解主流程与系统拼接
重点看：
- `scripts/main.gd`
- `scripts/services/board_progression_service.gd`
- `scripts/services/weekly_cycle_service.gd`
- `scripts/services/encounter_service.gd`
- `scripts/services/dojo_service.gd`
- `scripts/services/story_director.gd`

### 想改数据或扩内容
重点看：
- `scripts/autoload/data_repository.gd`
- `data/*.json`
- `da_fuwen_json_expansion/`
- `docs/current-project-status.md`

### 想排查回归
重点看：
- `scripts/*smoke_test.gd`

---

## 外置素材链路

项目内置了一套**不依赖 Godot 编辑器**的外置素材工作流，适合美术、UI、音频或非引擎同学直接交付资源。

### 目录
```text
external_assets/
├─ images/
├─ audio/
├─ fonts/
├─ video/
├─ files/
├─ manifest.json
└─ README.md
```

### 编辑器入口
- 启动脚本：`tools/launch_asset_editor.bat`
- 编辑器源码：`tools/asset_editor.py`

### 使用方式
```bat
tools\launch_asset_editor.bat
```

也可以直接把素材放到对应目录中，游戏启动时会自动同步；如果游戏已经在运行，重新打开开始菜单的“设置”页即可触发同步。

### 支持的内容类型
- 图片
- 音频
- 字体
- 视频
- 常用数据文件

其中图片导入支持：
- `png`
- `jpg`
- `jpeg`
- `webp`
- `bmp`
- `gif`
- `tif`
- `tiff`
- `tga`
- `ico`

### Sidecar 配置
每个素材都可以带一个 sidecar JSON，命名格式如下：

```text
素材文件名.asset.json
```

例如：

```text
hero.png.asset.json
battle_theme.ogg.asset.json
```

目前 sidecar JSON 支持：
- `id`
- `label`
- `bindings`

### 当前内置绑定槽位
- `app_icon`：运行时窗口图标
- `main_menu_bg`：主菜单背景
- `main_menu_logo`：主菜单 Logo
- `main_menu_bgm`：主菜单音乐
- `battle_bgm`：战斗音乐
- `ui_confirm_sfx`：界面确认音效
- `ui_font`：界面字体
- `ui_style_config`：界面样式配置 JSON

### `ui_style_config` 说明
`ui_style_config` 可绑定一个 JSON 文件，用于覆盖主菜单遮罩、主菜单背景透明度、主要面板、顶栏、日志、角色卡、状态标签、关卡高亮和标题文字颜色等 UI 样式。仓库当前 README 已给出示例配置，可直接作为模板。

> 注意：`app_icon` 控制的是运行时窗口图标；如果你需要修改 Windows / macOS 导出产物的原生图标，仍需在项目/导出设置中配置。

---

## 回归测试 / Smoke Tests

仓库内保留了大量 **headless 烟测脚本**，适合在修改服务逻辑、UI 或数据表后快速做基础回归。

### 常用运行方式
```bash
godot --headless --path . -s res://scripts/smoke_test.gd
```

### 已存在的测试覆盖（按主题归类）

#### 基础启动与主流程
- `smoke_test.gd`
- `run_upgrade_smoke_test.gd`
- `season_upgrade_smoke_test.gd`
- `special_loop_smoke_test.gd`
- `run_summary_smoke_test.gd`

#### 策略层 / 棋盘 / 风险
- `strategic_layer_smoke_test.gd`
- `board_branch_choice_smoke_test.gd`
- `board_exact_roll_smoke_test.gd`
- `board_threat_smoke_test.gd`
- `route_risk_advisor_smoke_test.gd`
- `threat_forecast_ui_smoke_test.gd`

#### 伙伴成长 / 羁绊 / 建筑 / 进化
- `bond_double_smoke_test.gd`
- `building_tier_smoke_test.gd`
- `pet_growth_smoke_test.gd`
- `nursery_smoke_test.gd`
- `trait_synergy_smoke_test.gd`
- `infirmary_tile_smoke_test.gd`

#### 剧情 / NPC / 公告 / 特殊玩法
- `cutscene_smoke_test.gd`
- `bulletin_board_smoke_test.gd`
- `minigame_tile_smoke_test.gd`
- `annual_competition_smoke_test.gd`
- `apartment_system_smoke_test.gd`

#### 数据加载 / 扩展包 / 元成长
- `json_expansion_smoke_test.gd`
- `mda120_upgrade_smoke_test.gd`
- `meta_bonus_report_smoke_test.gd`
- `meta_progression_reward_smoke_test.gd`
- `main_meta_bonus_ui_smoke_test.gd`
- `codex_stats_smoke_test.gd`

#### 输入 / UI / 战斗相关
- `battle_menu_smoke_test.gd`
- `input_controller_smoke_test.gd`
- `ai_turn_smoke_test.gd`
- `custom_asset_sync_smoke_test.gd`

### 建议
- **改数据表**：至少跑 `json_expansion_smoke_test.gd`、`mda120_upgrade_smoke_test.gd`
- **改主循环/棋盘**：至少跑 `run_upgrade_smoke_test.gd`、`strategic_layer_smoke_test.gd`
- **改养成/羁绊/建筑**：至少跑 `bond_double_smoke_test.gd`、`pet_growth_smoke_test.gd`、`trait_synergy_smoke_test.gd`
- **改 UI/外置素材**：至少跑 `battle_menu_smoke_test.gd`、`custom_asset_sync_smoke_test.gd`

---

## 目录结构

```text
DA-FUWEN/
├─ scenes/
│  └─ main.tscn                     # 主场景入口
├─ scripts/
│  ├─ autoload/
│  │  ├─ data_repository.gd         # 静态表加载 / 合并 / 查询
│  │  └─ game_state.gd              # 运行时状态与成长管理
│  ├─ services/                     # 规则与玩法服务层
│  ├─ ui/
│  │  └─ habitat_visit_panel.gd
│  ├─ main.gd                       # 主流程与主界面调度
│  └─ *smoke_test.gd                # headless 回归脚本
├─ data/                            # 实际运行时读取的 JSON 数据源
├─ docs/
│  └─ current-project-status.md     # 当前版本状态说明
├─ external_assets/                 # 外置素材链路
├─ tools/
│  ├─ asset_editor.py               # 外置素材编辑器
│  └─ launch_asset_editor.bat       # 编辑器启动脚本
├─ da_fuwen_json_expansion/         # 扩展数据源备份 / 参考补丁
├─ project.godot                    # Godot 项目配置
└─ README.md
```

---

## 主要服务层（`scripts/services/`）

当前仓库已经将很多玩法拆分到服务层，便于维护与后续扩展。已可见的服务包括但不限于：

- `ai_player_service.gd`
- `annual_competition_service.gd`
- `battle_roster_service.gd`
- `board_map_effect_service.gd`
- `board_progression_service.gd`
- `building_interaction_service.gd`
- `bulletin_service.gd`
- `cutscene_service.gd`
- `dialogue_service.gd`
- `dice_service.gd`
- `dojo_service.gd`
- `encounter_service.gd`
- `fishing_service.gd`
- `habitat_service.gd`
- `localization_service.gd`
- `meta_progression_service.gd`
- `minigame_service.gd`
- `npc_route_service.gd`
- `npc_service.gd`
- `nursery_service.gd`
- `run_modifier_service.gd`
- `shop_service.gd`
- `social_event_service.gd`
- `story_director.gd`
- `story_service.gd`
- `synergy_service.gd`
- `threat_service.gd`
- `visit_flow_controller.gd`
- `weekly_cycle_service.gd`

这意味着项目已经不只是“单脚本原型”，而是开始形成**主界面调度 + 自动加载单例 + 服务层 + JSON 数据层**的结构。

---

## 核心数据文件（`data/`）

项目的实际运行内容主要由 `data/` 下 JSON 表驱动。当前仓库可见的关键数据包括：

### 核心地图 / 回合 / 季节
- `board_regions.json`
- `board_map_effects.json`
- `board_threats.json`
- `season_rules.json`
- `weekly_objectives.json`
- `run_modifiers.json`
- `season_boss_rules.json`
- `annual_competition_rules.json`

### 生物 / 成长 / 战斗
- `species.json`
- `species_mda120.json`
- `aquatic_species.json`
- `skill_library_mda.json`
- `synergy_definitions_mda.json`
- `evolution_chains_mda.json`
- `progression_curves_mda.json`
- `pet_growth_rules.json`

### 地点 / 建筑 / 遭遇 / 道馆
- `habitats.json`
- `habitats_mda_expanded.json`
- `habitat_unlock_rules.json`
- `building_blueprints.json`
- `building_blueprints_mda.json`
- `encounter_tables.json`
- `encounter_tables_mda.json`
- `dojo_definitions.json`

### NPC / 任务 / 事件 / 剧情
- `npc_profiles.json`
- `npc_routes.json`
- `quest_templates.json`
- `events.json`
- `dialogues.json`
- `story_arcs.json`
- `story_dialogues.json`
- `social_events.json`
- `reward_tables.json`

### 钓鱼 / 经济 / 图鉴 / 元成长
- `fishing_spots.json`
- `fishing_events.json`
- `fishing_quest_templates.json`
- `fishing_codex_entries.json`
- `items.json`
- `shop_rules.json`
- `meta_progression.json`
- `codex_entries.json`
- `encyclopedia_entries.json`

> 建议：如果你准备加玩法，优先先看 `DataRepository` 的读取逻辑，再决定是扩表、并表，还是补服务层逻辑。

---

## 数据与文档边界

为了避免“历史资料”和“当前实现”冲突，建议遵循以下边界：

1. **当前项目说明以 `docs/current-project-status.md` 与仓库代码为准**
2. 如果历史升级包中的说明与当前实现冲突，以：
   - `scripts/`
   - `data/`
   - `scenes/`
   中的现状为准
3. 根目录旧文档、历史数据包目录与补丁文件更适合用于**需求回溯**，不建议把它们作为“当前实现的唯一真相来源”

---

## 开发建议

### 想新增玩法时
建议优先走下面的顺序：
1. 先补 `data/` 数据表
2. 再补 `DataRepository` 读取/索引能力（如果需要）
3. 再补 `scripts/services/` 的规则处理
4. 最后接入 `main.gd` 或相关面板/UI

这样会比直接把逻辑写进界面脚本更容易维护。

### 想做回归验证时
建议按“改动范围”最小化测试：
- 改数据：先跑数据加载与扩展测试
- 改主流程：先跑主循环与策略层测试
- 改 UI：先跑对应面板和同步测试
- 改成长：先跑 pet / bond / synergy / nursery 相关测试

---

## 已知说明

- 当前仓库首页描述（GitHub About）仍为空，可以后续补充简短项目介绍
- 当前仓库页面未显示 Release 发布记录
- 当前仓库根目录未见明确的 `LICENSE` 文件；如果后续准备开源分发，建议补充许可证说明

---

## 适合补充到后续版本的 README 内容

如果你准备继续迭代 README，下一步最值得加的是：

- 游戏截图 / GIF
- 主要 UI 页面说明
- 一局完整流程截图
- 数据表字段说明
- 新增 JSON 条目示例
- 贡献规范 / 分支规范 / 提交约定
- 导出与发布说明

---

## 参考与准则

- 当前实现以仓库代码、`project.godot`、`docs/current-project-status.md` 和 `data/` 目录为准
- 历史数据包、补丁和旧文档更适合做需求追溯，而不是直接代表当前运行结果

---

如果你准备直接替换仓库根目录的 `README.md`，可以将本文件内容整体覆盖进去；如果你还想更进一步，我建议下一步把 **“游戏截图 + 一局流程图 + 数据表示例”** 也补进去，仓库首页可读性会再上一个台阶。

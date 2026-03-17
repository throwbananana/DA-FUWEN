# Current Project Status

## Scope

仓库当前是已接入升级内容的可运行原型，不再是“待接入脚本包”。如果文档、升级包说明和项目实现出现冲突，以 `scripts/`、`data/`、`scenes/` 中的现有内容为准。

## Implemented Systems

- 季节轮换与地点开放：使用 `season_rules.json`、`habitat_unlock_rules.json`、`dojo_definitions.json`、`reward_tables.json`
- 双打与羁绊构筑：固定 `2v2`，背包容量由 `progression_curves_mda.json` 推导
- MDA120 内容：已接入物种、羁绊、建筑、技能、进化链、遭遇表与扩展地点
- 建筑共鸣：覆盖战前增益、经济追加产出、成长加速
- 进化条件：优先读取 `evolution_chains_mda.json`，支持地点、建筑、羁绊与阶段条件

## Runtime Entry Points

- `scenes/main.tscn`：主场景
- `scripts/autoload/data_repository.gd`：静态表读取与查询
- `scripts/autoload/game_state.gd`：运行时状态、背包、进化、奖励
- `scripts/services/visit_flow_controller.gd`：地点访问流程
- `scripts/services/dojo_service.gd`：道馆挑战、奖励与开放链
- `scripts/services/encounter_service.gd`：遭遇筛选与稀有度权重
- `scripts/services/synergy_service.gd`：羁绊与建筑共鸣

## Validation

使用下面四条命令做基础回归：

```powershell
godot --headless --path . -s res://scripts/smoke_test.gd
godot --headless --path . -s res://scripts/season_upgrade_smoke_test.gd
godot --headless --path . -s res://scripts/bond_double_smoke_test.gd
godot --headless --path . -s res://scripts/mda120_upgrade_smoke_test.gd
```

## Reference Materials

- 根目录两个早期“方案”文档已移除，避免继续把当前项目误读成未落地提案。
- `DA_FUWEN_升级文档与JSON示例包/` 与 `DA_FUWEN_MDA_JSON_120包/` 仍保留，作用是追溯上游 JSON 与需求说明。
- 根目录 `.docx` 视为历史策划材料；在没有明确清理要求前不作为当前实现文档。

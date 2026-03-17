# DA-FUWEN

当前仓库已经不是“重构接入包”，而是一个可直接运行的 Godot 4.6 原型。主循环为：棋盘推进 -> 地点拜访 / 道馆挑战 -> 双打战斗 -> 基地养成与羁绊构筑。

## 当前已接入内容

- 季节轮换、地点解锁、道馆挑战与奖励表结算
- 2v2 战斗、背包人口、重复个体 `3 合 1` 升星
- MDA120 内容包：物种、羁绊、建筑、技能、进化链、成长曲线
- 建筑共鸣：战前增益、经济追加产出、成长增益
- 基于 `unlock_rank` 和 `shop_odds` 的遭遇过滤与稀有度权重

## 目录说明

- `scenes/main.tscn`：主场景入口
- `scripts/autoload/`：全局数据与存档状态，已在 `project.godot` 注册为 AutoLoad
- `scripts/services/`：地点、遭遇、道馆、羁绊等服务逻辑
- `scripts/*_smoke_test.gd`：无界面烟测脚本
- `data/`：当前运行时使用的 JSON 表
- `DA_FUWEN_升级文档与JSON示例包/`、`DA_FUWEN_MDA_JSON_120包/`：保留的上游参考包，不是运行时入口

## 运行与验证

```powershell
godot --path .
godot --headless --path . -s res://scripts/smoke_test.gd
godot --headless --path . -s res://scripts/season_upgrade_smoke_test.gd
godot --headless --path . -s res://scripts/bond_double_smoke_test.gd
godot --headless --path . -s res://scripts/mda120_upgrade_smoke_test.gd
```

## 文档约定

- 当前实现与数据以 `scripts/`、`data/`、`scenes/` 为准。
- `docs/current-project-status.md` 记录当前版本范围与验证方式。
- 升级包内的说明文档仅用于回溯原始需求；若与仓库实现冲突，以仓库代码为准。

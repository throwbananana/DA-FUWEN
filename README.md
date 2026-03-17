# DA_FUWEN 养成化重构包

这个包包含三部分：

1. `docs/`：重构方案说明文档  
2. `data/`：可直接挂进 Godot 的 JSON 静态表样例  
3. `scripts/`：按“数据加载 / 据点服务 / NPC 服务 / 遭遇服务 / 访问流程 / UI 骨架”拆分的 GDScript 包

## 推荐接入顺序

1. 把 `scripts/autoload/data_repository.gd` 和 `scripts/autoload/game_state.gd` 配成 AutoLoad
2. 把 `data/*.json` 拷到 `res://data/`
3. 用 `VisitFlowController` 取代原本单回合里把战斗/捕捉/建筑都塞一起的流程
4. 先试做 `雾苔窟 / 晶溪滩 / 云升驿` 三个点
5. 再把原 `battle_panel.gd` 重构为“观察 -> 选择交互 -> 结果”的分步界面

## 注意

这些脚本是“重构起点”，不是对你现有项目的完整无缝替换。
最适合的做法是：
- 先保留原地图和原宠物类
- 再把“地点驻守、到点建造、NPC、结缘遭遇”四块逐步接进去

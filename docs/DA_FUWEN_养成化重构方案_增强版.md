# DA-FUWEN 养成化重构方案（增强版：含 JSON 数据与 GDScript 包）

> 适用对象：`throwbananana/DA-FUWEN` 的 Godot 原型  
> 本版新增：更完整的数据 JSON 设计、脚本拆包建议、可直接复制的样例文件目录。

---

## 1. 这次增强版补了什么

相比上一版文档，这一版多了三层能直接开工的内容：

1. **静态数据层**：把地点、宠物种族、NPC、建筑、遭遇、委托拆成独立 JSON 表。  
2. **运行时服务层**：把“地点驻守 / 到点建造 / NPC 关系 / 野外交互 / 拜访流程”拆成脚本服务。  
3. **UI 分步层**：给一套“到点 -> 选择模块 -> 结果反馈”的面板骨架，避免现在战斗/捕捉那种一屏信息过载。

这么拆是为了让项目真正从“战略原型”转成“养成框架”。MDA 的关键点就是：Mechanics 会推导出 Dynamics，再决定玩家最后收到的 Aesthetics；所以要改体验，必须先改机制和数据结构。citeturn714019search1

---

## 2. 目录结构建议

```text
res://
├─ data/
│  ├─ habitats.json
│  ├─ species.json
│  ├─ npc_profiles.json
│  ├─ building_blueprints.json
│  ├─ encounter_tables.json
│  ├─ quest_templates.json
│  └─ items.json
├─ scripts/
│  ├─ autoload/
│  │  ├─ data_repository.gd
│  │  └─ game_state.gd
│  ├─ services/
│  │  ├─ habitat_service.gd
│  │  ├─ npc_service.gd
│  │  ├─ encounter_service.gd
│  │  └─ visit_flow_controller.gd
│  └─ ui/
│     └─ habitat_visit_panel.gd
```

这里把“静态表”和“运行时状态”分开，是为了让玩法扩展不再继续堆在 `game_data.gd` 一个大文件里。Godot 官方文档里也明确建议用 `FileAccess` 读写文件、用 `JSON.parse_string()` 把文本转成可用的 Variant / Dictionary。citeturn714019search0turn714019search4

---

## 3. 数据层设计

### 3.1 `habitats.json`：地点主表

作用：
- 定义地点类型：栖居据点 / 聚落 / 异常区
- 规定这个地点能驻守什么偏好的宠物
- 规定有哪些建筑、NPC、野外个体与地点动作

核心字段：

- `id`
- `name`
- `type`
- `biome`
- `resident_slots`
- `resident_preferences`
- `buildings`
- `npc_pool`
- `wild_pool`
- `visit_actions`
- `unlock_rule`
- `seasonal_hooks`

这能把“地点只是收益点”的逻辑，改成“地点是生活内容的容器”。

### 3.2 `species.json`：宠物种族表

作用：
- 描述宠物的栖居偏好
- 描述喜欢/讨厌的照料方式
- 给后续“结缘而不是纯捕捉”做基础

核心字段：

- `temperament`
- `habitat_preferences`
- `resident_tags`
- `likes`
- `dislikes`
- `care_actions`
- `bond_skill`

这样宠物就不再只是战斗值和岗位值，而是会和地点、NPC、照料动作互相咬合。

### 3.3 `npc_profiles.json`：NPC 主表

作用：
- 把事件节点从“一次性奖励按钮”改成“持续关系入口”
- 常驻 NPC、巡游 NPC、服务型 NPC 都从同一张表读取

核心字段：

- `role`
- `home`
- `route`
- `tags`
- `trust_rewards`

好感奖励可以直接绑定“开放建筑”“解锁委托”“显示路线”“引来稀有个体”。

### 3.4 `building_blueprints.json`：地点建筑蓝图表

作用：
- 把原本基地里统一升级的建筑，拆成“地点专属建筑树”
- 每级都绑定材料消耗和生活向效果

核心字段：

- `site`
- `max_level`
- `levels`
  - `cost`
  - `effects`

这样升级动作只能发生在地点上，符合“到点建设”的设计方向。

### 3.5 `encounter_tables.json`：野外相遇表

作用：
- 用季节 / 天气 / 时间段 / 异常强度来控制野外个体出现
- 把“抓捕成功率公式”换成“情绪与结缘窗口”

核心字段：

- `habitat_id`
- `weight_groups`
- `when`
- `entries`
- `mood`

这样遭遇就更像观察与安抚，而不是见面就进战斗。

### 3.6 `quest_templates.json`：委托模板表

作用：
- 把任务目标改成送信、照料、观察、修缮、引导、救助
- 减少“击败 / 抢夺 / 压制”这一类战略目标

### 3.7 `items.json`：材料与道具表

作用：
- 让建造、投喂、修缮、寄养都有稳定材料来源
- 方便之后加采集与交易

---

## 4. 脚本包设计

### 4.1 `data_repository.gd`

职责：
- 统一读所有 JSON 表
- 建立 `id -> row` 索引
- 为别的服务提供 `get_habitat()`、`get_species()` 这类读接口

为什么要单独做这层：

- 让 UI 不再直接耦合原来的大 `GameData`
- 让数据扩展变成“改 JSON + 少量脚本”，而不是所有逻辑都硬编码

Godot 官方文档里说明了 `JSON.parse_string()` 会把 JSON object 转成 `Dictionary`，非常适合这种静态表读取。citeturn714019search0

### 4.2 `game_state.gd`

职责：
- 保存运行时状态
- 记录每个地点的驻守宠物、建筑等级、好感与访问历史
- 管理库存和季节状态

设计原则：
- 静态表不放这里
- 只有可变化的值才放这里

### 4.3 `habitat_service.gd`

职责：
- 处理驻守
- 检查建造条件
- 处理到点建造
- 刷新地点等级

这个服务是“把宠物和地点真正绑起来”的关键，因为它会强制：
- 没到地点不能升级
- 没驻守宠物就不能推进 habitat 类地点建筑

### 4.4 `npc_service.gd`

职责：
- 读取地点上可见 NPC
- 处理好感变化
- 处理委托完成与奖励

这层能把原来 `event` / `market` 那些节点，转成“有人、有关系、有连续性的地方”。

### 4.5 `encounter_service.gd`

职责：
- 按天气、季节、时间从遭遇表里抽取个体
- 判断当前情绪
- 给出可选动作
- 结算“安抚 / 投喂 / 观察 / 引导”的结果

这样战斗就不是默认路径，而是少数失控后的后备路径。  
这更符合你要的“养成为主”，也更符合 flow 里的清晰目标和即时反馈。citeturn714019search3

### 4.6 `visit_flow_controller.gd`

职责：
- 统一管理一次“拜访地点”的流程
- 让玩法变成：
  - 到点
  - 看环境
  - 选建设 / 对话 / 观察
  - 收到结果
  - 结束本次拜访

这个控制器最重要的价值，是把原来一回合里挤在一起的操作拆成阶段。  
NN/g 对 progressive disclosure 的定义就是：把高级或次要内容延后到二级步骤，降低学习成本和错误率。这里非常适合直接套用。citeturn714019search2

### 4.7 `habitat_visit_panel.gd`

职责：
- 提供一个极简的 UI 骨架
- 每一步只显示当前最需要的信息和按钮

这能直接对应你之前说的“战斗和捕捉界面很迷惑”。问题不只是文案，而是信息没有按步骤展开。

---

## 5. 这套拆法为什么更符合 MDA 和心流

### 5.1 MDA 对应关系

| 层 | 现在 | 改后 |
|---|---|---|
| Mechanics | 威望、抢点、Boss、岗位切换、总面板升级 | 驻守、到点建造、NPC 好感、结缘、拜访流程 |
| Dynamics | 算收益、抢节奏、压对手、打残后抓 | 回访地点、照料伙伴、记住人和地点、完成生活型委托 |
| Aesthetics | 战略、压迫、效率 | 悠闲、照料、归属、发现 |

MDA 论文本身就强调，玩家体验是系统行为推出来的，不是题材贴上去就会自动变。citeturn714019search1

### 5.2 心流对应关系

重构后更接近 flow 的原因是：

- **目标更近**：今天去哪个地点、推进哪件事，很清楚
- **反馈更快**：到点就能看到建筑和关系变化
- **控制感更强**：玩家不会被迫同时处理地图、战斗、基地、Boss 四套压力
- **挑战更匹配**：从“全局最优”改成“局部照料”

### 5.3 SDT（自主、胜任、关系）对应关系

Ryan、Rigby、Przybylski 的研究指出，游戏中的 autonomy 和 competence 与 enjoyment、偏好和幸福感变化有关。这里再加上 relationship / relatedness 的满足，就更适合做养成。citeturn714019search3

这套方案正好对应：

- **Autonomy**：今天去哪、带谁、先做什么由玩家定
- **Competence**：玩家会看到“我真的把这个地方养起来了”
- **Relatedness**：宠物、NPC、地点之间会建立关系，而不是只有数值

---

## 6. 本包里已经放进去的样例

### 6.1 地点样例

已给了 6 个点：

- 雾苔窟
- 晶溪滩
- 云升驿
- 古械平台
- 铜锤集
- 裂辉尖塔

### 6.2 种族样例

已给了 8 个样例种族：

- 苔团
- 穴嗅兽
- 壳幼
- 溪翔
- 齿翎雀
- 辉蛾
- 隙鹿
- 辉嚎

### 6.3 NPC 样例

已给了常驻 + 巡游混合的 13 个 NPC 样例。

### 6.4 建筑样例

已给了 12 个建筑蓝图，覆盖：

- 雾苔窟 3 个
- 晶溪滩 3 个
- 云升驿 3 个
- 古械平台 3 个

### 6.5 委托样例

已给了 8 个委托模板，都是偏生活 / 照料 / 观察 / 修缮方向。

---

## 7. 推荐你怎么接到当前原型里

### 第一步：保留现有地图和大场景，先替换顶层目标

先把：

- `MAX_ROUNDS`
- `TARGET_PRESTIGE`
- `BOSS_UNLOCK_ROUND`
- 顶部威望目标文案

从“胜负 KPI”改成“季节照料记录 / 地点成长记录”。

### 第二步：冻结旧的岗位系统

先别删原宠物类，但把：
- `assignment_changed`
- 全局岗位 `OptionButton`
- 面板里直接升级建筑

慢慢废弃掉，改成：
- 选地点驻守
- 到点推进建设

### 第三步：先接三个地点样板

优先试：
- 雾苔窟
- 晶溪滩
- 云升驿

因为这三类刚好分别代表：
- 栖居据点
- 栖居据点
- 聚落节点

### 第四步：把“捕缚”改成“结缘”

先不急着全删战斗，先把野外默认流程改成：

1. 相遇预览
2. 显示情绪
3. 只给少量动作
4. 再结算结果

这样最能直接改善“迷惑感”。

---

## 8. 文件清单

本次已生成的文件包括：

### 文档
- `docs/DA_FUWEN_养成化重构方案_增强版.md`

### JSON
- `data/habitats.json`
- `data/species.json`
- `data/npc_profiles.json`
- `data/building_blueprints.json`
- `data/encounter_tables.json`
- `data/quest_templates.json`
- `data/items.json`

### GDScript
- `scripts/autoload/data_repository.gd`
- `scripts/autoload/game_state.gd`
- `scripts/services/habitat_service.gd`
- `scripts/services/npc_service.gd`
- `scripts/services/encounter_service.gd`
- `scripts/services/visit_flow_controller.gd`
- `scripts/ui/habitat_visit_panel.gd`

---

## 9. 注意事项

这套脚本包是**重构起点**，不是对现有仓库的无缝替换版。

它最适合的使用方式是：

- 保留你现有的 `MonsterInstance`、主地图与基础资源系统
- 先把“地点驻守 / 到点建造 / NPC / 结缘遭遇”四块接上
- 再逐步缩掉旧的威望竞速和战略文案

这样你不会一次性重写整个项目，但体验方向会先扭正。

---

## 10. 参考

1. Hunicke, LeBlanc, Zubek, *MDA: A Formal Approach to Game Design and Game Research*. citeturn714019search1  
2. Godot 官方文档：`JSON` 与 `FileAccess`. citeturn714019search0turn714019search4  
3. NN/g: Progressive Disclosure. citeturn714019search2  
4. Ryan, Rigby, Przybylski: *The Motivational Pull of Video Games*. citeturn714019search3

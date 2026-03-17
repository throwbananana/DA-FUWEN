# DA_FUWEN 季节解锁 / 道馆挑战 / MDA+心流升级文档

## 1. 这次升级要解决什么

你希望在现有仓库基础上继续强化三件事：

1. **增加更多 JSON 数据内容**，把地点、季节、挑战、奖励、成长全部进一步数据驱动。
2. **增加更多可解锁地点/格子**，并且这些地点会随着季节变化而开放或关闭。
3. **加入道馆挑战（演武场 / 试炼所）**，让玩家通过挑战获得稳定成长奖励，而不是只靠随机事件推进。

我建议不要推翻当前重构包，而是沿着仓库里已经存在的 `DataRepository + GameState + VisitFlowController` 思路继续扩展。

---

## 2. 现有项目能直接承接哪些改动

当前仓库已经具备四个很好的基础：

- `DataRepository` 已经会统一读取 `res://data/*.json`，目前覆盖 `habitats / species / npc_profiles / building_blueprints / quest_templates / items / encounter_tables`。
- `GameState` 已经有 `season_id / weather_id / time_of_day / day_index / season_length`，说明“季节—天气—日程”状态机已经存在。
- `GameState` 的 habitat 状态里已经有 `is_unlocked`、`rank`、`building_levels` / `service_levels`，可以直接拿来做地点解锁。
- `BoardView` 也已经有 `locked_nodes` 的表现能力，因此如果你仍然保留棋盘推进层，也可以同步做“季节锁格”。

**结论：**
这次升级最合理的做法，是把“季节规则、地点解锁、道馆定义、奖励表”新增为独立 JSON，再通过少量脚本把它们接入现有状态流。

---

## 3. 先定设计原则：按 MDA + 心流理论调整

## 3.1 MDA 目标

### Mechanics（机制）
新增：
- 季节规则
- 季节开放地点
- 道馆挑战
- 首通奖励 / 重复挑战奖励
- 阶梯难度
- 推荐战力与推荐照料等级
- 季节限定事件与材料

### Dynamics（动态）
玩家会形成新的循环：

**准备资源 → 打开季节地点 → 收集限定素材 → 升级驻点 / 队伍 → 挑战道馆 → 获得更高级解锁权限**

这样能让成长不再只依赖单次事件，而是有明确的中期目标。

### Aesthetics（体验）
要强化的体验不是“纯随机惊喜”，而是：
- 期待感：下一个季节会开新地点
- 掌控感：我知道为了开这块区域该做什么
- 成长感：通过挑战获得明显回报
- 身份感：我正在经营一个逐季扩张的据点网络
- 复访价值：同一地点在不同季节有不同产出和事件

---

## 3.2 按心流理论做难度调节

### 必须满足的 5 个条件

1. **目标明确**
   - 当前季节主目标只能有 1 个主线目标 + 2 个支线目标
   - 道馆挑战条件必须在 UI 上直接可见

2. **反馈即时**
   - 解锁地点时立即提示“为什么开了”
   - 道馆失败时明确告诉玩家差在哪：等级、属性、材料、驻点等级

3. **挑战与能力匹配**
   - 道馆不要一上来就是“赢或输”
   - 改为：观察 / 试探 / 正式挑战 / 高阶挑战 四段

4. **控制感强**
   - 季节锁不要完全随机触发
   - 至少 70% 的地点解锁应由“可预期条件”达成

5. **避免焦虑与无聊**
   - 每季至少有 1 个“稳定收益点”
   - 每季最多只新增 1 个“高压挑战点”
   - 同一季里不要同时塞太多新系统

---

## 4. 数据层怎么改：新增 4 份 JSON

建议新增以下 4 个文件：

1. `season_rules.json`
2. `habitat_unlock_rules.json`
3. `dojo_definitions.json`
4. `reward_tables.json`

这样做的好处是：
- 季节逻辑不污染 habitats
- 解锁条件单独维护
- 挑战内容可持续扩表
- 奖励平衡可以独立调数值

---

## 5. 推荐 JSON 结构

## 5.1 season_rules.json

用途：
- 定义春夏秋冬的长度、天气池、开放地点、限定事件 tag、限定材料 tag。

建议字段：
- `id`
- `name`
- `days`
- `weather_pool`
- `unlock_habitats`
- `lock_habitats`
- `event_tags`
- `resource_bonus`
- `dojo_rotation`

### 设计重点
- **不要只做视觉换皮**
- 季节必须实打实改变：可去地点、可拿素材、可见事件、可打道馆

---

## 5.2 habitat_unlock_rules.json

用途：
- 定义地点什么时候开启，不直接写死在 `GameState`。

建议字段：
- `id`
- `habitat_id`
- `conditions`
- `unlock_text`
- `priority`

`conditions` 建议支持：
- `season_is`
- `season_in`
- `trust_at_least`
- `habitat_rank_total_at_least`
- `built_level_at_least`
- `quest_completed`
- `dojo_cleared`
- `species_seen`
- `weather_is`

### 设计重点
把解锁分成三种：

1. **季节门**
   - 例：春季才能进入“潮芽浅滩”

2. **成长门**
   - 例：总驻点等级达到 4 才能进入“回声断桥”

3. **技法门**
   - 例：通过“云阶演武场·初段”后开放“裂辉观测台”

---

## 5.3 dojo_definitions.json

用途：
- 定义演武场 / 道馆内容。

建议字段：
- `id`
- `name`
- `location_id`
- `season_tags`
- `recommended_rank`
- `entry_cost`
- `rounds`
- `enemy_pool`
- `modifiers`
- `first_clear_rewards`
- `repeat_rewards`
- `failure_consolation`
- `unlock_on_clear`
- `ui_hint`

### 道馆设计建议
每个道馆分 3 层：

- **试炼一阶**
  - 给“新理解”
  - 用来教学，不应该太难

- **试炼二阶**
  - 给“成长材料”
  - 用来强化中盘循环

- **试炼三阶 / 季节高阶**
  - 给“稀有蓝图 / 稀有点位解锁”
  - 用来承接追求 mastery 的玩家

---

## 5.4 reward_tables.json

用途：
- 将奖励做成表驱动，避免把奖励逻辑散落在多个脚本里。

建议字段：
- `reward_bundles`
- `season_bonus`
- `dojo_clear_grade`
- `unlock_bonus`

奖励建议分四类：
- 资源类：材料、货币、料理
- 成长类：建筑蓝图、队伍位、服务位
- 叙事类：日志、手札、NPC 信赖事件
- 地图类：新地点、新捷径、新季节支线

---

## 6. 新地点与季节解锁建议

建议新增 6 个地点，其中 4 个是季节主打点，2 个是中后期永久点。

## 6.1 季节地点（建议）

### 春：潮芽浅滩
- 关键词：复苏、幼体、观察
- 作用：新手友好素材点
- 解锁：春季自动开放
- 核心奖励：孵育素材、轻度信赖推进

### 夏：鸣雷草场
- 关键词：高风险、高收益、训练
- 作用：战斗型玩家的材料场
- 解锁：夏季 + 总驻点等级 2
- 核心奖励：训练材料、速度向道馆门票

### 秋：赤叶演武场
- 关键词：对决、试炼、奖章
- 作用：主道馆点
- 解锁：秋季 + 完成一项建筑 2 级升级
- 核心奖励：道馆奖章、蓝图碎片、稀有饰件

### 冬：霜镜湖
- 关键词：静观、修整、稀有结缘
- 作用：低刺激但高价值
- 解锁：冬季 + 信赖总值达到 6
- 核心奖励：特殊观察事件、冬季限定伙伴线索

## 6.2 常驻中后期地点（建议）

### 回声断桥
- 用途：作为季节切换时的中枢点
- 解锁：通关任意 2 个道馆一阶

### 裂辉观测台
- 用途：后期异常天气 / 稀有事件入口
- 解锁：完成“秋季主道馆二阶”或总信赖达到 10

---

## 7. 道馆系统怎么做才不会破坏节奏

## 7.1 为什么要有道馆
道馆的功能不是“又一个战斗关卡”，而是提供：
- 明确目标
- 阶梯难度
- 稳定奖励
- 验证 build 的场所

## 7.2 推荐的挑战节奏
每季只重点推 **1 个主道馆 + 1 个支线试炼**。

这样可以避免信息过载。

### 每季推荐节奏
- 第 1~2 天：探索季节新地点
- 第 2~3 天：收集材料与培养
- 第 3~4 天：挑战一阶
- 第 4~5 天：强化建筑 / 关系推进
- 第 5~6 天：挑战二阶或季末高阶

这正好符合当前 `season_length = 6` 的节拍。

## 7.3 奖励结构建议
### 首通奖励
- 强，必须让玩家感到“挑战值”
- 例：新蓝图 / 新地点解锁 / 新服务槽

### 重复奖励
- 稳定但不爆炸
- 例：固定材料包 + 少量积分

### 失败补偿
- 必须有
- 例：观察笔记 / 少量训练经验 / 再挑战折扣

这是心流里“避免一次失败打断长期投入”的关键。

---

## 8. 如何调整成“既有心流也有成长感”的数值节奏

## 8.1 前 20 分钟
必须保证玩家能完成：
- 访问 2 个基础地点
- 接到 1 个委托
- 升 1 次建筑
- 看见 1 个“下一季会开放”的提示
- 打 1 次低压试炼

## 8.2 前 60 分钟
必须保证玩家能完成：
- 解锁 1 个季节限定地点
- 首通 1 个道馆一阶
- 获得 1 个新的系统性奖励（蓝图 / 新槽位 / 新路线）

## 8.3 防止无聊
如果玩家 2 次访问都没有新东西，系统就要强制投放以下至少一种内容：
- 新 NPC 对话
- 新观察条目
- 建筑升级素材
- 道馆前置线索
- 季节倒计时提示

## 8.4 防止挫败
如果玩家连续 2 次道馆失败，下一次挑战前应至少提供 1 个补偿：
- 推荐组合提示
- 入场费减免
- 试探模式开放
- 训练素材赠送

---

## 9. 对现有 JSON 的具体修改建议

## 9.1 habitats.json
建议新增字段：

- `unlock_rule_id`
- `season_availability`
- `dojo_id`
- `recommended_rank`
- `flow_band`
- `seasonal_events`
- `seasonal_resources`
- `mda_role`

### 示例
- `flow_band: "low_pressure"`：偏观察/经营
- `flow_band: "mid_pressure"`：偏成长/收集
- `flow_band: "high_pressure"`：偏挑战/验证 build

这样做的意义是：以后 UI 和 encounter service 可以根据 `flow_band` 自动决定事件密度。

## 9.2 species.json
建议新增字段：

- `season_affinity`
- `dojo_traits`
- `challenge_bonus_tags`
- `bond_unlock_rewards`

这样做之后，某些伙伴就能天然成为“秋季道馆强势宠”或“冬季观察型宠”。

## 9.3 npc_profiles.json
建议新增字段：

- `season_presence`
- `dojo_mentor_for`
- `unlock_clues`
- `season_dialogue_sets`

这样 NPC 不只是给任务，还能承担：
- 季节预告
- 道馆提示
- 地图解锁线索
- 流程节拍器

## 9.4 quest_templates.json
建议新增两类任务：

1. **季节任务**
   - 在某季节限定出现
   - 引导玩家去看当季核心地点

2. **道馆准备任务**
   - 通过交付或观察，帮助玩家完成挑战前置

---

## 10. 脚本接入建议（按最小改动顺序）

## 第一步：先扩 DataRepository
新增加载：
- `season_rules.json`
- `habitat_unlock_rules.json`
- `dojo_definitions.json`
- `reward_tables.json`

并新增接口：
- `get_season_rule(season_id)`
- `get_unlock_rules_for_habitat(habitat_id)`
- `get_dojo(dojo_id)`
- `get_reward_bundle(reward_id)`

## 第二步：扩 GameState
新增状态：
- `dojo_clear_flags`
- `season_unlock_history`
- `season_points`
- `badge_count`
- `failed_dojo_streak`
- `current_available_habitats_cache`

并补 3 个方法：
- `refresh_season_unlocks()`
- `mark_dojo_clear(dojo_id, tier, first_clear)`
- `can_unlock_habitat(habitat_id)`

## 第三步：扩 HabitatService
职责：
- 读取地点 profile
- 判断该地点今天/本季是否可进入
- 汇总季节事件 tag
- 返回推荐内容强度

## 第四步：扩 VisitFlowController
到达地点后：
1. 先判定是否开放
2. 若关闭，显示“差什么条件”
3. 若开放，决定当前菜单里是否出现：
   - 普通访问
   - 建造
   - NPC
   - 观察
   - 道馆挑战

## 第五步：扩 UI
建议在地点面板上增加：
- 推荐等级
- 当前季节图标
- 本季剩余天数
- 道馆状态（未开 / 可试炼 / 已首通 / 可高阶）
- 解锁提示文案

---

## 11. 直接可用的内容扩展方案（推荐第一版）

为了控制工作量，我建议先上一个 **V1 内容包**：

### V1 新增
- 2 个季节地点：`thunder_meadow`、`frost_mirror_lake`
- 1 个主道馆：`autumn_leaf_dojo`
- 1 个支线试炼：`summer_storm_trial`
- 8~12 条新季节事件
- 2~3 个新 NPC
- 2 套季节任务链
- 6~10 个新奖励条目

### 为什么先做 V1
因为 V1 已经足够验证：
- 季节解锁是否让玩家期待下个周期
- 道馆是否真的构成稳定成长目标
- 奖励会不会太肥或太抠
- 玩家会不会在中期失去动力

---

## 12. 推荐的 MDA 对应表

| 模块 | Mechanics | Dynamics | Aesthetics |
|---|---|---|---|
| 季节地点 | 季节开放/关闭、限定掉落 | 玩家提前规划本季行程 | 期待、世界变化 |
| 道馆 | 固定规则、阶梯难度、首通奖励 | 形成准备—挑战—强化循环 | 成就、 mastery |
| 信赖/NPC | 线索、奖励、出场时机 | 引导玩家去正确内容 | 关系、陪伴 |
| 建筑升级 | 功能增强、解锁新菜单 | 玩家会反复回基地规划 | 经营感、掌控感 |
| 季节任务 | 明确目标与节拍 | 防止玩家迷失 | 安心、推进感 |

---

## 13. 我最推荐你优先落地的 3 个改动

### 优先级 A：季节解锁规则表
这是你整个“更多格子可解锁”的基础。

### 优先级 A：道馆定义表 + 奖励表
这是成长闭环的核心。

### 优先级 B：habitats / npc / quest 扩表
这是把系统做“厚”的部分。

---

## 14. 验收标准（很重要）

你可以用下面 6 条来判断这次升级有没有成功：

1. 玩家在第一季结束前，至少能明确感知“下一季会开新点”。
2. 玩家第一次挑战道馆失败后，不会觉得白玩。
3. 玩家首通道馆后，能拿到明显改变后续策略的奖励。
4. 同一个地点在不同季节里至少有 2 种不同内容表现。
5. 解锁条件对玩家来说是“能理解、能追、能规划”的。
6. 任何一个季节内，玩家都至少有：
   - 一个稳定收益点
   - 一个成长目标点
   - 一个高风险高收益点

---

## 15. 最后给你的落地建议

如果你要马上开做，我建议顺序是：

1. 先把 **`season_rules.json`、`habitat_unlock_rules.json`、`dojo_definitions.json`、`reward_tables.json`** 接入 `DataRepository`
2. 再改 `GameState.refresh_season_unlocks()`
3. 再把 `VisitFlowController` 做成“地点开放判定 + 道馆入口”
4. 然后只做 **2 个季节点 + 1 个主道馆** 的最小验证包
5. 最后再扩 NPC、任务和更多季节事件

这样开发成本最低，同时最容易验证 MDA 和心流调节有没有真的生效。

---

## 16. 这次我额外给你的建议

和你最初的想法相比，我建议再补一句总原则：

> **不要把“更多地点”理解成“更多地图块”，而要理解成“更多可预期、可规划、可复访的成长节点”。**

真正符合 MDA 和心流的，不是单纯堆内容量，而是让每个新地点都能承担明确功能：
- 教学
- 收集
- 培养
- 验证 build
- 解锁后续内容

只要按这个方向做，你的“季节解锁 + 道馆奖励 + JSON 扩表”会很自然地串成一个完整成长闭环。

# DA-FUWEN MDA / 心流扩展 JSON 包

这个包面向你当前仓库的 `data/*.json` 结构，目标是把项目升级为：
- 固定 2v2 双打
- 背包容量 = 人口
- 背包 / 建筑 / 前台 三源羁绊
- 同种物种不重复计羁绊
- 3 合 1 升星 + 场地/建筑条件进化

## 包含内容
- `species_mda120.json`：120 个可用物种（40 家族 × 3 进化阶段）
- `skill_library_mda.json`：通用技能 + 家族签名技
- `evolution_chains_mda.json`：进化链与场地条件
- `synergy_definitions_mda.json`：属性 / 生态 / 职能羁绊
- `building_blueprints_mda.json`：建筑驻守与共鸣效果
- `habitats_mda_expanded.json`：扩展地点表
- `encounter_tables_mda.json`：扩展遭遇权重
- `progression_curves_mda.json`：人口曲线、商店概率、心流节奏

## 推荐接法
1. 先用 `species_mda120.json` 替换或并表原 `species.json`
2. 再接 `building_blueprints_mda.json`、`habitats_mda_expanded.json`、`encounter_tables_mda.json`
3. 在 `DataRepository.load_all()` 里新增四行读取：
   - `synergy_definitions_mda.json`
   - `skill_library_mda.json`
   - `evolution_chains_mda.json`
   - `progression_curves_mda.json`
4. UI 必须同时显示：
   - 出战 2 只
   - 背包人口占用
   - 已激活羁绊
   - 建筑驻守的共鸣
   - 同物种不重复计羁绊的说明

## 平衡抓手
- 早期多用 common / uncommon stage1，让学习成本稳定
- 中期再逐步引入双属性、建筑联动和 stage2 主力
- stage3 与 epic/legendary 会显著抬高人口值，防止“高星万能”
- 高压地图主要增加条件复杂度，而不是粗暴膨胀数值

## 当前统计
- 物种：120
- 家族：40
- 技能：150
- 地图：16
- 建筑：31

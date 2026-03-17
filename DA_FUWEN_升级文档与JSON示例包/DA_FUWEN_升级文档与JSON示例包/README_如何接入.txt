这个包包含：
- DA_FUWEN_季节解锁_道馆挑战_MDA心流升级文档.md
- season_rules.json
- habitat_unlock_rules.json
- dojo_definitions.json
- reward_tables.json
- habitats_patch_example.json

接入顺序建议：
1. 先扩 DataRepository 的 load_all()
2. 再扩 GameState 的 season / dojo / unlock 状态
3. 再在 VisitFlowController 里增加开放判定与道馆入口
4. 最后扩 habitats / npc / quest 内容

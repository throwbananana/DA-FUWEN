class_name GameConstants
extends RefCounted

const WEATHER_ORDER := ["clear", "fog", "rain", "storm"]

const WEATHER_NAMES := {
	"clear": "晴日",
	"fog": "薄雾",
	"mist": "雾息",
	"rain": "细雨",
	"storm": "风暴",
	"drizzle": "微雨",
	"humid": "闷热",
	"windy": "劲风",
	"dry": "燥风",
	"snow": "雪幕",
}

const TIME_ORDER := ["day", "evening", "night"]

const TIME_NAMES := {
	"day": "白昼",
	"evening": "黄昏",
	"night": "夜晚",
}

const STARTER_SPECIES_IDS := ["steam_otter_1", "moss_deer_1", "spark_mouse_1"]

const TUTORIAL_ORDER := ["run_intro", "management_intro", "battle_intro"]

const TUTORIAL_ENTRIES := {
	"run_intro": {
		"title": "初来雾野市",
		"close_text": "出门走走",
		"body": "[b]第一回合怎么开始[/b]\n先点 [b]掷骰[/b] 开始前进。只有真的走到分叉口，才需要你选方向。\n\n[b]平时先看什么[/b]\n物资、任务和伙伴近况，都在 [b]背包[/b] 里；想知道这回合该做什么，先看右侧提示。\n\n[b]第一天建议[/b]\n先去一个压力不高的地点，熟悉移动、停留和地点事件；路过营地时，再顺手整理队伍和补给。",
	},
	"management_intro": {
		"title": "先把日子安顿下来",
		"close_text": "接着收拾",
		"body": "[b]营地能做什么[/b]\n路过营地时，可以整理队伍、调整驻守、处理留信，也能顺手补一点状态。\n\n[b]这时候优先什么[/b]\n先把出战位和驻守安排稳，再看今天缺什么资源、要推进哪件事。\n\n[b]东西去哪看[/b]\n饥饿、物资、金钱、伙伴和任务，都放在 [b]背包[/b] 里。",
	},
	"battle_intro": {
		"title": "真闹起来时怎么办",
		"close_text": "去应付一下",
		"body": "[b]战斗怎么开始[/b]\n轮到你时，先选动作，再选目标；看清谁先动、谁更危险，再决定这一手。\n\n[b]最先看哪三样[/b]\n行动顺序、剩余状态、危险单位。先看这三样，通常就够了。\n\n[b]打前还能做什么[/b]\n想换同行、补状态或重新安排，就先回营地整理，再来接这场战斗。",
	},
}

-- Game versions
---Default target version for unknown builds and builds created before 3.0.0.
legacyTargetVersion = "2_6"
---Default target for new builds and target to convert legacy builds to.
liveTargetVersion = "3_0"

-- Skill tree versions
---Added for convenient indexing of skill tree versions.
---@type string[]
treeVersionList = { "2_6", "3_6", "3_7", "3_8", "3_9", "3_10", "3_11", "3_12" , "3_13", "3_14", "3_15", "3_16", "3_17", "3_18", "3_19", "3_20", "3_21", "3_22"}
--- Always points to the latest skill tree version.
latestTreeVersion = treeVersionList[#treeVersionList]
---Tree version where multiple skill trees per build were introduced to PoBC.
defaultTreeVersion = treeVersionList[2]
---Display, comparison and export data for all supported skill tree versions.
---@type table<string, {display: string, num: number, url: string}>
treeVersions = {
	["2_6"] = {
		display = "2.6",
		num = 2.06,
		url = "https://poe.game.qq.com/passive-skill-tree/2.6.2/",
	},
	["3_6"] = {
		display = "3.6（虚空幻境）",
		num = 3.06,
		url = "https://poe.game.qq.com/passive-skill-tree/3.6.0/",
	},
	["3_7"] = {
		display = "3.7（军团）",
		num = 3.07,
		url = "https://poe.game.qq.com/passive-skill-tree/3.7.0/",
	},
	["3_8"] = {
		display = "3.8（枯疫）",
		num = 3.08,
		url = "https://poe.game.qq.com/passive-skill-tree/3.8.0/",
	},
	["3_9"] = {
		display = "3.9（灾变 ）",
		num = 3.09,
		url = "https://poe.game.qq.com/passive-skill-tree/3.9.0/",
	},
	["3_10"] = {
		display = "3.10（惊悸迷雾）",
		num = 3.10,
		url = "https://poe.game.qq.com/passive-skill-tree/3.10.0/",
	},
	["3_11"] = {
		display = "3.11（庄园）",
		num = 3.11,
		url = "https://poe.game.qq.com/passive-skill-tree/3.11.0/",
	},
	["3_12"] = {
		display = "3.12（夺宝奇兵）",
		num = 3.12,
		url = "https://poe.game.qq.com/passive-skill-tree/3.12.0/",
	},
	["3_13"] = {
		display = "3.13（驱灵仪式）",
		num = 3.13,
		url = "https://poe.game.qq.com/passive-skill-tree/3.13.0/",
	},
	["3_14"] = {
		display = "3.14（致命贪婪）",
		num = 3.14,
		url = "https://poe.game.qq.com/passive-skill-tree/3.14.0/",
	},
	["3_15"] = {
		display = "3.15（先祖秘藏）",
		num = 3.15,
		url = "https://poe.game.qq.com/passive-skill-tree/3.15.0/",
	},
	["3_16"] = {
		display = "3.16（异度天灾）",
		num = 3.16,
		url = "https://www.pathofexile.com/passive-skill-tree/3.16.0/",
	},
	["3_17"] = {
		display = "3.17（罪恶枷锁）",
		num = 3.17,
		url = "https://www.pathofexile.com/passive-skill-tree/3.17.0/",
	},
	["3_18"] = {
		display = "3.18（灵能护卫）",
		num = 3.18,
		url = "https://www.pathofexile.com/passive-skill-tree/3.18.0/",
	},
	["3_19"] = {
		display = "3.19（卡兰德之湖）",
		num = 3.19,
		url = "https://www.pathofexile.com/passive-skill-tree/3.19.0/",
	},
	["3_20"] = {
		display = "3.20（永生禁域）",
		num = 3.20,
		url = "https://www.pathofexile.com/passive-skill-tree/3.20.0/",
	},
	["3_21"] = {
		display = "3.21（古神熔炉）",
		num = 3.2,
		url = "https://www.pathofexile.com/passive-skill-tree/3.21.0/",
	},
	["3_22"] = {
		display = "3.22（命运试炼）",
		num = 3.2,
		url = "https://www.pathofexile.com/passive-skill-tree/3.22.0/",
	}
}

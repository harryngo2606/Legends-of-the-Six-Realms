--!strict

local DungeonConfig = {}

export type DungeonData = {
	Id: string,
	Name: string,

	EnterSpawnName: string,
	ExitSpawnName: string,

	MonsterSpawnName: string,
	MonsterTemplateName: string,
	MonsterId: string,
	MonsterCount: number,
	MonsterSpreadRadius: number,
	MonsterMinSpacing: number,

	BossSpawnName: string,
	BossTemplateName: string,
	BossId: string,
	BossMonsterName: string,

	ClearExpReward: number,
}

local dungeons: {[string]: DungeonData} = {
	SlimeDungeon = {
		Id = "SlimeDungeon",
		Name = "Slime Dungeon",

		EnterSpawnName = "EnterSpawn",
		ExitSpawnName = "ExitSpawn",

		MonsterSpawnName = "MonsterSpawn",
		MonsterTemplateName = "Slime",
		MonsterId = "Slime_Lv1",
		MonsterCount = 5,
		MonsterSpreadRadius = 12,
		MonsterMinSpacing = 6,

		BossSpawnName = "BossSpawn",
		BossTemplateName = "SlimeKing",
		BossId = "SlimeKing",
		BossMonsterName = "SlimeKing",

		ClearExpReward = 50,
	},
}

DungeonConfig.Dungeons = dungeons

function DungeonConfig.GetDungeon(dungeonId: string): DungeonData?
	return dungeons[dungeonId]
end

return DungeonConfig
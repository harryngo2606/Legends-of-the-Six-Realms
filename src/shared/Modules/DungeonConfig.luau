--!strict

local DungeonConfig = {}

export type DungeonData = {
	Id: string,
	Name: string,
	EnterSpawnName: string,
	ExitSpawnName: string,
	BossMonsterName: string,
	ClearExpReward: number,
}

local dungeons: {[string]: DungeonData} = {
	SlimeDungeon = {
		Id = "SlimeDungeon",
		Name = "Slime Dungeon",
		EnterSpawnName = "EnterSpawn",
		ExitSpawnName = "ExitSpawn",
		BossMonsterName = "SlimeKing",
		ClearExpReward = 25,
	},
}

DungeonConfig.Dungeons = dungeons

function DungeonConfig.GetDungeon(dungeonId: string): DungeonData?
	return dungeons[dungeonId]
end

return DungeonConfig
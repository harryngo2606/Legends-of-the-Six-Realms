--!strict

local BossConfig = {}

export type BossData = {
	Id: string,
	Name: string,
	MaxHP: number,
	WalkSpeed: number,
	ExpReward: number,
}

local bosses: {[string]: BossData} = {
	SlimeKing = {
		Id = "SlimeKing",
		Name = "Slime King",
		MaxHP = 300,
		WalkSpeed = 10,
		ExpReward = 50,
	},
}

BossConfig.Bosses = bosses

function BossConfig.GetBoss(bossId: string): BossData?
	return bosses[bossId]
end

return BossConfig
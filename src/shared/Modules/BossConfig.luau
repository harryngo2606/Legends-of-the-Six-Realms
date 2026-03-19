--!strict

local BossConfig = {}

export type TargetMode = "Nearest" | "HighestDamage"

export type BossData = {
	Id: string,
	Name: string,
	MaxHP: number,
	WalkSpeed: number,
	Attack: number,
	AttackCooldown: number,
	DetectRange: number,
	AttackRange: number,
	ChaseRange: number,
	LeashRange: number,
	ExpReward: number,
	TargetMode: TargetMode,
}

local bosses: {[string]: BossData} = {
	SlimeKing = {
		Id = "SlimeKing",
		Name = "Slime King",
		MaxHP = 300,
		WalkSpeed = 10,
		Attack = 28,
		AttackCooldown = 1.25,
		DetectRange = 45,
		AttackRange = 8,
		ChaseRange = 60,
		LeashRange = 80,
		ExpReward = 50,
		TargetMode = "HighestDamage",
	},
}

BossConfig.Bosses = bosses

function BossConfig.GetBoss(bossId: string): BossData?
	return bosses[bossId]
end

return BossConfig
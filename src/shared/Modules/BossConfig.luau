--!strict

local BossConfig = {}

export type TargetMode = "Nearest" | "HighestDamage"
export type AggroMode = "PassiveCounter" | "AutoAggro"

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
	AssistRadius: number,
	ExpReward: number,
	TargetMode: TargetMode,
	AggroMode: AggroMode,
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
		AssistRadius = 0,
		ExpReward = 50,
		TargetMode = "HighestDamage",
		AggroMode = "AutoAggro",
	},
}

BossConfig.Bosses = bosses

function BossConfig.GetBoss(bossId: string): BossData?
	return bosses[bossId]
end

return BossConfig
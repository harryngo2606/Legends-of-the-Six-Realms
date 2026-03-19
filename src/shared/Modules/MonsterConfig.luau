--!strict

local MonsterConfig = {}

export type TargetMode = "Nearest" | "HighestDamage"

export type MonsterData = {
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

local monsters: {[string]: MonsterData} = {
	-- alias để world monster cũ tên "Slime" vẫn chạy AI nếu chưa gắn MonsterId
	Slime = {
		Id = "Slime",
		Name = "Slime",
		MaxHP = 80,
		WalkSpeed = 12,
		Attack = 12,
		AttackCooldown = 1.1,
		DetectRange = 28,
		AttackRange = 6,
		ChaseRange = 40,
		LeashRange = 55,
		ExpReward = 10,
		TargetMode = "Nearest",
	},

	Slime_Lv1 = {
		Id = "Slime_Lv1",
		Name = "Slime Lv1",
		MaxHP = 80,
		WalkSpeed = 12,
		Attack = 12,
		AttackCooldown = 1.1,
		DetectRange = 28,
		AttackRange = 6,
		ChaseRange = 40,
		LeashRange = 55,
		ExpReward = 10,
		TargetMode = "Nearest",
	},

	Slime_Lv5 = {
		Id = "Slime_Lv5",
		Name = "Slime Lv5",
		MaxHP = 140,
		WalkSpeed = 13,
		Attack = 20,
		AttackCooldown = 1.0,
		DetectRange = 30,
		AttackRange = 6,
		ChaseRange = 45,
		LeashRange = 60,
		ExpReward = 20,
		TargetMode = "Nearest",
	},

	Wolf_Lv8 = {
		Id = "Wolf_Lv8",
		Name = "Wolf Lv8",
		MaxHP = 180,
		WalkSpeed = 16,
		Attack = 26,
		AttackCooldown = 0.9,
		DetectRange = 34,
		AttackRange = 6,
		ChaseRange = 52,
		LeashRange = 70,
		ExpReward = 30,
		TargetMode = "Nearest",
	},
}

MonsterConfig.Monsters = monsters

function MonsterConfig.GetMonster(monsterId: string): MonsterData?
	return monsters[monsterId]
end

return MonsterConfig
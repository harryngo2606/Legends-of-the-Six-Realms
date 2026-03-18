--!strict

local StatsConfig = {}

export type BaseStats = {
	MaxHP: number,
	Attack: number,
	Defense: number,
	WalkSpeed: number,
}

export type EquipmentData = {
	WeaponId: string,
}

export type PlayerData = {
	Level: number,
	Exp: number,
	BaseStats: BaseStats,
	Equipment: EquipmentData,
}

StatsConfig.DEFAULT_DATA = {
	Level = 1,
	Exp = 0,
	BaseStats = {
		MaxHP = 100,
		Attack = 10,
		Defense = 5,
		WalkSpeed = 16,
	},
	Equipment = {
		WeaponId = "",
	},
} :: PlayerData

function StatsConfig.GetExpNeeded(level: number): number
	return 50 + (level - 1) * 25
end

function StatsConfig.GetStatsForLevel(level: number): BaseStats
	local base = StatsConfig.DEFAULT_DATA.BaseStats

	return {
		MaxHP = base.MaxHP + (level - 1) * 10,
		Attack = base.Attack + (level - 1) * 2,
		Defense = base.Defense + (level - 1) * 1,
		WalkSpeed = base.WalkSpeed,
	}
end

return StatsConfig
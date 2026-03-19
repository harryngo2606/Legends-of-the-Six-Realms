--!strict

local StatsConfig = {}

export type CoreStats = {
	STR: number,
	AGI: number,
	HP: number,
	MP: number,
}

export type BaseStats = {
	MaxHP: number,
	MaxMana: number,
	Attack: number,
	AttackSpeed: number,
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

local DEFAULT_LEVEL = 1

local DEFAULT_CORE_STATS: CoreStats = {
	STR = 11,
	AGI = 5,
	HP = 11,
	MP = 5,
}

local DEFAULT_BASE_STATS: BaseStats = {
	MaxHP = 100,
	MaxMana = 50,
	Attack = 10,
	AttackSpeed = 1,
	Defense = 5,
	WalkSpeed = 16,
}

StatsConfig.DEFAULT_LEVEL = DEFAULT_LEVEL
StatsConfig.DEFAULT_CORE_STATS = DEFAULT_CORE_STATS
StatsConfig.DEFAULT_BASE_STATS = DEFAULT_BASE_STATS

StatsConfig.DEFAULT_DATA = {
	Level = DEFAULT_LEVEL,
	Exp = 0,
	BaseStats = DEFAULT_BASE_STATS,
	Equipment = {
		WeaponId = "",
	},
} :: PlayerData

function StatsConfig.GetExpNeeded(level: number): number
	local safeLevel = math.max(level, 1)
	return 50 + (safeLevel - 1) * 25
end

function StatsConfig.GetCoreStatsForLevel(level: number): CoreStats
	local safeLevel = math.max(level, 1)

	return {
		STR = 10 + safeLevel,
		AGI = 5 + math.floor(safeLevel / 2),
		HP = 10 + safeLevel,
		MP = 5 + math.floor(safeLevel / 2),
	}
end

function StatsConfig.GetStatsForLevel(level: number): BaseStats
	local safeLevel = math.max(level, 1)
	local coreStats = StatsConfig.GetCoreStatsForLevel(safeLevel)

	local hpSteps = coreStats.HP - DEFAULT_CORE_STATS.HP
	local mpSteps = coreStats.MP - DEFAULT_CORE_STATS.MP
	local strSteps = coreStats.STR - DEFAULT_CORE_STATS.STR
	local agiSteps = coreStats.AGI - DEFAULT_CORE_STATS.AGI

	return {
		MaxHP = DEFAULT_BASE_STATS.MaxHP + (hpSteps * 10),
		MaxMana = DEFAULT_BASE_STATS.MaxMana + (mpSteps * 8),
		Attack = DEFAULT_BASE_STATS.Attack + (strSteps * 2),
		AttackSpeed = DEFAULT_BASE_STATS.AttackSpeed + (agiSteps * 0.02),
		Defense = DEFAULT_BASE_STATS.Defense + (safeLevel - 1),
		WalkSpeed = DEFAULT_BASE_STATS.WalkSpeed,
	}
end

return StatsConfig
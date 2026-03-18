--!strict

local EquipmentConfig = {}

export type StatBonus = {
	MaxHP: number,
	Attack: number,
	Defense: number,
	WalkSpeed: number,
}

export type WeaponData = {
	Id: string,
	Name: string,
	Slot: "Weapon",
	StatBonus: StatBonus,
}

local weapons: {[string]: WeaponData} = {
	WoodenSword = {
		Id = "WoodenSword",
		Name = "Wooden Sword",
		Slot = "Weapon",
		StatBonus = {
			MaxHP = 0,
			Attack = 5,
			Defense = 0,
			WalkSpeed = 0,
		},
	},
}

EquipmentConfig.Weapons = weapons

function EquipmentConfig.GetWeapon(weaponId: string): WeaponData?
	return weapons[weaponId]
end

return EquipmentConfig
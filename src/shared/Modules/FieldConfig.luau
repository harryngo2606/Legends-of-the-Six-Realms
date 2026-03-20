--!strict

local FieldConfig = {}

export type FieldData = {
	Id: string,
	Name: string,
	MonsterId: string,
	MonsterTemplateName: string,
	SpawnNames: {string},
	RespawnTime: number,
}

local fields: {[string]: FieldData} = {
	SlimeField_Lv1 = {
		Id = "SlimeField_Lv1",
		Name = "Slime Field Lv1",
		MonsterId = "Slime_Lv1",
		MonsterTemplateName = "Slime",
		SpawnNames = {"Spawn_01", "Spawn_02", "Spawn_03"},
		RespawnTime = 5,
	},

	WolfField_Lv8 = {
		Id = "WolfField_Lv8",
		Name = "Wolf Field Lv8",
		MonsterId = "Wolf_Lv8",
		MonsterTemplateName = "Wolf",
		SpawnNames = {"Spawn_01", "Spawn_02"},
		RespawnTime = 5,
	},
}

FieldConfig.Fields = fields

function FieldConfig.GetField(fieldId: string): FieldData?
	return fields[fieldId]
end

return FieldConfig
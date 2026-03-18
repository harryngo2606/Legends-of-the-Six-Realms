--!strict

local Services = script:WaitForChild("Services")

local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local CharacterService = require(Services:WaitForChild("CharacterService"))
local CombatService = require(Services:WaitForChild("CombatService"))
local EquipmentService = require(Services:WaitForChild("EquipmentService"))
local BossService = require(Services:WaitForChild("BossService"))
local DungeonService = require(Services:WaitForChild("DungeonService"))

PlayerDataService.Init()
CharacterService.Init()
CombatService.Init()
EquipmentService.Init()
BossService.Init()
DungeonService.Init()
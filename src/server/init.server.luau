--!strict

local Services = script:WaitForChild("Services")

local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local CharacterService = require(Services:WaitForChild("CharacterService"))
local CombatService  = require(Services:WaitForChild("CombatService"))

PlayerDataService.Init()
CharacterService.Init()
CombatService.Init()
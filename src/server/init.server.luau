--!strict

local Services = script:WaitForChild("Services")

local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local CharacterService = require(Services:WaitForChild("CharacterService"))

PlayerDataService.Init()
CharacterService.Init()
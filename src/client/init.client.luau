--!strict

local Controllers = script:WaitForChild("Controllers")

local UIController = require(Controllers:WaitForChild("UIController"))
local AnimationController = require(Controllers:WaitForChild("AnimationController"))
local CombatController = require(Controllers:WaitForChild("CombatController"))
local EquipmentController = require(Controllers:WaitForChild("EquipmentController"))
local DungeonController  = require(Controllers:WaitForChild("DungeonController"))

UIController.Init()
CombatController.Init()
EquipmentController.Init()
DungeonController.Init()
AnimationController.Init()
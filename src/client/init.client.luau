--!strict

local Controllers = script:WaitForChild("Controllers")

local UIController = require(Controllers:WaitForChild("UIController"))
-- local AnimationController = require(Controllers:WaitForChild("AnimationController"))
local CombatController = require(Controllers:WaitForChild("CombatController"))
local EquipmentController = require(Controllers:WaitForChild("EquipmentController"))
local DungeonController  = require(Controllers:WaitForChild("DungeonController"))

print("Client: init.client loaded")

UIController.Init()
print("Client: UIController.Init done")

CombatController.Init()
print("Client: CombatController.Init done")

EquipmentController.Init()
print("Client: EquipmentController.Init done")

DungeonContainer.Init()
print("Clinet: DungeonContainer.Init done")
-- AnimationController.Init()
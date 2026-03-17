--!strict

local Controllers = script:WaitForChild("Controllers")

local UIController = require(Controllers:WaitForChild("UIController"))
-- local AnimationController = require(Controllers:WaitForChild("AnimationController"))
local CombatController = require(Controllers:WaitForChild("CombatController"))

print("Client: init.client loaded")

UIController.Init()
print("Client: UIController.Init done")

CombatController.Init()
print("Client: CombatController.Init done")

-- AnimationController.Init()
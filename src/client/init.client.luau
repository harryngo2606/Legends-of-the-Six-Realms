--!strict

local Controllers = script:WaitForChild("Controllers")

local UIController = require(Controllers:WaitForChild("UIController"))
-- local AnimationController = require(Controllers:WaitForChild("AnimationController"))
local CombatController = require(Controllers:WaitForChild("CombatController"))

UIController.Init()
CombatController.Init()
-- AnimationController.Init()

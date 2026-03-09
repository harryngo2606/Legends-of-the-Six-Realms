--!strict

local Controllers = script:WaitForChild("Controllers")

local UIController = require(Controllers:WaitForChild("UIController"))
local AnimationController = require(Controllers:WaitForChild("AnimationController"))

UIController.Init()
AnimationController.Init()

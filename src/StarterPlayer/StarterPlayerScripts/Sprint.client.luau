--[[
	Sprint: hold Shift to run. On mobile, a Run button toggles sprinting.
	Sprint speed goes up a little for each gym leader beaten (the "Badges" attribute).
	You can't move during battles.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))

local sprinting = false

local function targetSpeed(): number
	if player:GetAttribute("InBattle") or player:GetAttribute("InCutscene") then
		return 0
	end
	if sprinting then
		return GameData.SprintSpeed + GameData.SprintPerBadge * (player:GetAttribute("Badges") or 0)
	end
	return GameData.WalkSpeed
end

local function apply()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = targetSpeed()
	end
end

local function onSprint(_, state: Enum.UserInputState, input: InputObject)
	if input.UserInputType == Enum.UserInputType.Touch then
		-- mobile: tap to toggle
		if state == Enum.UserInputState.Begin then
			sprinting = not sprinting
		end
	else
		-- keyboard / gamepad: hold
		sprinting = state == Enum.UserInputState.Begin
	end
	apply()
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("Sprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("Sprint", "Run")
ContextActionService:SetPosition("Sprint", UDim2.new(1, -170, 1, -110))

player:GetAttributeChangedSignal("InBattle"):Connect(apply)
player:GetAttributeChangedSignal("InCutscene"):Connect(apply)
player:GetAttributeChangedSignal("Badges"):Connect(apply)
player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid")
	apply()
end)
apply()

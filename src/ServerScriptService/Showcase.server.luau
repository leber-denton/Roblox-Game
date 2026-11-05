--[[
	Showcase: owner-only chat commands.
	  /showcase      teleports the owner to Workspace.ShowcaseArea (built by ServerStorage.ShowcaseBuilder)
	  /showcase off  sends the owner back to spawn
	Checked on the server by UserId. Nothing in the map links to the showcase.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ServerStorage = game:GetService("ServerStorage")

local OWNER_USER_ID = 1170990981 -- LilDiesel468
local Builder = require(ServerStorage:WaitForChild("ShowcaseBuilder"))

local command = Instance.new("TextChatCommand")
command.Name = "ShowcaseCommand"
command.PrimaryAlias = "/showcase"
command.Parent = TextChatService

command.Triggered:Connect(function(origin, text)
	if origin.UserId ~= OWNER_USER_ID then
		return
	end
	local player = Players:GetPlayerByUserId(origin.UserId)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if text:lower():match("off%s*$") then
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
		root.CFrame = (spawn and spawn.CFrame or CFrame.new(0, 5, -70)) + Vector3.new(0, 5, 0)
		return
	end
	local target = Builder.arrivalCFrame()
	if workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(target.Position)
		end)
	end
	root.CFrame = target
end)

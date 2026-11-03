--[[
	FirstSpawnLock: a brand-new player can only interact with Professor Maple.
	While TutorialStep is "meet_prof" or "choose_starter" (no partner yet), every ProximityPrompt in
	the world except the Professor's is switched off on this client, including prompts that stream
	in later. They come back the moment the player has picked a starter.
	The SHOP / BASE / HEAL teleport buttons are hidden by the HUD for the same steps, and the server
	refuses those teleports too (Main, Teleport handler).
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local LOCKED_STEPS = { meet_prof = true, choose_starter = true }

local map = workspace:WaitForChild("Map")
local professor = map:WaitForChild("Hub"):WaitForChild("Lab"):WaitForChild("Professor")

local disabled = {} -- [ProximityPrompt] = connection (prompts we switched off)

local function isLocked(): boolean
	return LOCKED_STEPS[player:GetAttribute("TutorialStep")] == true
end

local function lockPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") or prompt:IsDescendantOf(professor) or disabled[prompt] then
		return
	end
	prompt.Enabled = false
	-- the server may switch it back on (e.g. a creature finishing a battle): keep it off while locked
	disabled[prompt] = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled and isLocked() then
			prompt.Enabled = false
		end
	end)
end

local function unlockAll()
	for prompt, conn in disabled do
		conn:Disconnect()
		if prompt.Parent then
			prompt.Enabled = true
		end
	end
	disabled = {}
end

local addedConn
local function update()
	if isLocked() then
		for _, d in workspace:GetDescendants() do
			lockPrompt(d)
		end
		if not addedConn then
			addedConn = workspace.DescendantAdded:Connect(function(d)
				if isLocked() then
					lockPrompt(d)
				end
			end)
		end
	else
		if addedConn then
			addedConn:Disconnect()
			addedConn = nil
		end
		unlockAll()
	end
end

player:GetAttributeChangedSignal("TutorialStep"):Connect(update)
update()

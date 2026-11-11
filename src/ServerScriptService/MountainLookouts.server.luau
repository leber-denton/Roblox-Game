-- Summit and lookout prompts for part-built mountains (Workspace.Map.Mountains).
-- Prompt text comes from attributes on each mountain Model and prompt positions come from
-- marker parts (attribute MountainMarker = "Summit" or "Lookout"), so both can be edited in
-- Studio without code changes. Prompts are cosmetic: they show a message and grant nothing.
-- Built-in prompts support keyboard, controller and touch without replacing movement controls.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local BattleService = require(script.Parent.Modules.BattleService)
local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local PROMPT = "MountainPrompt"
local COOLDOWN = 3
local lastUse = {}
local wiredMarkers = {}
local wiredModels = {}

local function mountainOf(marker)
	local model = marker:FindFirstAncestorOfClass("Model")
	while model and model:GetAttribute("MountainName") == nil do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end

-- Returns object text, action text and message for one marker, all read from attributes.
local function textsFor(model, marker)
	local mountain = model:GetAttribute("MountainName")
	if marker:GetAttribute("MountainMarker") == "Summit" then
		local name = model:GetAttribute("SummitName") or (mountain .. " Summit")
		local message = model:GetAttribute("SummitMessage") or ("You reached the top of " .. mountain .. "!")
		return name, model:GetAttribute("SummitPrompt") or "Survey", message
	end
	local name = model:GetAttribute(marker.Name .. "Name") or marker.Name
	local message = model:GetAttribute(marker.Name .. "Message") or (name .. " · " .. mountain)
	return name, model:GetAttribute("LookoutPrompt") or "Look out", message
end

local function refresh(model, marker)
	local prompt = marker:FindFirstChild(PROMPT)
	if not prompt then return end
	local objectText, actionText = textsFor(model, marker)
	prompt.ObjectText, prompt.ActionText = objectText, actionText
	prompt.MaxActivationDistance = model:GetAttribute("PromptDistance") or 10
end

local function onTriggered(marker, prompt, player)
	local model = mountainOf(marker)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not model or not root or not humanoid or humanoid.Health <= 0 then return end
	if (root.Position - marker.Position).Magnitude > prompt.MaxActivationDistance + 2 then return end
	if os.clock() - (lastUse[player] or -math.huge) < COOLDOWN or BattleService.isInBattle(player) then return end
	lastUse[player] = os.clock()
	local lane = model:GetAttribute("Lane")
	local champion = (player:GetAttribute("Stat_leagueWins") or 0) > 0
	if lane and not GameData.canEnter(lane, player:GetAttribute("Badges") or 0, champion) then
		Notify:FireClient(player, "Earn this route's badges before surveying its mountain.", "fail")
		return
	end
	local _, _, message = textsFor(model, marker)
	Notify:FireClient(player, message, "info")
end

local function wireModel(model)
	if wiredModels[model] then return end
	wiredModels[model] = true
	model.AttributeChanged:Connect(function()
		for marker in wiredMarkers do
			if marker:IsDescendantOf(model) then refresh(model, marker) end
		end
	end)
end

local function wireMarker(marker)
	if wiredMarkers[marker] or not marker:IsA("BasePart") or not marker:GetAttribute("MountainMarker") then return end
	local model = mountainOf(marker)
	if not model then return end
	wiredMarkers[marker] = true
	wireModel(model)
	local prompt = marker:FindFirstChild(PROMPT) or Instance.new("ProximityPrompt")
	prompt.Name, prompt.HoldDuration, prompt.RequiresLineOfSight = PROMPT, 0.4, false
	prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
	prompt.Parent = marker
	refresh(model, marker)
	prompt.Triggered:Connect(function(player) onTriggered(marker, prompt, player) end)
	marker.Destroying:Connect(function() wiredMarkers[marker] = nil end)
end

local function watch(root)
	for _, descendant in root:GetDescendants() do wireMarker(descendant) end
	root.DescendantAdded:Connect(wireMarker)
end

local map = workspace:WaitForChild("Map")
local function onMapChild(child)
	if child.Name == "Mountains" then watch(child) end
end
for _, child in map:GetChildren() do onMapChild(child) end
map.ChildAdded:Connect(onMapChild)
Players.PlayerRemoving:Connect(function(player) lastUse[player] = nil end)

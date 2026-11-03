--[[
	Regions: opens region gates for this player once they have enough gym badges.
	Each gate in workspace.Map.Gates has attributes Lane and Badges. Gates are solid for everyone
	on the server; this script makes them passable (and invisible) just for you when you qualify,
	and updates the region signs. The server also checks badges before any battle in a region.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))

local map = workspace:WaitForChild("Map")
local gates = map:WaitForChild("Gates")
local lanes = map:WaitForChild("Lanes")

local opened = {} -- [lane] = true once opened (so we only celebrate once per session)
local firstPass = true

local function regionName(lane: string): string
	if GameData.VictoryRoads and GameData.VictoryRoads[lane] then
		return GameData.VictoryRoads[lane] -- "Maple Victory Road" / "Summit Victory Road"
	end
	if lane == "Town2Pass" then
		return "The mountain pass to " .. GameData.Region2.region
	end
	if lane == "Town2" and GameData.Region2 then
		return GameData.Region2.name
	end
	for _, r in GameData.Regions do
		if r.lane == lane then
			return r.name
		end
	end
	return lane
end

local function setSign(lane: string, open: boolean, need: number)
	local sign = lanes:FindFirstChild(lane .. "Sign")
	if not sign then
		return
	end
	-- the sign is a two-sided board: update every face
	for _, label in sign:GetDescendants() do
		if label:IsA("TextLabel") and label.Name == "Text" then
			if open then
				label.Text = regionName(lane)
				label.TextColor3 = Color3.new(1, 1, 1)
			else
				label.Text = ("%s\n%d badge%s needed"):format(regionName(lane), need, need == 1 and "" or "s")
				label.TextColor3 = Color3.fromRGB(255, 120, 120)
			end
		end
	end
end

local function apply(gate: BasePart)
	local lane = gate:GetAttribute("Lane")
	local need = gate:GetAttribute("Badges") or 0
	local champion = (player:GetAttribute("Stat_leagueWins") or 0) > 0
	local open = (player:GetAttribute("Badges") or 0) >= need and (not gate:GetAttribute("NeedChampion") or champion)
	gate.CanCollide = not open
	for _, sg in gate:GetChildren() do
		if sg:IsA("SurfaceGui") then
			sg.Enabled = not open
		end
	end
	if open and not opened[lane] then
		opened[lane] = true
		if firstPass then
			gate.Transparency = 1
		else
			-- just earned it: fade the gate away
			TweenService:Create(gate, TweenInfo.new(1.5), { Transparency = 1 }):Play()
		end
	elseif not open then
		opened[lane] = nil
		gate.Transparency = 0.2
	end
	setSign(lane, open, need)
end

local function applyAll()
	for _, gate in gates:GetChildren() do
		if gate:IsA("BasePart") then
			apply(gate)
		end
	end
	firstPass = false
end

player:GetAttributeChangedSignal("Badges"):Connect(applyAll)
player:GetAttributeChangedSignal("Stat_leagueWins"):Connect(applyAll)
gates.ChildAdded:Connect(function(g)
	if g:IsA("BasePart") then
		apply(g)
	end
end)
applyAll()

-- bumping a locked gate tells you what it needs (once every few seconds)
local lastHint = 0

-- The mountains between the regions: you can see the other region through the valleys, but walking up
-- to them only tells you how to get there (Region 2 opens once you've beaten Region 1's Champion).
do
	local hints = map:WaitForChild("MountainHints", 10)
	if hints then
		local function onTouch(part: BasePart, hit: BasePart)
			local character = player.Character
			if not character or not hit:IsDescendantOf(character) or os.clock() - lastHint < 6 then
				return
			end
			lastHint = os.clock()
			local champion = (player:GetAttribute("Stat_leagueWins") or 0) > 0
			local other = part:GetAttribute("Side") == 2 and (GameData.Region1.name .. " region") or (GameData.Region2.region .. " region")
			local text
			if part:GetAttribute("Side") == 2 then
				text = ("The %s is past these mountains. Open MAP to travel back."):format(other)
			elseif champion then
				text = ("The %s is past these mountains. Take the road east of the Hub, or hop there from MAP."):format(other)
			else
				text = ("The %s is past these mountains. Beat %s and become the Champion to open the way."):format(other, GameData.VictoryRoads.League)
			end
			local toast = player:FindFirstChild("LocalToast")
			if toast then
				toast:Fire(text, champion and "info" or "fail")
			end
		end
		for _, part in hints:GetChildren() do
			if part:IsA("BasePart") then
				part.Touched:Connect(function(hit)
					onTouch(part, hit)
				end)
			end
		end
	end
end
for _, gate in gates:GetChildren() do
	if gate:IsA("BasePart") then
		gate.Touched:Connect(function(hit)
			if not gate.CanCollide or os.clock() - lastHint < 4 then
				return
			end
			local character = player.Character
			if character and hit:IsDescendantOf(character) then
				lastHint = os.clock()
				local need = gate:GetAttribute("Badges") or 0
				local have = player:GetAttribute("Badges") or 0
				local text
				if have >= need and gate:GetAttribute("NeedChampion") then
					text = ("%s is locked. Beat the Elite Four and become the Champion first!"):format(regionName(gate:GetAttribute("Lane")))
				else
					text = ("%s is locked. You need %d gym badge%s (you have %d)."):format(regionName(gate:GetAttribute("Lane")), need, need == 1 and "" or "s", have)
				end
				-- the HUD shows it like any other message
				local toast = player:FindFirstChild("LocalToast")
				if toast then
					toast:Fire(text, "fail")
				end
			end
		end)
	end
end

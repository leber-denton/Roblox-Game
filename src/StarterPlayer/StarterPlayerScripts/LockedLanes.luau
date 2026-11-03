--[[
	LockedLanes (client): regions you haven't unlocked are greyed out, just for you.
	  - You can still read the region's name on its sign and see its big landmarks (trees, rocks, the gym building),
	    but everything is drained of colour.
	  - What's actually in the region stays hidden until you earn the badges: route trainers, the gym leader,
	    wild creatures, lights, effects and the small props.
	  - Earning the badges brings the colour back with a short fade.
	Works with streaming: parts that load in later are greyed as they arrive.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))

local map = workspace:WaitForChild("Map")
local lanesFolder = map:WaitForChild("Lanes")
local gatesFolder = map:WaitForChild("Gates")

local SMALL = 5 -- props smaller than this (longest side) are hidden while locked
local LOCK_GREY = Color3.fromRGB(120, 122, 128)

-- containers never touched: they're shared or always visible
local SKIP = {}
for _, name in { "Bases", "Hub", "Gates", "Walls", "Bounds", "DungeonTower" } do
	local f = map:FindFirstChild(name)
	if f then
		SKIP[f] = true
	end
end

-- Each region: the box it covers (beyond its gate) and the badges it needs.
-- Built from the gates as they stream in (each region is a 420-stud strip behind its gate).
local REGION_LENGTH = 520
local regions = {}
local refresh -- set below
local function addRegion(gate: Instance)
	if not gate:IsA("BasePart") then
		return
	end
	local laneName = gate:GetAttribute("Lane")
	if not laneName or regions[laneName] then
		return
	end
	local halfX = gate.Size.X / 2 + 1
	regions[laneName] = {
		lane = laneName,
		need = gate:GetAttribute("Badges") or 0,
		champion = gate:GetAttribute("NeedChampion") == true,
		minX = gate.Position.X - halfX, maxX = gate.Position.X + halfX,
		minZ = gate.Position.Z - 12, maxZ = gate.Position.Z + (gate:GetAttribute("RegionLength") or REGION_LENGTH),
		locked = nil,
		parts = {}, -- [BasePart] = original look
		other = {}, -- lights, effects, guis, prompts: [Instance] = original Enabled
	}
	if refresh then
		refresh(true)
	end
end
for _, gate in gatesFolder:GetChildren() do
	addRegion(gate)
end
gatesFolder.ChildAdded:Connect(addRegion)

local function regionAt(pos: Vector3)
	for _, r in regions do
		if pos.X >= r.minX and pos.X <= r.maxX and pos.Z >= r.minZ and pos.Z <= r.maxZ then
			return r
		end
	end
	return nil
end

local function skipped(inst: Instance): boolean
	local a = inst.Parent
	while a and a ~= workspace do
		if SKIP[a] then
			return true
		end
		a = a.Parent
	end
	return false
end

-- Is this part one of the things that should vanish (not just go grey)?
local function isContent(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") or model:GetAttribute("NPC") or model:IsDescendantOf(map.RouteTrainers) then
			return true
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	if part.Parent == lanesFolder then
		return false -- the lane ground itself
	end
	local s = part.Size
	return math.max(s.X, s.Y, s.Z) < SMALL
end

local function grey(c: Color3): Color3
	local l = c.R * 0.3 + c.G * 0.59 + c.B * 0.11
	return Color3.new(l, l, l):Lerp(LOCK_GREY, 0.45)
end

local function lockPart(r, part: BasePart)
	if r.parts[part] then
		return
	end
	local orig = { color = part.Color, material = part.Material }
	r.parts[part] = orig
	if isContent(part) then
		part.LocalTransparencyModifier = 1
	else
		part.Color = grey(part.Color)
		if part.Material == Enum.Material.Neon then
			part.Material = Enum.Material.SmoothPlastic
		end
		-- textured meshes (trees, rocks) keep their colours in the texture: drop it while locked
		if part:IsA("MeshPart") and part.TextureID ~= "" then
			orig.texture = part.TextureID
			pcall(function()
				part.TextureID = ""
			end)
		end
		local sa = part:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			orig.appearance = sa
			sa.Parent = nil
		end
	end
end

local OTHER = { "Light", "ParticleEmitter", "Fire", "Smoke", "Sparkles", "BillboardGui", "ProximityPrompt", "Beam", "Trail", "Decal", "Texture" }
local function isOther(inst: Instance): boolean
	for _, cls in OTHER do
		if inst:IsA(cls) then
			return true
		end
	end
	return false
end

local function lockOther(r, inst: Instance)
	if r.other[inst] ~= nil then
		return
	end
	if inst:IsA("Decal") or inst:IsA("Texture") then
		r.other[inst] = inst.Transparency
		inst.Transparency = 1
	else
		r.other[inst] = inst.Enabled
		inst.Enabled = false
	end
end

local function positionOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	end
	local p = inst:FindFirstAncestorWhichIsA("BasePart")
	return p and p.Position
end

-- Look at one instance and grey / hide it if it's inside a locked region
local function consider(inst: Instance)
	if inst:IsDescendantOf(lanesFolder) and inst.Name:find("Sign") then
		return -- region name signs stay readable
	end
	if inst:IsA("BasePart") or isOther(inst) then
		local pos = positionOf(inst)
		local r = pos and regionAt(pos)
		if not r or not r.locked or skipped(inst) then
			return
		end
		if inst:IsA("BasePart") then
			lockPart(r, inst)
		else
			lockOther(r, inst)
		end
	end
end

local function lockRegion(r)
	for _, d in map:GetDescendants() do
		consider(d)
	end
	local wild = workspace:FindFirstChild("WildCreatures")
	if wild then
		for _, d in wild:GetDescendants() do
			if d:IsA("BasePart") or isOther(d) then
				local pos = positionOf(d)
				if pos and regionAt(pos) == r then
					if d:IsA("BasePart") then
						r.parts[d] = r.parts[d] or { color = d.Color, material = d.Material }
						d.LocalTransparencyModifier = 1
					else
						lockOther(r, d)
					end
				end
			end
		end
	end
end

local function unlockRegion(r, fade: boolean)
	for part, orig in r.parts do
		if part.Parent then
			part.Material = orig.material
			if fade then
				TweenService:Create(part, TweenInfo.new(1.6), { Color = orig.color }):Play()
			else
				part.Color = orig.color
			end
			part.LocalTransparencyModifier = 0
			if orig.texture then
				pcall(function()
					part.TextureID = orig.texture
				end)
			end
			if orig.appearance then
				orig.appearance.Parent = part
			end
		end
	end
	for inst, orig in r.other do
		if inst.Parent then
			if inst:IsA("Decal") or inst:IsA("Texture") then
				inst.Transparency = orig
			else
				inst.Enabled = orig
			end
		end
	end
	r.parts, r.other = {}, {}
end

refresh = function(firstTime: boolean)
	local badges = player:GetAttribute("Badges") or 0
	local champion = (player:GetAttribute("Stat_leagueWins") or 0) > 0
	for _, r in regions do
		local locked = badges < r.need or (r.champion and not champion)
		if locked ~= r.locked then
			local was = r.locked
			r.locked = locked
			if locked then
				lockRegion(r)
			elseif was ~= nil then
				unlockRegion(r, not firstTime)
			end
		end
	end
end

-- wait for the save to load so returning players don't see a flash of grey
do
	local t0 = os.clock()
	while player:GetAttribute("SaveStatus") == nil and os.clock() - t0 < 12 do
		task.wait(0.2)
	end
end
refresh(true)
player:GetAttributeChangedSignal("Badges"):Connect(function()
	refresh(false)
end)
player:GetAttributeChangedSignal("Stat_leagueWins"):Connect(function()
	refresh(false)
end)

-- streamed-in parts, newly spawned creatures, NPC effects
map.DescendantAdded:Connect(function(d)
	task.defer(consider, d)
end)
task.spawn(function()
	local wild = workspace:WaitForChild("WildCreatures", 30)
	if not wild then
		return
	end
	wild.DescendantAdded:Connect(function(d)
		task.defer(function()
			if not d.Parent or not (d:IsA("BasePart") or isOther(d)) then
				return
			end
			local pos = positionOf(d)
			local r = pos and regionAt(pos)
			if r and r.locked then
				if d:IsA("BasePart") then
					r.parts[d] = r.parts[d] or { color = d.Color, material = d.Material }
					d.LocalTransparencyModifier = 1
				else
					lockOther(r, d)
				end
			end
		end)
	end)
end)

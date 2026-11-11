--[[
	TowerBuilder (Studio only): builds and themes Workspace.Map.DungeonTower in the place file.
	Run in Studio's command bar (Edit mode), then save the place:
	  local TB = require(game.ServerStorage.TowerBuilder)
	  TB.build()          -- adds rooms up to #GameData.Dungeon.floors, fixes trainers, paints (one undo step)
	  TB.paint()          -- re-apply Shared.TowerThemes colours only (after changing a theme)
	  TB.purpleReport()   -- lists anything still purple in the tower and the hub portal (should be empty)

	Layout: RoomN sits at y = Room1 + (N-1) * 24. Floor index N in GameData.Dungeon.floors is RoomN.
	New trainer rooms are clones of Room<TEMPLATE>; the top room (the rest room: no trainer, solid ceiling)
	is cloned to the new top before the old top becomes a trainer room, so every room keeps its own
	StartPad (StoryService reads Room11.StartPad). Battlements and the beacon move up with the top.
	Safe to re-run: rooms that exist are kept, trainers already fixed are skipped, paint is idempotent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local GameData = require(ReplicatedStorage.Shared.GameData)
local TowerThemes = require(ReplicatedStorage.Shared.TowerThemes)
local Styler = require(ServerScriptService.Modules.DungeonNPCStyler)

local TowerBuilder = {}

TowerBuilder.STEP = 24 -- studs between floors
TowerBuilder.TEMPLATE = 9 -- a plain trainer room (not a boss room) to clone
-- Hair for the trainers, cloned from map NPCs that already wear it (none of these is purple)
TowerBuilder.HAIR = { "MessyHair", "Pal Hair", "BrownCharmerHair", "Kate Hair" }
-- Old Studio-built head pieces that hid the trainers' real faces (a box hood over a stock smiley head)
TowerBuilder.BROKEN_PARTS = { "ClassicHead", "Hood", "Collar" }

local function tower(): Model
	return workspace:WaitForChild("Map"):WaitForChild("DungeonTower")
end

local function room(i: number): Model?
	return tower():FindFirstChild("Room" .. i)
end

local function topRoomIndex(): number
	local i = 1
	while room(i + 1) do
		i += 1
	end
	return i
end

local function shift(inst: Instance, dy: number)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + Vector3.new(0, dy, 0))
	elseif inst:IsA("BasePart") then
		inst.CFrame += Vector3.new(0, dy, 0)
	end
end

-- Adds rooms so that every floor in GameData has one. Returns the names of the rooms it made.
local function addRooms(): { string }
	local floors = GameData.Dungeon.floors
	local want = #floors
	local have = topRoomIndex()
	local made = {}
	if have >= want then
		return made
	end
	local T = tower()
	local template = assert(room(TowerBuilder.TEMPLATE), "TowerBuilder: template room missing")
	local oldTop = room(have) :: Model
	local dyTop = (want - have) * TowerBuilder.STEP

	-- 1. the rest room moves to the new top: clone it there before the old top is converted
	local restRoom = oldTop:Clone()
	restRoom.Name = "Room" .. want
	shift(restRoom, dyTop)
	restRoom.Parent = T
	table.insert(made, restRoom.Name)
	-- the top room needs a closed ceiling: the template's four pieces plus a cap over the lift hole
	local restCeilings = 0
	for _, c in restRoom:GetChildren() do
		if c.Name == "Ceiling" then
			restCeilings += 1
		end
	end
	if restCeilings ~= 1 then
		for _, c in restRoom:GetChildren() do
			if c.Name == "Ceiling" then
				c.Parent = nil
			end
		end
		local dy = (want - TowerBuilder.TEMPLATE) * TowerBuilder.STEP
		local y
		for _, c in template:GetChildren() do
			if c.Name == "Ceiling" and c:IsA("BasePart") then
				local copy = c:Clone()
				shift(copy, dy)
				copy.Parent = restRoom
				y = copy.Position.Y
			end
		end
		local hatch = restRoom:FindFirstChild("Hatch") :: BasePart?
		if y and hatch then
			local cap = hatch:Clone()
			cap:ClearAllChildren()
			cap.Name = "Ceiling"
			cap.Transparency = 0
			cap.CanCollide = true
			cap.Size = Vector3.new(hatch.Size.X + 0.4, hatch.Size.Y, hatch.Size.Z + 0.4)
			cap.Position = Vector3.new(hatch.Position.X, y, hatch.Position.Z)
			cap.Parent = restRoom
		end
	end

	-- 2. the old top becomes a trainer room: open ceiling (lift hole) and a trainer, StartPad untouched.
	-- Parts are removed with Parent = nil, not Destroy(), so Studio's undo can bring them back.
	if not oldTop:FindFirstChild("Trainer") then
		local dy = (have - TowerBuilder.TEMPLATE) * TowerBuilder.STEP
		for _, c in oldTop:GetChildren() do
			if c.Name == "Ceiling" then
				c.Parent = nil
			end
		end
		for _, c in template:GetChildren() do
			if c.Name == "Ceiling" or c.Name == "Trainer" then
				local copy = c:Clone()
				shift(copy, dy)
				copy.Parent = oldTop
			end
		end
	end

	-- 3. the floors in between are clones of the template room
	for i = have + 1, want - 1 do
		local r = template:Clone()
		r.Name = "Room" .. i
		shift(r, (i - TowerBuilder.TEMPLATE) * TowerBuilder.STEP)
		r.Parent = T
		table.insert(made, r.Name)
	end

	-- 4. battlements and beacon ride up with the top; the invisible bounds grow to cover the new height
	local topY = room(want).Center.Position.Y + 40
	for _, c in T:GetChildren() do
		if c.Name == "Battlement" or c.Name == "Beacon" then
			shift(c, dyTop)
		elseif c.Name:match("^TowerBound") and c:IsA("BasePart") then
			local bottom = c.Position.Y - c.Size.Y / 2
			if topY > bottom + c.Size.Y then
				c.Size = Vector3.new(c.Size.X, topY - bottom, c.Size.Z)
				c.Position = Vector3.new(c.Position.X, bottom + c.Size.Y / 2, c.Position.Z)
			end
		end
	end
	return made
end

local hairCache = {}
local function hairSource(name: string): Accessory?
	if hairCache[name] == nil then
		hairCache[name] = false
		for _, d in workspace.Map:GetDescendants() do
			if d:IsA("Accessory") and d.Name == name and not d:IsDescendantOf(tower()) then
				hairCache[name] = d
				break
			end
		end
	end
	return hairCache[name] or nil
end

-- Puts an accessory on a rig in Edit or Play: AddAccessory, then a manual weld if it did not make one.
local function wear(model: Model, acc: Accessory)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local handle = acc:FindFirstChild("Handle") :: BasePart?
	if not humanoid or not handle then
		return
	end
	for _, d in handle:GetChildren() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("RigidConstraint") then
			d.Parent = nil
		end
	end
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	humanoid:AddAccessory(acc)
	if handle:FindFirstChildWhichIsA("Weld") or handle:FindFirstChildWhichIsA("WeldConstraint") then
		return
	end
	local att = handle:FindFirstChildWhichIsA("Attachment")
	local head = model:FindFirstChild("Head") :: BasePart?
	local target = att and head and head:FindFirstChild(att.Name) :: Attachment?
	if att and target then
		handle.CFrame = target.WorldCFrame * att.CFrame:Inverse()
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = handle
		weld.Parent = handle
	end
end

-- Shows the real R15 head (its face is on the head mesh), removes the box hood and stock smiley head,
-- gives each trainer hair and paints its clothes in the tower theme. Returns a line per trainer.
local function fixTrainers(): { string }
	local lines = {}
	for i, f in GameData.Dungeon.floors do
		local r = room(i)
		local trainer = r and r:FindFirstChild("Trainer")
		if f.rest or not trainer then
			continue
		end
		local removed = 0
		for _, n in TowerBuilder.BROKEN_PARTS do
			local p = trainer:FindFirstChild(n)
			if p then
				p.Parent = nil
				removed += 1
			end
		end
		local head = trainer:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			head.Transparency = 0
		end
		local hair = "kept"
		if not trainer:FindFirstChildWhichIsA("Accessory") then
			local name = TowerBuilder.HAIR[(i - 1) % #TowerBuilder.HAIR + 1]
			local src = hairSource(name)
			if src then
				wear(trainer, src:Clone())
				hair = name
			else
				hair = "MISSING " .. name
			end
		end
		Styler.paint(trainer, f.trainer, i)
		trainer:SetAttribute("TrainerName", f.trainer)
		table.insert(lines, ("Room%d %s: removed %d, hair %s"):format(i, f.trainer, removed, hair))
	end
	return lines
end

local function setPart(p: BasePart, spec)
	p.Color = spec[1]
	p.Material = spec[2]
end

local ROLE = {
	Wall = "wall",
	Floor = "floor",
	Ceiling = "ceiling",
	Pillar = "pillar",
	Carpet = "carpet",
	WindowSlit = "trim",
	LiftRing = "trim",
	Torch = "torch",
	Hatch = "hatch",
	StartPad = "startPad",
	ExitPortal = "exit",
}

local function isPurple(c: Color3): boolean
	local h, s, v = c:ToHSV()
	return s > 0.18 and v > 0.08 and h >= 0.69 and h <= 0.92
end

-- Hub portal and other leftovers: any purple becomes the matching Bone Crypt colour.
local function depurple(root: Instance, roomTheme)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and isPurple(d.Color) then
			if d.Material == Enum.Material.Neon then
				setPart(d, roomTheme.trim)
			elseif d.Material == Enum.Material.Fabric then
				setPart(d, roomTheme.carpet)
			else
				local _, _, v = d.Color:ToHSV()
				setPart(d, v > 0.33 and roomTheme.pillar or roomTheme.wall)
			end
		elseif d:IsA("Light") and isPurple(d.Color) then
			d.Color = roomTheme.torchLight
		elseif d:IsA("ParticleEmitter") and isPurple(d.Color.Keypoints[1].Value) then
			d.Color = ColorSequence.new(roomTheme.trim[1])
		elseif (d:IsA("TextLabel") or d:IsA("TextButton")) and isPurple(d.TextColor3) then
			d.TextColor3 = roomTheme.sign
		elseif d:IsA("UIStroke") and isPurple(d.Color) then
			d.Color = roomTheme.signStroke
		end
	end
end

function TowerBuilder.paint()
	local floors = GameData.Dungeon.floors
	for i, f in floors do
		local r = room(i)
		if not r then
			continue
		end
		local _, palette, boss = TowerThemes.forFloor(i)
		local trainer = r:FindFirstChild("Trainer")
		for _, p in r:GetDescendants() do
			if trainer and p:IsDescendantOf(trainer) then
				continue
			end
			local role = p:IsA("BasePart") and ROLE[p.Name]
			if role then
				setPart(p, palette[role])
				for _, light in p:GetChildren() do
					if light:IsA("Light") then
						light.Color = role == "torch" and palette.torchLight or palette[role][1]
					end
				end
			end
			if p:IsA("TextLabel") then
				if p.Parent and p.Parent.Parent and p.Parent.Parent.Name == "FloorSign" then
					p.Text = "FLOOR " .. f.label .. (boss and "  ·  BOSS" or f.rest and "  ·  SUMMIT" or "")
					p.TextColor3 = palette.sign
					p.TextStrokeColor3 = palette.signStroke
				elseif p:FindFirstAncestor("ExitPortal") then
					p.TextColor3 = palette.exitText
				end
			end
		end
	end
	-- outside: the ground belongs to tower 1, the battlements and beacon to the top tower
	local _, bottom = TowerThemes.forFloor(1)
	local _, top = TowerThemes.forFloor(#floors)
	for _, c in tower():GetChildren() do
		if c:IsA("BasePart") then
			if c.Name == "Battlement" then
				setPart(c, top.outer)
			elseif c.Name == "Beacon" then
				setPart(c, top.beacon)
				for _, light in c:GetChildren() do
					if light:IsA("Light") then
						light.Color = top.beacon[1]
					end
				end
			elseif c.Name == "TowerGround" then
				setPart(c, bottom.outer)
			end
		end
	end
	local portal = workspace.Map:FindFirstChild("Hub") and workspace.Map.Hub:FindFirstChild("DungeonPortal")
	if portal then
		depurple(portal, bottom)
	end
	-- anything the role table missed (trainer clothes are painted by the styler)
	for i = 1, #floors do
		local r = room(i)
		if r then
			depurple(r, select(2, TowerThemes.forFloor(i)))
		end
	end
end

-- Everything still purple under the tower and the hub portal, as "path (what)" lines.
function TowerBuilder.purpleReport(): { string }
	local out = {}
	local roots = { tower() }
	local portal = workspace.Map:FindFirstChild("Hub") and workspace.Map.Hub:FindFirstChild("DungeonPortal")
	if portal then
		table.insert(roots, portal)
	end
	for _, root in roots do
		for _, d in root:GetDescendants() do
			local c
			if (d:IsA("BasePart") and d.Transparency < 1) or d:IsA("Light") or d:IsA("UIStroke") then
				c = (d :: any).Color
			elseif d:IsA("ParticleEmitter") then
				c = d.Color.Keypoints[1].Value
			elseif d:IsA("TextLabel") then
				c = d.TextColor3
			elseif d:IsA("BodyColors") then
				c = d.TorsoColor3
			end
			if c and isPurple(c) then
				table.insert(out, d:GetFullName() .. " (" .. d.ClassName .. ")")
			end
		end
	end
	return out
end

TowerBuilder.addRooms = addRooms
TowerBuilder.fixTrainers = fixTrainers

function TowerBuilder.build()
	local recording = not RunService:IsRunning() and ChangeHistoryService:TryBeginRecording("TowerBuilder.build") or nil
	local ok, result = pcall(function()
		local made = addRooms()
		local trainers = fixTrainers()
		TowerBuilder.paint()
		return { made = made, trainers = trainers, purple = TowerBuilder.purpleReport() }
	end)
	if recording then
		ChangeHistoryService:FinishRecording(
			recording,
			ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel
		)
	end
	if not ok then
		error(result, 0)
	end
	print(("TowerBuilder: made %d rooms, %d trainers, %d purple left"):format(#result.made, #result.trainers, #result.purple))
	return result
end

return TowerBuilder

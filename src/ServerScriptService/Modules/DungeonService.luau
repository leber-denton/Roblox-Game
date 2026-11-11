--[[
	DungeonService: the dark tower behind the hub.
	Enter through the portal in the hub. Two towers of ten floors are stacked: 1.1-1.10 (Bone Crypt) and
	2.1-2.10 (Ember Forge); x.10 is each tower's boss and 3.1 is a rest room at the top, the end for now.
	Beat a floor's trainer and a glowing lift carries you up through the ceiling to the next floor.
	Lose and you're sent to the Healing Center (progress is kept).
	Progress: player attribute "DungeonFloor" (index into GameData.Dungeon.floors = RoomN).
	Colours and stage names come from Shared.TowerThemes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameData = require(ReplicatedStorage.Shared.GameData)
local TowerThemes = require(ReplicatedStorage.Shared.TowerThemes)
local BattleService = require(script.Parent.BattleService)
local NPC = require(script.Parent.NPC)
local DungeonNPCStyler = require(script.Parent.DungeonNPCStyler)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local DungeonService = {}

local tower = workspace:WaitForChild("Map"):WaitForChild("DungeonTower")
local floors = GameData.Dungeon.floors
local LIFT_SECONDS = 3.2

local function room(i: number): Model?
	return tower:FindFirstChild("Room" .. i)
end

local function hipHeight(character: Model): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 and hrp then
		return humanoid.HipHeight + hrp.Size.Y / 2
	end
	return 3
end

-- The tower sits far from the main map so it only loads for players inside it.
-- Load the destination on the player's client before moving them there.
local function streamTo(player: Player, pos: Vector3)
	pcall(player.RequestStreamAroundAsync, player, pos, 4)
end
DungeonService.streamTo = streamTo

function DungeonService.initPlayer(player: Player)
	player:SetAttribute("DungeonFloor", 1)
	player:SetAttribute("InDungeon", false)
end

function DungeonService.enter(player: Player)
	if BattleService.isInBattle(player) or player:GetAttribute("Elevating") then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local i = player:GetAttribute("DungeonFloor") or 1
	local r = room(i)
	if not r then
		return
	end
	local pos = r.StartPad.Position + Vector3.new(0, hipHeight(character), 0)
	streamTo(player, pos)
	if not character.Parent then
		return
	end
	character:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
	player:SetAttribute("InDungeon", true)
	Notify:FireClient(player, ("Dungeon Floor %s"):format(floors[i].label), "info")
end

function DungeonService.leave(player: Player)
	if BattleService.isInBattle(player) or player:GetAttribute("Elevating") then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local portal = workspace.Map.Hub.DungeonPortal.PrimaryPart
	local pos = Vector3.new(portal.Position.X, hipHeight(character) + 0.6, portal.Position.Z + 10)
	streamTo(player, pos)
	if not character.Parent then
		return
	end
	character:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
	player:SetAttribute("InDungeon", false)
end

-- The lift: a glowing platform carries the player up through the ceiling to the next floor
local function ride(player: Player, fromIndex: number)
	local from, to = room(fromIndex), room(fromIndex + 1)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not from or not to or not hrp then
		return
	end
	player:SetAttribute("DungeonFloor", fromIndex + 1)
	player:SetAttribute("Elevating", true)
	hrp.Anchored = true

	local c = from.Center.Position
	local startY, endY = c.Y - 0.1, to.Center.Position.Y - 0.1
	local hip = hipHeight(character)
	local platform = Instance.new("Part")
	platform.Name = "Lift"
	platform.Anchored = true
	platform.Size = Vector3.new(7, 1, 7)
	platform.Material = Enum.Material.Neon
	platform.Color = TowerThemes.forFloor(fromIndex + 1).lift
	platform.Position = Vector3.new(c.X, startY - 0.4, c.Z)
	local glow = Instance.new("PointLight")
	glow.Color = platform.Color
	glow.Range = 20
	glow.Brightness = 3
	glow.Parent = platform
	platform.Parent = workspace

	local hatch = to:FindFirstChild("Hatch")
	if hatch then
		hatch.CanCollide = false
		hatch.Transparency = 1
	end

	local t0 = os.clock()
	while true do
		local t = math.min(1, (os.clock() - t0) / LIFT_SECONDS)
		local eased = t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2
		local y = startY + (endY - startY) * eased
		platform.Position = Vector3.new(c.X, y - 0.4, c.Z)
		if character.Parent then
			character:PivotTo(CFrame.lookAt(Vector3.new(c.X, y + hip, c.Z), Vector3.new(c.X, y + hip, c.Z - 1)))
		end
		if t >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end

	if hatch then
		hatch.CanCollide = true
		hatch.Transparency = 0.45
	end
	platform:Destroy()
	if hrp.Parent then
		hrp.Anchored = false
	end
	player:SetAttribute("Elevating", false)

	local next = floors[fromIndex + 1]
	if next.rest then
		local theme = TowerThemes.forFloor(fromIndex)
		Notify:FireClient(
			player,
			("You conquered the %s, the tower's %s stage! Floor %s: more floors are coming soon."):format(theme.name, theme.stage, next.label),
			"success"
		)
	else
		Notify:FireClient(player, ("Floor %s%s"):format(next.label, next.boss and "  ·  BOSS" or ""), "info")
	end
end

function DungeonService.init()
	-- hub portal
	local portal = workspace.Map.Hub:WaitForChild("DungeonPortal")
	NPC.prompt(portal.PrimaryPart, "Enter Dungeon", "Dark Tower", 18).Triggered:Connect(DungeonService.enter)

	for i, f in floors do
		local r = room(i)
		if not r then
			continue
		end
		-- exit portal on every floor
		local exit = r:FindFirstChild("ExitPortal")
		if exit then
			NPC.prompt(exit, "Leave Dungeon", "Exit", 10).Triggered:Connect(DungeonService.leave)
		end
		-- the floor's trainer
		local trainer = r:FindFirstChild("Trainer")
		if trainer and not f.rest then
			-- unique spooky look per trainer; a styling error must never break the tower
			local styled, styleErr = pcall(DungeonNPCStyler.apply, trainer, f.trainer, i)
			if not styled then
				warn("DungeonService: couldn't style", f.trainer, styleErr)
			end
			NPC.prompt(trainer.PrimaryPart, "Battle", f.trainer, 14).Triggered:Connect(function(player)
				if BattleService.isInBattle(player) or player:GetAttribute("Elevating") then
					return
				end
				local current = player:GetAttribute("DungeonFloor") or 1
				if current > i then
					NPC.say(trainer, "You already beat me! Ride the lift up.", 3)
					return
				elseif current < i then
					return
				end
				local intro = f.boss and ("BOSS BATTLE! %s blocks the way!"):format(f.trainer) or ("%s challenges you!"):format(f.trainer)
				BattleService.startTrainer(player, {
					name = f.trainer, team = f.team, kind = "dungeon", floor = i, intro = intro, boss = f.boss,
					reward = { coins = f.coins, xp = f.xp },
					place = { center = r.Center.Position - Vector3.new(0, 0.1, 0), look = Vector3.new(0, 0, -1) },
				})
			end)
		end
	end

	BattleService.onEnded(function(player, b, result)
		if not (b.isTrainer and b.trainer.kind == "dungeon") then
			return
		end
		local f = floors[b.trainer.floor]
		if result == "won" then
			b.dungeonWon = true
			if f.boss then
				local theme = TowerThemes.forFloor(b.trainer.floor)
				Notify:FireAllClients(
					("%s defeated %s and conquered the %s, the Dark Tower's %s stage!"):format(player.DisplayName, f.trainer, theme.name, theme.stage),
					"announce"
				)
			end
		elseif result == "lost" then
			b.dungeonLost = true
		end
	end)

	BattleService.onReleased(function(player, b)
		if b.dungeonWon then
			ride(player, b.trainer.floor)
		elseif b.dungeonLost then
			-- defeated: off to the Healing Center (your floor progress is kept)
			local nurse = workspace.Map.Hub.HealingCenter:FindFirstChild("Nurse")
			local character = player.Character
			if nurse and character then
				local p = nurse.PrimaryPart.Position
				local stand = Vector3.new(p.X, 3.6, p.Z + 9)
				streamTo(player, stand)
				character:PivotTo(CFrame.lookAt(stand, Vector3.new(p.X, 3.6, p.Z)))
			end
			player:SetAttribute("InDungeon", false)
			Notify:FireClient(player, "You were defeated in the tower. Heal up and try again!", "fail")
		end
	end)
end

return DungeonService

--[[
	RouteTrainerService: the three trainers in the later part of every area (GameData.RouteTrainers).
	Walk into a trainer's line of sight (straight in front of them, up to SIGHT studs) and they spot
	you: a "!" pops up, they call out, and the battle starts. No running. You can also talk to them.
	Beat one and it stays beaten (saved). Lose and you're taken to the Healing Center.
	Trainers don't challenge you mid-tutorial, without a healthy creature, or right after a loss.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local BattleService = require(script.Parent.BattleService)
local BaseManager = require(script.Parent.BaseManager)
local PlayerData = require(script.Parent.PlayerData)
local NPC = require(script.Parent.NPC)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local RouteTrainerService = {}

local SIGHT = 26      -- how far ahead they see
local HALF_WIDTH = 66  -- their line of sight covers the whole route width (lanes are 130 wide), so you can't sneak past
local COOLDOWN = 20    -- seconds before the same trainer can spot you again (after a loss)

local byId = {}
local busy = {} -- [Player] = true while a challenge is starting
local cooldown = {} -- [Player] = { [id] = os.clock() }

local function reward(t)
	local total = 0
	for _, e in t.team do
		total += e[2]
	end
	local avg = total / #t.team
	return { coins = math.floor(10 + avg * 4), xp = math.floor(avg * 8) }
end

-- "!" over the trainer's head
local function exclaim(model: Model)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Spotted"
	bb.Size = UDim2.fromOffset(60, 60)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(220, 40, 40)
	l.Text = "!"
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.3, 0)
	c.Parent = l
	l.Parent = bb
	bb.Parent = head
	task.delay(1.6, function()
		bb:Destroy()
	end)
end

local function canChallenge(player: Player, t): boolean
	if busy[player] or BattleService.isInBattle(player) or player:GetAttribute("InDialogue") then
		return false
	end
	if player:GetAttribute("TutorialStep") ~= "done" or PlayerData.hasBeatenTrainer(player, t.id) then
		return false
	end
	if not GameData.canEnter(t.lane, player:GetAttribute("Badges") or 0, (player:GetAttribute("Stat_leagueWins") or 0) > 0) then
		return false
	end
	if not BaseManager.firstHealthy(player) then
		return false
	end
	local last = cooldown[player] and cooldown[player][t.id]
	return not last or os.clock() - last > COOLDOWN
end

local function challenge(player: Player, t, model: Model)
	busy[player] = true
	cooldown[player] = cooldown[player] or {}
	cooldown[player][t.id] = os.clock()
	exclaim(model)
	NPC.say(model, t.intro, 3)
	-- hold the player in place for a moment, like being spotted
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true
	end
	task.wait(1.4)
	if hrp and hrp.Parent then
		hrp.Anchored = false
	end
	if player.Parent then
		BattleService.startTrainer(player, {
			name = t.name, team = t.team, kind = "route", trainerId = t.id, noRun = true,
			intro = ("%s wants to battle!"):format(t.name), reward = reward(t),
		})
	end
	busy[player] = nil
end

function RouteTrainerService.init()
	local folder = workspace:WaitForChild("Map"):WaitForChild("RouteTrainers")
	local models = {}
	for _, t in GameData.RouteTrainers do
		byId[t.id] = t
		local model = folder:FindFirstChild(t.id)
		if model and model.PrimaryPart then
			models[t.id] = model
			-- the model is the source of truth: if the data and the model ever drift apart (like when the
			-- lanes were lengthened), line of sight still starts where the trainer actually stands
			local p = model.PrimaryPart.Position
			if math.abs(p.Z - t.z) > 2 or math.abs(p.X - t.x) > 2 then
				warn(("RouteTrainerService: %s data (%d, %d) didn't match its model (%d, %d); using the model"):format(t.id, t.x, t.z, p.X, p.Z))
				t.x, t.z = p.X, p.Z
			end
			NPC.prompt(model.PrimaryPart, "Talk", t.name, 10).Triggered:Connect(function(player)
				if PlayerData.hasBeatenTrainer(player, t.id) then
					NPC.say(model, t.after, 3)
				elseif canChallenge(player, t) then
					challenge(player, t, model)
				elseif not BaseManager.firstHealthy(player) then
					NPC.say(model, "Your team looks tired. Heal up, then come battle me!", 3)
				end
			end)
		else
			warn("RouteTrainerService: missing model for", t.id)
		end
	end

	-- line of sight: each trainer looks along -Z (toward the hub)
	task.spawn(function()
		while true do
			task.wait(0.35)
			for _, player in Players:GetPlayers() do
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if hrp and not busy[player] then
					local pos = hrp.Position
					for id, model in models do
						local t = byId[id]
						local ahead = t.z - pos.Z
						-- same lane only, anywhere across it
						local laneX = workspace.Map.Lanes[t.lane].Position.X
						if ahead > -4 and ahead < SIGHT and math.abs(pos.X - laneX) < HALF_WIDTH and math.abs(pos.Y - model.PrimaryPart.Position.Y) < 12 then
							if canChallenge(player, t) then
								task.spawn(challenge, player, t, model)
								break
							end
						end
					end
				end
			end
		end
	end)

	BattleService.onEnded(function(player, b, result)
		if not (b.isTrainer and b.trainer.kind == "route") then
			return
		end
		local t = byId[b.trainer.trainerId]
		if result == "won" and t then
			if (player:GetAttribute("BeatenTrainers") or "[]") == "[]" then
				require(script.Parent.TutorialService).logFunnel(player, 4, "First route trainer")
			end
			PlayerData.markTrainerBeaten(player, t.id)
			local model = models[t.id]
			if model then
				task.delay(3, function()
					NPC.say(model, t.after, 4)
				end)
			end
		elseif result == "lost" then
			b.routeLost = true
		end
	end)

	-- lost: off to the Healing Center
	BattleService.onReleased(function(player, b)
		if not b.routeLost then
			return
		end
		-- (Main sends a wiped-out player to their last heal spot)
		Notify:FireClient(player, "You were defeated! Heal your team and try again.", "fail")
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		cooldown[player] = nil
	end)
end

return RouteTrainerService

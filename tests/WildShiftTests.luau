-- Run the returned function in a single-player Studio Play SERVER session.
-- Creates disposable sentinels, performs one shift, and refills Lane1.
return function()
	local RunService = game:GetService("RunService")
	assert(RunService:IsStudio() and RunService:IsRunning() and RunService:IsServer(), "Use a Studio Play server")
	local players = game:GetService("Players"):GetPlayers()
	assert(#players == 1, "Use one local test player")
	local root = players[1].Character and players[1].Character:FindFirstChild("HumanoidRootPart")
	assert(root, "Wait for the test character")
	local spawner = require(game.ServerScriptService.Modules.WildSpawner)
	local data = require(game.ReplicatedStorage.Shared.GameData)
	local folder = workspace:FindFirstChild("WildCreatures")
	local oldHotZone = spawner.getHotZone()
	local created, checks = {}, 0
	local function check(value, label)
		assert(value, label)
		checks += 1
	end
	local function sentinel(distance, attrs, parent)
		local model = Instance.new("Model")
		model.Name = "WildShiftTestSentinel"
		local part = Instance.new("Part")
		part.Size = Vector3.new(1, 1, 1)
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Parent = model
		model.PrimaryPart = part
		model:PivotTo(CFrame.new(root.Position + Vector3.new(distance, 0, 0)))
		for name, value in attrs or {} do
			model:SetAttribute(name, value)
		end
		model.Parent = parent or folder
		table.insert(created, model)
		return model
	end
	local report
	local ok, err = xpcall(function()
		local near = sentinel(59)
		local boundary = sentinel(60)
		local far = sentinel(61)
		local battle = sentinel(500, { InBattle = true })
		local tutorial = sentinel(500, { TutorialOwner = players[1].UserId })
		local rare = sentinel(500, { RareEvent = true })
		local caught = sentinel(500, { Caught = true })
		local otherFolder = Instance.new("Folder")
		otherFolder.Name = "WildShiftTestSeparateEventFolder"
		otherFolder.Parent = workspace
		table.insert(created, otherFolder)
		local event = sentinel(500, nil, otherFolder)
		check(not spawner.canReplace(near), "59-stud creature protected")
		check(not spawner.canReplace(boundary), "60-stud boundary protected")
		check(spawner.canReplace(far), "61-stud creature eligible")
		for _, model in { battle, tutorial, rare, caught, event } do
			check(not spawner.canReplace(model), "Special/battle/event creature protected")
		end
		local removed = spawner.shift()
		check(removed >= 1 and not far.Parent, "Shift removed distant ordinary sentinel")
		for _, model in { near, boundary, battle, tutorial, rare, caught, event } do
			check(model.Parent ~= nil, "Shift retained protected sentinel")
		end
		local function sample(lane)
			local result = { shiny = 0, Large = 0, Huge = 0 }
			for _ = 1, 100000 do
				local shiny, size = spawner.rollVariant(lane)
				if shiny then result.shiny += 1 end
				if result[size] ~= nil then result[size] += 1 end
			end
			return result
		end
		spawner.setHotZone("Lane1")
		local normal, hot = sample("Lane3"), sample("Lane1")
		check(hot.shiny > normal.shiny * 2 and hot.shiny < normal.shiny * 4, "Hot Zone shiny rate about 3x base")
		check(hot.Large > normal.Large and hot.Huge > normal.Huge, "Hot Zone boosts Large and Huge")
		spawner.setHotZone(nil)
		check(spawner.getHotZone() == nil, "Hot Zone can be cleared")
		local reset = sample("Lane1")
		check(reset.shiny < hot.shiny * 0.6, "Clearing Hot Zone removes shiny boost")
		local lane = workspace.Map.Lanes:FindFirstChild("Lane1")
		if lane and lane:GetAttribute("Unlocked") then
			spawner.spawnLane("Lane1")
			check(spawner.countLane("Lane1") == data.WildPerLane, "Lane fills vacant slots")
			spawner.spawnLane("Lane1")
			check(spawner.countLane("Lane1") == data.WildPerLane, "Repeated fill cannot double lane population")
		end
		report = { checks = checks, removed = removed, per100000 = { normal = normal, hot = hot, afterClear = reset } }
	end, debug.traceback)
	for _, object in created do
		if object.Parent then object:Destroy() end
	end
	spawner.setHotZone(oldHotZone)
	if not ok then error(err) end
	return report
end

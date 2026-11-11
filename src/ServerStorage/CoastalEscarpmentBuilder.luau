-- Additive reverse-face terrain sculpt. Never removes the hub screen or arena models.
local Builder = {}
local TERRAIN_MIN = Vector3int16.new(-160, -12, -180)

function Builder.build()
	assert(game:GetService("RunService"):IsStudio() and game.PlaceId == 94034385545160, "Cloud test place only")
	assert(game.ServerStorage.Backups:FindFirstChild("RidgeBase_PreBuild"), "Back up terrain first")
	if workspace.Map:FindFirstChild("CoastalEscarpment") then return false end
	-- Replaced by part-built Map.Mountains.Coast (MountainPartBuilder); never sculpt terrain over it.
	local mountains = workspace.Map:FindFirstChild("Mountains")
	if mountains and mountains:FindFirstChild("Coast") then return false end
	local terrain = workspace.Terrain
	-- Overlapping, irregular buttresses blend the old Z=-480 cut face into a broad coastline.
	-- All fills stay inside the copied terrain region and south of the hub-facing mass.
	for x = -500, 900, 56 do
		local wave = math.sin(x * 0.019)
		local radius = 72 + 7 * math.cos(x * 0.033)
		terrain:FillBall(Vector3.new(x, 12, -550 + wave * 12), radius, Enum.Material.Basalt)
		terrain:FillBall(Vector3.new(x, 90 + wave * 9, -509), 77, Enum.Material.Sandstone)
		terrain:FillBall(Vector3.new(x, 159 + wave * 12, -483), 59, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(x, 204 + wave * 9, -480), 28, Enum.Material.Grass)
		task.wait()
	end
	local marker = Instance.new("Folder")
	marker.Name = "CoastalEscarpment"
	marker:SetAttribute("Version", 1)
	marker:SetAttribute("Backup", "ServerStorage.Backups.RidgeBase_PreBuild.SouthernRidgeTerrain")
	marker.Parent = workspace.Map
	local cleared = game.ServerStorage.Backups.RidgeBase_PreBuild:FindFirstChild("ClearedBaseSurroundings")
	local tree = cleared and cleared:FindFirstChild("OakTree")
	if tree then
		local params = RaycastParams.new()
		params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { terrain }
		for _, x in { -360, -140, 100, 360, 620, 840 } do
			local hit = workspace:Raycast(Vector3.new(x, 300, -492), Vector3.new(0, -160, 0), params)
			if hit then
				local shrub = tree:Clone()
				shrub.Name = "CoastalRimTree"
				shrub:ScaleTo(shrub:GetScale() * 0.5)
				local cf, size = shrub:GetBoundingBox()
				shrub:PivotTo(shrub:GetPivot() + Vector3.new(x - cf.Position.X, hit.Position.Y + size.Y / 2 - cf.Position.Y, -492 - cf.Position.Z))
				shrub.Parent = marker
			end
		end
	end
	game:GetService("ChangeHistoryService"):SetWaypoint("Coastal escarpment built")
	return true
end

function Builder.restore()
	assert(game:GetService("RunService"):IsStudio() and game.PlaceId == 94034385545160, "Cloud test place only")
	local backup = game.ServerStorage.Backups.RidgeBase_PreBuild.SouthernRidgeTerrain
	workspace.Terrain:PasteRegion(backup, TERRAIN_MIN, true)
	local marker = workspace.Map:FindFirstChild("CoastalEscarpment")
	if marker then marker:Destroy() end
	return true
end

return Builder

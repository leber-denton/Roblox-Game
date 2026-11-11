--[[
	NPCAnimator: plays Roblox's standard R15 idle animation (owned by Roblox, free for any game)
	on every NPC, with a random start point so they don't all breathe in sync.
]]

local IDLE = { "rbxassetid://507766666", "rbxassetid://507766951" }

local function animate(model: Model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or not model:GetAttribute("R15") or model:GetAttribute("Animated") then
		return
	end
	model:SetAttribute("Animated", true)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local anim = Instance.new("Animation")
	anim.AnimationId = IDLE[math.random(1, #IDLE)]
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		track:Play(0.2)
		task.defer(function()
			if track.Length > 0 then
				track.TimePosition = math.random() * track.Length
			end
		end)
	end
end

for _, d in workspace:GetDescendants() do
	if d:IsA("Humanoid") and d.Parent:IsA("Model") then
		task.spawn(animate, d.Parent)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then
		task.defer(animate, d.Parent)
	end
end)

-- CQ_WORLD_POLISH_BEGIN
-- Idempotent in edit mode and at server start. Kept scenery is archived, never destroyed.
local function buildQuestWorld()
	local map = workspace:WaitForChild("Map")
	local Lighting = game:GetService("Lighting")
	local ServerStorage = game:GetService("ServerStorage")
	local GameData = require(game:GetService("ReplicatedStorage").Shared.GameData)
	-- Route corridors (every lane's RegionPaths bounds, x +-136 of the lane centre): decor inside them is
	-- never thinned by trim() below. Was Meadow only; every route is dressed to Meadow's density now
	-- (Overhaul Phase 2, RegionStyle). Only scenery behind the ridges (136-190 studs out) is still thinned.
	local ROUTE_CORRIDOR_MAX_ABS_X = 136
	Lighting.FogStart, Lighting.FogEnd = 600, 1500
	Lighting.FogColor = Color3.fromRGB(164, 191, 204)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then atmosphere = Instance.new("Atmosphere"); atmosphere.Parent = Lighting end
	atmosphere.Density, atmosphere.Haze = 0.28, 2.1
	atmosphere.Color = Color3.fromRGB(194, 212, 225)
	if map:FindFirstChild("WorldPolish") then return end
	local root = Instance.new("Folder"); root.Name = "WorldPolish"; root.Parent = map
	local archive = ServerStorage:FindFirstChild("WorldPolishArchive") or Instance.new("Folder")
	archive.Name = "WorldPolishArchive"; archive.Parent = ServerStorage
	local function part(parent, name, size, pos, color, material, collide)
		local p = Instance.new("Part"); p.Name = name; p.Size = size; p.Position = pos
		p.Anchored = true; p.Color = color; p.Material = material or Enum.Material.Slate
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = collide ~= false; p.Parent = parent; return p
	end
	local function label(p, text, face)
		local gui = Instance.new("SurfaceGui"); gui.Face = face or Enum.NormalId.Front; gui.CanvasSize = Vector2.new(800, 240); gui.Parent = p
		local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1,1); t.BackgroundTransparency = 1
		t.Text = text; t.Font = Enum.Font.FredokaOne; t.TextScaled = true; t.TextColor3 = Color3.fromRGB(255,244,211); t.Parent = gui
	end
	local stone = Color3.fromRGB(61,70,87)
	-- Battle Coliseum and Trade Center: no runtime shell any more (Overhaul Phase 5). Both are enclosed by
	-- their own Rojo-synced builds, Map.Coliseum.RomanShell (velarium roof, tools/gen_coliseum.py) and
	-- Map.TradePlaza.SunDome plus Map.TradePlazaBeach (tools/gen_trade_beach.py). The old StadiumShell and
	-- MarketHall boxes hid both. The arena sand keeps its warm colour.
	local arena = map:FindFirstChild("Coliseum")
	local arenaFloor = arena and arena:FindFirstChild("ArenaFloor")
	if arenaFloor then arenaFloor.Material = Enum.Material.Sand; arenaFloor.Color = Color3.fromRGB(211,181,119) end
	-- Continuous divider: the narrower foot stays between the route footprints.
	local mountains=Instance.new("Folder"); mountains.Name="MountainDivider"; mountains.Parent=root
	part(mountains,"SolidMountainSpine",Vector3.new(100,180,4550),Vector3.new(257,65,2525),Color3.fromRGB(101,112,126),Enum.Material.Rock)
	for i=0,29 do
		local z=310+i*151; local h=185+(i*37)%105
		local peak=Instance.new("WedgePart");peak.Name="SnowRidge";peak.Size=Vector3.new(105,h,190);peak.Anchored=true;peak.Material=Enum.Material.Rock
		peak.Color=Color3.fromRGB(113,126,143);peak.CFrame=CFrame.new(257,85+h/2,z)*CFrame.Angles(0,i%2*math.pi,0);peak.Parent=mountains
		local snow=Instance.new("WedgePart");snow.Name="SnowCap";snow.Size=Vector3.new(107,h*0.3,60);snow.Anchored=true;snow.Material=Enum.Material.Snow;snow.Color=Color3.fromRGB(231,239,246)
		snow.CFrame=peak.CFrame*CFrame.new(0,h*0.35,-65);snow.Parent=mountains
	end
	-- Natural coast, thin Terrain water ring and a horizon which fades into the fog.
	local coast=Instance.new("Folder");coast.Name="Coastline";coast.Parent=root
	local terrain=workspace.Terrain
	terrain.WaterColor=Color3.fromRGB(41,112,150);terrain.WaterTransparency=0.26;terrain.WaterWaveSize=0.2
	for _,box in {
		{Vector3.new(-635,-12,2200),Vector3.new(830,12,6200)},
		{Vector3.new(1165,-12,2200),Vector3.new(830,12,6200)},
		{Vector3.new(265,-12,-610),Vector3.new(970,12,580)},
		{Vector3.new(265,-12,5260),Vector3.new(970,12,720)},
	} do terrain:FillBlock(CFrame.new(box[1]),box[2],Enum.Material.Water) end
	for i=0,53 do
		local z=180+i*90
		for _,x in {-219,754} do
			part(coast,"CoastalCliff",Vector3.new(26,13+(i%3)*2,94),Vector3.new(x,-5,z),Color3.fromRGB(104,108,105),Enum.Material.Rock)
			part(coast,"Beach",Vector3.new(19,1.2,94),Vector3.new(x+(x<0 and -17 or 17),-4.8,z),Color3.fromRGB(211,196,143),Enum.Material.Sand)
		end
	end
	for i=1,6 do
		local x=i%2==0 and -510 or 1060
		local island=part(coast,"DistantIsland",Vector3.new(90,23,120),Vector3.new(x,3,450+i*660),Color3.fromRGB(72,108,94),Enum.Material.Grass)
		island.Shape=Enum.PartType.Ball
	end
	-- Keep landmark assemblies; thin repeated decoration into three short scenes per route.
	local decor=map:FindFirstChild("Decor")
	local removed=0
	local function archiveObject(d)
		d:SetAttribute("OriginalPath",d:GetFullName()); d.Parent=archive; removed+=1
	end
	local function trim(folder)
		for _,d in folder:GetChildren() do
			if d:IsA("Folder") then trim(d)
			elseif d:IsA("Model") or d:IsA("BasePart") then
				local cf,size
				if d:IsA("Model") then cf,size=d:GetBoundingBox() else cf,size=d.CFrame,d.Size end
				local p=cf.Position; local center=p.X>230 and 460 or 0
				local route=p.Z>310 and p.Z<4390 and math.abs(p.X-center)<190
				local inRouteCorridor=math.abs(p.X-center)<ROUTE_CORRIDOR_MAX_ABS_X
				local functional=d:FindFirstChildWhichIsA("ProximityPrompt",true) or d:FindFirstChildWhichIsA("Humanoid",true)
				local protected=d.Name:lower():find("path") or d.Name:lower():find("pier") or d.Name:lower():find("arch") or d.Name:lower():find("volcano") or d.Name:lower():find("cave")
				if route and not inRouteCorridor and not functional and not protected and math.max(size.X,size.Y,size.Z)<65 then
					local phase=(p.Z-(center==0 and 250 or 300))%174
					if math.abs(p.X-center)<25 or phase>58 then archiveObject(d) end
				end
			end
		end
	end
	if decor then trim(decor) end
	root:SetAttribute("ArchivedDecorAssemblies",removed)
	-- Gate ridges between routes. The roads themselves are terrain now (RegionPaths / RegionTerrainBuilder,
	-- Overhaul Phase 2), so the old painted WindingPath and the two GateBaffle slabs that blocked every
	-- road past its gate are gone. Ridges take the route's RegionStyle palette.
	local routes=Instance.new("Folder");routes.Name="RoutePassages";routes.Parent=root
	local okStyle,RegionStyle=pcall(function() return require(game:GetService("ReplicatedStorage").Shared.RegionStyle) end)
	for _,region in GameData.Regions do
		local lane=map.Lanes:FindFirstChild(region.lane)
		if not lane then continue end
		local start=lane.Position.Z-lane.Size.Z/2
		local gate=map.Gates:FindFirstChild("Gate_"..region.lane)
		if not gate then for _,g in map.Gates:GetChildren() do if g:GetAttribute("Lane")==region.lane then gate=g;break end end end
		local gz=gate and gate.Position.Z or start
		local x=lane.Position.X
		local theme=okStyle and RegionStyle.lanes[region.lane]
		if gate then
			local ridgeColor=theme and theme.palette.trim:Lerp(stone,0.5) or stone
			for _,dx in {-140,140} do part(routes,"GateRidge",Vector3.new(150,82,27),Vector3.new(x+dx,40,gz+5),ridgeColor) end
			part(routes,"GateCanopy",Vector3.new(130,14,28),Vector3.new(x,82,gz+5),theme and theme.palette.primary or Color3.fromRGB(79,107,90),Enum.Material.Grass)
		end
	end
	-- Town's cross road ends at its two buildings, with gardens at the endpoints.
	local town=map:FindFirstChild("SummitTown")
	if town then
		local p=town:FindFirstChild("Plaza")
		if p then p.Size=Vector3.new(270,p.Size.Y,p.Size.Z);p.Position=Vector3.new(460,p.Position.Y,p.Position.Z) end
		for _,x in {312,608} do
			part(routes,"TownPlanter",Vector3.new(12,3,32),Vector3.new(x,2,280),Color3.fromRGB(92,108,92),Enum.Material.Slate)
			local crown=part(routes,"TownGarden",Vector3.new(10,6,28),Vector3.new(x,6,280),Color3.fromRGB(67,133,91),Enum.Material.Grass);crown.Shape=Enum.PartType.Ball
		end
	end
	-- Give the long connector a destination off its center: a coastal lookout.
	local lookout=Instance.new("Folder");lookout.Name="CoastalLookout";lookout.Parent=root
	part(lookout,"Deck",Vector3.new(54,2,40),Vector3.new(402,1,80),Color3.fromRGB(131,107,73),Enum.Material.WoodPlanks)
	part(lookout,"LookoutPath",Vector3.new(42,0.3,9),Vector3.new(435,0.5,80),Color3.fromRGB(150,128,91),Enum.Material.WoodPlanks)
	for _,x in {376,428} do part(lookout,"Rail",Vector3.new(2,5,40),Vector3.new(x,4,80),Color3.fromRGB(82,71,54),Enum.Material.Wood) end
	part(lookout,"Rail",Vector3.new(54,5,2),Vector3.new(402,4,99),Color3.fromRGB(82,71,54),Enum.Material.Wood)
	label(part(lookout,"LookoutSign",Vector3.new(24,6,1),Vector3.new(402,8,61),Color3.fromRGB(43,86,101),Enum.Material.Wood),"COASTAL LOOKOUT")
	-- One readable gate sign; stop gym labels showing through several regions.
	for _,d in map:GetDescendants() do
		if d:IsA("BillboardGui") then
			local a=d.Parent;local gym=false
			while a and a~=map do if a.Name:find("Gym") then gym=true;break end;a=a.Parent end
			if gym then d.MaxDistance=80 end
		elseif d:IsA("SurfaceGui") and d.Parent and d.Parent:IsA("BasePart") then
			if d.Face==Enum.NormalId.Top and d.Parent:IsDescendantOf(map.Lanes) then d.Enabled=false end
		elseif d:IsA("TextLabel") or d:IsA("TextButton") then
			d.Text=d.Text:gsub("Maple Victory Road",GameData.VictoryRoads.League):gsub("Summit Victory Road",GameData.VictoryRoads.League2)
		end
	end
	root:SetAttribute("Complete",true)
end
buildQuestWorld()
-- CQ_WORLD_POLISH_END

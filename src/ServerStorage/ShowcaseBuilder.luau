--[[
	ShowcaseBuilder: builds Workspace.ShowcaseArea, a far-away grid of every model type in the game,
	grouped by category with a header per section and a label above each model.
	Safe to re-run: it only destroys and rebuilds Workspace.ShowcaseArea. Source models are never touched.
	Showcase models are CLONES (not Packages), so editing one does not update the others.
	What goes in each section comes from ServerStorage.ModelSyncLookup (plus Workspace.ModelGallery trainers).
	Models are made inert (anchored, scripts off, tags removed); the original anchoring, script state and
	tags are saved as Showcase* attributes so ModelSync.apply can restore them on the real copies.
	Run in Studio's command bar:  require(game.ServerStorage.ShowcaseBuilder).build()
]]

local CollectionService = game:GetService("CollectionService")

local Lookup = require(script.Parent:WaitForChild("ModelSyncLookup"))

local ShowcaseBuilder = {}
ShowcaseBuilder.FORMAT = 2 -- ModelSync refuses showcases built with another format

-- Sits where the old ModelGallery is (its platform spans X -3065..-2785, top at Y 51, Z -20..20).
-- The grid starts at the gallery's west edge and runs south (+Z) from just past the gallery platform.
ShowcaseBuilder.ORIGIN = Vector3.new(-3045, 51, 60)
local COLUMNS = 8
local GAP_X = 20 -- clear studs between neighbouring models on X
local GAP_Z = 25 -- clear studs between rows on Z
local SECTION_GAP = 60 -- clear studs between category sections

local SAFE_SERVICES = {
	Workspace = true,
	ServerStorage = true,
	ReplicatedStorage = true,
	ServerScriptService = true,
	ReplicatedFirst = true,
	StarterPack = true,
	StarterGui = true,
	StarterPlayer = true,
	Lighting = true,
}

local function resolve(path)
	local first, rest = path:match("^([^%.]+)%.?(.*)$")
	if not first or not SAFE_SERVICES[first] then
		return nil
	end
	local node = game:FindFirstChild(first)
	for part in rest:gmatch("[^%.]+") do
		node = node and node:FindFirstChild(part)
	end
	return node
end

-- First copy named `name` under the root, directly inside a Folder (stable order by full name).
local function firstPropCopy(name, rootPath)
	local root = resolve(rootPath)
	if not root then
		return nil
	end
	local best
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == name and d:IsA("Model") and d.Parent:IsA("Folder") then
			if not best or d:GetFullName() < best:GetFullName() then
				best = d
			end
		end
	end
	return best
end

local function sourceOf(name, e)
	if e.source then
		return resolve(e.source)
	end
	if e.map and e.map[1] then
		return resolve(e.map[1])
	end
	if e.template then
		return resolve(e.template)
	end
	if e.byName then
		return firstPropCopy(name, e.byName)
	end
	return nil
end

-- Workspace.ModelGallery trainers are version comparisons: reference-only in ModelSync.
local function galleryTrainers(list)
	local gallery = workspace:FindFirstChild("ModelGallery")
	if gallery then
		for _, c in ipairs(gallery:GetChildren()) do
			if c:IsA("Model") and not c.Name:find("Lumifawn") then
				table.insert(list, { name = c.Name, src = c })
			end
		end
	end
end

-- Returns { {name=, items={ {name=, src=} }} } and the names whose source could not be found.
local function categories()
	local byCat, missing = {}, {}
	for _, cat in ipairs(Lookup.CATEGORY_ORDER) do
		byCat[cat] = {}
	end
	for name, e in pairs(Lookup.entries) do
		local src = sourceOf(name, e)
		if src then
			table.insert(byCat[e.category], { name = name, src = src })
		else
			table.insert(missing, name)
		end
	end
	galleryTrainers(byCat.TRAINERS)
	local result = {}
	for _, cat in ipairs(Lookup.CATEGORY_ORDER) do
		table.insert(result, { name = cat, items = byCat[cat] })
	end
	table.sort(missing)
	return result, missing
end

local function mkPart(parent, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Anchored = name, size, cf, true
	p.Color, p.Material, p.CanCollide = color or Color3.fromRGB(40, 42, 55), Enum.Material.SmoothPlastic, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Floating name tag. adornee is the specific model/part it belongs to; the tag is a BillboardGui parented
-- to that instance and offset in world space above it, so it can only ever appear over its own model.
local function label(parent, text, adornee, offsetY, big)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = adornee
	gui.Size = big and UDim2.fromOffset(520, 90) or UDim2.fromOffset(200, 36)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = big and 400 or 120
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	t.Text, t.TextScaled, t.Font = text, true, Enum.Font.GothamBold
	t.TextColor3, t.TextStrokeTransparency = Color3.new(1, 1, 1), 0.3
	t.Parent = gui
	return gui
end

local function extents(inst)
	if inst:IsA("Model") then
		return inst:GetExtentsSize()
	end
	return inst.Size
end

local function prepare(clone)
	local all = { clone }
	for _, d in ipairs(clone:GetDescendants()) do
		table.insert(all, d)
	end
	for _, d in ipairs(all) do
		-- remember what we change so ModelSync can undo it on the real copies
		local tags = CollectionService:GetTags(d)
		if #tags > 0 then
			d:SetAttribute("ShowcaseTags", table.concat(tags, "\n"))
			for _, tag in ipairs(tags) do
				CollectionService:RemoveTag(d, tag)
			end
		end
		if d:IsA("BasePart") then
			if not d.Anchored then
				d:SetAttribute("ShowcaseUnanchored", true)
			end
			d.Anchored = true
		elseif d:IsA("BaseScript") then
			if d.Enabled then
				d:SetAttribute("ShowcaseEnabled", true)
			end
			d.Enabled = false
		end
	end
end

function ShowcaseBuilder.build()
	local old = workspace:FindFirstChild("ShowcaseArea")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ShowcaseArea"
	root:SetAttribute("ShowcaseFormat", ShowcaseBuilder.FORMAT)
	root.Parent = workspace

	local cursorZ = 0 -- start of the next section, advanced after every section
	local counts = {}
	local cats, missing = categories()
	for _, cat in ipairs(cats) do
		local items = cat.items
		table.sort(items, function(a, b)
			return a.name < b.name
		end)
		-- one cell size per section, from its largest model, plus the required gaps
		local maxX, maxZ = 8, 8
		for _, it in ipairs(items) do
			local e = extents(it.src)
			maxX, maxZ = math.max(maxX, e.X), math.max(maxZ, e.Z)
		end
		local cellX, cellZ = maxX + GAP_X, maxZ + GAP_Z
		local rows = math.max(1, math.ceil(#items / COLUMNS))
		local folder = Instance.new("Folder")
		folder.Name = cat.name
		folder.Parent = root

		local firstRowZ = cursorZ + 40 -- header sits 40 studs ahead of the first row
		local width = cellX * math.min(COLUMNS, #items)
		local floorCenter = ShowcaseBuilder.ORIGIN + Vector3.new(width / 2 - cellX / 2, -1, firstRowZ + (rows - 1) * cellZ / 2)
		mkPart(folder, "Floor", Vector3.new(width + 20, 2, rows * cellZ + 20), CFrame.new(floorCenter))

		local header = mkPart(
			folder,
			"Header",
			Vector3.new(4, 4, 4),
			CFrame.new(ShowcaseBuilder.ORIGIN + Vector3.new(width / 2 - cellX / 2, 30, cursorZ))
		)
		header.Transparency, header.CanCollide = 1, false
		label(header, cat.name .. " (" .. #items .. ")", header, 0, true)

		for i, it in ipairs(items) do
			local col, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
			local pos = ShowcaseBuilder.ORIGIN + Vector3.new(col * cellX, 0, firstRowZ + row * cellZ)
			local ok, clone = pcall(function()
				return it.src:Clone()
			end)
			if ok and clone then
				prepare(clone)
				clone.Name = it.name
				clone.Parent = folder
				-- centre over the cell, bottom resting on the floor top (ORIGIN.Y)
				local bbCF, bbSize
				if clone:IsA("Model") then
					bbCF, bbSize = clone:GetBoundingBox()
				else
					bbCF, bbSize = clone.CFrame, clone.Size
				end
				local target = pos + Vector3.new(0, bbSize.Y / 2, 0)
				clone:PivotTo(clone:GetPivot() + (target - bbCF.Position))
				clone:SetAttribute("ShowcaseSource", it.src:GetFullName())

				-- tag lives inside THIS model, adorned to an invisible anchor at its top centre
				local tagPart = mkPart(clone, "LabelAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(0, bbSize.Y, 0)))
				tagPart.Transparency, tagPart.CanCollide, tagPart.CanQuery, tagPart.CanTouch = 1, false, false, false
				label(tagPart, it.name, tagPart, 2, false)
			end
		end
		counts[cat.name] = #items
		cursorZ = firstRowZ + rows * cellZ + SECTION_GAP
	end

	-- arrival pad in front of the first section
	mkPart(
		root,
		"ArrivalPad",
		Vector3.new(30, 2, 30),
		CFrame.new(ShowcaseBuilder.ORIGIN + Vector3.new(0, -1, -60)),
		Color3.fromRGB(80, 160, 255)
	)
	if #missing > 0 then
		warn("ShowcaseBuilder: source not found for " .. table.concat(missing, ", "))
	end
	return counts, missing
end

function ShowcaseBuilder.arrivalCFrame()
	return CFrame.new(ShowcaseBuilder.ORIGIN + Vector3.new(0, 5, -60))
end

return ShowcaseBuilder

--[[
	DecorUI: the BUILD menu and build mode.
	  Tabs: My Items (place / edit), Shop, Daily, Crates (odds + shards), Themes, Base (upgrades + Coin Jar), Robux
	  Build mode: a see-through preview follows the mouse (or your tap) over your base, green = fits, red = doesn't.
	    PC: R rotate, click to place, Q to cancel, X to put away the item you're moving.
	    Phone/tablet: tap where it goes, then the on-screen Rotate / Place / Cancel buttons.
	Server side: ServerScriptService.Modules.DecorService. Shared rules: ReplicatedStorage.Shared.DecorData.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DecorData = require(Shared:WaitForChild("DecorData"))
local GameData = require(Shared:WaitForChild("GameData"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Decor = Remotes:WaitForChild("Decor")
local DecorSync = Remotes:WaitForChild("DecorSync")
local Teleport = Remotes:WaitForChild("Teleport")
local Items = DecorData.Items

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 215, 80)
local PANEL = Color3.fromRGB(28, 30, 42)
local CARD = Color3.fromRGB(46, 50, 68)
local MUTED = Color3.fromRGB(190, 190, 205)
local GREEN = Color3.fromRGB(55, 165, 85)
local RED = Color3.fromRGB(200, 60, 60)
local BLUE = Color3.fromRGB(70, 130, 220)
local GREY = Color3.fromRGB(80, 80, 92)
local PURPLE = Color3.fromRGB(150, 90, 230)
local ACCENT = Color3.fromRGB(240, 150, 50)

local function new(className: string, props, parent)
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end
local function round(inst, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, inst)
end
local function label(props, parent)
	local p = { BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE }
	for k, v in props do
		p[k] = v
	end
	return new("TextLabel", p, parent)
end
local function button(props, text: string, color: Color3, parent, onClick)
	local p = { BackgroundColor3 = color, Font = FONT, TextScaled = true, TextColor3 = WHITE, Text = text, AutoButtonColor = true }
	for k, v in props do
		p[k] = v
	end
	local b = new("TextButton", p, parent)
	round(b, 10)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local state = nil -- latest decor state from the server
local refreshTab -- set below

local function call(action: string, ...)
	local ok, result, s = Decor:InvokeServer(action, ...)
	if typeof(s) == "table" then
		state = s
	end
	return ok, result
end

local function toast(text: string, kind: string?)
	local ev = player:FindFirstChild("LocalToast")
	if ev and text then
		ev:Fire(text, kind or "info")
	end
end

local function myBase(): Model?
	local bases = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Bases")
	if not bases then
		return nil
	end
	for _, b in bases:GetChildren() do
		if b:GetAttribute("OwnerId") == player.UserId then
			return b
		end
	end
	return nil
end

-- A small 3D preview of an item
local function preview(id: string, parent: GuiObject, size: UDim2, position: UDim2?)
	local vp = new("ViewportFrame", { Size = size, Position = position or UDim2.new(), BackgroundColor3 = Color3.fromRGB(36, 40, 56), Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -2, -1) }, parent)
	round(vp, 10)
	local model = DecorData.build(id)
	if not model then
		return vp
	end
	model.Parent = vp
	local cf, ext = model:GetBoundingBox()
	local radius = math.max(ext.X, ext.Y, ext.Z)
	local cam = new("Camera", { FieldOfView = 40 }, vp)
	local center = cf.Position
	cam.CFrame = CFrame.lookAt(center + Vector3.new(radius * 1.15, radius * 0.9, radius * 1.4), center)
	vp.CurrentCamera = cam
	return vp
end

----------------------------------------------------------------------------------------------
-- window
----------------------------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "DecorUI", ResetOnSpawn = false, DisplayOrder = 9, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false }, player:WaitForChild("PlayerGui"))

local win = new("Frame", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromScale(0.94, 0.8), BackgroundColor3 = PANEL, Visible = false, ZIndex = 5 }, gui)
round(win, 18)
new("UISizeConstraint", { MaxSize = Vector2.new(780, 560) }, win)
new("UIStroke", { Color = ACCENT, Thickness = 3 }, win)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, win)
label({ Size = UDim2.new(0.4, 0, 0, 34), Text = "Base Builder", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ACCENT }, win)
local walletLabel = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -50, 0, 4), Size = UDim2.new(0.5, -50, 0, 28), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GOLD }, win)
button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(40, 40) }, "X", RED, win, function()
	win.Visible = false
end)

local tabsBar = new("Frame", { Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, win)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabsBar)

local content = new("ScrollingFrame", { Position = UDim2.new(0, 0, 0, 92), Size = UDim2.new(1, 0, 1, -124), BackgroundTransparency = 1, ScrollBarThickness = 8, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y }, win)
local status = label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 26), Text = "", TextColor3 = MUTED }, win)

local function setStatus(ok: boolean?, text: string?)
	status.Text = text or ""
	status.TextColor3 = ok and Color3.fromRGB(150, 240, 150) or (ok == false and Color3.fromRGB(255, 140, 140) or MUTED)
end

local currentTab = "Items"
local tabButtons = {}
local TABS = {
	{ key = "Items", text = "My Items", color = ACCENT },
	{ key = "Shop", text = "Shop", color = GREEN },
	{ key = "Daily", text = "Daily", color = Color3.fromRGB(230, 90, 120) },
	{ key = "Crates", text = "Crates", color = PURPLE },
	{ key = "Themes", text = "Themes", color = Color3.fromRGB(40, 165, 160) },
	{ key = "Base", text = "Base", color = BLUE },
	{ key = "Robux", text = "Robux", color = Color3.fromRGB(50, 170, 80) },
}

local function clearContent()
	for _, c in content:GetChildren() do
		if not c:IsA("UIComponent") then
			c:Destroy()
		end
	end
	for _, c in content:GetChildren() do
		c:Destroy()
	end
	content.CanvasPosition = Vector2.zero
end

local function gridLayout()
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 210), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	new("UIPadding", { PaddingRight = UDim.new(0, 10) }, content)
end

local function listLayout()
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	new("UIPadding", { PaddingRight = UDim.new(0, 10) }, content)
end

local function heading(order: number, text: string, color: Color3?)
	return label({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 26), Text = text, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or MUTED }, content)
end

-- One item card: preview, name, rarity / effect line, an action button
local function itemCard(order: number, id: string, sub: string, buttonText: string, buttonColor: Color3, onClick)
	local item = Items[id]
	local rarity = DecorData.Rarities[item.rarity]
	local card = new("Frame", { LayoutOrder = order, BackgroundColor3 = CARD }, content)
	round(card, 12)
	new("UIStroke", { Color = rarity.color, Thickness = 2, Transparency = 0.3 }, card)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, card)
	preview(id, card, UDim2.new(1, 0, 0.5, 0))
	label({ Position = UDim2.fromScale(0, 0.52), Size = UDim2.new(1, 0, 0.12, 0), Text = item.name }, card)
	label({ Position = UDim2.fromScale(0, 0.64), Size = UDim2.new(1, 0, 0.09, 0), Text = item.rarity .. "  ·  " .. DecorData.describe(id), TextColor3 = rarity.color }, card)
	label({ Position = UDim2.fromScale(0, 0.73), Size = UDim2.new(1, 0, 0.08, 0), Text = sub, TextColor3 = MUTED }, card)
	local b = button({ Position = UDim2.fromScale(0, 0.83), Size = UDim2.fromScale(1, 0.17) }, buttonText, buttonColor, card, onClick)
	b.AutoButtonColor = buttonColor ~= GREY
	return card
end

local function placedCount(id: string): number
	local n = 0
	for _, p in state.placed do
		if p.id == id then
			n += 1
		end
	end
	return n
end

----------------------------------------------------------------------------------------------
-- crate reveal
----------------------------------------------------------------------------------------------
local reveal = new("Frame", { Name = "Reveal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(340, 380), BackgroundColor3 = PANEL, Visible = false, ZIndex = 20 }, gui)
round(reveal, 18)
local revealStroke = new("UIStroke", { Thickness = 4, Color = GOLD }, reveal)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, reveal)
local revealHolder = new("Frame", { Size = UDim2.new(1, 0, 0, 220), BackgroundTransparency = 1, ZIndex = 20 }, reveal)
local revealName = label({ Position = UDim2.fromOffset(0, 228), Size = UDim2.new(1, 0, 0, 36), ZIndex = 21 }, reveal)
local revealSub = label({ Position = UDim2.fromOffset(0, 266), Size = UDim2.new(1, 0, 0, 26), ZIndex = 21, TextColor3 = MUTED }, reveal)
button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(180, 46), ZIndex = 21 }, "Nice!", GREEN, reveal, function()
	reveal.Visible = false
end)

local function showReveal(result)
	for _, c in revealHolder:GetChildren() do
		c:Destroy()
	end
	local item = Items[result.id]
	local rarity = DecorData.Rarities[result.rarity]
	revealStroke.Color = rarity.color
	revealName.Text = item.name
	revealName.TextColor3 = rarity.color
	revealSub.Text = result.dup and ("%s  ·  Duplicate: +%d shards"):format(result.rarity, result.shards) or ("%s  ·  NEW!"):format(result.rarity)
	local vp = preview(result.id, revealHolder, UDim2.fromScale(1, 1))
	vp.ZIndex = 21
	reveal.Size = UDim2.fromOffset(60, 60)
	reveal.Visible = true
	TweenService:Create(reveal, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(340, 380) }):Play()
	-- spin the preview
	local cam = vp.CurrentCamera
	if cam then
		local model = vp:FindFirstChildOfClass("Model")
		local center = model and model:GetBoundingBox().Position or Vector3.zero
		local offset = cam.CFrame.Position - center
		task.spawn(function()
			local t0 = os.clock()
			while reveal.Visible and vp.Parent do
				local a = (os.clock() - t0) * 0.8
				cam.CFrame = CFrame.lookAt(center + CFrame.Angles(0, a, 0) * offset, center)
				RunService.RenderStepped:Wait()
			end
		end)
	end
end

----------------------------------------------------------------------------------------------
-- build mode
----------------------------------------------------------------------------------------------
local build = { active = false } -- { id, uid, r, ghost, x, z, ok, reason, hidden }
local buildBar = new("Frame", { Name = "BuildBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(560, 104), BackgroundColor3 = PANEL, BackgroundTransparency = 0.1, Visible = false }, gui)
round(buildBar, 16)
new("UIStroke", { Color = ACCENT, Thickness = 2 }, buildBar)
new("UISizeConstraint", { MaxSize = Vector2.new(560, 104) }, buildBar)
local buildTitle = label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 26), TextColor3 = GOLD }, buildBar)
local buildHint = label({ Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 18), TextColor3 = MUTED }, buildBar)
local buildButtons = new("Frame", { Position = UDim2.new(0, 10, 1, -46), Size = UDim2.new(1, -20, 0, 40), BackgroundTransparency = 1 }, buildBar)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, buildButtons)

local staticCache = {} -- [base] = parts decor can't overlap
local EXCLUDE = {
	Floor = true, Path = true, PathEdge = true, Pen = true, SpawnPoint = true, HouseFloor = true,
	ExpFloor = true, Pen2 = true, Pond = true, ExpansionBarrier = true, LockLabel = true, Gate = true,
	SignAnchor = true, Leaves = true, ExpLeaves = true, Roof = true, Chimney = true,
}
local function staticParts(base: Model)
	if staticCache[base] then
		return staticCache[base]
	end
	local list = {}
	for _, d in base:GetDescendants() do
		if d:IsA("BasePart") and not EXCLUDE[d.Name] then
			local skip = false
			local a = d.Parent
			while a and a ~= base do
				if a.Name == "Creatures" or a.Name == "Decor" then
					skip = true
					break
				end
				a = a.Parent
			end
			if not skip then
				table.insert(list, d)
			end
		end
	end
	staticCache[base] = list
	return list
end

local function overlaps(ax, az, afx, afz, bx, bz, bfx, bfz): boolean
	return math.abs(ax - bx) * 2 < afx + bfx - 0.01 and math.abs(az - bz) * 2 < afz + bfz - 0.01
end

-- Same rules as the server (the server has the final say)
local function check(base: Model, id: string, x: number, z: number, r: number, ignoreUid: number?): (boolean, string?)
	local item = Items[id]
	local fx, fz = DecorData.footprint(id, r)
	if not DecorData.inBounds(x, z, fx, fz, state.expansion, state.level) then
		return false, state.expansion and "Outside your base" or "Outside your base (unlock the expansion for more room)"
	end
	if not ignoreUid and #state.placed >= DecorData.BaseLevels[state.level].cap then
		return false, "Decoration limit reached: upgrade your base"
	end
	local floor = base.Floor
	local spawn = base:FindFirstChild("SpawnPoint")
	if spawn then
		local sx, sz = DecorData.toLocal(floor, spawn.Position)
		local c = DecorData.SpawnClear * 2
		if overlaps(x, z, fx, fz, sx, sz, c, c) then
			return false, "Keep your spawn point clear"
		end
	end
	for _, p in state.placed do
		if p.uid ~= ignoreUid then
			local other = Items[p.id]
			if other and (other.flat == true) == (item.flat == true) then
				local ofx, ofz = DecorData.footprint(p.id, p.r)
				if overlaps(x, z, fx, fz, p.x, p.z, ofx, ofz) then
					return false, "Overlaps your " .. other.name
				end
			end
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = staticParts(base)
	local cf = DecorData.toWorld(floor, x, z, 0)
	for _, hit in workspace:GetPartBoundsInBox(cf + Vector3.new(0, 3.3, 0), Vector3.new(fx - 0.2, 5.2, fz - 0.2), params) do
		if hit.CanCollide or hit.Transparency < 1 then
			return false, "Something is already there"
		end
	end
	return true, nil
end

local function setModelHidden(model: Model?, hidden: boolean)
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function placedModel(uid: number): Model?
	local base = myBase()
	local folder = base and base:FindFirstChild("Decor")
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:GetAttribute("Uid") == uid then
			return m
		end
	end
	return nil
end

local function stopBuild()
	if build.ghost then
		build.ghost:Destroy()
	end
	if build.uid then
		setModelHidden(placedModel(build.uid), false)
	end
	build = { active = false }
	buildBar.Visible = false
end

local highlight
local function makeGhost(id: string)
	local ghost = DecorData.build(id)
	for _, d in ghost:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Name ~= "Root" then
				d.Transparency = math.max(d.Transparency, 0.35)
			end
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") then
			d:Destroy()
		end
	end
	ghost.Root.Transparency = 0.5
	ghost.Root.Size = Vector3.new(ghost.Root.Size.X, 0.08, ghost.Root.Size.Z)
	ghost.Name = "DecorGhost"
	highlight = new("Highlight", { FillTransparency = 0.6, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, ghost)
	ghost.Parent = workspace
	return ghost
end

local function rebuildBar()
	for _, c in buildButtons:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if build.picking then
		buildTitle.Text = "Edit mode: tap a decoration to move it"
		buildHint.Text = touch and "Tap any of your decorations" or "Click any of your decorations  ·  Q to stop"
	else
		local item = Items[build.id]
		buildTitle.Text = (build.uid and "Moving: " or "Placing: ") .. item.name
		buildHint.Text = touch and "Tap where it goes, then Place" or "R rotate  ·  Click to place  ·  Q cancel" .. (build.uid and "  ·  X put away" or "")
	end
	local order = 0
	local function add(text, color, fn)
		order += 1
		button({ LayoutOrder = order, Size = UDim2.fromOffset(120, 40) }, text, color, buildButtons, fn)
	end
	if not build.picking then
		add("Rotate", BLUE, function()
			build.r = (build.r + 90) % 360
		end)
		add("Place", GREEN, function()
			build.confirm = true
		end)
		if build.uid then
			add("Put away", PURPLE, function()
				build.putAway = true
			end)
		end
	end
	add("Go to base", GREY, function()
		Teleport:FireServer("base")
	end)
	add(build.picking and "Done" or "Cancel", RED, function()
		stopBuild()
	end)
end

local function startPlacing(id: string, uid: number?, r: number?)
	stopBuild()
	win.Visible = false
	build = { active = true, id = id, uid = uid, r = r or 0, ghost = makeGhost(id) }
	if uid then
		setModelHidden(placedModel(uid), true)
	end
	buildBar.Visible = true
	rebuildBar()
end

local function startPicking()
	stopBuild()
	win.Visible = false
	build = { active = true, picking = true }
	buildBar.Visible = true
	rebuildBar()
end

local pointer = nil -- screen position for touch devices
local function aimRay(): RaycastResult?
	local base = myBase()
	if not base then
		return nil
	end
	local pos = pointer or UserInputService:GetMouseLocation()
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { base }
	return workspace:Raycast(ray.Origin, ray.Direction * 400, params)
end

local function tryCommit()
	if not build.active or build.picking or build.busy then
		return
	end
	if not build.ok then
		toast(build.reason or "Can't place that there.", "fail")
		return
	end
	build.busy = true
	local ok, message
	if build.uid then
		ok, message = call("move", build.uid, build.x, build.z, build.r)
	else
		ok, message = call("place", build.id, build.x, build.z, build.r)
	end
	build.busy = false
	if not ok then
		toast(message or "Can't place that there.", "fail")
		return
	end
	if build.uid then
		-- moved: the old model is replaced by the server
		build.uid = nil
		stopBuild()
		return
	end
	-- placed: keep placing more of the same if you still have some
	if placedCount(build.id) >= (state.owned[build.id] or 0) then
		stopBuild()
	end
end

local function tryPutAway()
	if not build.uid then
		return
	end
	local uid = build.uid
	local ok, message = call("remove", uid)
	toast(message, ok and "success" or "fail")
	if ok then
		build.uid = nil
		stopBuild()
	end
end

local function tryPick()
	local hit = aimRay()
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	while model and model:GetAttribute("Uid") == nil do
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	if model and model:GetAttribute("OwnerId") == player.UserId then
		startPlacing(model:GetAttribute("DecorId"), model:GetAttribute("Uid"), model:GetAttribute("R"))
	end
end

RunService.RenderStepped:Connect(function()
	if not build.active or build.picking or not build.ghost then
		return
	end
	if build.confirm then
		build.confirm = false
		task.spawn(tryCommit)
	end
	if build.putAway then
		build.putAway = false
		task.spawn(tryPutAway)
	end
	if not state or not build.ghost then
		return
	end
	local base = myBase()
	local hit = aimRay()
	if not base or not hit then
		build.ghost.Parent = nil
		build.ok, build.reason = false, "Point at your base"
		return
	end
	build.ghost.Parent = workspace
	local fx, fz = DecorData.footprint(build.id, build.r)
	local lx, lz = DecorData.toLocal(base.Floor, hit.Position)
	-- snap so the footprint's edges sit on whole studs
	local x = math.floor(lx - fx / 2 + 0.5) + fx / 2
	local z = math.floor(lz - fz / 2 + 0.5) + fz / 2
	build.x, build.z = x, z
	build.ok, build.reason = check(base, build.id, x, z, build.r, build.uid)
	build.ghost:PivotTo(DecorData.toWorld(base.Floor, x, z, build.r))
	if highlight then
		highlight.FillColor = build.ok and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 70, 70)
		highlight.OutlineColor = highlight.FillColor
	end
	buildHint.TextColor3 = build.ok and MUTED or Color3.fromRGB(255, 140, 140)
	if not build.ok and build.reason then
		buildHint.Text = build.reason
	else
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		buildHint.Text = touch and "Tap where it goes, then Place" or "R rotate  ·  Click to place  ·  Q cancel" .. (build.uid and "  ·  X put away" or "")
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not build.active then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
		stopBuild()
		return
	end
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R and not build.picking then
		build.r = (build.r + 90) % 360
	elseif input.KeyCode == Enum.KeyCode.X and build.uid then
		task.spawn(tryPutAway)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		pointer = nil
		if build.picking then
			tryPick()
		else
			task.spawn(tryCommit)
		end
	end
end)

UserInputService.TouchTapInWorld:Connect(function(position, processed)
	if not build.active or processed then
		return
	end
	pointer = position + Vector2.new(0, game:GetService("GuiService"):GetGuiInset().Y)
	if build.picking then
		tryPick()
	end
end)

-- leave build mode in battles and cutscenes
for _, attr in { "InBattle", "InCutscene", "InDialogue" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if player:GetAttribute(attr) then
			stopBuild()
			win.Visible = false
		end
	end)
end

----------------------------------------------------------------------------------------------
-- tabs
----------------------------------------------------------------------------------------------
local productPrices = {}
local function productPrice(p)
	if not p.id or p.id == 0 then
		return nil
	end
	if productPrices[p.id] == nil then
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, p.id, Enum.InfoType.Product)
		productPrices[p.id] = ok and info and info.PriceInRobux or false
	end
	return productPrices[p.id] or nil
end

local tabs = {}

function tabs.Items()
	listLayout()
	local cap = DecorData.BaseLevels[state.level].cap
	local top = new("Frame", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, content)
	label({ Size = UDim2.new(0.5, 0, 1, 0), Text = ("Placed %d / %d"):format(#state.placed, cap), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, top)
	button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.42, 0, 1, 0) }, "Move / put away placed items", BLUE, top, startPicking)
	local grid = new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, content)
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 210), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	local ids = {}
	for id, n in state.owned do
		if n > 0 and Items[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Items[a].name < Items[b].name
	end)
	if #ids == 0 then
		label({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 60), Text = "You don't own any decorations yet. Check the Shop, Daily deals or open a Crate!", TextColor3 = MUTED, TextWrapped = true }, content)
		return
	end
	local old = content
	content = grid
	for i, id in ids do
		local free = state.owned[id] - placedCount(id)
		itemCard(i, id, ("Owned %d  ·  Free %d"):format(state.owned[id], free), free > 0 and "Place" or "All placed", free > 0 and ACCENT or GREY, function()
			if free > 0 then
				startPlacing(id)
			end
		end)
	end
	content = old
end

local function buyResult(ok, message)
	setStatus(ok, message)
	if refreshTab then
		refreshTab()
	end
end

function tabs.Shop()
	gridLayout()
	for i, id in DecorData.ShopOrder do
		local item = Items[id]
		local owned = state.owned[id] or 0
		itemCard(i, id, owned > 0 and ("You own " .. owned) or " ", ("%d coins"):format(item.price), GREEN, function()
			buyResult(call("buy", id))
		end)
	end
end

function tabs.Daily()
	listLayout()
	local left = math.max(0, state.dailyEndsAt - os.time())
	heading(0, ("Today's deals. New items in %dh %02dm. One of each per day."):format(left // 3600, (left % 3600) // 60), GOLD)
	local grid = new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, content)
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 210), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	local old = content
	content = grid
	for i, id in state.daily do
		local item = Items[id]
		local bought = state.dailyBought[id]
		itemCard(i, id, "Only in the daily shop", bought and "Bought today" or ("%d coins"):format(item.price), bought and GREY or Color3.fromRGB(230, 90, 120), function()
			if not bought then
				buyResult(call("buyDaily", id))
			end
		end)
	end
	content = old
end

function tabs.Crates()
	listLayout()
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	heading(nextOrder(), "Crates cost coins only. Odds are shown below. Duplicates turn into shards.", MUTED)
	for _, boxId in DecorData.BoxOrder do
		local box = DecorData.Boxes[boxId]
		local earned = state.boxes[boxId] or 0
		local row = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = CARD }, content)
		round(row, 12)
		new("UIStroke", { Color = box.color, Thickness = 2 }, row)
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, row)
		label({ Size = UDim2.new(0.6, 0, 0.55, 0), Text = box.name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = box.color }, row)
		label({ Position = UDim2.fromScale(0, 0.58), Size = UDim2.new(0.6, 0, 0.42, 0), Text = earned > 0 and ("You have %d free from battles"):format(earned) or "Win trainer and gym battles to earn free ones", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MUTED }, row)
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.36, 0, 1, 0) }, earned > 0 and "Open free crate" or ("Open · %d coins"):format(box.price), PURPLE, row, function()
			local ok, result = call("openBox", boxId)
			if ok and typeof(result) == "table" then
				setStatus(nil, "")
				showReveal(result)
			else
				setStatus(false, result)
			end
			refreshTab()
		end)
		-- odds
		local odds = DecorData.boxOdds(boxId)
		local oddsFrame = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, content)
		new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 22), CellPadding = UDim2.fromOffset(6, 2), SortOrder = Enum.SortOrder.LayoutOrder }, oddsFrame)
		for i, e in odds do
			local owned = (state.owned[e.id] or 0) > 0
			label({ LayoutOrder = i, Text = ("%s%s  %.1f%%"):format(owned and "✓ " or "", Items[e.id].name, e.pct), TextColor3 = DecorData.Rarities[e.rarity].color, TextXAlignment = Enum.TextXAlignment.Left }, oddsFrame)
		end
	end
	heading(nextOrder(), ("Shards: %d  ·  trade shards for any crate item"):format(state.shards), GOLD)
	local seen, list = {}, {}
	for _, boxId in DecorData.BoxOrder do
		for _, id in DecorData.Boxes[boxId].pool do
			if not seen[id] then
				seen[id] = true
				table.insert(list, id)
			end
		end
	end
	table.sort(list, function(a, b)
		return DecorData.Rarities[Items[a].rarity].order < DecorData.Rarities[Items[b].rarity].order
	end)
	local grid = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, content)
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 210), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	local old = content
	content = grid
	for i, id in list do
		local cost = DecorData.Rarities[Items[id].rarity].shardCost
		local can = state.shards >= cost
		itemCard(i, id, ("Owned %d"):format(state.owned[id] or 0), ("%d shards"):format(cost), can and GOLD:Lerp(Color3.new(0, 0, 0), 0.25) or GREY, function()
			buyResult(call("shardBuy", id))
		end)
	end
	content = old
end

function tabs.Themes()
	listLayout()
	heading(0, "Change your whole base's look in one click.", MUTED)
	for i, key in DecorData.ThemeOrder do
		local theme = DecorData.Themes[key]
		local owned = state.themes[key] == true
		local equipped = state.theme == key
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = CARD }, content)
		round(row, 12)
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, row)
		for j, col in { theme.floor, theme.path, theme.fence, theme.cap, theme.lamp } do
			local sw = new("Frame", { Position = UDim2.fromOffset((j - 1) * 30, 4), Size = UDim2.fromOffset(24, 38), BackgroundColor3 = col }, row)
			round(sw, 6)
		end
		label({ Position = UDim2.fromOffset(160, 0), Size = UDim2.new(0.6, -160, 1, 0), Text = theme.name, TextXAlignment = Enum.TextXAlignment.Left }, row)
		local text, color
		if equipped then
			text, color = "Equipped", GREY
		elseif owned then
			text, color = "Use", GREEN
		elseif theme.premium then
			text, color = "Premium Pack", PURPLE
		else
			text, color = ("%d coins"):format(theme.price), Color3.fromRGB(40, 165, 160)
		end
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.32, 0, 1, 0) }, text, color, row, function()
			if equipped then
				return
			end
			if theme.premium and not owned then
				currentTab = "Robux"
				refreshTab()
				return
			end
			buyResult(call("theme", key))
		end)
	end
end

function tabs.Base()
	listLayout()
	local lv = DecorData.BaseLevels[state.level]
	local nextLv = DecorData.BaseLevels[state.level + 1]
	local function row(order, h)
		local r = new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = CARD }, content)
		round(r, 12)
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, r)
		return r
	end
	local r1 = row(1, 96)
	label({ Size = UDim2.new(0.62, 0, 0.36, 0), Text = ("%s Base  (level %d/%d)"):format(lv.name, state.level, #DecorData.BaseLevels), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, r1)
	label({ Position = UDim2.fromScale(0, 0.4), Size = UDim2.new(0.62, 0, 0.28, 0), Text = ("Holds %d decorations  ·  +%d%% coins  ·  Jar holds %d min"):format(lv.cap, lv.bonus * 100, lv.jarMinutes), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MUTED }, r1)
	label({ Position = UDim2.fromScale(0, 0.7), Size = UDim2.new(0.62, 0, 0.28, 0), Text = nextLv and ("Next: %s  ·  %d decorations  ·  +%d%% coins"):format(nextLv.name, nextLv.cap, nextLv.bonus * 100) or "Max level!", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MUTED }, r1)
	button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.34, 0, 0.7, 0) }, nextLv and ("Upgrade · %d coins"):format(nextLv.cost) or "Max level", nextLv and BLUE or GREY, r1, function()
		if nextLv then
			buyResult(call("upgrade"))
		end
	end)
	local r2 = row(2, 80)
	label({ Size = UDim2.new(0.62, 0, 0.5, 0), Text = ("Coin Jar: %d / %d"):format(state.bank, state.bankCap), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, r2)
	label({ Position = UDim2.fromScale(0, 0.52), Size = UDim2.new(0.62, 0, 0.42, 0), Text = ("Earning %.1f coins/min  ·  keeps filling while you're offline"):format(state.rate), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MUTED }, r2)
	button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.34, 0, 0.8, 0) }, "Collect", GREEN, r2, function()
		buyResult(call("collect"))
	end)
	heading(3, "How to earn more:", GOLD)
	for i, line in {
		"Coin Fountain, Golden Statue and other generators add coins every minute.",
		"Habitats pay +1 coin/min for each creature of their type on your team (up to 6).",
		"Healing Pads heal your team; Training Dummies give them XP while you build.",
		"Display Pedestals and Trophy Walls show off your best catches to visitors.",
		"Visitors can like your base at the gate: +10 coins each, and the Most Liked board in the hub.",
	} do
		label({ LayoutOrder = 3 + i, Size = UDim2.new(1, 0, 0, 22), Text = "• " .. line, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MUTED }, content)
	end
end

function tabs.Robux()
	listLayout()
	heading(30, "Coin bundles", GOLD)
	for i, p in DecorData.CoinProducts do
		local row = new("Frame", { LayoutOrder = 30 + i, Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = CARD }, content)
		round(row, 12)
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, row)
		label({ Size = UDim2.new(0.6, 0, 0.55, 0), Text = ("%s  ·  %s coins"):format(p.label, tostring(p.coins)), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, row)
		label({ Position = UDim2.fromScale(0, 0.58), Size = UDim2.new(0.6, 0, 0.42, 0), Text = p.tag or " ", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(150, 240, 150) }, row)
		local price = productPrice(p)
		local ready = p.id and p.id > 0
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.3, 0, 1, 0) }, ready and ("R$ %d"):format(price or p.robux) or "Coming soon", ready and GREEN or GREY, row, function()
			if ready then
				MarketplaceService:PromptProductPurchase(player, p.id)
			end
		end)
	end
	heading(0, "Bundles", GOLD)
	for i, b in DecorData.Bundles do
		local owned = b.once and state.bought and state.bought[b.key]
		local row = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = CARD }, content)
		round(row, 12)
		if b.once then
			new("UIStroke", { Color = GOLD, Thickness = 2 }, row)
		end
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, row)
		label({ Size = UDim2.new(0.66, 0, 0.5, 0), Text = b.label .. (b.tag and ("  ·  " .. b.tag) or ""), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, row)
		label({ Position = UDim2.fromScale(0, 0.52), Size = UDim2.new(0.66, 0, 0.44, 0), Text = b.desc, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MUTED, TextWrapped = true }, row)
		local ready = b.id and b.id > 0
		local price = productPrice(b)
		local text = owned and "Owned" or (ready and ("R$ %d"):format(price or b.robux) or "Coming soon")
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.3, 0, 0.9, 0) }, text, (owned or not ready) and GREY or GREEN, row, function()
			if not owned and ready then
				MarketplaceService:PromptProductPurchase(player, b.id)
			end
		end)
	end
	heading(40, "Game passes", GOLD)
	for i, key in { "VIP", "DoubleCoins" } do
		local pass = GameData.GamePasses[key]
		if pass then
			local owned = player:GetAttribute("Pass_" .. key) == true
			local row = new("Frame", { LayoutOrder = 40 + i, Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = CARD }, content)
			round(row, 12)
			new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, row)
			label({ Size = UDim2.new(0.66, 0, 0.5, 0), Text = pass.name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD }, row)
			label({ Position = UDim2.fromScale(0, 0.52), Size = UDim2.new(0.66, 0, 0.44, 0), Text = pass.description, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = MUTED, TextWrapped = true }, row)
			local ready = pass.id and pass.id > 0
			local text = owned and "Owned" or (ready and ("R$ %d"):format(pass.price) or "Coming soon")
			button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.3, 0, 0.9, 0) }, text, (owned or not ready) and GREY or GREEN, row, function()
				if not owned and ready then
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				end
			end)
		end
	end
end

refreshTab = function()
	if not win.Visible or not state then
		return
	end
	for key, b in tabButtons do
		local def
		for _, t in TABS do
			if t.key == key then
				def = t
			end
		end
		b.BackgroundColor3 = key == currentTab and def.color or GREY
	end
	walletLabel.Text = ("%d coins  ·  %d shards"):format(player:GetAttribute("Coins") or 0, state.shards or 0)
	local y = content.CanvasPosition
	clearContent()
	tabs[currentTab]()
	content.CanvasPosition = y
end

for i, t in TABS do
	tabButtons[t.key] = button({ LayoutOrder = i, Size = UDim2.new(1 / #TABS, -6, 0, 36) }, t.text, GREY, tabsBar, function()
		currentTab = t.key
		setStatus(nil, "")
		local old = content.CanvasPosition
		content.CanvasPosition = Vector2.zero
		refreshTab()
		content.CanvasPosition = Vector2.zero
		local _ = old
	end)
end

local function openMenu(tab: string?)
	if player:GetAttribute("InBattle") or player:GetAttribute("InCutscene") then
		return
	end
	if tab then
		currentTab = tab
	end
	stopBuild()
	if not state then
		call("state")
	end
	win.Visible = not win.Visible or tab ~= nil
	setStatus(nil, "")
	content.CanvasPosition = Vector2.zero
	refreshTab()
end

-- other scripts can open a tab: player.OpenDecor:Fire("Robux")
do
	local ev = Instance.new("BindableEvent")
	ev.Name = "OpenDecor"
	ev.Event:Connect(function(tab)
		if win.Visible and tab == currentTab then
			return
		end
		win.Visible = false
		openMenu(tab)
	end)
	ev.Parent = player
end

DecorSync.OnClientEvent:Connect(function(s)
	state = s
	if win.Visible and not build.active then
		refreshTab()
	end
end)
player:GetAttributeChangedSignal("Coins"):Connect(function()
	if win.Visible and state then
		walletLabel.Text = ("%d coins  ·  %d shards"):format(player:GetAttribute("Coins") or 0, state.shards or 0)
	end
end)

----------------------------------------------------------------------------------------------
-- BUILD button on the right, under BAG and INDEX
----------------------------------------------------------------------------------------------
do
	local color = ACCENT
	local b = new("TextButton", { Name = "BuildButton", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 90), Size = UDim2.fromOffset(78, 78), BackgroundColor3 = color, Text = "" }, gui)
	local function updateVisible()
		b.Visible = not (player:GetAttribute("InBattle") or player:GetAttribute("InCutscene") or player:GetAttribute("InDialogue"))
	end
	for _, attr in { "InBattle", "InCutscene", "InDialogue" } do
		player:GetAttributeChangedSignal(attr):Connect(updateVisible)
	end
	updateVisible()
	round(b, 18)
	new("UIStroke", { Color = color:Lerp(Color3.new(0, 0, 0), 0.4), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	label({ Size = UDim2.fromScale(1, 0.56), Position = UDim2.fromScale(0, 0.05), Text = "⚒" }, b)
	local t = label({ Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.64), Text = "BUILD" }, b)
	new("UIStroke", { Thickness = 1.5, Color = color:Lerp(Color3.new(0, 0, 0), 0.55) }, t)
	-- red dot when there's a free crate or a full coin jar
	local dot = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 0, BackgroundColor3 = RED, Text = "!", Visible = false, ZIndex = 3 }, b)
	round(dot, 999)
	local function updateDot()
		local free = 0
		for _, n in (state and state.boxes or {}) do
			free += n
		end
		local bank, cap = player:GetAttribute("BaseBank") or 0, player:GetAttribute("BaseBankCap") or 1
		dot.Visible = free > 0 or (bank > 0 and bank >= cap)
	end
	DecorSync.OnClientEvent:Connect(updateDot)
	player:GetAttributeChangedSignal("BaseBank"):Connect(updateDot)
	b.Activated:Connect(function()
		openMenu(nil)
	end)
end

-- first state
task.spawn(function()
	task.wait(3)
	if not state then
		pcall(call, "state")
	end
end)

--[[
	Wander: one shared loop that makes creatures stroll around inside a box,
	plus groundAt(), which finds the real ground height (terrain or floor) under a point
	so creatures stand on top of it instead of sinking in.
	Performance note: movement runs on the server for now. If lots of base creatures lag on
	mobile, move it to the client and only animate creatures near the player.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Wander = {}

local active = {} -- [Model] = state

-- Things a ground ray should pass through (creatures, decorations, players)
local function ignoreList()
	local list = {}
	for _, name in { "WildCreatures", "TutorialCreatures", "BattleAllies" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	local map = workspace:FindFirstChild("Map")
	if map then
		if map:FindFirstChild("Decor") then
			table.insert(list, map.Decor)
		end
		if map:FindFirstChild("Bounds") then
			table.insert(list, map.Bounds)
		end
		for _, base in map.Bases:GetChildren() do
			if base:FindFirstChild("Creatures") then
				table.insert(list, base.Creatures)
			end
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- Height of the ground directly under (x, z), or nil if nothing is there
function Wander.groundAt(position: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList()
	local hit = workspace:Raycast(Vector3.new(position.X, position.Y + 60, position.Z), Vector3.new(0, -160, 0), params)
	return hit and hit.Position.Y or nil
end

function Wander.add(model: Model, center: Vector3, halfX: number, halfZ: number, groundY: number, speed: number?)
	active[model] = {
		center = center,
		halfX = halfX,
		halfZ = halfZ,
		groundY = groundY,
		speed = speed or 6,
		nextMove = os.clock() + math.random() * 3,
	}
	model.Destroying:Connect(function()
		active[model] = nil
	end)
end

function Wander.remove(model: Model)
	local st = active[model]
	if st and st.tween then
		st.tween:Cancel()
	end
	active[model] = nil
end

local function step(model: Model, st)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local offset = model:GetAttribute("GroundOffset") or 1
	local from = body.Position
	local tx = st.center.X + (math.random() * 2 - 1) * st.halfX
	local tz = st.center.Z + (math.random() * 2 - 1) * st.halfZ
	local flat = Vector3.new(tx - from.X, 0, tz - from.Z)
	if flat.Magnitude < 1 then
		return
	end
	local ground = Wander.groundAt(Vector3.new(tx, st.groundY, tz)) or st.groundY
	-- ignore big drops/jumps (e.g. the ray found something odd)
	if math.abs(ground - st.groundY) > 6 then
		ground = st.groundY
	end
	local target = Vector3.new(tx, ground + offset, tz)
	local duration = math.clamp(flat.Magnitude / st.speed, 0.5, 6)
	local facing = CFrame.lookAt(from, from + flat.Unit)
	body.CFrame = facing
	st.tween = TweenService:Create(body, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		CFrame = facing.Rotation + target,
	})
	st.tween:Play()
	st.nextMove = os.clock() + duration + 1.5 + math.random() * 3
end

task.spawn(function()
	while true do
		local now = os.clock()
		for model, st in active do
			if not model.Parent then
				active[model] = nil
			elseif now >= st.nextMove then
				step(model, st)
				if now >= st.nextMove then
					st.nextMove = now + 1
				end
			end
		end
		task.wait(0.25)
	end
end)

return Wander

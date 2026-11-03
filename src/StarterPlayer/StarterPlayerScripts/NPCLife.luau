--[[
	NPCLife: idle animation for people (models with the "NPC" attribute). Client-only.
	  - gentle breathing (upper body rises and falls)
	  - when you're within LOOK studs, they turn their head to look at you
	NPCs never move on the server, so changing their parts here doesn't fight replication.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local RANGE, LOOK = 90, 22
local LOWER = { ["Left Leg"] = true, ["Right Leg"] = true, BootL = true, BootR = true }
local tracked = {}

local function register(m: Model)
	if tracked[m] or not m:GetAttribute("NPC") then
		return
	end
	local head = m:FindFirstChild("Head")
	if not head then
		return
	end
	-- R15 NPCs animate (idle animation); just turn the neck joint to look at you
	local neck = head:FindFirstChild("Neck")
	if m:GetAttribute("R15") and neck and neck:IsA("Motor6D") then
		tracked[m] = { r15 = true, head = head, neck = neck, neckC0 = neck.C0, yaw = 0 }
		return
	end
	local headParts, upper = {}, {}
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") then
			if c == head or c:GetAttribute("HeadPart") then
				table.insert(headParts, { p = c, base = c.CFrame })
			elseif not LOWER[c.Name] then
				table.insert(upper, { p = c, base = c.CFrame })
			end
		end
	end
	tracked[m] = { head = head, headBase = head.CFrame, headParts = headParts, upper = upper, yaw = 0, phase = math.random() * 6 }
end

workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") then
		task.delay(0.5, register, d)
	end
end)
for _, d in workspace:GetDescendants() do
	if d:IsA("Model") then
		register(d)
	end
end

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local now = os.clock()
	for m, st in tracked do
		if not m.Parent then
			tracked[m] = nil
			continue
		end
		if st.r15 then
			local hp = st.head.Position
			if (hp - cam.CFrame.Position).Magnitude > RANGE then
				continue
			end
			local want = 0
			if hrp then
				local to = hrp.Position - hp
				if to.Magnitude < LOOK then
					local root = m.PrimaryPart or st.head
					local localDir = root.CFrame:VectorToObjectSpace(Vector3.new(to.X, 0, to.Z))
					want = math.clamp(math.atan2(-localDir.X, -localDir.Z), -1.05, 1.05)
				end
			end
			st.yaw += (want - st.yaw) * math.min(1, dt * 5)
			st.neck.C0 = st.neckC0 * CFrame.Angles(0, st.yaw, 0)
			continue
		end
		local hb = st.headBase
		if (hb.Position - cam.CFrame.Position).Magnitude > RANGE then
			continue
		end
		-- breathing
		local bob = math.sin(now * 2 + st.phase) * 0.035
		for _, e in st.upper do
			e.p.CFrame = e.base + Vector3.new(0, bob, 0)
		end
		-- look at the player when close (turn the head, limited to +-60 degrees)
		local want = 0
		if hrp then
			local to = hrp.Position - hb.Position
			if to.Magnitude < LOOK then
				local localDir = hb:VectorToObjectSpace(Vector3.new(to.X, 0, to.Z))
				want = math.clamp(math.atan2(-localDir.X, -localDir.Z), -1.05, 1.05)
			end
		end
		st.yaw += (want - st.yaw) * math.min(1, dt * 5)
		local pivot = hb.Position
		local turn = CFrame.new(pivot) * CFrame.Angles(0, st.yaw, 0) * CFrame.new(-pivot)
		local lift = Vector3.new(0, bob, 0)
		for _, e in st.headParts do
			e.p.CFrame = (turn * e.base) + lift
		end
	end
end)

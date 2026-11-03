--[[
	Team Havoc's blimp drifts in a slow circle over the map. Animated on each client so the motion is smooth;
	the server copy stays put. Orbit settings live as attributes on workspace.HavocBlimp
	(OrbitCenter, OrbitRadius, LapSeconds) so later content can change the route.
]]
local RunService = game:GetService("RunService")
local blimp = workspace:WaitForChild("HavocBlimp")
local body = blimp.PrimaryPart or blimp:WaitForChild("Envelope")

-- remember every piece relative to the envelope
local pieces = {}
for _, p in blimp:GetDescendants() do
	if p:IsA("BasePart") then
		table.insert(pieces, { part = p, offset = body.CFrame:ToObjectSpace(p.CFrame) })
	end
end

local start = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock() - start
	local center = blimp:GetAttribute("OrbitCenter") or body.Position
	local radius = blimp:GetAttribute("OrbitRadius") or 260
	local lap = blimp:GetAttribute("LapSeconds") or 240
	local a = (t / lap) * math.pi * 2
	local pos = center + Vector3.new(math.cos(a) * radius, math.sin(t * 0.6) * 2.5, math.sin(a) * radius)
	local ahead = center + Vector3.new(math.cos(a + 0.01) * radius, 0, math.sin(a + 0.01) * radius)
	local cf = CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z)) * CFrame.Angles(0, 0, math.rad(-4)) -- slight bank into the turn
	local blink = (t % 1.4) < 0.15
	for _, e in pieces do
		local p = e.part
		local pcf = cf * e.offset
		if p:GetAttribute("Spin") then
			-- spin around the propeller hub's axis
			local hubOffset = Vector3.new(e.offset.X > 0 and 8.5 or -8.5, -12, 11)
			pcf = cf * CFrame.new(hubOffset) * CFrame.Angles(0, 0, t * 12) * CFrame.new(-hubOffset) * e.offset
		end
		p.CFrame = pcf
		if p:GetAttribute("Blink") then
			p.Transparency = blink and 0 or 0.7
			local light = p:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = blink
			end
		end
	end
end)

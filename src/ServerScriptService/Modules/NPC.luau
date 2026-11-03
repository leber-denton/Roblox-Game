--[[
	NPC helpers: speech bubbles, a wave, and interaction prompts for blocky NPC models.
]]

local NPC = {}

function NPC.say(npc: Model, text: string, seconds: number?)
	local head = npc:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Speech"
	bb.Size = UDim2.fromOffset(300, 76)
	bb.StudsOffset = Vector3.new(0, 3.6, 0)
	bb.MaxDistance = 50
	bb.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(40, 40, 55)
	label.Text = text
	label.Parent = frame
	bb.Parent = head
	task.delay(seconds or 4, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

function NPC.wave(npc: Model)
	local arm = npc:FindFirstChild("Right Arm")
	if not arm then
		return
	end
	local parts = { arm }
	for _, p in npc:GetChildren() do
		if p.Name == "Hand" and (p.Position - arm.Position).Magnitude < 1.5 then
			table.insert(parts, p)
		end
	end
	local shoulder = arm.CFrame * CFrame.new(0, 1, 0)
	local originals = {}
	for _, p in parts do
		originals[p] = p.CFrame
	end
	for _, angle in { 150, 125, 150, 125, 150 } do
		local turn = shoulder * CFrame.Angles(0, 0, math.rad(angle)) * shoulder:Inverse()
		for _, p in parts do
			p.CFrame = turn * originals[p]
		end
		task.wait(0.18)
	end
	for _, p in parts do
		p.CFrame = originals[p]
	end
end

function NPC.prompt(parent: Instance, action: string, objectText: string, distance: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = distance or 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

return NPC

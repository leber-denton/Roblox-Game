--[[
	DungeonClient: effects for the Dark Tower.
	  - a rumbling camera shake and a tint in the tower's colour while the lift carries you up
	  - a big "FLOOR 1.4" banner when you arrive on a new floor
	Colours and tower names come from Shared.TowerThemes.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local UIStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIStyle"))

local player = Players.LocalPlayer
local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
local TowerThemes = require(ReplicatedStorage.Shared:WaitForChild("TowerThemes"))

local gui = Instance.new("ScreenGui")
gui.Name = "DungeonUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 7
gui.Parent = player:WaitForChild("PlayerGui")
UIStyle.mount(gui)

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "LiftTint"
tint.TintColor = Color3.new(1, 1, 1)
tint.Parent = Lighting

local function banner(text: string, color: Color3, strokeColor: Color3)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.38)
	label.Size = UDim2.fromScale(0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = strokeColor
	stroke.Parent = label
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(700, 110)
	limit.Parent = label
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.6, 0.13) }):Play()
	task.delay(2.2, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		task.wait(0.6)
		label:Destroy()
	end)
end

-- camera rumble while the lift rises
local shaking = false
RunService.RenderStepped:Connect(function()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if shaking then
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * 0.35, (math.random() - 0.5) * 0.35, 0)
	elseif humanoid.CameraOffset ~= Vector3.zero then
		humanoid.CameraOffset = Vector3.zero
	end
end)

player:GetAttributeChangedSignal("Elevating"):Connect(function()
	local on = player:GetAttribute("Elevating") == true
	shaking = on
	local index = player:GetAttribute("DungeonFloor") or 1
	local theme = TowerThemes.forFloor(index)
	TweenService:Create(tint, TweenInfo.new(0.6), { TintColor = on and theme.tint or Color3.new(1, 1, 1) }):Play()
	if not on then
		local f = GameData.Dungeon.floors[index]
		if f then
			if f.rest then
				banner("FLOOR " .. f.label .. "  ·  STAGE CLEAR!", Color3.fromRGB(255, 220, 110), theme.bannerStroke)
			else
				-- the first floor of a new tower announces the tower's name
				local first = (index - 1) % TowerThemes.FLOORS_PER_TOWER == 0
				local text = (first and (theme.name:upper() .. "  ·  ") or "") .. "FLOOR " .. f.label .. (f.boss and "  ·  BOSS" or "")
				banner(text, f.boss and Color3.fromRGB(255, 200, 90) or theme.banner, theme.bannerStroke)
			end
		end
	end
end)

-- banner when entering the tower
player:GetAttributeChangedSignal("InDungeon"):Connect(function()
	if player:GetAttribute("InDungeon") then
		local index = player:GetAttribute("DungeonFloor") or 1
		local f = GameData.Dungeon.floors[index]
		if f then
			local theme = TowerThemes.forFloor(index)
			banner(theme.name:upper() .. "  ·  FLOOR " .. f.label, theme.banner, theme.bannerStroke)
		end
	end
end)

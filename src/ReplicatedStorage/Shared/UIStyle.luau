--[[
	UIStyle: the presentation-only layer shared by the runtime ScreenGuis.
	It deliberately owns no UI actions or game state: callers retain their existing
	Activated callbacks while this module supplies responsive visual feedback.
]]

local TweenService = game:GetService("TweenService")

local UIStyle = {}

local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function namedChild(parent: Instance, className: string, name: string)
	local child = parent:FindFirstChild(name)
	if child and child:IsA(className) then
		return child
	end
	return nil
end

local function ensureScale(button: GuiButton): UIScale
	local scale = namedChild(button, "UIScale", "UIStyleScale")
	if scale then
		return scale :: UIScale
	end
	scale = Instance.new("UIScale")
	scale.Name = "UIStyleScale"
	scale.Parent = button
	return scale
end

local function ensureStroke(button: GuiButton): UIStroke
	local existing = button:FindFirstChildWhichIsA("UIStroke")
	if existing then
		return existing
	end
	local stroke = Instance.new("UIStroke")
	stroke.Name = "UIStyleStroke"
	stroke.Color = button.BackgroundColor3:Lerp(Color3.new(0, 0, 0), 0.35)
	stroke.Transparency = 0.2
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	return stroke
end

local function tween(object: Instance, info: TweenInfo, props)
	TweenService:Create(object, info, props):Play()
end

function UIStyle.button(button: GuiButton)
	if button:GetAttribute("UIStyleBound") then
		return
	end
	button:SetAttribute("UIStyleBound", true)

	local scale = ensureScale(button)
	local stroke = ensureStroke(button)
	local baseTransparency = stroke.Transparency
	local function setDisabled()
		local enabled = button.Active
		tween(scale, HOVER, { Scale = enabled and 1 or 0.98 })
		tween(stroke, HOVER, { Transparency = enabled and baseTransparency or math.max(baseTransparency, 0.58) })
	end
	local function release()
		if button.Active then
			tween(scale, HOVER, { Scale = 1 })
			tween(stroke, HOVER, { Transparency = baseTransparency })
		end
	end

	button.MouseEnter:Connect(function()
		if button.Active then
			tween(scale, HOVER, { Scale = 1.025 })
			tween(stroke, HOVER, { Transparency = math.max(0, baseTransparency - 0.12) })
		end
	end)
	button.MouseLeave:Connect(release)
	button.SelectionGained:Connect(function()
		if button.Active then
			tween(scale, HOVER, { Scale = 1.025 })
		end
	end)
	button.SelectionLost:Connect(release)
	button.InputBegan:Connect(function(input)
		if button.Active and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			tween(scale, PRESS, { Scale = 0.97 })
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)
	button:GetPropertyChangedSignal("Active"):Connect(setDisabled)
	setDisabled()
end

function UIStyle.text(object: GuiObject)
	if not object:IsA("TextLabel") and not object:IsA("TextButton") and not object:IsA("TextBox") then
		return
	end
	if object.TextScaled and not object:FindFirstChildWhichIsA("UITextSizeConstraint") then
		local limit = Instance.new("UITextSizeConstraint")
		limit.Name = "UIStyleTextLimit"
		limit.MinTextSize = 10
		limit.MaxTextSize = 30
		limit.Parent = object
	end
end

function UIStyle.constraint(object: GuiObject, maxSize: Vector2, minSize: Vector2?)
	local constraint = namedChild(object, "UISizeConstraint", "UIStyleSizeConstraint")
	if not constraint then
		constraint = Instance.new("UISizeConstraint")
		constraint.Name = "UIStyleSizeConstraint"
		constraint.Parent = object
	end
	constraint.MaxSize = maxSize
	if minSize then
		constraint.MinSize = minSize
	end
	return constraint
end

function UIStyle.stack(parent: GuiObject, direction: Enum.FillDirection, padding: number)
	local layout = namedChild(parent, "UIListLayout", "UIStyleList")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Name = "UIStyleList"
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = parent
	end
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, padding)
	return layout
end

function UIStyle.mount(gui: ScreenGui)
	if gui:GetAttribute("UIStyleMounted") then
		return
	end
	gui:SetAttribute("UIStyleMounted", true)
	-- Runtime screens remain inside Roblox's safe area; individual cinematic screens can still opt into an inset.
	gui.ClipToDeviceSafeArea = true

	local function style(object: Instance)
		if object:IsA("GuiButton") then
			UIStyle.button(object)
		end
		if object:IsA("GuiObject") then
			UIStyle.text(object)
		end
	end
	for _, object in gui:GetDescendants() do
		style(object)
	end
	gui.DescendantAdded:Connect(style)
end

return UIStyle

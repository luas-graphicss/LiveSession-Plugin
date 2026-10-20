local UserInputService = game:GetService("UserInputService")

local Constants = require(script.Parent.Parent.Core.Constants)

local PromptGui = {}
PromptGui.__index = PromptGui

local PROMPTS = Constants.PROXIMITY_PROMPTS
local UI = PROMPTS.UI
local CLASSES = Constants.CLASS_NAMES
local THEME = Constants.UI

local function corner(parent, radius)
	local instance = Instance.new(CLASSES.UI_CORNER)
	instance.CornerRadius = radius
	instance.Parent = parent
end

local function label(parent, text, textSize, color, bold, order)
	local instance = Instance.new(CLASSES.TEXT_LABEL)
	instance.BackgroundTransparency = 1
	instance.Font = bold and THEME.FONT_BOLD or THEME.FONT
	instance.TextSize = textSize
	instance.TextColor3 = color
	instance.TextXAlignment = Enum.TextXAlignment.Left
	instance.Text = text
	instance.AutomaticSize = Enum.AutomaticSize.XY
	instance.Size = UDim2.new(0, 0, 0, textSize)
	instance.LayoutOrder = order
	instance.Parent = parent
	return instance
end

local function keyText(keyCode)
	local ok, text = pcall(UserInputService.GetStringForKeyCode, UserInputService, keyCode)
	if ok and text ~= THEME.EMPTY_TEXT then
		return text
	end
	return keyCode.Name
end

local function ringHalf(ring, clipPosition, circlePosition)
	local clip = Instance.new(CLASSES.FRAME)
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UI.RING_HALF_SIZE
	clip.Position = clipPosition
	clip.Parent = ring
	local circle = Instance.new(CLASSES.FRAME)
	circle.BackgroundTransparency = 1
	circle.Size = UI.RING_CIRCLE_SIZE
	circle.Position = circlePosition
	circle.Parent = clip
	corner(circle, UI.RING_CORNER)
	local stroke = Instance.new(CLASSES.UI_STROKE)
	stroke.Thickness = UI.RING_THICKNESS
	stroke.Color = UI.RING_COLOR
	stroke.Parent = circle
	local gradient = Instance.new(CLASSES.UI_GRADIENT)
	gradient.Transparency = UI.RING_GRADIENT
	gradient.Parent = stroke
	return gradient
end

local function buildRing(key)
	local ring = Instance.new(CLASSES.FRAME)
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(UI.KEY_SIZE + UI.RING_PADDING * 2, UI.KEY_SIZE + UI.RING_PADDING * 2)
	ring.Parent = key
	local rightGradient = ringHalf(ring, UI.RING_RIGHT_CLIP_POSITION, UI.RING_RIGHT_CIRCLE_POSITION)
	local leftGradient = ringHalf(ring, UDim2.new(), UDim2.new())
	return ring, rightGradient, leftGradient
end

function PromptGui.new(prompt, adornee, parent, onHoldBegin, onHoldEnd)
	local billboard = Instance.new(CLASSES.BILLBOARD_GUI)
	billboard.Name = prompt.Name
	billboard.Adornee = adornee
	billboard.Size = UI.BILLBOARD_SIZE
	billboard.AlwaysOnTop = true
	billboard.Active = true
	billboard.ResetOnSpawn = false
	local pill = Instance.new(CLASSES.FRAME)
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Size = UDim2.new(0, 0, 0, UI.PILL_HEIGHT)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = UI.PILL_COLOR
	pill.BackgroundTransparency = UI.PILL_TRANSPARENCY
	pill.BorderSizePixel = 0
	pill.Parent = billboard
	corner(pill, UDim.new(0, UI.PILL_CORNER))
	local padding = Instance.new(CLASSES.UI_PADDING)
	padding.PaddingLeft = UDim.new(0, UI.PILL_PADDING)
	padding.PaddingRight = UDim.new(0, UI.PILL_PADDING + UI.GAP)
	padding.Parent = pill
	local layout = Instance.new(CLASSES.UI_LIST_LAYOUT)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, UI.GAP)
	layout.Parent = pill
	local key = Instance.new(CLASSES.FRAME)
	key.Size = UDim2.fromOffset(UI.KEY_SIZE, UI.KEY_SIZE)
	key.BackgroundColor3 = UI.KEY_COLOR
	key.BorderSizePixel = 0
	key.LayoutOrder = 1
	key.Parent = pill
	corner(key, UDim.new(0, UI.KEY_CORNER))
	local keyLabel = label(key, keyText(prompt.KeyboardKeyCode), UI.KEY_TEXT_SIZE, UI.KEY_TEXT_COLOR, true, 1)
	keyLabel.AutomaticSize = Enum.AutomaticSize.None
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.TextXAlignment = Enum.TextXAlignment.Center
	local ring, rightGradient, leftGradient = buildRing(key)
	local texts = Instance.new(CLASSES.FRAME)
	texts.BackgroundTransparency = 1
	texts.AutomaticSize = Enum.AutomaticSize.XY
	texts.Size = UDim2.new()
	texts.LayoutOrder = 2
	texts.Parent = pill
	local textsLayout = Instance.new(CLASSES.UI_LIST_LAYOUT)
	textsLayout.FillDirection = Enum.FillDirection.Vertical
	textsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	textsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	textsLayout.Parent = texts
	local objectLabel = label(texts, prompt.ObjectText, UI.OBJECT_TEXT_SIZE, UI.OBJECT_TEXT_COLOR, false, 1)
	local actionLabel = label(texts, prompt.ActionText, UI.ACTION_TEXT_SIZE, UI.TEXT_COLOR, true, 2)
	local self = setmetatable({
		prompt = prompt,
		billboard = billboard,
		pill = pill,
		keyLabel = keyLabel,
		objectLabel = objectLabel,
		actionLabel = actionLabel,
		ring = ring,
		rightGradient = rightGradient,
		leftGradient = leftGradient,
		connections = {},
	}, PromptGui)
	if prompt.ClickablePrompt then
		self:addButton(onHoldBegin, onHoldEnd)
	end
	for _, property in ipairs(PROMPTS.WATCHED_PROPERTIES) do
		table.insert(self.connections, prompt:GetPropertyChangedSignal(property):Connect(function()
			self:refresh()
		end))
	end
	self:refresh()
	self:setProgress(0)
	billboard.Parent = parent
	return self
end

function PromptGui:addButton(onHoldBegin, onHoldEnd)
	local button = Instance.new(CLASSES.TEXT_BUTTON)
	button.BackgroundTransparency = 1
	button.Text = THEME.EMPTY_TEXT
	button.Size = UDim2.new(1, UI.PILL_PADDING * 2 + UI.GAP, 1, 0)
	button.Position = UDim2.new(0, -UI.PILL_PADDING, 0, 0)
	button.ZIndex = 2
	button.Parent = self.pill
	button.MouseButton1Down:Connect(onHoldBegin)
	button.MouseButton1Up:Connect(onHoldEnd)
	button.MouseLeave:Connect(onHoldEnd)
end

function PromptGui:refresh()
	local prompt = self.prompt
	self.objectLabel.Text = prompt.ObjectText
	self.objectLabel.Visible = prompt.ObjectText ~= THEME.EMPTY_TEXT
	self.actionLabel.Text = prompt.ActionText
	self.keyLabel.Text = keyText(prompt.KeyboardKeyCode)
	self.pill.Position = UDim2.new(0.5, prompt.UIOffset.X, 0.5, prompt.UIOffset.Y)
	self.ring.Visible = prompt.HoldDuration > 0
end

function PromptGui:setProgress(fraction)
	local angle = math.clamp(fraction, 0, 1) * UI.RING_FULL_TURN
	self.rightGradient.Rotation = math.min(angle, UI.RING_HALF_TURN)
	self.leftGradient.Rotation = math.max(angle, UI.RING_HALF_TURN)
end

function PromptGui:destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	self.billboard:Destroy()
end

return PromptGui

local Constants = require(script.Parent.Parent.Core.Constants)

local KickOverlay = {}
KickOverlay.__index = KickOverlay

local KICK = Constants.KICK
local TEXTS = Constants.TEXTS
local THEME = Constants.UI
local CLASSES = Constants.CLASS_NAMES
local TYPES = Constants.TYPE_NAMES

local function label(parent, text, textSize, color, bold, order)
	local instance = Instance.new(CLASSES.TEXT_LABEL)
	instance.BackgroundTransparency = 1
	instance.Font = bold and THEME.FONT_BOLD or THEME.FONT
	instance.TextSize = textSize
	instance.TextColor3 = color
	instance.TextXAlignment = Enum.TextXAlignment.Left
	instance.TextWrapped = true
	instance.Text = text
	instance.AutomaticSize = Enum.AutomaticSize.Y
	instance.Size = UDim2.new(1, 0, 0, textSize)
	instance.LayoutOrder = order
	instance.Parent = parent
	return instance
end

function KickOverlay.new(getRoot)
	return setmetatable({
		getRoot = getRoot,
		gui = nil,
	}, KickOverlay)
end

function KickOverlay:show(message)
	self:hide()
	local root = self.getRoot()
	if root == nil then
		return
	end
	local gui = Instance.new(CLASSES.SCREEN_GUI)
	gui.Name = KICK.GUI_NAME
	gui.DisplayOrder = KICK.DISPLAY_ORDER
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	local backdrop = Instance.new(CLASSES.FRAME)
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = THEME.COLORS.BACKDROP
	backdrop.BackgroundTransparency = KICK.BACKGROUND_TRANSPARENCY
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	local panel = Instance.new(CLASSES.FRAME)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = KICK.PANEL_SIZE
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = THEME.COLORS.PANEL
	panel.BorderSizePixel = 0
	panel.Parent = backdrop
	local corner = Instance.new(CLASSES.UI_CORNER)
	corner.CornerRadius = UDim.new(0, THEME.CORNER_RADIUS)
	corner.Parent = panel
	local padding = Instance.new(CLASSES.UI_PADDING)
	padding.PaddingTop = UDim.new(0, THEME.PADDING)
	padding.PaddingBottom = UDim.new(0, THEME.PADDING)
	padding.PaddingLeft = UDim.new(0, THEME.PADDING)
	padding.PaddingRight = UDim.new(0, THEME.PADDING)
	padding.Parent = panel
	local layout = Instance.new(CLASSES.UI_LIST_LAYOUT)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, THEME.GAP)
	layout.Parent = panel
	label(panel, TEXTS.KICK_TITLE, THEME.TITLE_TEXT_SIZE, THEME.COLORS.TEXT, true, 1)
	local body = type(message) == TYPES.STRING and message ~= THEME.EMPTY_TEXT and message or TEXTS.KICK_DEFAULT_MESSAGE
	label(panel, body, THEME.TEXT_SIZE, THEME.COLORS.TEXT_MUTED, false, 2)
	gui.Parent = root
	self.gui = gui
end

function KickOverlay:hide()
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

return KickOverlay

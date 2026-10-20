local Constants = require(script.Parent.Parent.Core.Constants)

local Toolbar = {}
Toolbar.__index = Toolbar

local UI = Constants.UI
local STATES = Constants.STATES

local function createButton(toolbar, id, tooltip, text, onClick)
	local button = toolbar:CreateButton(id, tooltip, UI.BUTTON_ICON, text)
	button.ClickableWhenViewportHidden = true
	button.Click:Connect(onClick)
	return button
end

function Toolbar.new(plugin, onToggle, onPanel, onOutput)
	local toolbar = plugin:CreateToolbar(UI.TOOLBAR_NAME)
	local button = createButton(toolbar, UI.BUTTON_ID, UI.BUTTON_TOOLTIP, UI.BUTTON_TEXT, onToggle)
	local panelButton = createButton(toolbar, UI.PANEL_BUTTON_ID, UI.PANEL_BUTTON_TOOLTIP, UI.PANEL_BUTTON_TEXT, onPanel)
	local outputButton = createButton(toolbar, UI.OUTPUT_BUTTON_ID, UI.OUTPUT_BUTTON_TOOLTIP, UI.OUTPUT_BUTTON_TEXT, onOutput)
	return setmetatable({ toolbar = toolbar, button = button, panelButton = panelButton, outputButton = outputButton }, Toolbar)
end

function Toolbar:setState(state)
	local busy = state ~= STATES.IDLE and state ~= STATES.RUNNING
	self.button.Enabled = not busy
	self.button:SetActive(state == STATES.RUNNING)
end

function Toolbar:setPanelActive(visible)
	self.panelButton:SetActive(visible)
end

function Toolbar:setOutputActive(visible)
	self.outputButton:SetActive(visible)
end

return Toolbar

local Constants = require(script.Parent.Parent.Core.Constants)
local Widgets = require(script.Parent.Widgets)

local FidelityMatrix = {}
FidelityMatrix.__index = FidelityMatrix

local UI = Constants.UI
local AREA_SCALE = UI.FIDELITY_AREA_SCALE
local STATUS_SCALE = UI.FIDELITY_STATUS_SCALE
local NOTE_SCALE = 1 - AREA_SCALE - STATUS_SCALE

local function numbered(items)
	local lines = {}
	for index, text in ipairs(items) do
		table.insert(lines, string.format(UI.FIDELITY_ITEM_FORMAT, index, text))
	end
	return table.concat(lines, UI.LINE_SEPARATOR)
end

local function column(row, text, scale, offsetScale, options)
	options.size = UDim2.new(scale, 0, 0, 0)
	options.autoHeight = true
	local label = Widgets.label(row, text, options)
	label.Position = UDim2.new(offsetScale, 0, 0, 0)
	return label
end

local function row(parent, entry, order)
	local frame = Widgets.frame(parent, UI.COLORS.PANEL, UDim2.new(1, 0, 0, 0))
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	column(frame, entry.area, AREA_SCALE, 0, { bold = true })
	column(frame, entry.status, STATUS_SCALE, AREA_SCALE, { color = UI.FIDELITY_COLORS[entry.status] })
	column(frame, entry.note, NOTE_SCALE, AREA_SCALE + STATUS_SCALE, { color = UI.COLORS.TEXT_MUTED })
end

function FidelityMatrix.new(parent, order)
	Widgets.label(parent, UI.FIDELITY_LABEL, { bold = true, color = UI.COLORS.TEXT_MUTED, order = order })
	for index, entry in ipairs(Constants.FIDELITY_MATRIX) do
		row(parent, entry, order + index)
	end
	local findingsOrder = order + #Constants.FIDELITY_MATRIX + 1
	Widgets.label(parent, UI.FIDELITY_FINDINGS_LABEL, { bold = true, color = UI.COLORS.ACCENT, order = findingsOrder })
	local findingsLabel = Widgets.label(parent, UI.EMPTY_VALUE, {
		autoHeight = true,
		size = UDim2.new(1, 0, 0, 0),
		color = UI.COLORS.TEXT_MUTED,
		order = findingsOrder + 1,
	})
	return setmetatable({ findingsLabel = findingsLabel, findings = {} }, FidelityMatrix)
end

function FidelityMatrix:addFinding(text)
	table.insert(self.findings, text)
	self.findingsLabel.Text = numbered(self.findings)
end

function FidelityMatrix:clearFindings()
	self.findings = {}
	self.findingsLabel.Text = UI.EMPTY_VALUE
end

return FidelityMatrix

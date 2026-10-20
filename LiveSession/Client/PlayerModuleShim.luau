local Constants = require(script.Parent.Parent.Core.Constants)

local PlayerModuleShim = {}

local SHIM = Constants.PLAYER_MODULE
local CLASSES = Constants.CLASS_NAMES
local PROPERTIES = Constants.PROPERTY_NAMES

function PlayerModuleShim.mount(playerScripts, tracker, owner)
	if playerScripts:FindFirstChild(SHIM.NAME) then
		return nil
	end
	local module = Instance.new(CLASSES.MODULE_SCRIPT)
	module.Name = SHIM.NAME
	module[PROPERTIES.SOURCE] = string.format(SHIM.SOURCE_FORMAT, SHIM.ENABLED_ATTRIBUTE, SHIM.MOVE_VECTOR_ATTRIBUTE)
	module:SetAttribute(SHIM.ENABLED_ATTRIBUTE, true)
	module:SetAttribute(SHIM.MOVE_VECTOR_ATTRIBUTE, Vector3.zero)
	tracker:addInstance(owner, module)
	module.Parent = playerScripts
	return module
end

function PlayerModuleShim.controlsEnabled(module)
	return module:GetAttribute(SHIM.ENABLED_ATTRIBUTE) ~= false
end

function PlayerModuleShim.setMoveVector(module, moveVector)
	if module:GetAttribute(SHIM.MOVE_VECTOR_ATTRIBUTE) ~= moveVector then
		module:SetAttribute(SHIM.MOVE_VECTOR_ATTRIBUTE, moveVector)
	end
end

return PlayerModuleShim

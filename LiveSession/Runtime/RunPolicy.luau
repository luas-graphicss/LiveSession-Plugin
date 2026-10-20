local Constants = require(script.Parent.Parent.Core.Constants)

local RunPolicy = {}

local CLASSES = Constants.CLASS_NAMES
local PROPERTIES = Constants.PROPERTY_NAMES

local function isEnabled(instance)
	return instance:IsA(CLASSES.BASE_SCRIPT) and instance[PROPERTIES.ENABLED]
end

RunPolicy.isEnabled = isEnabled

function RunPolicy.server(isServerContainer)
	return function(instance)
		if instance.ClassName ~= CLASSES.SCRIPT or not isEnabled(instance) then
			return false
		end
		local runContext = instance[PROPERTIES.RUN_CONTEXT]
		if runContext == Enum.RunContext.Server then
			return true
		end
		if runContext ~= Enum.RunContext.Legacy then
			return false
		end
		return isServerContainer(instance)
	end
end

function RunPolicy.client(isClientPlace, isReplicatedContainer)
	return function(instance)
		if not isEnabled(instance) then
			return false
		end
		if instance.ClassName == CLASSES.LOCAL_SCRIPT then
			return isClientPlace(instance)
		end
		if instance.ClassName == CLASSES.SCRIPT then
			return instance[PROPERTIES.RUN_CONTEXT] == Enum.RunContext.Client and isReplicatedContainer(instance)
		end
		return false
	end
end

return RunPolicy

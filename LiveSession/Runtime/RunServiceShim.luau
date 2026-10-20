local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Core.Constants)

local RunServiceShim = {}

local CONTEXTS = Constants.CONTEXTS
local MEMBERS = Constants.RUN_SERVICE_MEMBERS

local function constantMethod(value)
	local method = function()
		return value
	end
	return function()
		return method
	end
end

local SESSION_GETTERS = {
	[MEMBERS.IS_RUNNING] = constantMethod(true),
	[MEMBERS.IS_EDIT] = constantMethod(false),
	[MEMBERS.IS_RUN_MODE] = constantMethod(false),
}

local function clientOnlyGetter(member)
	local message = string.format(Constants.ERRORS.RUN_SERVICE_CLIENT_ONLY, member.name)
	local function raise()
		error(message, 0)
	end
	if member.method then
		return function()
			return raise
		end
	end
	return raise
end

local SERVER_GETTERS = {
	[MEMBERS.IS_SERVER] = constantMethod(true),
	[MEMBERS.IS_CLIENT] = constantMethod(false),
}
for _, member in ipairs(Constants.RUN_SERVICE_CLIENT_ONLY) do
	SERVER_GETTERS[member.name] = clientOnlyGetter(member)
end

local CONTEXT_GETTERS = {
	[CONTEXTS.SERVER] = SERVER_GETTERS,
	[CONTEXTS.CLIENT] = {
		[MEMBERS.IS_SERVER] = constantMethod(false),
		[MEMBERS.IS_CLIENT] = constantMethod(true),
	},
}

function RunServiceShim.install(proxy, simulationSignals)
	local getters = table.clone(SESSION_GETTERS)
	for member, getter in pairs(simulationSignals:getters()) do
		getters[member] = getter
	end
	proxy:override(RunService, getters)
	for context, contextGetters in pairs(CONTEXT_GETTERS) do
		proxy:overrideForContext(context, RunService, contextGetters)
	end
end

return RunServiceShim

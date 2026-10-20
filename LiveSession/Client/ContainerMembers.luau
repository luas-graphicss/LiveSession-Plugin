local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.Parent.Runtime.HostedSignal)

local ContainerMembers = {}

local API = Constants.CLIENT.CONTAINER_API

local function constantMethod(value)
	return function()
		return value
	end
end

function ContainerMembers.new(tracker, className)
	local api = API[className]
	if not api then
		return nil
	end
	local values = {}
	local signals = {}
	local function signalOf(key)
		local signal = signals[key]
		if not signal then
			signal = HostedSignal.new(tracker)
			signals[key] = signal
		end
		return signal:interface()
	end
	return {
		read = function(key)
			local default = api.PROPERTIES[key]
			if default ~= nil then
				local stored = values[key]
				if stored ~= nil then
					return true, stored
				end
				return true, default
			end
			if api.SIGNALS[key] then
				return true, signalOf(key)
			end
			local constant = api.CONSTANT_METHODS[key]
			if constant ~= nil then
				return true, constantMethod(constant)
			end
			if api.NO_OP_METHODS[key] then
				return true, constantMethod(nil)
			end
			return false, nil
		end,
		write = function(key, value)
			if api.PROPERTIES[key] == nil then
				return false
			end
			values[key] = value
			return true
		end,
	}
end

return ContainerMembers

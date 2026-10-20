local Constants = require(script.Parent.Parent.Core.Constants)

local ScriptStateWatcher = {}
ScriptStateWatcher.__index = ScriptStateWatcher

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
end

function ScriptStateWatcher.new(isObserved)
	return setmetatable({
		isObserved = isObserved,
		connections = {},
		onChanged = nil,
	}, ScriptStateWatcher)
end

function ScriptStateWatcher:start(onChanged)
	self.onChanged = onChanged
end

function ScriptStateWatcher:watch(instance)
	if self.connections[instance] or not instance:IsA(Constants.CLASS_NAMES.BASE_SCRIPT) or not self.isObserved(instance) then
		return
	end
	local connections = {}
	for _, property in ipairs(Constants.SCRIPT_STATE_PROPERTIES) do
		table.insert(connections, instance:GetPropertyChangedSignal(property):Connect(function()
			if self.onChanged then
				self.onChanged(instance, property)
			end
		end))
	end
	self.connections[instance] = connections
end

function ScriptStateWatcher:unwatch(instance)
	local connections = self.connections[instance]
	if connections then
		disconnectAll(connections)
		self.connections[instance] = nil
	end
end

function ScriptStateWatcher:stop()
	for _, connections in pairs(self.connections) do
		disconnectAll(connections)
	end
	self.connections = {}
	self.onChanged = nil
end

return ScriptStateWatcher

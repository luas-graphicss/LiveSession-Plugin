local Constants = require(script.Parent.Parent.Core.Constants)

local HostedSignal = {}
HostedSignal.__index = HostedSignal

local TYPES = Constants.TYPE_NAMES
local DEAD = Constants.COROUTINE_STATUS_DEAD
local LOCKED = { __metatable = Constants.LOCKED_METATABLE_MESSAGE }

local interfaces = setmetatable({}, { __mode = "k" })
local connections = setmetatable({}, { __mode = "k" })

function HostedSignal.new(tracker)
	return setmetatable({
		tracker = tracker,
		handlers = {},
		waiting = {},
		public = nil,
	}, HostedSignal)
end

function HostedSignal.typeOf(value)
	if interfaces[value] then
		return TYPES.SIGNAL
	elseif connections[value] then
		return TYPES.CONNECTION
	end
	return nil
end

function HostedSignal:connect(callback, once)
	local owner = self.tracker and self.tracker:currentOwner()
	local handler = { callback = callback, once = once, owner = owner, connected = true }
	table.insert(self.handlers, handler)
	local connection = setmetatable({ Connected = true }, LOCKED)
	connection.Disconnect = function()
		handler.connected = false
		connection.Connected = false
		local index = table.find(self.handlers, handler)
		if index then
			table.remove(self.handlers, index)
		end
	end
	connections[connection] = true
	if owner then
		self.tracker:addConnection(owner, connection)
	end
	return connection
end

function HostedSignal:wait()
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end

function HostedSignal:fire(...)
	local handlers = table.clone(self.handlers)
	local waiting = self.waiting
	self.waiting = {}
	for _, handler in ipairs(handlers) do
		if handler.connected then
			if handler.once then
				handler.connected = false
				local index = table.find(self.handlers, handler)
				if index then
					table.remove(self.handlers, index)
				end
			end
			task.spawn(function(...)
				if self.tracker and handler.owner then
					self.tracker:adopt(coroutine.running(), handler.owner)
				end
				handler.callback(...)
			end, ...)
		end
	end
	for _, thread in ipairs(waiting) do
		if coroutine.status(thread) ~= DEAD then
			task.spawn(thread, ...)
		end
	end
end

function HostedSignal:interface()
	if self.public then
		return self.public
	end
	self.public = setmetatable({
		Connect = function(_, callback)
			return self:connect(callback, false)
		end,
		Once = function(_, callback)
			return self:connect(callback, true)
		end,
		ConnectParallel = function(_, callback)
			return self:connect(callback, false)
		end,
		Wait = function()
			return self:wait()
		end,
	}, LOCKED)
	interfaces[self.public] = true
	return self.public
end

function HostedSignal:clear()
	for _, handler in ipairs(self.handlers) do
		handler.connected = false
	end
	self.handlers = {}
	self.waiting = {}
end

return HostedSignal

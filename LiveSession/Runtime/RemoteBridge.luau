local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.HostedSignal)

local RemoteBridge = {}
RemoteBridge.__index = RemoteBridge

local MEMBERS = Constants.REMOTE_MEMBERS
local SLOTS = Constants.REMOTE_SLOTS
local MEMBER_CONTEXT = Constants.REMOTE_MEMBER_CONTEXT
local TYPES = Constants.TYPE_NAMES
local ERRORS = Constants.ERRORS
local DEAD = Constants.COROUTINE_STATUS_DEAD

local function serialize(proxy, value, copies)
	local kind = type(value)
	if kind == TYPES.FUNCTION or kind == TYPES.THREAD then
		return nil
	end
	if kind ~= TYPES.TABLE or proxy:isProxy(value) then
		return value
	end
	local existing = copies[value]
	if existing then
		return existing
	end
	local copy = {}
	copies[value] = copy
	for key, item in pairs(value) do
		copy[key] = serialize(proxy, item, copies)
	end
	return copy
end

local function serializePack(proxy, packed)
	local copy = { n = packed.n }
	for index = 1, packed.n do
		copy[index] = serialize(proxy, packed[index], {})
	end
	return copy
end

local function resumeWaiting(thread, ...)
	if coroutine.status(thread) ~= DEAD then
		task.spawn(thread, ...)
	end
end

function RemoteBridge.new(tracker, proxy, getPlayer, onTimeout)
	return setmetatable({
		tracker = tracker,
		proxy = proxy,
		getPlayer = getPlayer,
		onTimeout = onTimeout,
		states = setmetatable({}, { __mode = "k" }),
		timeouts = 0,
		bridgeTable = nil,
	}, RemoteBridge)
end

function RemoteBridge:isRemote(instance)
	return Constants.REMOTE_CLASSES[instance.ClassName] == true
end

function RemoteBridge:bridge()
	if not self.bridgeTable then
		self.bridgeTable = {
			name = Constants.BRIDGES.REMOTE,
			matches = function(instance)
				return self:isRemote(instance)
			end,
			read = function(remote, key)
				local member = self:member(remote, key)
				return member ~= nil, member
			end,
			write = function(remote, key, value)
				return self:set(remote, key, value)
			end,
		}
	end
	return self.bridgeTable
end

function RemoteBridge:stateFor(remote)
	local state = self.states[remote]
	if not state then
		state = {
			serverEvent = HostedSignal.new(self.tracker),
			clientEvent = HostedSignal.new(self.tracker),
			callbackChanged = HostedSignal.new(nil),
		}
		self.states[remote] = state
	end
	return state
end

function RemoteBridge:assertContext(key)
	local required = MEMBER_CONTEXT[key]
	local owner = self.tracker:currentOwner()
	local context = owner and owner.context
	if required and context and context ~= required then
		error(string.format(ERRORS.REMOTE_WRONG_CONTEXT, key, required), 0)
	end
end

function RemoteBridge:isSessionPlayer(player)
	return player ~= nil and player == self.getPlayer()
end

function RemoteBridge:waitForCallback(remote, state, slot)
	local thread = coroutine.running()
	local finished = false
	local connection = state.callbackChanged:connect(function(changedSlot)
		if changedSlot == slot and not finished then
			finished = true
			resumeWaiting(thread, state[slot])
		end
	end, false)
	task.delay(Constants.REMOTE_INVOKE_TIMEOUT_SECONDS, function()
		if not finished then
			finished = true
			resumeWaiting(thread, nil)
		end
	end)
	local callback = coroutine.yield()
	connection.Disconnect()
	if not callback then
		self.timeouts += 1
		self.onTimeout(remote)
		error(string.format(ERRORS.REMOTE_TIMEOUT, remote:GetFullName(), Constants.REMOTE_INVOKE_TIMEOUT_SECONDS), 3)
	end
	return callback
end

function RemoteBridge:invoke(remote, slot, player, ...)
	local state = self:stateFor(remote)
	local callback = state[slot] or self:waitForCallback(remote, state, slot)
	local arguments = serializePack(self.proxy, table.pack(...))
	local results
	if player ~= nil then
		results = table.pack(callback(player, table.unpack(arguments, 1, arguments.n)))
	else
		results = table.pack(callback(table.unpack(arguments, 1, arguments.n)))
	end
	return self.proxy:wrapPack(serializePack(self.proxy, results))
end

function RemoteBridge:deliver(signal, player, ...)
	local arguments = serializePack(self.proxy, table.pack(...))
	if player ~= nil then
		signal:fire(player, table.unpack(arguments, 1, arguments.n))
	else
		signal:fire(table.unpack(arguments, 1, arguments.n))
	end
end

function RemoteBridge:member(remote, key)
	self:assertContext(key)
	local state = self:stateFor(remote)
	if key == MEMBERS.ON_SERVER_EVENT then
		return state.serverEvent:interface()
	elseif key == MEMBERS.ON_CLIENT_EVENT then
		return state.clientEvent:interface()
	elseif key == MEMBERS.ON_SERVER_INVOKE then
		return state[SLOTS.SERVER_INVOKE]
	elseif key == MEMBERS.ON_CLIENT_INVOKE then
		return state[SLOTS.CLIENT_INVOKE]
	elseif key == MEMBERS.FIRE_SERVER then
		return function(_, ...)
			self:deliver(state.serverEvent, self.getPlayer(), ...)
		end
	elseif key == MEMBERS.FIRE_ALL_CLIENTS then
		return function(_, ...)
			self:deliver(state.clientEvent, nil, ...)
		end
	elseif key == MEMBERS.FIRE_CLIENT then
		return function(_, player, ...)
			if not self:isSessionPlayer(player) then
				error(string.format(ERRORS.REMOTE_WRONG_PLAYER, remote:GetFullName()), 2)
			end
			self:deliver(state.clientEvent, nil, ...)
		end
	elseif key == MEMBERS.INVOKE_SERVER then
		return function(_, ...)
			return self:invoke(remote, SLOTS.SERVER_INVOKE, self.getPlayer(), ...)
		end
	elseif key == MEMBERS.INVOKE_CLIENT then
		return function(_, player, ...)
			if not self:isSessionPlayer(player) then
				error(string.format(ERRORS.REMOTE_WRONG_PLAYER, remote:GetFullName()), 2)
			end
			return self:invoke(remote, SLOTS.CLIENT_INVOKE, nil, ...)
		end
	end
	return nil
end

function RemoteBridge:set(remote, key, value)
	self:assertContext(key)
	local slot = nil
	if key == MEMBERS.ON_SERVER_INVOKE then
		slot = SLOTS.SERVER_INVOKE
	elseif key == MEMBERS.ON_CLIENT_INVOKE then
		slot = SLOTS.CLIENT_INVOKE
	else
		return false
	end
	local state = self:stateFor(remote)
	state[slot] = value
	state.callbackChanged:fire(slot)
	return true
end

function RemoteBridge:counts()
	local remotes = 0
	local handlers = 0
	for _, state in pairs(self.states) do
		remotes += 1
		handlers += #state.serverEvent.handlers + #state.clientEvent.handlers
		if state[SLOTS.SERVER_INVOKE] then
			handlers += 1
		end
		if state[SLOTS.CLIENT_INVOKE] then
			handlers += 1
		end
	end
	return { remotes = remotes, handlers = handlers, timeouts = self.timeouts }
end

function RemoteBridge:clear()
	for _, state in pairs(self.states) do
		state.serverEvent:clear()
		state.clientEvent:clear()
		state.callbackChanged:clear()
	end
	self.states = setmetatable({}, { __mode = "k" })
	self.timeouts = 0
end

return RemoteBridge

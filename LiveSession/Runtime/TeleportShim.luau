local TeleportService = game:GetService("TeleportService")

local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.HostedSignal)

local TeleportShim = {}
TeleportShim.__index = TeleportShim

local TELEPORT = Constants.TELEPORT
local TYPES = Constants.TYPE_NAMES

local function constantMethod(value)
	return function()
		return function()
			return value
		end
	end
end

function TeleportShim.new(proxy, tracker, getPlayer, onError)
	return setmetatable({
		proxy = proxy,
		tracker = tracker,
		getPlayer = getPlayer,
		onError = onError,
		settings = {},
		initFailed = HostedSignal.new(tracker),
		arrived = HostedSignal.new(tracker),
	}, TeleportShim)
end

function TeleportShim:playersOf(value)
	local unwrapped = self.proxy:unwrap(value)
	if type(unwrapped) == TYPES.TABLE then
		local players = {}
		for _, item in ipairs(unwrapped) do
			table.insert(players, self.proxy:wrap(item))
		end
		return players
	end
	return { self.getPlayer() }
end

function TeleportShim:fail(placeId, players, options)
	for _, player in ipairs(players) do
		self.initFailed:fire(player, TELEPORT.FAILURE_RESULT, TELEPORT.STUDIO_MESSAGE, placeId, options)
	end
	if self.onError then
		self.onError(TELEPORT.STUDIO_MESSAGE)
	end
end

function TeleportShim:teleportMethod(signature)
	return function()
		return function(_, ...)
			local arguments = table.pack(...)
			local placeId = arguments[signature.placeIdIndex]
			local players = self:playersOf(arguments[signature.playersIndex])
			local options = arguments[signature.optionsIndex]
			self:fail(placeId, players, options)
		end
	end
end

function TeleportShim:reserveServer(placeId)
	local ok, code, serverId = pcall(TeleportService.ReserveServer, TeleportService, self.proxy:unwrap(placeId))
	if ok then
		return code, serverId
	end
	return TELEPORT.RESERVED_CODE_FALLBACK, TELEPORT.RESERVED_SERVER_ID_FALLBACK
end

function TeleportShim:install()
	local getters = {
		[TELEPORT.INIT_FAILED] = function()
			return self.initFailed:interface()
		end,
		[TELEPORT.ARRIVED] = function()
			return self.arrived:interface()
		end,
		[TELEPORT.GET_SETTING] = function()
			return function(_, key)
				return self.settings[key]
			end
		end,
		[TELEPORT.SET_SETTING] = function()
			return function(_, key, value)
				self.settings[key] = self.proxy:unwrap(value)
			end
		end,
		[TELEPORT.RESERVE_SERVER] = function()
			return function(_, placeId)
				return self:reserveServer(placeId)
			end
		end,
		[TELEPORT.GET_PLACE_INSTANCE] = function()
			return function()
				return table.unpack(TELEPORT.PLACE_INSTANCE_RESULT, 1, TELEPORT.PLACE_INSTANCE_RESULT.n)
			end
		end,
	}
	for name, signature in pairs(TELEPORT.METHODS) do
		getters[name] = self:teleportMethod(signature)
	end
	for _, name in ipairs(TELEPORT.NO_OP_METHODS) do
		getters[name] = constantMethod(nil)
	end
	self.proxy:override(TeleportService, getters)
end

function TeleportShim:clear()
	self.initFailed:clear()
	self.arrived:clear()
	self.settings = {}
	self.proxy:clearOverrides(TeleportService)
end

return TeleportShim

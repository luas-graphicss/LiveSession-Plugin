local StarterPlayer = game:GetService("StarterPlayer")
local Teams = game:GetService("Teams")

local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.Parent.Runtime.HostedSignal)

local PlayerMembers = {}

local API = Constants.PLAYER_API
local MEMBERS = Constants.PLAYER_MEMBERS

local function constantMethod(value)
	return function()
		return value
	end
end

local function defaultOf(key)
	local starterProperty = API.STARTER_PROPERTIES[key]
	if starterProperty then
		local ok, value = pcall(function()
			return StarterPlayer[starterProperty]
		end)
		if ok then
			return value
		end
	end
	return API.DEFAULTS[key]
end

local function teamOfColor(teamColor)
	for _, team in ipairs(Teams:GetTeams()) do
		if team.TeamColor == teamColor then
			return team
		end
	end
	return nil
end

local function buildMethods(player)
	local methods = {
		[API.METHODS.DISTANCE_FROM_CHARACTER] = function(_, point)
			return player:distanceTo(point)
		end,
		[API.METHODS.LOAD_CHARACTER_WITH_DESCRIPTION] = function()
			player:loadCharacter()
		end,
		[API.METHODS.MOVE] = function(_, direction, relativeToCamera)
			player:move(direction, relativeToCamera)
		end,
		[API.METHODS.GET_FRIENDS_ONLINE] = function()
			return {}
		end,
	}
	for name, value in pairs(API.CONSTANT_METHODS) do
		methods[name] = constantMethod(value)
	end
	for _, name in ipairs(API.NO_OP_METHODS) do
		methods[name] = constantMethod(nil)
	end
	return methods
end

function PlayerMembers.new(tracker, player)
	local values = {}
	local signals = {}
	local methods = buildMethods(player)
	local function valueOf(key)
		local stored = values[key]
		if stored ~= nil then
			return stored
		end
		return defaultOf(key)
	end
	local function signalOf(key)
		local signal = signals[key]
		if not signal then
			signal = HostedSignal.new(tracker)
			signals[key] = signal
		end
		return signal:interface()
	end
	local function readTeam()
		if valueOf(MEMBERS.NEUTRAL) then
			return nil
		end
		return teamOfColor(valueOf(MEMBERS.TEAM_COLOR))
	end
	local function writeTeam(team)
		values[MEMBERS.NEUTRAL] = team == nil
		if team ~= nil then
			values[MEMBERS.TEAM_COLOR] = team.TeamColor
		end
	end
	return {
		read = function(key)
			if key == MEMBERS.TEAM then
				return true, readTeam()
			end
			if API.PROPERTIES[key] then
				return true, valueOf(key)
			end
			if API.SIGNALS[key] then
				return true, signalOf(key)
			end
			local method = methods[key]
			if method then
				return true, method
			end
			return false, nil
		end,
		write = function(key, value)
			if key == MEMBERS.TEAM then
				writeTeam(value)
				return true
			end
			if not API.PROPERTIES[key] then
				return false
			end
			values[key] = value
			return true
		end,
		fire = function(key, ...)
			local signal = signals[key]
			if signal then
				signal:fire(...)
			end
		end,
	}
end

return PlayerMembers

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StudioService = game:GetService("StudioService")

local Constants = require(script.Parent.Constants)

local TeamCreate = {}

local TYPES = Constants.TYPE_NAMES
local TEAM = Constants.TEAM_CREATE

function TeamCreate.isActive()
	return RunService:IsEdit() and #Players:GetPlayers() > 0
end

local function studioUserId()
	local ok, userId = pcall(StudioService.GetUserId, StudioService)
	if ok and type(userId) == TYPES.NUMBER and userId > 0 then
		return userId
	end
	return nil
end

function TeamCreate.identity()
	local localPlayer = Players.LocalPlayer
	local userId = studioUserId()
	if userId == nil and localPlayer then
		userId = localPlayer.UserId
	end
	local name = TEAM.UNKNOWN_NAME
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			name = player.Name
		end
	end
	if name == TEAM.UNKNOWN_NAME and localPlayer then
		name = localPlayer.Name
	end
	return { userId = userId or 0, name = name }
end

function TeamCreate.collaborators(localUserId)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId ~= localUserId then
			table.insert(list, { userId = player.UserId, name = player.Name })
		end
	end
	table.sort(list, function(left, right)
		return left.name < right.name
	end)
	return list
end

function TeamCreate.names(collaborators)
	local names = {}
	for _, collaborator in ipairs(collaborators) do
		table.insert(names, collaborator.name)
	end
	return names
end

return TeamCreate

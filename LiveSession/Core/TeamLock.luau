local ServerStorage = game:GetService("ServerStorage")

local Constants = require(script.Parent.Constants)

local TeamLock = {}

local TEAM = Constants.TEAM_CREATE
local ATTRIBUTES = TEAM.ATTRIBUTES
local TYPES = Constants.TYPE_NAMES
local TEXTS = Constants.TEXTS

function TeamLock.isLockFolder(instance)
	return instance.Parent == ServerStorage and instance.Name == Constants.PLUGIN_FOLDER_NAME
end

function TeamLock.folders()
	local list = {}
	for _, child in ipairs(ServerStorage:GetChildren()) do
		if child.Name == Constants.PLUGIN_FOLDER_NAME then
			table.insert(list, child)
		end
	end
	return list
end

function TeamLock.write(folder, identity, sessionId, startedAt)
	folder:SetAttribute(ATTRIBUTES.OWNER_USER_ID, identity.userId)
	folder:SetAttribute(ATTRIBUTES.OWNER_NAME, identity.name)
	folder:SetAttribute(ATTRIBUTES.SESSION_ID, sessionId)
	folder:SetAttribute(ATTRIBUTES.STARTED_AT, startedAt)
	folder:SetAttribute(ATTRIBUTES.HEARTBEAT, os.time())
end

function TeamLock.heartbeat(folder)
	folder:SetAttribute(ATTRIBUTES.HEARTBEAT, os.time())
end

function TeamLock.read(folder, localUserId, now)
	local userId = folder:GetAttribute(ATTRIBUTES.OWNER_USER_ID)
	local heartbeatAt = folder:GetAttribute(ATTRIBUTES.HEARTBEAT)
	if type(userId) ~= TYPES.NUMBER or type(heartbeatAt) ~= TYPES.NUMBER then
		return nil
	end
	local current = now or os.time()
	local ageSeconds = math.max(0, current - heartbeatAt)
	local startedAt = folder:GetAttribute(ATTRIBUTES.STARTED_AT)
	local name = folder:GetAttribute(ATTRIBUTES.OWNER_NAME)
	return {
		folder = folder,
		userId = userId,
		name = type(name) == TYPES.STRING and name or TEAM.UNKNOWN_NAME,
		sessionId = folder:GetAttribute(ATTRIBUTES.SESSION_ID),
		startedAt = type(startedAt) == TYPES.NUMBER and startedAt or heartbeatAt,
		heartbeatAt = heartbeatAt,
		ageSeconds = ageSeconds,
		alive = ageSeconds < TEAM.STALE_SECONDS,
		mine = userId == localUserId,
	}
end

function TeamLock.all(localUserId, now)
	local locks = {}
	for _, folder in ipairs(TeamLock.folders()) do
		local lock = TeamLock.read(folder, localUserId, now)
		if lock then
			table.insert(locks, lock)
		end
	end
	return locks
end

function TeamLock.foreign(localUserId, now)
	for _, lock in ipairs(TeamLock.all(localUserId, now)) do
		if lock.alive and not lock.mine then
			return lock
		end
	end
	return nil
end

function TeamLock.pickWinner(locks)
	local winner = nil
	for _, lock in ipairs(locks) do
		if winner == nil
			or lock.startedAt < winner.startedAt
			or (lock.startedAt == winner.startedAt and lock.userId < winner.userId) then
			winner = lock
		end
	end
	return winner
end

function TeamLock.markObserver(folder, userId)
	folder:SetAttribute(TEAM.OBSERVER_ATTRIBUTE_PREFIX .. tostring(userId), os.time())
end

function TeamLock.observers(folder, now)
	local current = now or os.time()
	local prefixLength = #TEAM.OBSERVER_ATTRIBUTE_PREFIX
	local list = {}
	for name, value in pairs(folder:GetAttributes()) do
		if string.sub(name, 1, prefixLength) == TEAM.OBSERVER_ATTRIBUTE_PREFIX
			and type(value) == TYPES.NUMBER
			and current - value < TEAM.STALE_SECONDS then
			local userId = tonumber(string.sub(name, prefixLength + 1))
			if userId then
				table.insert(list, userId)
			end
		end
	end
	table.sort(list)
	return list
end

function TeamLock.describe(lock)
	return string.format(
		TEXTS.TEAM_LOCK_FORMAT,
		lock.name,
		lock.userId,
		tostring(lock.sessionId),
		os.date(TEAM.TIME_FORMAT, lock.startedAt),
		lock.ageSeconds
	)
end

return TeamLock

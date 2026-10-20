local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(script.Parent.Constants)
local TeamCreate = require(script.Parent.TeamCreate)
local TeamLock = require(script.Parent.TeamLock)

local TeamMonitor = {}
TeamMonitor.__index = TeamMonitor

local TEAM = Constants.TEAM_CREATE
local TEXTS = Constants.TEXTS

function TeamMonitor.new(identity)
	return setmetatable({
		identity = identity,
		listeners = {},
		connections = {},
		folderConnections = {},
		running = false,
		refreshQueued = false,
		lastObserverMarkAt = 0,
		summary = nil,
	}, TeamMonitor)
end

function TeamMonitor:onSummary(callback)
	table.insert(self.listeners, callback)
	if self.summary then
		callback(self.summary, nil)
	end
end

function TeamMonitor:start()
	self.running = true
	table.insert(self.connections, ServerStorage.ChildAdded:Connect(function(child)
		if child.Name == Constants.PLUGIN_FOLDER_NAME then
			self:watchFolder(child)
			self:refresh()
		end
	end))
	table.insert(self.connections, ServerStorage.ChildRemoved:Connect(function(child)
		if child.Name == Constants.PLUGIN_FOLDER_NAME then
			self:unwatchFolder(child)
			self:refresh()
		end
	end))
	table.insert(self.connections, Players.PlayerAdded:Connect(function()
		self:refresh()
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function()
		self:refresh()
	end))
	for _, folder in ipairs(TeamLock.folders()) do
		self:watchFolder(folder)
	end
	task.spawn(function()
		while self.running do
			self:refresh()
			task.wait(TEAM.MONITOR_SECONDS)
		end
	end)
end

function TeamMonitor:watchFolder(folder)
	if self.folderConnections[folder] then
		return
	end
	self.folderConnections[folder] = folder.AttributeChanged:Connect(function()
		self:refresh()
	end)
end

function TeamMonitor:unwatchFolder(folder)
	local connection = self.folderConnections[folder]
	if connection then
		connection:Disconnect()
		self.folderConnections[folder] = nil
	end
end

function TeamMonitor:refresh()
	if self.refreshQueued then
		return
	end
	self.refreshQueued = true
	task.defer(function()
		self.refreshQueued = false
		if self.running then
			self:compute()
		end
	end)
end

function TeamMonitor:isActive()
	return TeamCreate.isActive()
end

function TeamMonitor:compute()
	local now = os.time()
	if self.identity.name == TEAM.UNKNOWN_NAME then
		self.identity = TeamCreate.identity()
	end
	local lock = TeamLock.pickWinner(TeamLock.all(self.identity.userId, now))
	local observers = {}
	if lock then
		if lock.alive and not lock.mine and now - self.lastObserverMarkAt >= Constants.LOCK_HEARTBEAT_SECONDS then
			self.lastObserverMarkAt = now
			pcall(TeamLock.markObserver, lock.folder, self.identity.userId)
		end
		observers = TeamLock.observers(lock.folder, now)
	end
	local previous = self.summary
	local summary = {
		active = TeamCreate.isActive(),
		collaborators = TeamCreate.collaborators(self.identity.userId),
		lock = lock,
		observers = observers,
		withPlugin = 1 + #observers,
	}
	self.summary = summary
	for _, listener in ipairs(self.listeners) do
		listener(summary, previous)
	end
end

function TeamMonitor:current()
	return self.summary
end

function TeamMonitor:othersPresent()
	return #TeamCreate.collaborators(self.identity.userId) > 0
end

function TeamMonitor.foreignOf(summary)
	local lock = summary and summary.lock
	if lock and lock.alive and not lock.mine then
		return lock
	end
	return nil
end

function TeamMonitor.namesOf(summary)
	return TeamCreate.names(summary.collaborators)
end

function TeamMonitor.describe(summary, collaboratorEntries)
	if not summary.active then
		return TEXTS.TEAM_OFF
	end
	local text = string.format(TEXTS.TEAM_SUMMARY_FORMAT, #summary.collaborators, summary.withPlugin)
	local lock = summary.lock
	if lock and lock.mine and lock.alive then
		text ..= string.format(TEXTS.TEAM_OWN_SUFFIX, collaboratorEntries or 0)
	elseif lock and lock.alive then
		text ..= string.format(TEXTS.TEAM_FOREIGN_SUFFIX, lock.name, lock.ageSeconds)
	elseif lock then
		text ..= string.format(TEXTS.TEAM_STALE_SUFFIX, lock.name, lock.ageSeconds)
	end
	return text
end

function TeamMonitor:stop()
	self.running = false
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	for folder in pairs(self.folderConnections) do
		self:unwatchFolder(folder)
	end
end

return TeamMonitor

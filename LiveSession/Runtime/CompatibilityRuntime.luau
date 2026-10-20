local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Core.Constants)

local CompatibilityRuntime = {}
CompatibilityRuntime.__index = CompatibilityRuntime

local COMPAT = Constants.COMPAT

local function waitUntil(condition, timeoutSeconds)
	local waited = 0
	while not condition() and waited < timeoutSeconds do
		waited += task.wait(COMPAT.POLL_SECONDS)
	end
	return condition()
end

function CompatibilityRuntime.new(pluginFolder)
	return setmetatable({
		pluginFolder = pluginFolder,
		marker = nil,
		running = false,
	}, CompatibilityRuntime)
end

function CompatibilityRuntime.detachedHolder()
	local holder = Instance.new(Constants.CLASS_NAMES.FOLDER)
	holder.Name = Constants.QUARANTINE_FOLDER_NAME
	return holder
end

function CompatibilityRuntime:start()
	RunService:Run()
	self.running = true
	waitUntil(function()
		return RunService:IsRunning()
	end, COMPAT.START_TIMEOUT_SECONDS)
	local marker = Instance.new(Constants.CLASS_NAMES.FOLDER)
	marker.Name = COMPAT.MARKER_NAME
	marker.Parent = self.pluginFolder
	self.marker = marker
end

function CompatibilityRuntime:stop()
	if not self.running then
		return true
	end
	self.running = false
	RunService:Stop()
	local marker = self.marker
	self.marker = nil
	local reverted = waitUntil(function()
		return marker == nil or marker.Parent == nil
	end, COMPAT.REVERT_TIMEOUT_SECONDS)
	if marker and marker.Parent ~= nil then
		marker:Destroy()
	end
	return reverted
end

function CompatibilityRuntime:isRunning()
	return self.running
end

return CompatibilityRuntime

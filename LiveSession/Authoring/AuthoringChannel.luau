local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Constants = require(script.Parent.Parent.Core.Constants)

local AuthoringChannel = {}
AuthoringChannel.__index = AuthoringChannel

local CLASSIFICATIONS = Constants.CLASSIFICATIONS
local ORIGINS = Constants.ORIGINS

function AuthoringChannel.new(tracker, touched, isSelected, capabilities, fallback)
	return setmetatable({
		tracker = tracker,
		touched = touched,
		isSelected = isSelected,
		capabilities = capabilities,
		fallback = fallback,
		recordingDepth = 0,
		connections = {},
	}, AuthoringChannel)
end

function AuthoringChannel:start(onUndoRedo)
	if self.capabilities.changeHistoryRecording then
		table.insert(self.connections, ChangeHistoryService.OnRecordingStarted:Connect(function()
			self.recordingDepth += 1
		end))
		table.insert(self.connections, ChangeHistoryService.OnRecordingFinished:Connect(function()
			self.recordingDepth = math.max(0, self.recordingDepth - 1)
		end))
	end
	table.insert(self.connections, ChangeHistoryService.OnUndo:Connect(function()
		onUndoRedo(Constants.TEXTS.UNDO_LABEL)
	end))
	table.insert(self.connections, ChangeHistoryService.OnRedo:Connect(function()
		onUndoRedo(Constants.TEXTS.REDO_LABEL)
	end))
end

function AuthoringChannel:isRecording()
	return self.recordingDepth > 0
end

function AuthoringChannel:isHostedThread()
	return self.tracker:currentOwner() ~= nil
end

function AuthoringChannel:isHostedTree(instance, predicate)
	local current = instance
	while current and current ~= game do
		if predicate(current) then
			return true
		end
		current = current.Parent
	end
	return false
end

function AuthoringChannel:isHostedInstance(instance)
	return self:isHostedTree(instance, function(candidate)
		return self.tracker:isHostedInstance(candidate)
	end)
end

function AuthoringChannel:isHostedDestroy(instance)
	return self:isHostedTree(instance, function(candidate)
		return self.tracker:isDestroying(candidate)
	end)
end

function AuthoringChannel:classifySource()
	return CLASSIFICATIONS.AUTHORING, ORIGINS.EDITOR
end

function AuthoringChannel:classifyCreate(instance)
	if self:isHostedThread() or self:isHostedInstance(instance) then
		return CLASSIFICATIONS.RUNTIME
	end
	if self:isRecording() then
		return CLASSIFICATIONS.AUTHORING, ORIGINS.RECORDING
	end
	if self.touched:isRuntimeTree(instance) then
		return CLASSIFICATIONS.RUNTIME
	end
	return self.fallback:classifyCreate(instance)
end

function AuthoringChannel:classifyDestroy(instance)
	if self:isHostedThread() or self:isHostedDestroy(instance) or self:isHostedInstance(instance) then
		return CLASSIFICATIONS.RUNTIME
	end
	if self:isRecording() then
		return CLASSIFICATIONS.AUTHORING, ORIGINS.RECORDING
	end
	if self.touched:isRuntimeTree(instance) then
		return CLASSIFICATIONS.RUNTIME
	end
	if self.isSelected(instance) then
		return CLASSIFICATIONS.AMBIGUOUS, ORIGINS.SELECTION
	end
	return self.fallback:classifyDestroy(instance)
end

function AuthoringChannel:classifyProperty(instance, property)
	if self:isHostedThread() then
		return CLASSIFICATIONS.RUNTIME
	end
	if self:isRecording() then
		return CLASSIFICATIONS.AUTHORING, ORIGINS.RECORDING
	end
	if self.isSelected(instance) then
		return CLASSIFICATIONS.AMBIGUOUS, ORIGINS.SELECTION
	end
	return self.fallback:classifyProperty(instance, property)
end

function AuthoringChannel:stop()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	self.recordingDepth = 0
end

return AuthoringChannel

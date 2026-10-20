local Selection = game:GetService("Selection")

local Constants = require(script.Parent.Parent.Core.Constants)

local InstanceWatcher = {}
InstanceWatcher.__index = InstanceWatcher

function InstanceWatcher.new(containers, isObserved)
	return setmetatable({
		containers = containers,
		isObserved = isObserved,
		containerConnections = {},
		selectionConnection = nil,
		selectedConnections = {},
		selected = {},
		watched = {},
		watchedCount = 0,
		callbacks = nil,
	}, InstanceWatcher)
end

function InstanceWatcher:start(callbacks)
	self.callbacks = callbacks
	for _, container in ipairs(self.containers) do
		table.insert(self.containerConnections, container.DescendantAdded:Connect(function(instance)
			if self.isObserved(instance) then
				callbacks.onAdded(instance)
			end
		end))
		table.insert(self.containerConnections, container.DescendantRemoving:Connect(function(instance)
			if self.isObserved(instance) then
				callbacks.onRemoving(instance)
			end
		end))
	end
	self.selectionConnection = Selection.SelectionChanged:Connect(function()
		self:syncSelection()
	end)
	self:syncSelection()
end

function InstanceWatcher:connectChanged(instance)
	return instance.Changed:Connect(function(property)
		if type(property) ~= Constants.TYPE_NAMES.STRING then
			property = Constants.PROPERTY_NAMES.VALUE
		end
		self.callbacks.onPropertyChanged(instance, property)
	end)
end

function InstanceWatcher:syncSelection()
	local selected = {}
	for _, instance in ipairs(Selection:Get()) do
		if self.isObserved(instance) then
			selected[instance] = true
			if not self.selectedConnections[instance] and not self.watched[instance] then
				self.selectedConnections[instance] = self:connectChanged(instance)
			end
		end
	end
	for instance, connection in pairs(self.selectedConnections) do
		if not selected[instance] then
			connection:Disconnect()
			self.selectedConnections[instance] = nil
		end
	end
	self.selected = selected
end

function InstanceWatcher:isSelected(instance)
	return self.selected[instance] == true
end

function InstanceWatcher:watchProperties(instance)
	if self.watched[instance] or self.callbacks == nil then
		return
	end
	local existing = self.selectedConnections[instance]
	if existing then
		self.selectedConnections[instance] = nil
		self.watched[instance] = existing
	else
		self.watched[instance] = self:connectChanged(instance)
	end
	self.watchedCount += 1
end

function InstanceWatcher:unwatchProperties(instance)
	local connection = self.watched[instance]
	if connection then
		connection:Disconnect()
		self.watched[instance] = nil
		self.watchedCount -= 1
	end
end

function InstanceWatcher:watchedTotal()
	return self.watchedCount
end

function InstanceWatcher:stop()
	for _, connection in ipairs(self.containerConnections) do
		connection:Disconnect()
	end
	self.containerConnections = {}
	if self.selectionConnection then
		self.selectionConnection:Disconnect()
		self.selectionConnection = nil
	end
	for _, connection in pairs(self.selectedConnections) do
		connection:Disconnect()
	end
	self.selectedConnections = {}
	self.selected = {}
	for _, connection in pairs(self.watched) do
		connection:Disconnect()
	end
	self.watched = {}
	self.watchedCount = 0
	self.callbacks = nil
end

return InstanceWatcher

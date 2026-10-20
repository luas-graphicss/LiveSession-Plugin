local ScriptEditorService = game:GetService("ScriptEditorService")

local Constants = require(script.Parent.Parent.Core.Constants)

local SourceWatcher = {}
SourceWatcher.__index = SourceWatcher

local ORIGINS = Constants.ORIGINS

function SourceWatcher.new(isObserved, capabilities)
	return setmetatable({
		isObserved = isObserved,
		capabilities = capabilities,
		connections = {},
		documentConnection = nil,
		onChanged = nil,
	}, SourceWatcher)
end

function SourceWatcher:start(onChanged)
	self.onChanged = onChanged
	if self.capabilities.textDocumentDidChange then
		self.documentConnection = ScriptEditorService.TextDocumentDidChange:Connect(function(document)
			local ok, instance = pcall(document.GetScript, document)
			if ok and instance and self.connections[instance] then
				self.onChanged(instance, ORIGINS.EDITOR)
			end
		end)
	end
end

function SourceWatcher:watch(instance)
	if self.connections[instance] or not Constants.SCRIPT_CLASSES[instance.ClassName] or not self.isObserved(instance) then
		return
	end
	self.connections[instance] = instance:GetPropertyChangedSignal(Constants.PROPERTY_NAMES.SOURCE):Connect(function()
		if self.onChanged then
			self.onChanged(instance, ORIGINS.SOURCE)
		end
	end)
end

function SourceWatcher:unwatch(instance)
	local connection = self.connections[instance]
	if connection then
		connection:Disconnect()
		self.connections[instance] = nil
	end
end

function SourceWatcher:isWatching(instance)
	return self.connections[instance] ~= nil
end

function SourceWatcher.readSource(instance)
	local ok, document = pcall(ScriptEditorService.FindScriptDocument, ScriptEditorService, instance)
	if ok and document then
		local textOk, text = pcall(document.GetText, document)
		if textOk and type(text) == Constants.TYPE_NAMES.STRING then
			return text
		end
	end
	return instance[Constants.PROPERTY_NAMES.SOURCE]
end

function SourceWatcher.writeSource(instance, source)
	local ok = pcall(ScriptEditorService.UpdateSourceAsync, ScriptEditorService, instance, function()
		return source
	end)
	if not ok then
		instance[Constants.PROPERTY_NAMES.SOURCE] = source
	end
end

function SourceWatcher:stop()
	if self.documentConnection then
		self.documentConnection:Disconnect()
		self.documentConnection = nil
	end
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	self.onChanged = nil
end

return SourceWatcher

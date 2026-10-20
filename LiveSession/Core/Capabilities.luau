local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Constants)

local Capabilities = {}

local function probe(check)
	local ok, result = pcall(check)
	return ok and result == true
end

function Capabilities.detect(plugin)
	local detected = {}
	detected.loadstring = probe(function()
		return typeof(loadstring(Constants.CAPABILITY_PROBE_CHUNK)) == Constants.TYPE_NAMES.FUNCTION
	end)
	detected.setfenv = probe(function()
		local chunk = loadstring(Constants.CAPABILITY_PROBE_CHUNK)
		setfenv(chunk, { marker = Constants.CAPABILITY_PROBE_MARKER })
		return chunk() == Constants.CAPABILITY_PROBE_MARKER
	end)
	detected.stepPhysics = probe(function()
		return typeof(workspace.StepPhysics) == Constants.TYPE_NAMES.FUNCTION
	end)
	detected.changeHistoryRecording = probe(function()
		return typeof(ChangeHistoryService.OnRecordingStarted) == Constants.TYPE_NAMES.SIGNAL
			and typeof(ChangeHistoryService.OnRecordingFinished) == Constants.TYPE_NAMES.SIGNAL
	end)
	detected.textDocumentDidChange = probe(function()
		return typeof(ScriptEditorService.TextDocumentDidChange) == Constants.TYPE_NAMES.SIGNAL
	end)
	detected.pluginSettings = probe(function()
		plugin:SetSetting(Constants.SETTINGS.PROBE, true)
		local stored = plugin:GetSetting(Constants.SETTINGS.PROBE)
		plugin:SetSetting(Constants.SETTINGS.PROBE, nil)
		return stored == true
	end)
	detected.createLocalPlayer = probe(function()
		return typeof(Players.CreateLocalPlayer) == Constants.TYPE_NAMES.FUNCTION
	end)
	detected.runMode = probe(function()
		return typeof(RunService.Run) == Constants.TYPE_NAMES.FUNCTION
			and typeof(RunService.Stop) == Constants.TYPE_NAMES.FUNCTION
			and typeof(RunService.IsRunning) == Constants.TYPE_NAMES.FUNCTION
	end)
	detected.fallbacks = {}
	for name, text in pairs(Constants.CAPABILITY_FALLBACKS) do
		if not detected[name] then
			table.insert(detected.fallbacks, text)
		end
	end
	return detected
end

function Capabilities.missingRequired(detected)
	local missing = {}
	for _, name in ipairs(Constants.REQUIRED_CAPABILITIES) do
		if not detected[name] then
			table.insert(missing, name)
		end
	end
	return missing
end

return Capabilities

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(script.Parent.Parent.Core.Constants)

local StressSuite = {}

local STRESS = Constants.STRESS
local CLASSES = Constants.CLASS_NAMES

local function folderIn(parent)
	local folder = parent:FindFirstChild(STRESS.FOLDER_NAME)
	if not folder then
		folder = Instance.new(CLASSES.FOLDER)
		folder.Name = STRESS.FOLDER_NAME
		folder.Parent = parent
	end
	return folder
end

local function yieldEvery(counter)
	if counter % STRESS.BUILD_BATCH == 0 then
		task.wait()
	end
end

function StressSuite.memoryMb()
	return math.floor(gcinfo() / Constants.KILOBYTES_PER_MEGABYTE)
end

function StressSuite.buildInstances(count)
	local root = folderIn(workspace)
	local built = 0
	local modelIndex = 0
	while built < count do
		modelIndex += 1
		local model = Instance.new(CLASSES.MODEL)
		model.Name = string.format(STRESS.MODEL_NAME_FORMAT, modelIndex)
		for partIndex = 1, math.min(STRESS.PARTS_PER_MODEL, count - built) do
			local part = Instance.new(CLASSES.PART)
			part.Anchored = true
			part.Size = STRESS.PART_SIZE
			part.Position = Vector3.new(partIndex * STRESS.PART_SPACING, modelIndex * STRESS.PART_SPACING, 0)
			part.Parent = model
			built += 1
			yieldEvery(built)
		end
		model.Parent = root
	end
	return built
end

function StressSuite.buildScripts(count)
	local root = folderIn(ServerScriptService)
	for index = 1, count do
		local scriptInstance = Instance.new(CLASSES.SCRIPT)
		scriptInstance.Name = string.format(STRESS.SCRIPT_NAME_FORMAT, index)
		scriptInstance.Source = string.format(STRESS.SCRIPT_SOURCE_FORMAT, index)
		scriptInstance.Parent = root
		yieldEvery(index)
	end
	return count
end

function StressSuite.buildRemotes(count)
	local root = folderIn(ReplicatedStorage)
	for index = 1, count do
		local remote = Instance.new(STRESS.REMOTE_CLASS)
		remote.Name = string.format(STRESS.REMOTE_NAME_FORMAT, index)
		remote.Parent = root
	end
	return count
end

function StressSuite.build(options)
	options = options or {}
	local startedAt = os.clock()
	local instances = StressSuite.buildInstances(options.instances or STRESS.INSTANCES)
	local scripts = StressSuite.buildScripts(options.scripts or STRESS.SCRIPTS)
	local remotes = StressSuite.buildRemotes(options.remotes or STRESS.REMOTES)
	return string.format(STRESS.REPORT_FORMAT, instances, scripts, remotes, os.clock() - startedAt, StressSuite.memoryMb())
end

function StressSuite.touchScripts(count)
	local root = ServerScriptService:FindFirstChild(STRESS.FOLDER_NAME)
	if not root then
		return 0
	end
	local touched = 0
	for _, child in ipairs(root:GetChildren()) do
		if touched >= count then
			break
		end
		child.Source = string.format(STRESS.SCRIPT_SOURCE_FORMAT, os.time() + touched)
		touched += 1
	end
	return touched
end

function StressSuite.runReloadLoop(seconds, scriptsPerReload)
	local baselineMb = StressSuite.memoryMb()
	local deadline = os.clock() + seconds
	local reloads = 0
	while os.clock() < deadline do
		StressSuite.touchScripts(scriptsPerReload)
		reloads += 1
		task.wait(STRESS.RELOAD_INTERVAL_SECONDS)
	end
	return { reloads = reloads, growthMb = StressSuite.memoryMb() - baselineMb, limitMb = Constants.MEMORY_GROWTH_WARN_MB }
end

function StressSuite.teardown()
	for _, parent in ipairs({ workspace, ServerScriptService, ReplicatedStorage }) do
		local folder = parent:FindFirstChild(STRESS.FOLDER_NAME)
		if folder then
			folder:Destroy()
		end
	end
end

return StressSuite

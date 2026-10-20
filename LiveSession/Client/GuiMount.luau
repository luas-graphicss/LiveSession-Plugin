local StarterGui = game:GetService("StarterGui")

local Constants = require(script.Parent.Parent.Core.Constants)
local StarterClone = require(script.Parent.StarterClone)

local GuiMount = {}
GuiMount.__index = GuiMount

function GuiMount.new(tracker, owner, onScripts)
	return setmetatable({
		tracker = tracker,
		owner = owner,
		onScripts = onScripts,
		playerGui = nil,
		mounted = {},
	}, GuiMount)
end

function GuiMount:resetsOnSpawn(original)
	return original:IsA(Constants.CLASS_NAMES.LAYER_COLLECTOR) and original.ResetOnSpawn
end

function GuiMount:mount(playerGui)
	self.playerGui = playerGui
	local clones, pairs_ = StarterClone.children(StarterGui, playerGui, self.tracker, self.owner)
	self.mounted = clones
	self.onScripts(pairs_)
end

function GuiMount:respawn()
	if not self.playerGui then
		return
	end
	local pairs_ = {}
	for _, entry in ipairs(self.mounted) do
		if self:resetsOnSpawn(entry.original) then
			if entry.clone.Parent then
				entry.clone:Destroy()
			end
			local clone, clonePairs = StarterClone.one(entry.original, self.playerGui, self.tracker, self.owner)
			entry.clone = clone
			table.move(clonePairs, 1, #clonePairs, #pairs_ + 1, pairs_)
		end
	end
	self.onScripts(pairs_)
end

function GuiMount:count()
	local count = 0
	for _, entry in ipairs(self.mounted) do
		if entry.clone and entry.clone.Parent then
			count += 1
		end
	end
	return count
end

function GuiMount:unmount()
	self.mounted = {}
	self.playerGui = nil
end

return GuiMount

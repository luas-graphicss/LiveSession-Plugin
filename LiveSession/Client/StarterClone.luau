local Constants = require(script.Parent.Parent.Core.Constants)

local StarterClone = {}

local PROPERTIES = Constants.PROPERTY_NAMES

local function pairScripts(original, clone, pairs_)
	local cloneChildren = clone:GetChildren()
	local cloneIndex = 1
	for _, child in ipairs(original:GetChildren()) do
		if child[PROPERTIES.ARCHIVABLE] then
			local cloneChild = cloneChildren[cloneIndex]
			cloneIndex += 1
			if cloneChild then
				if child:IsA(Constants.CLASS_NAMES.LUA_SOURCE_CONTAINER) then
					table.insert(pairs_, { clone = cloneChild, original = child })
				end
				pairScripts(child, cloneChild, pairs_)
			end
		end
	end
end

function StarterClone.one(original, parent, tracker, owner)
	if not original[PROPERTIES.ARCHIVABLE] then
		return nil, {}
	end
	local clone = original:Clone()
	local pairs_ = {}
	if original:IsA(Constants.CLASS_NAMES.LUA_SOURCE_CONTAINER) then
		table.insert(pairs_, { clone = clone, original = original })
	end
	pairScripts(original, clone, pairs_)
	tracker:addInstance(owner, clone)
	clone.Parent = parent
	return clone, pairs_
end

function StarterClone.pairsOf(original, clone)
	local pairs_ = {}
	if original and clone then
		pairScripts(original, clone, pairs_)
	end
	return pairs_
end

function StarterClone.children(container, parent, tracker, owner)
	local clones = {}
	local pairs_ = {}
	if not container then
		return clones, pairs_
	end
	for _, child in ipairs(container:GetChildren()) do
		local clone, childPairs = StarterClone.one(child, parent, tracker, owner)
		if clone then
			table.insert(clones, { clone = clone, original = child })
			table.move(childPairs, 1, #childPairs, #pairs_ + 1, pairs_)
		end
	end
	return clones, pairs_
end

return StarterClone

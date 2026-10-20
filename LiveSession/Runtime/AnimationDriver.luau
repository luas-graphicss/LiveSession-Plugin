local Constants = require(script.Parent.Parent.Core.Constants)

local AnimationDriver = {}
AnimationDriver.__index = AnimationDriver

local CLASSES = Constants.CLASS_NAMES
local BRIDGES = Constants.BRIDGES

local function animatorOf(instance)
	if instance:IsA(CLASSES.ANIMATOR) then
		return instance
	end
	return instance:FindFirstChildOfClass(CLASSES.ANIMATOR)
end

local function isAnimated(instance)
	for _, className in ipairs(BRIDGES.ANIMATION_CLASSES) do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

function AnimationDriver.new(onError)
	return setmetatable({
		onError = onError,
		animators = {},
		bridgeTable = nil,
	}, AnimationDriver)
end

function AnimationDriver:bridge()
	if not self.bridgeTable then
		self.bridgeTable = {
			name = BRIDGES.ANIMATION,
			matches = isAnimated,
			afterCall = function(methodName, instance)
				if methodName == BRIDGES.LOAD_ANIMATION then
					self:track(instance)
				end
			end,
		}
	end
	return self.bridgeTable
end

function AnimationDriver:track(instance)
	local animator = animatorOf(instance)
	if animator then
		self.animators[animator] = true
	end
end

function AnimationDriver:step(deltaSeconds)
	for animator in pairs(self.animators) do
		if animator.Parent == nil then
			self.animators[animator] = nil
		else
			local ok, err = pcall(animator.StepAnimations, animator, deltaSeconds)
			if not ok then
				self.animators[animator] = nil
				self.onError(string.format(Constants.ERRORS.STEP_ANIMATIONS, animator:GetFullName(), tostring(err)))
			end
		end
	end
end

function AnimationDriver:count()
	local count = 0
	for _ in pairs(self.animators) do
		count += 1
	end
	return count
end

function AnimationDriver:clear()
	self.animators = {}
end

return AnimationDriver

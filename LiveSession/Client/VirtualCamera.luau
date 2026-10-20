local Constants = require(script.Parent.Parent.Core.Constants)

local VirtualCamera = {}
VirtualCamera.__index = VirtualCamera

local MEMBERS = Constants.CAMERA_MEMBERS
local CONTROLLER = Constants.CONTROLLER
local CLASSES = Constants.CLASS_NAMES
local RIG = Constants.RIG

local function humanoidFocus(humanoid)
	local character = humanoid.Parent
	local root = humanoid.RootPart or (character and character:FindFirstChild(RIG.ROOT_NAME))
	if not root then
		return nil
	end
	return (root.CFrame * CFrame.new(CONTROLLER.SUBJECT_OFFSET + humanoid.CameraOffset)).Position
end

function VirtualCamera.new(proxy)
	return setmetatable({
		proxy = proxy,
		camera = nil,
		cameraType = CONTROLLER.DEFAULT_CAMERA_TYPE,
		subject = nil,
	}, VirtualCamera)
end

function VirtualCamera:attach(camera)
	self.camera = camera
	self.cameraType = CONTROLLER.DEFAULT_CAMERA_TYPE
	self.subject = nil
	self.proxy:override(camera, {
		[MEMBERS.CAMERA_TYPE] = function()
			return self.cameraType
		end,
		[MEMBERS.CAMERA_SUBJECT] = function()
			return self.proxy:wrap(self.subject)
		end,
	}, {
		[MEMBERS.CAMERA_TYPE] = function(value)
			self.cameraType = value
		end,
		[MEMBERS.CAMERA_SUBJECT] = function(value)
			self.subject = value
		end,
	})
end

function VirtualCamera:setDefaultSubject(humanoid)
	self.subject = humanoid
end

function VirtualCamera:isDefaultActive()
	return self.cameraType ~= CONTROLLER.GAME_DRIVEN_CAMERA_TYPE
end

function VirtualCamera:subjectPosition()
	local subject = self.subject
	if subject == nil or subject.Parent == nil then
		return nil
	end
	if subject:IsA(CLASSES.HUMANOID) then
		return humanoidFocus(subject)
	end
	if subject:IsA(CLASSES.BASE_PART) then
		return subject.Position
	end
	if subject:IsA(CLASSES.MODEL) then
		return subject:GetPivot().Position
	end
	return nil
end

function VirtualCamera:detach()
	if self.camera then
		self.proxy:clearOverrides(self.camera)
	end
	self.camera = nil
	self.subject = nil
end

return VirtualCamera

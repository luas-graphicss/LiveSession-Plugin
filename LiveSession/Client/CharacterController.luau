local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Core.Constants)
local PlayerModuleShim = require(script.Parent.PlayerModuleShim)

local CharacterController = {}
CharacterController.__index = CharacterController

local CONTROLLER = Constants.CONTROLLER
local RIG = Constants.RIG
local MEMBERS = Constants.PLAYER_MEMBERS

local function cameraYaw(camera)
	local look = camera.CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end

function CharacterController.new(input, capabilities, virtualCamera)
	return setmetatable({
		input = input,
		capabilities = capabilities,
		virtualCamera = virtualCamera,
		virtualPlayer = nil,
		humanoid = nil,
		root = nil,
		yaw = 0,
		pitch = CONTROLLER.INITIAL_PITCH,
		zoom = CONTROLLER.DEFAULT_ZOOM,
		subject = nil,
		saved = nil,
		connection = nil,
	}, CharacterController)
end

function CharacterController:start(virtualPlayer)
	local camera = workspace.CurrentCamera
	self.virtualPlayer = virtualPlayer
	self.saved = { cameraType = camera.CameraType, cframe = camera.CFrame, focus = camera.Focus }
	self.yaw = cameraYaw(camera)
	self.subject = camera.Focus.Position
	self.zoom = self:clampZoom(CONTROLLER.DEFAULT_ZOOM)
	camera.CameraType = CONTROLLER.CAMERA_TYPE
	self.virtualCamera:attach(camera)
	virtualPlayer:onCharacterChanged(function(model)
		self:setCharacter(model)
	end)
	self.connection = RunService.RenderStepped:Connect(function(deltaSeconds)
		self:step(deltaSeconds)
	end)
end

function CharacterController:setCharacter(model)
	if not model then
		self.humanoid = nil
		self.root = nil
		return
	end
	self.humanoid = model:FindFirstChildOfClass(Constants.CLASS_NAMES.HUMANOID)
	self.root = model:FindFirstChild(RIG.ROOT_NAME) or model.PrimaryPart
	self.virtualCamera:setDefaultSubject(self.humanoid)
end

function CharacterController:clampZoom(zoom)
	local minZoom = self.virtualPlayer:property(MEMBERS.CAMERA_MIN_ZOOM_DISTANCE)
	local maxZoom = self.virtualPlayer:property(MEMBERS.CAMERA_MAX_ZOOM_DISTANCE)
	return math.clamp(zoom, math.min(minZoom, maxZoom), math.max(minZoom, maxZoom))
end

function CharacterController:isFirstPerson()
	return self.zoom <= CONTROLLER.FIRST_PERSON_ZOOM
		or self.virtualPlayer:property(MEMBERS.CAMERA_MODE) == CONTROLLER.CAMERA_MODE_FIRST_PERSON
end

function CharacterController:readLook(cameraActive)
	local input = self.input
	local delta = input:consumeMouseDelta()
	local zoomDelta = input:consumeZoomDelta()
	if not cameraActive or not input:isActive() then
		return
	end
	local rotating = input:isRotating() or self:isFirstPerson()
	if rotating then
		self.yaw -= delta.X * CONTROLLER.MOUSE_SENSITIVITY
		self.pitch = math.clamp(self.pitch - delta.Y * CONTROLLER.MOUSE_SENSITIVITY, -CONTROLLER.PITCH_LIMIT, CONTROLLER.PITCH_LIMIT)
	end
	input:setMouseLocked(rotating)
	self.zoom = self:clampZoom(self.zoom - zoomDelta * CONTROLLER.ZOOM_STEP)
end

function CharacterController:moveVector()
	if not self.input:isActive() then
		return Vector3.zero
	end
	local x, z = self.input:moveAxes()
	if x == 0 and z == 0 then
		return Vector3.zero
	end
	return Vector3.new(x, 0, z).Unit
end

function CharacterController:move(camera, deltaSeconds, moveVector)
	local humanoid = self.humanoid
	local root = self.root
	if not humanoid or not root or not root.Parent then
		return
	end
	local direction = CFrame.fromEulerAnglesYXZ(0, cameraYaw(camera), 0):VectorToWorldSpace(moveVector)
	humanoid:Move(direction, false)
	if self.input:consumeJump() then
		humanoid.Jump = true
	end
	if not self.capabilities.stepPhysics and direction.Magnitude > CONTROLLER.MOVE_EPSILON then
		local facing = math.atan2(-direction.X, -direction.Z)
		root.CFrame = CFrame.new(root.Position + direction * humanoid.WalkSpeed * deltaSeconds) * CFrame.fromEulerAnglesYXZ(0, facing, 0)
	end
end

function CharacterController:placeCamera(camera)
	self.subject = self.virtualCamera:subjectPosition() or self.subject
	local rotation = CFrame.fromEulerAnglesYXZ(self.pitch, self.yaw, 0)
	local subject = CFrame.new(self.subject)
	if self:isFirstPerson() then
		camera.CFrame = subject * rotation
	else
		camera.CFrame = subject * rotation * CFrame.new(0, 0, self.zoom)
	end
	camera.Focus = subject
end

function CharacterController:step(deltaSeconds)
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= CONTROLLER.CAMERA_TYPE then
		camera.CameraType = CONTROLLER.CAMERA_TYPE
	end
	local controls = self.virtualPlayer:controls()
	local cameraActive = controls ~= nil and self.virtualCamera:isDefaultActive()
	self:readLook(cameraActive)
	if controls then
		local moveVector = self:moveVector()
		PlayerModuleShim.setMoveVector(controls, moveVector)
		if PlayerModuleShim.controlsEnabled(controls) then
			self:move(camera, deltaSeconds, moveVector)
		end
	end
	if cameraActive then
		self:placeCamera(camera)
	end
end

function CharacterController:stop()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	self.virtualCamera:detach()
	self.input:setMouseLocked(false)
	local camera = workspace.CurrentCamera
	if self.saved and camera then
		camera.CameraType = self.saved.cameraType
		camera.CFrame = self.saved.cframe
		camera.Focus = self.saved.focus
	end
	self.saved = nil
	self.humanoid = nil
	self.root = nil
	self.virtualPlayer = nil
end

return CharacterController

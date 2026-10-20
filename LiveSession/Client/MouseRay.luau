local UserInputService = game:GetService("UserInputService")

local Constants = require(script.Parent.Parent.Core.Constants)

local MouseRay = {}
MouseRay.__index = MouseRay

local INPUT = Constants.INPUT

function MouseRay.new(getCharacter)
	local params = RaycastParams.new()
	params.FilterType = INPUT.RAY_FILTER_TYPE
	return setmetatable({
		getCharacter = getCharacter,
		params = params,
		filteredCharacter = nil,
	}, MouseRay)
end

function MouseRay:screenPosition()
	return UserInputService:GetMouseLocation()
end

function MouseRay:updateFilter()
	local character = self.getCharacter()
	if character ~= self.filteredCharacter then
		self.filteredCharacter = character
		self.params.FilterDescendantsInstances = character and { character } or {}
	end
end

function MouseRay:cast(maxDistance)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	self:updateFilter()
	local position = self:screenPosition()
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	return workspace:Raycast(ray.Origin, ray.Direction * (maxDistance or INPUT.RAY_MAX_DISTANCE), self.params)
end

return MouseRay

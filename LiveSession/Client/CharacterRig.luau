local Constants = require(script.Parent.Parent.Core.Constants)

local CharacterRig = {}

local RIG = Constants.RIG
local CLASSES = Constants.CLASS_NAMES

local function part(name, size, color, parent)
	local instance = Instance.new(CLASSES.PART)
	instance.Name = name
	instance.Size = size
	instance.Color = color
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Parent = parent
	return instance
end

local function motor(name, part0, part1, offset, parent)
	local joint = Instance.new(CLASSES.MOTOR6D)
	joint.Name = name
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = CFrame.new(offset)
	joint.Parent = parent
	return joint
end

function CharacterRig.build(name)
	local model = Instance.new(CLASSES.MODEL)
	model.Name = name
	local root = part(RIG.ROOT_NAME, RIG.TORSO_SIZE, RIG.COLOR, model)
	root.Transparency = RIG.ROOT_TRANSPARENCY
	root.CanCollide = false
	local torso = part(RIG.TORSO_NAME, RIG.TORSO_SIZE, RIG.COLOR, model)
	local head = part(RIG.HEAD_NAME, RIG.HEAD_SIZE, RIG.COLOR, model)
	motor(RIG.ROOT_MOTOR_NAME, root, torso, Vector3.zero, root)
	motor(RIG.NECK_NAME, torso, head, RIG.HEAD_OFFSET, torso)
	for _, limb in ipairs(RIG.LIMBS) do
		local limbPart = part(limb.name, RIG.LIMB_SIZE, RIG.COLOR, model)
		motor(string.format(RIG.MOTOR_FORMAT, limb.name), torso, limbPart, limb.offset, torso)
	end
	local humanoid = Instance.new(CLASSES.HUMANOID)
	humanoid.RigType = RIG.RIG_TYPE
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

return CharacterRig

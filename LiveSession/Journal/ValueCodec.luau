local Constants = require(script.Parent.Parent.Core.Constants)

local ValueCodec = {}

local TYPES = Constants.TYPE_NAMES

local encoders = {
	[TYPES.NIL] = function()
		return nil
	end,
	[TYPES.NUMBER] = function(value)
		return value
	end,
	[TYPES.STRING] = function(value)
		return value
	end,
	[TYPES.BOOLEAN] = function(value)
		return value
	end,
	Color3 = function(value)
		return { value.R, value.G, value.B }
	end,
	Vector3 = function(value)
		return { value.X, value.Y, value.Z }
	end,
	Vector2 = function(value)
		return { value.X, value.Y }
	end,
	CFrame = function(value)
		return { value:GetComponents() }
	end,
	UDim = function(value)
		return { value.Scale, value.Offset }
	end,
	UDim2 = function(value)
		return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	end,
	EnumItem = function(value)
		return { tostring(value.EnumType), value.Name }
	end,
	BrickColor = function(value)
		return value.Number
	end,
	NumberRange = function(value)
		return { value.Min, value.Max }
	end,
	Rect = function(value)
		return { value.Min.X, value.Min.Y, value.Max.X, value.Max.Y }
	end,
	Instance = function(value, idOf)
		return idOf(value)
	end,
	 
	 
	ColorSequence = function(value)
		local keypoints = {}
		for _, keypoint in ipairs(value.Keypoints) do
			table.insert(keypoints, { keypoint.Time, keypoint.Value.R, keypoint.Value.G, keypoint.Value.B })
		end
		return keypoints
	end,
	NumberSequence = function(value)
		local keypoints = {}
		for _, keypoint in ipairs(value.Keypoints) do
			table.insert(keypoints, { keypoint.Time, keypoint.Value, keypoint.Envelope })
		end
		return keypoints
	end,
	Font = function(value)
		return { value.Family, value.Weight.Name, value.Style.Name }
	end,
	PhysicalProperties = function(value)
		return { value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight }
	end,
	Vector3int16 = function(value)
		return { value.X, value.Y, value.Z }
	end,
	Vector2int16 = function(value)
		return { value.X, value.Y }
	end,
	Faces = function(value)
		return { value.Top, value.Bottom, value.Left, value.Right, value.Back, value.Front }
	end,
	Axes = function(value)
		return { value.X, value.Y, value.Z }
	end,
	Content = function(value)
		if value.SourceType ~= Enum.ContentSourceType.Uri then
			error("Content sem Uri (objeto em memoria) nao e serializavel", 0)
		end
		return value.Uri
	end,
}

local decoders = {
	[TYPES.NUMBER] = function(raw)
		return raw
	end,
	[TYPES.STRING] = function(raw)
		return raw
	end,
	[TYPES.BOOLEAN] = function(raw)
		return raw
	end,
	Color3 = function(raw)
		return Color3.new(raw[1], raw[2], raw[3])
	end,
	Vector3 = function(raw)
		return Vector3.new(raw[1], raw[2], raw[3])
	end,
	Vector2 = function(raw)
		return Vector2.new(raw[1], raw[2])
	end,
	CFrame = function(raw)
		return CFrame.new(table.unpack(raw))
	end,
	UDim = function(raw)
		return UDim.new(raw[1], raw[2])
	end,
	UDim2 = function(raw)
		return UDim2.new(raw[1], raw[2], raw[3], raw[4])
	end,
	EnumItem = function(raw)
		return Enum[raw[1]][raw[2]]
	end,
	BrickColor = function(raw)
		return BrickColor.new(raw)
	end,
	NumberRange = function(raw)
		return NumberRange.new(raw[1], raw[2])
	end,
	Rect = function(raw)
		return Rect.new(raw[1], raw[2], raw[3], raw[4])
	end,
	Instance = function(raw, resolve)
		return resolve(raw)
	end,
	ColorSequence = function(raw)
		local keypoints = {}
		for _, point in ipairs(raw) do
			table.insert(keypoints, ColorSequenceKeypoint.new(point[1], Color3.new(point[2], point[3], point[4])))
		end
		return ColorSequence.new(keypoints)
	end,
	NumberSequence = function(raw)
		local keypoints = {}
		for _, point in ipairs(raw) do
			table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2], point[3] or 0))
		end
		return NumberSequence.new(keypoints)
	end,
	Font = function(raw)
		return Font.new(raw[1], Enum.FontWeight[raw[2]], Enum.FontStyle[raw[3]])
	end,
	PhysicalProperties = function(raw)
		return PhysicalProperties.new(raw[1], raw[2], raw[3], raw[4], raw[5])
	end,
	Vector3int16 = function(raw)
		return Vector3int16.new(raw[1], raw[2], raw[3])
	end,
	Vector2int16 = function(raw)
		return Vector2int16.new(raw[1], raw[2])
	end,
	Faces = function(raw)
		local faces = {}
		for index, name in ipairs({ "Top", "Bottom", "Left", "Right", "Back", "Front" }) do
			if raw[index] then
				table.insert(faces, Enum.NormalId[name])
			end
		end
		return Faces.new(table.unpack(faces))
	end,
	Axes = function(raw)
		local axes = {}
		for index, name in ipairs({ "X", "Y", "Z" }) do
			if raw[index] then
				table.insert(axes, Enum.Axis[name])
			end
		end
		return Axes.new(table.unpack(axes))
	end,
	Content = function(raw)
		return Content.fromUri(raw)
	end,
}

function ValueCodec.encode(value, idOf)
	local kind = typeof(value)
	local encoder = encoders[kind]
	if not encoder then
		return nil, string.format(Constants.ERRORS.UNSUPPORTED_VALUE, kind)
	end
	if kind == TYPES.INSTANCE and not idOf(value) then
		return nil, string.format(Constants.ERRORS.UNSUPPORTED_VALUE, kind)
	end
	local ok, encoded = pcall(encoder, value, idOf)
	if not ok then
		return nil, tostring(encoded)
	end
	return { t = kind, v = encoded }
end

function ValueCodec.decode(encoded, resolve)
	if type(encoded) ~= TYPES.TABLE or type(encoded.t) ~= TYPES.STRING then
		return nil, string.format(Constants.ERRORS.UNSUPPORTED_VALUE, tostring(encoded))
	end
	if encoded.t == TYPES.NIL then
		return nil
	end
	local decoder = decoders[encoded.t]
	if not decoder then
		return nil, string.format(Constants.ERRORS.UNSUPPORTED_VALUE, encoded.t)
	end
	local ok, value = pcall(decoder, encoded.v, resolve)
	if not ok then
		return nil, value
	end
	return value
end

return ValueCodec

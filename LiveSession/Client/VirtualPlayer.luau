local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPack = game:GetService("StarterPack")
local Teams = game:GetService("Teams")

local Constants = require(script.Parent.Parent.Core.Constants)
local TeamCreate = require(script.Parent.Parent.Core.TeamCreate)
local HostedSignal = require(script.Parent.Parent.Runtime.HostedSignal)
local StarterClone = require(script.Parent.StarterClone)
local CharacterRig = require(script.Parent.CharacterRig)
local GuiMount = require(script.Parent.GuiMount)
local PlayerModuleShim = require(script.Parent.PlayerModuleShim)
local PlayerMembers = require(script.Parent.PlayerMembers)
local ContainerMembers = require(script.Parent.ContainerMembers)

local VirtualPlayer = {}
VirtualPlayer.__index = VirtualPlayer

local CLIENT = Constants.CLIENT
local CONTEXTS = Constants.CONTEXTS
local MEMBERS = Constants.PLAYER_MEMBERS
local CLASSES = Constants.CLASS_NAMES
local TEXTS = Constants.TEXTS
local ERRORS = Constants.ERRORS
local UNKNOWN_NAME = Constants.TEAM_CREATE.UNKNOWN_NAME

local function folder(name, parent)
	local instance = Instance.new(CLASSES.FOLDER)
	instance.Name = name
	instance.Parent = parent
	return instance
end

function VirtualPlayer.new(deps)
	local self = setmetatable({
		deps = deps,
		owner = { name = CLIENT.OWNER_NAME, context = CONTEXTS.CLIENT },
		playerAdded = HostedSignal.new(deps.tracker),
		playerRemoving = HostedSignal.new(deps.tracker),
		characterAdded = HostedSignal.new(deps.tracker),
		characterRemoving = HostedSignal.new(deps.tracker),
		appearanceLoaded = HostedSignal.new(deps.tracker),
		characterObservers = {},
		playerModule = nil,
		character = nil,
		humanoid = nil,
		diedConnection = nil,
		prepared = false,
		joined = false,
		active = false,
		spawnCount = 0,
		userId = CLIENT.DEFAULT_USER_ID,
		name = CLIENT.DEFAULT_PLAYER_NAME,
	}, VirtualPlayer)
	self.guiMount = GuiMount.new(deps.tracker, self.owner, deps.onScripts)
	self.members = PlayerMembers.new(deps.tracker, self)
	return self
end

function VirtualPlayer:onCharacterChanged(callback)
	table.insert(self.characterObservers, callback)
end

function VirtualPlayer:notifyCharacter(model)
	for _, callback in ipairs(self.characterObservers) do
		callback(model)
	end
end

function VirtualPlayer:resolveIdentity()
	local identity = TeamCreate.identity()
	if identity.userId > 0 then
		self.userId = identity.userId
	end
	if identity.name ~= UNKNOWN_NAME then
		self.name = identity.name
	end
end

function VirtualPlayer:virtualizeClass(container, className)
	local classes = CLIENT.CONTAINER_CLASSES[className]
	self.deps.proxy:override(container, {
		[MEMBERS.CLASS_NAME] = function()
			return className
		end,
		[MEMBERS.IS_A] = function()
			return function(_, name)
				return classes[name] == true
			end
		end,
	})
	local members = ContainerMembers.new(self.deps.tracker, className)
	if members then
		self.deps.proxy:overrideFallback(container, members)
	end
end

function VirtualPlayer:createContainers()
	local root = Instance.new(CLASSES.FOLDER)
	root.Name = CLIENT.ROOT_NAME
	self.deps.tracker:addInstance(self.owner, root)
	root.Parent = CoreGui
	self.root = root
	self.playerFolder = folder(self.name, root)
	self.playerGui = folder(CLIENT.PLAYER_GUI, self.playerFolder)
	self.backpack = folder(CLIENT.BACKPACK, self.playerFolder)
	self.playerScripts = folder(CLIENT.PLAYER_SCRIPTS, self.playerFolder)
	self.containers = {
		[CLIENT.PLAYER_GUI] = self.playerGui,
		[CLIENT.BACKPACK] = self.backpack,
		[CLIENT.PLAYER_SCRIPTS] = self.playerScripts,
	}
	for className, container in pairs(self.containers) do
		self:virtualizeClass(container, className)
	end
	self.playerProxy = self.deps.proxy:wrap(self.playerFolder)
end

function VirtualPlayer:playerIf(condition)
	if self.joined and condition then
		return self.playerProxy
	end
	return nil
end

function VirtualPlayer:playerList()
	if self.joined then
		return { self.playerProxy }
	end
	return {}
end

function VirtualPlayer:containerOfClass(className)
	local container = self.containers[className]
	if container then
		return self.deps.proxy:wrap(container)
	end
	return nil
end

function VirtualPlayer:registerPlayersOverrides()
	local proxy = self.deps.proxy
	local playerProxy = self.playerProxy
	local function listMethod()
		return function()
			return self:playerList()
		end
	end
	proxy:override(Players, {
		[MEMBERS.LOCAL_PLAYER] = function()
			return playerProxy
		end,
		[MEMBERS.GET_PLAYERS] = listMethod,
		[MEMBERS.GET_CHILDREN] = listMethod,
		[MEMBERS.GET_DESCENDANTS] = function()
			return function()
				local list = self:playerList()
				if self.joined then
					for _, descendant in ipairs(self.playerFolder:GetDescendants()) do
						table.insert(list, proxy:wrap(descendant))
					end
				end
				return list
			end
		end,
		[MEMBERS.FIND_FIRST_CHILD] = function()
			return function(_, name)
				return self:playerIf(name == self.name)
			end
		end,
		[MEMBERS.FIND_FIRST_CHILD_OF_CLASS] = function()
			return function(_, className)
				return self:playerIf(className == CLASSES.PLAYER)
			end
		end,
		[MEMBERS.FIND_FIRST_CHILD_WHICH_IS_A] = function()
			return function(_, className)
				return self:playerIf(className == CLASSES.PLAYER or className == CLASSES.INSTANCE)
			end
		end,
		[MEMBERS.GET_PLAYER_FROM_CHARACTER] = function()
			return function(_, model)
				return self:playerIf(model ~= nil and proxy:unwrap(model) == self.character)
			end
		end,
		[MEMBERS.GET_PLAYER_BY_USER_ID] = function()
			return function(_, userId)
				return self:playerIf(userId == self.userId)
			end
		end,
		[MEMBERS.PLAYER_ADDED] = function()
			return self.playerAdded:interface()
		end,
		[MEMBERS.CHILD_ADDED] = function()
			return self.playerAdded:interface()
		end,
		[MEMBERS.PLAYER_REMOVING] = function()
			return self.playerRemoving:interface()
		end,
		[MEMBERS.CHILD_REMOVED] = function()
			return self.playerRemoving:interface()
		end,
	})
	proxy:overrideForContext(CONTEXTS.SERVER, Players, {
		[MEMBERS.LOCAL_PLAYER] = function()
			return nil
		end,
	})
end

function VirtualPlayer:registerPlayerOverrides()
	local proxy = self.deps.proxy
	proxy:override(self.playerFolder, {
		[MEMBERS.CLASS_NAME] = function()
			return CLASSES.PLAYER
		end,
		[MEMBERS.IS_A] = function()
			return function(_, className)
				return className == CLASSES.PLAYER or className == CLASSES.INSTANCE
			end
		end,
		[MEMBERS.FIND_FIRST_CHILD_OF_CLASS] = function()
			return function(_, className)
				return self:containerOfClass(className)
			end
		end,
		[MEMBERS.FIND_FIRST_CHILD_WHICH_IS_A] = function()
			return function(_, className)
				return self:containerOfClass(className)
			end
		end,
		[MEMBERS.DISPLAY_NAME] = function()
			return self.name
		end,
		[MEMBERS.USER_ID] = function()
			return self.userId
		end,
		[MEMBERS.CHARACTER] = function()
			if self.character then
				return proxy:wrap(self.character)
			end
			return nil
		end,
		[MEMBERS.CHARACTER_ADDED] = function()
			return self.characterAdded:interface()
		end,
		[MEMBERS.CHARACTER_REMOVING] = function()
			return self.characterRemoving:interface()
		end,
		[MEMBERS.CHARACTER_APPEARANCE_LOADED] = function()
			return self.appearanceLoaded:interface()
		end,
		[MEMBERS.HAS_APPEARANCE_LOADED] = function()
			return function()
				return self.character ~= nil
			end
		end,
		[MEMBERS.LOAD_CHARACTER] = function()
			return function()
				self:loadCharacter()
			end
		end,
		[MEMBERS.GET_MOUSE] = function()
			return function()
				return proxy:wrap(self.deps.plugin:GetMouse())
			end
		end,
		[MEMBERS.PARENT] = function()
			if self.joined then
				return proxy:wrap(Players)
			end
			return nil
		end,
		[MEMBERS.KICK] = function()
			return function(_, message)
				self:kick(message)
			end
		end,
		[MEMBERS.GET_JOIN_DATA] = function()
			return function()
				return {}
			end
		end,
	}, {
		[MEMBERS.CHARACTER] = function(model)
			self:adoptCharacter(model)
		end,
	})
	proxy:overrideFallback(self.playerFolder, self.members)
end

function VirtualPlayer:prepare()
	if self.prepared then
		return
	end
	self.prepared = true
	self:resolveIdentity()
	self:createContainers()
	self:registerPlayersOverrides()
	self:registerPlayerOverrides()
end

function VirtualPlayer:mountStarter(container, parent)
	local _, pairs_ = StarterClone.children(container, parent, self.deps.tracker, self.owner)
	self.deps.onScripts(pairs_)
end

function VirtualPlayer:assignAutoTeam()
	for _, team in ipairs(Teams:GetTeams()) do
		if team.AutoAssignable then
			self.members.write(MEMBERS.TEAM, team)
			return
		end
	end
end

function VirtualPlayer:spawn()
	self:prepare()
	self.active = true
	self.joined = true
	self:assignAutoTeam()
	self.playerAdded:fire(self.playerProxy)
	self:mountStarter(StarterPlayer:FindFirstChild(CLIENT.STARTER_PLAYER_SCRIPTS), self.playerScripts)
	self.playerModule = PlayerModuleShim.mount(self.playerScripts, self.deps.tracker, self.owner)
	self:mountStarter(StarterPack, self.backpack)
	self.guiMount:mount(self.playerGui)
	if Players.CharacterAutoLoads then
		self:loadCharacter()
	end
end

function VirtualPlayer:controls()
	return self.playerModule
end

function VirtualPlayer:property(name)
	local _, value = self.members.read(name)
	return value
end

function VirtualPlayer:buildCharacter()
	local starter = StarterPlayer:FindFirstChild(CLIENT.STARTER_CHARACTER)
	if starter then
		return starter:Clone(), starter
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new(CLASSES.HUMANOID_DESCRIPTION), Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model, nil
	end
	return CharacterRig.build(self.name), nil
end

function VirtualPlayer:applyStarterSettings(humanoid)
	for _, setting in ipairs(Constants.HUMANOID_SETTINGS) do
		local ok, value = pcall(function()
			return StarterPlayer[setting.starter]
		end)
		if ok and value ~= nil then
			pcall(function()
				humanoid[setting.humanoid] = value
			end)
		end
	end
end

function VirtualPlayer:spawnCFrame()
	local spawnLocation = self:property(MEMBERS.RESPAWN_LOCATION) or workspace:FindFirstChildWhichIsA(CLASSES.SPAWN_LOCATION, true)
	local base = spawnLocation and spawnLocation.Position or Vector3.zero
	return CFrame.new(base + Vector3.new(0, CLIENT.SPAWN_HEIGHT_OFFSET, 0))
end

function VirtualPlayer:loadCharacter()
	if not self.active then
		return
	end
	self:removeCharacter()
	local ok, model, template = pcall(self.buildCharacter, self)
	if not ok then
		self.deps.onError(string.format(ERRORS.CHARACTER_BUILD, tostring(model)))
		return
	end
	model.Name = self.name
	local humanoid = model:FindFirstChildOfClass(CLASSES.HUMANOID)
	if not humanoid then
		self.deps.onError(string.format(ERRORS.HUMANOID_MISSING, model.Name))
		model:Destroy()
		return
	end
	self:applyStarterSettings(humanoid)
	model:PivotTo(self:spawnCFrame())
	self.deps.tracker:addInstance(self.owner, model)
	model.Parent = workspace
	self.spawnCount += 1
	local pairs_ = StarterClone.pairsOf(template, model)
	local _, starterPairs = StarterClone.children(StarterPlayer:FindFirstChild(CLIENT.STARTER_CHARACTER_SCRIPTS), model, self.deps.tracker, self.owner)
	table.move(starterPairs, 1, #starterPairs, #pairs_ + 1, pairs_)
	self:attachCharacter(model, humanoid)
	self.deps.onScripts(pairs_)
	if self.spawnCount > 1 then
		self.guiMount:respawn()
	end
end

function VirtualPlayer:attachCharacter(model, humanoid)
	self.character = model
	self.humanoid = humanoid
	if humanoid then
		self.diedConnection = humanoid.Died:Connect(function()
			self:onDied(humanoid)
		end)
	end
	self:notifyCharacter(model)
	local wrapped = self.deps.proxy:wrap(model)
	self.characterAdded:fire(wrapped)
	self.appearanceLoaded:fire(wrapped)
end

function VirtualPlayer:detachCharacter()
	self.character = nil
	self.humanoid = nil
	if self.diedConnection then
		self.diedConnection:Disconnect()
		self.diedConnection = nil
	end
	self:notifyCharacter(nil)
end

function VirtualPlayer:adoptCharacter(model)
	if model == self.character then
		return
	end
	if self.character then
		self:detachCharacter()
	end
	if model ~= nil then
		self:attachCharacter(model, model:FindFirstChildOfClass(CLASSES.HUMANOID))
	end
end

function VirtualPlayer:onDied(deadHumanoid)
	task.delay(Players.RespawnTime, function()
		if self.active and self.humanoid == deadHumanoid then
			self:loadCharacter()
		end
	end)
end

function VirtualPlayer:removeCharacter()
	local model = self.character
	if not model then
		return
	end
	self.characterRemoving:fire(self.deps.proxy:wrap(model))
	self:detachCharacter()
	self.deps.tracker:markDestroying(model)
	model:Destroy()
end

function VirtualPlayer:kick(message)
	if not self.active then
		return
	end
	self.deps.onKick(message)
	self.active = false
	self.joined = false
	self.playerRemoving:fire(self.playerProxy)
	self:removeCharacter()
	self.guiMount:unmount()
end

function VirtualPlayer:chat(message)
	self.members.fire(MEMBERS.CHATTED, message)
end

function VirtualPlayer:distanceTo(point)
	local root = self.humanoid and self.humanoid.RootPart
	if not root then
		return 0
	end
	return (root.Position - point).Magnitude
end

function VirtualPlayer:move(direction, relativeToCamera)
	if self.humanoid then
		self.humanoid:Move(direction, relativeToCamera == true)
	end
end

function VirtualPlayer:owns(instance)
	if self.root and instance:IsDescendantOf(self.root) then
		return true
	end
	return self.character ~= nil and instance:IsDescendantOf(self.character)
end

function VirtualPlayer:ownsServerContainer(instance)
	if not self.prepared then
		return false
	end
	for name in pairs(CLIENT.SERVER_CONTAINERS) do
		local container = self.containers[name]
		if container and instance:IsDescendantOf(container) then
			return true
		end
	end
	return false
end

function VirtualPlayer:isAlive()
	return self.humanoid ~= nil and self.humanoid.Health > 0
end

function VirtualPlayer:status()
	local characterState = TEXTS.CHARACTER_NONE
	if self.character then
		characterState = self:isAlive() and TEXTS.CHARACTER_ALIVE or TEXTS.CHARACTER_DEAD
	end
	return string.format(TEXTS.CLIENT_FORMAT, self.name, characterState, self.guiMount:count())
end

function VirtualPlayer:destroy()
	if not self.prepared then
		return
	end
	if self.active then
		self.active = false
		self.playerRemoving:fire(self.playerProxy)
		self:removeCharacter()
		self.guiMount:unmount()
	end
	self.joined = false
	self.prepared = false
	local proxy = self.deps.proxy
	proxy:clearOverrides(Players)
	proxy:clearOverrides(self.playerFolder)
	for _, container in pairs(self.containers) do
		proxy:clearOverrides(container)
	end
	self.deps.tracker:release(self.owner)
	for _, signal in ipairs({ self.playerAdded, self.playerRemoving, self.characterAdded, self.characterRemoving, self.appearanceLoaded }) do
		signal:clear()
	end
	self.characterObservers = {}
	self.playerModule = nil
	self.root = nil
end

return VirtualPlayer

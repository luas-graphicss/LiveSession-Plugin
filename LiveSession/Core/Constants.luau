local Constants = {}

Constants.PLUGIN_NAME = "LiveSession"
Constants.LOG_PREFIX = "[LiveSession]"
Constants.LOG_FORMAT = "%s %s %s: %s"
Constants.LOG_LEVELS = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }
Constants.LOG_LEVEL_NAMES = { "DEBUG", "INFO", "WARN", "ERROR" }
Constants.FPS_SAMPLE_SECONDS = 1

Constants.PLUGIN_FOLDER_NAME = "__LiveSession"
Constants.UNRESOLVED_FOLDER_NAME = "__LiveSession_NaoResolvidos"
Constants.TESTS_FOLDER_NAME = "__LiveSessionTests"
Constants.SNAPSHOT_FOLDER_NAME = "Snapshot"
Constants.JOURNAL_FOLDER_NAME = "Journal"
Constants.QUARANTINE_FOLDER_NAME = "Quarantine"
Constants.FIXED_FOLDER_NAME = "Fixed"
Constants.FIXED_CLASS_ATTRIBUTE = "RootClass"
Constants.FIXED_PARTIAL_ATTRIBUTE = "Partial"
Constants.TERRAIN_REGION_NAME = "TerrainRegion"
Constants.MIRROR_CHUNK_NAME_PREFIX = "Chunk"
Constants.MIRROR_CHUNK_COUNT_ATTRIBUTE = "ChunkCount"
Constants.MIRROR_HASH_ATTRIBUTE = "Hash"
Constants.MIRROR_SESSION_ATTRIBUTE = "SessionId"

Constants.STABLE_ID_ATTRIBUTE = "LiveSessionId"
Constants.STABLE_ID_PREFIX = "ls:"
Constants.STABLE_ID_FORMAT = "ls:%05d"
Constants.PATH_LAST_SEGMENT_PATTERN = "[^%.]+$"
Constants.SESSION_ID_FORMAT = "ls_%s_%04x"
Constants.SESSION_ID_DATE_FORMAT = "%Y%m%d_%H%M%S"
Constants.SESSION_ID_RANDOM_MAX = 65535

Constants.JOURNAL_FORMAT_VERSION = 1
Constants.JOURNAL_CHUNK_CHARS = 256000
Constants.MIRROR_CHUNK_CHARS = 150000
Constants.SOURCE_HISTORY_DEPTH = 5
Constants.CLOSED_JOURNAL_RETENTION_SESSIONS = 3
Constants.JOURNAL_WARN_CHARS = 4000000
Constants.LOCK_STALE_SECONDS = 60
Constants.LOCK_HEARTBEAT_SECONDS = 10
Constants.TEAM_CREATE = {
	STALE_SECONDS = 90,
	CLAIM_SETTLE_SECONDS = 1.5,
	MONITOR_SECONDS = 5,
	MIRROR_INTERVAL_SECONDS = 5,
	WATCH_MAX_INSTANCES = 60000,
	OBSERVER_ATTRIBUTE_PREFIX = "Observer_",
	TIME_FORMAT = "%H:%M:%S",
	UNKNOWN_NAME = "?",
	ATTRIBUTES = {
		OWNER_USER_ID = "OwnerUserId",
		OWNER_NAME = "OwnerName",
		SESSION_ID = "SessionId",
		STARTED_AT = "StartedAt",
		HEARTBEAT = "Heartbeat",
	},
}
Constants.ATTRIBUTION = {
	KINEMATIC_PROPERTIES = {
		CFrame = true,
		Position = true,
		Orientation = true,
		Rotation = true,
		WorldPivot = true,
		Velocity = true,
		RotVelocity = true,
		AssemblyLinearVelocity = true,
		AssemblyAngularVelocity = true,
	},
	IGNORED_PROPERTIES = {
		Jump = true,
		Sit = true,
		PlatformStand = true,
		WalkToPoint = true,
		WalkToPart = true,
		TargetPoint = true,
		Playing = true,
		TimePosition = true,
		CameraSubject = true,
		Focus = true,
	},
	ENGINE_CLASSES = {
		Camera = true,
		TouchTransmitter = true,
		Animator = true,
	},
	ENGINE_NAMES = {
		SeatWeld = true,
		RightGrip = true,
		AccessoryWeld = true,
	},
}

Constants.RELOAD_DEBOUNCE_SECONDS = 0.25
Constants.BROKEN_SCRIPT_WARNING_SECONDS = 30
Constants.SOURCE_POLL_SECONDS = 1

Constants.SLICE_BUDGET_MS = 16
Constants.DEGRADE_FRAME_MS = 33
Constants.DEGRADE_WINDOW_SECONDS = 5
Constants.PHYSICS_FULL_RATE_HZ = 60
Constants.PHYSICS_DEGRADED_RATE_HZ = 30
Constants.PHYSICS_MAX_STEPS_PER_FRAME = 4
Constants.CLIENT_JOIN_DELAY_SECONDS = 0.5
Constants.TRACKER_COMPACT_MIN_ENTRIES = 256
Constants.STATUS_REFRESH_SECONDS = 0.5
Constants.STATUS_REFRESH_DEGRADED_SECONDS = 2
Constants.RELOAD_DEBOUNCE_DEGRADED_SECONDS = 1
Constants.RELOAD_TIMER_TOLERANCE_SECONDS = 0.01
Constants.STATUS_MAX_ERRORS = 5
Constants.MILLISECONDS_PER_SECOND = 1000
Constants.KILOBYTES_PER_MEGABYTE = 1024
Constants.INCREMENTAL_LIMIT_RATIO = 0.4
Constants.MOVED_BODY_EPSILON = 0.001
Constants.MEMORY_GROWTH_WARN_MB = 256
Constants.DEGRADATION_LEVELS = { NONE = 0, PHYSICS = 1, RELOAD = 2, GUI = 3 }
Constants.ENGINES = { HOSTED = "hosted", COMPATIBILITY = "compatibility" }
Constants.COST_KEYS = { PHYSICS = "physics", SERVER = "server", CLIENT = "client", WATCHERS = "watchers" }
Constants.CONTEXTS = { SERVER = "server", CLIENT = "client" }
Constants.COMPAT = {
	MARKER_NAME = "RunMarker",
	POLL_SECONDS = 0.1,
	START_TIMEOUT_SECONDS = 5,
	REVERT_TIMEOUT_SECONDS = 10,
}
Constants.STRESS = {
	FOLDER_NAME = "__LiveSessionStress",
	INSTANCES = 200000,
	SCRIPTS = 300,
	REMOTES = 50,
	PARTS_PER_MODEL = 100,
	BUILD_BATCH = 2000,
	RELOAD_INTERVAL_SECONDS = 10,
	SESSION_SECONDS = 3600,
	SCRIPT_SOURCE_FORMAT = "local RunService = game:GetService(\"RunService\")\nlocal counter = %d\nRunService.Heartbeat:Connect(function()\n\tcounter += 1\nend)\n",
	MODEL_NAME_FORMAT = "Model%d",
	SCRIPT_NAME_FORMAT = "Stress%d",
	REMOTE_NAME_FORMAT = "Remote%d",
	PART_SIZE = Vector3.new(1, 1, 1),
	PART_SPACING = 2,
	REPORT_FORMAT = "estresse: %d instância(s) · %d script(s) · %d remote(s) · %.1f s · %d MB",
	REMOTE_CLASS = "RemoteEvent",
}

Constants.HASH = {
	OFFSET_BASIS = 2166136261,
	PRIME_SHIFT = 24,
	PRIME_REMAINDER = 403,
	MODULO = 4294967296,
	WORD_BYTES = 4,
	WORD_FORMAT = "<I4",
	WORDS_PER_BATCH = 128,
	PADDING = "\0",
	FORMAT = "%08x",
}

Constants.SETTINGS = {
	JOURNAL_INDEX = "LiveSession.Journal.Index",
	JOURNAL_CHUNK_PREFIX = "LiveSession.Journal.Chunk.",
	ARCHIVE_PREFIX = "LiveSession.Archive.",
	ARCHIVE_INDEX_SUFFIX = ".Index",
	ARCHIVE_CHUNK_SUFFIX = ".Chunk.",
	CLOSED_SESSIONS = "LiveSession.ClosedSessions",
	LOCK = "LiveSession.Lock",
	ACKNOWLEDGED_PREFIX = "LiveSession.Acknowledged.",
	PROBE = "LiveSession.Probe",
	ENGINE_PREFIX = "LiveSession.Engine.",
}

Constants.GAME_CONTAINERS = {
	"Workspace",
	"Lighting",
	"ReplicatedStorage",
	"ReplicatedFirst",
	"ServerStorage",
	"ServerScriptService",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"Chat",
	"TextChatService",
}
Constants.SERVER_SCRIPT_CONTAINERS = { Workspace = true, ServerScriptService = true }
Constants.SERVICE_PROPERTIES = {
	Lighting = {
		"Ambient",
		"Brightness",
		"ClockTime",
		"ColorShift_Bottom",
		"ColorShift_Top",
		"EnvironmentDiffuseScale",
		"EnvironmentSpecularScale",
		"ExposureCompensation",
		"FogColor",
		"FogEnd",
		"FogStart",
		"GeographicLatitude",
		"GlobalShadows",
		"OutdoorAmbient",
		"ShadowSoftness",
	},
	Workspace = { "Gravity", "AirDensity", "GlobalWind" },
	SoundService = { "AmbientReverb", "DistanceFactor", "DopplerScale", "RolloffScale", "RespectFilteringEnabled" },
}

Constants.FIXED_ROOT_CLASSES = {
	Terrain = true,
	StarterPlayerScripts = true,
	StarterCharacterScripts = true,
	BubbleChatConfiguration = true,
	ChatWindowConfiguration = true,
	ChatInputBarConfiguration = true,
	ChannelTabsConfiguration = true,
}
Constants.TERRAIN = {
	CLASS_NAME = "Terrain",
	REGION_CLASS_NAME = "TerrainRegion",
	PROPERTIES = { "WaterColor", "WaterReflectance", "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed", "Decoration", "GrassLength" },
}

Constants.STATES = {
	IDLE = "Idle",
	PREFLIGHT = "Preflight",
	STARTING = "Starting",
	RUNNING = "Running",
	STOPPING = "Stopping",
	RECOVERING = "Recovering",
}
Constants.STATE_LABELS = {
	[Constants.STATES.IDLE] = "Parada",
	[Constants.STATES.PREFLIGHT] = "Verificando",
	[Constants.STATES.STARTING] = "Iniciando",
	[Constants.STATES.RUNNING] = "Rodando",
	[Constants.STATES.STOPPING] = "Encerrando",
	[Constants.STATES.RECOVERING] = "Recuperando",
}
Constants.ENTRY_KINDS = { SOURCE = "source", PROPERTY = "property", CREATE = "create", DESTROY = "destroy" }
Constants.ORIGINS = { EDITOR = "editor", SOURCE = "source", RECORDING = "recording", SELECTION = "selection", REVIEW = "review", STUDIO = "studio", COLLABORATOR = "collaborator", MCP = "mcp" }
Constants.CLASSIFICATIONS = { AUTHORING = "authoring", RUNTIME = "runtime", AMBIGUOUS = "ambiguous" }
Constants.STOP_MODES = { REVERT = "revert", FREEZE = "freeze" }
Constants.SEVERITIES = { BLOCKING = "blocking", CRITICAL = "critical", ALERT = "alert" }
Constants.RELOAD_STATUS = {
	WAITING_COMPILABLE = "aguardando código compilável",
	LOAD_ERROR = "erro na carga",
	RELOADED = "recarregado",
}

Constants.SCRIPT_CLASSES = { Script = true, ModuleScript = true, LocalScript = true }
Constants.CLASS_NAMES = {
	SCRIPT = "Script",
	LOCAL_SCRIPT = "LocalScript",
	MODULE_SCRIPT = "ModuleScript",
	BASE_SCRIPT = "BaseScript",
	PLAYER = "Player",
	INSTANCE = "Instance",
	MODEL = "Model",
	PART = "Part",
	HUMANOID = "Humanoid",
	MOTOR6D = "Motor6D",
	LAYER_COLLECTOR = "LayerCollector",
	SPAWN_LOCATION = "SpawnLocation",
	HUMANOID_DESCRIPTION = "HumanoidDescription",
	FOLDER = "Folder",
	STRING_VALUE = "StringValue",
	SCREEN_GUI = "ScreenGui",
	FRAME = "Frame",
	TEXT_LABEL = "TextLabel",
	TEXT_BUTTON = "TextButton",
	SCROLLING_FRAME = "ScrollingFrame",
	UI_LIST_LAYOUT = "UIListLayout",
	UI_PADDING = "UIPadding",
	UI_CORNER = "UICorner",
	TEXT_BOX = "TextBox",
	BASE_PART = "BasePart",
	LUA_SOURCE_CONTAINER = "LuaSourceContainer",
	ANIMATOR = "Animator",
	BILLBOARD_GUI = "BillboardGui",
	TOOL = "Tool",
	WELD = "Weld",
	ATTACHMENT = "Attachment",
	ANIMATION = "Animation",
	UI_STROKE = "UIStroke",
	UI_GRADIENT = "UIGradient",
	IMAGE_LABEL = "ImageLabel",
	TWEEN_BASE = "TweenBase",
}
Constants.MUTATING_METHODS = {
	PivotTo = true,
	SetPrimaryPartCFrame = true,
	MoveTo = true,
	TranslateBy = true,
	ScaleTo = true,
	SetAttribute = true,
	AddTag = true,
	RemoveTag = true,
	ClearAllChildren = true,
	BreakJoints = true,
	MakeJoints = true,
	ApplyImpulse = true,
	ApplyAngularImpulse = true,
	ApplyImpulseAtPosition = true,
	SetNetworkOwner = true,
	Create = true,
	Play = true,
	Stop = true,
	Pause = true,
	Resume = true,
	TakeDamage = true,
	ChangeState = true,
	SetStateEnabled = true,
	Sit = true,
	EquipTool = true,
	UnequipTools = true,
	Emit = true,
	AddItem = true,
}
Constants.REFERENCE_PROPERTIES = {
	{ class = "ObjectValue", properties = { "Value" } },
	{ class = "JointInstance", properties = { "Part0", "Part1" } },
	{ class = "WeldConstraint", properties = { "Part0", "Part1" } },
	{ class = "NoCollisionConstraint", properties = { "Part0", "Part1" } },
	{ class = "Constraint", properties = { "Attachment0", "Attachment1" } },
	{ class = "Beam", properties = { "Attachment0", "Attachment1" } },
	{ class = "Trail", properties = { "Attachment0", "Attachment1" } },
	{ class = "PathfindingLink", properties = { "Attachment0", "Attachment1" } },
	{ class = "Model", properties = { "PrimaryPart" } },
	{ class = "BillboardGui", properties = { "Adornee" } },
	{ class = "SurfaceGui", properties = { "Adornee" } },
	{ class = "Highlight", properties = { "Adornee" } },
	{ class = "PVAdornment", properties = { "Adornee" } },
	{ class = "Camera", properties = { "CameraSubject" } },
	{ class = "Sound", properties = { "SoundGroup" } },
}
Constants.UNSUPPORTED_APIS = {
	{ api = "RequestStreamAroundAsync", note = "streaming não se aplica ao DataModel de edição" },
	{ api = "DragDetector", note = "arrastar objetos com DragDetector não é emulado" },
	{ api = "VRService", note = "não há dispositivo de realidade virtual no Studio" },
	{ api = "HapticService", note = "não há dispositivo com vibração no Studio" },
	{ api = "CreatePlaceAsync", note = "AssetService:CreatePlaceAsync não cria places a partir do Studio" },
	{ api = "FilterStringAsync", note = "o texto não passa por filtro na sessão; a chamada devolve o texto original" },
	{ api = "FilterStringForBroadcast", note = "o texto não passa por filtro na sessão; a chamada devolve o texto original" },
}
Constants.LUA_COMMENT_LINE_PATTERN = "^%s*%-%-"
Constants.PROPERTY_NAMES = {
	SOURCE = "Source",
	PARENT = "Parent",
	DISABLED = "Disabled",
	ENABLED = "Enabled",
	RUN_CONTEXT = "RunContext",
	ARCHIVABLE = "Archivable",
	NAME = "Name",
	VALUE = "Value",
	TEXT = "Text",
	ABSOLUTE_SIZE = "AbsoluteSize",
}
Constants.SCRIPT_STATE_PROPERTIES = { Constants.PROPERTY_NAMES.DISABLED, Constants.PROPERTY_NAMES.RUN_CONTEXT }
Constants.SERVICE_NAMES = {
	SERVER_STORAGE = "ServerStorage",
	RUN_SERVICE = "RunService",
	HTTP_SERVICE = "HttpService",
	CHANGE_HISTORY = "ChangeHistoryService",
	SCRIPT_EDITOR = "ScriptEditorService",
	SELECTION = "Selection",
	PLAYERS = "Players",
	CORE_GUI = "CoreGui",
}
Constants.RUN_SERVICE_MEMBERS = {
	IS_RUNNING = "IsRunning",
	IS_EDIT = "IsEdit",
	IS_RUN_MODE = "IsRunMode",
	IS_SERVER = "IsServer",
	IS_CLIENT = "IsClient",
	STEPPED = "Stepped",
	PRE_SIMULATION = "PreSimulation",
	POST_SIMULATION = "PostSimulation",
	PRE_ANIMATION = "PreAnimation",
	RENDER_STEPPED = "RenderStepped",
	PRE_RENDER = "PreRender",
	BIND_TO_RENDER_STEP = "BindToRenderStep",
}
Constants.RUN_SERVICE_CLIENT_ONLY = {
	{ name = "RenderStepped", method = false },
	{ name = "PreRender", method = false },
	{ name = "BindToRenderStep", method = true },
}
Constants.CAMERA_MEMBERS = { CAMERA_TYPE = "CameraType", CAMERA_SUBJECT = "CameraSubject" }

Constants.HIDDEN_GLOBALS = { plugin = true, settings = true, PluginManager = true, DebuggerManager = true }
Constants.SIGNAL_CONNECT_METHODS = { Connect = "Connect", Once = "Once", ConnectParallel = "Connect" }
Constants.SIGNAL_WAIT_METHOD = "Wait"
Constants.INSTANCE_METHODS = { DESTROY = "Destroy" }
Constants.VALUE_PROXY_TYPES = { RaycastParams = true, OverlapParams = true, RaycastResult = true }
Constants.EDIT_MODE_SHIM = {
	BIND_TO_CLOSE = "BindToClose",
	NO_OP_METHODS = { "SetNetworkOwner", "SetNetworkOwnershipAuto", "GetNetworkOwner", "RemoveDefaultLoadingScreen" },
	CONSTANT_METHODS = { CanSetNetworkOwnership = true },
	SILENT_SERVICES = { "AnalyticsService" },
	SERVICE_NO_OP_METHODS = {
		SocialService = { "PromptGameInvite", "PromptPhoneBook" },
	},
	SERVICE_PASSTHROUGH_METHODS = {
		Chat = { "FilterStringAsync", "FilterStringForBroadcast" },
	},
	SERVICE_GUARDED_DEFAULTS = {
		BadgeService = { UserHasBadgeAsync = false, GetBadgeInfoAsync = {}, CheckUserBadgesAsync = {} },
	},
	SERVICE_SIGNAL_METHODS = {
		Chat = { Chat = "Chatted", ChatLocal = "Chatted" },
	},
	SERVICE_CONSTANT_METHODS = {
		SocialService = { CanSendGameInviteAsync = false, CanSendCallInviteAsync = false, GetPlayersByPartyId = {}, GetPartyAsync = {} },
		VoiceChatService = { IsVoiceEnabledForUserIdAsync = false },
		BadgeService = { AwardBadge = false },
		PolicyService = {
			GetPolicyInfoForPlayerAsync = {
				AreAdsAllowed = true,
				ArePaidRandomItemsRestricted = false,
				AllowedExternalLinkReferences = { "Discord", "Facebook", "Twitch", "YouTube", "Guilded", "X" },
				IsContentSharingAllowed = true,
				IsEligibleToPurchaseCommerceProduct = true,
				IsEligibleToPurchaseSubscription = true,
				IsPaidItemTradingAllowed = true,
				IsSubjectToChinaPolicies = false,
			},
		},
	},
	SERVICE_SIGNALS = {
		SocialService = { "GameInvitePromptClosed", "PhoneBookPromptClosed", "CallInviteStateChanged" },
		BadgeService = { "BadgeAwarded" },
		Chat = { "Chatted" },
	},
	PLAYER_LOCALE_METHODS = { LocalizationService = { "GetTranslatorForPlayerAsync", "GetTranslatorForPlayer" } },
	LOCALE_METHOD = "GetTranslatorForLocaleAsync",
}
Constants.MESSAGING = {
	SUBSCRIBE = "SubscribeAsync",
	PUBLISH = "PublishAsync",
	TOPIC_ERROR = "MessagingService: topic must be a string",
	CALLBACK_ERROR = "MessagingService: callback must be a function",
}
Constants.TELEPORT = {
	STUDIO_MESSAGE = "Cannot Teleport in the Roblox Studio.",
	FAILURE_RESULT = Enum.TeleportResult.Failure,
	RESERVE_SERVER = "ReserveServer",
	RESERVED_CODE_FALLBACK = "RESERVED-STUDIO",
	RESERVED_SERVER_ID_FALLBACK = 0,
	GET_PLACE_INSTANCE = "GetPlayerPlaceInstanceAsync",
	PLACE_INSTANCE_RESULT = { false, "", 0, "", n = 4 },
	INIT_FAILED = "TeleportInitFailed",
	ARRIVED = "LocalPlayerArrivedFromTeleport",
	GET_SETTING = "GetTeleportSetting",
	SET_SETTING = "SetTeleportSetting",
	METHODS = {
		Teleport = { placeIdIndex = 1, playersIndex = 2 },
		TeleportAsync = { placeIdIndex = 1, playersIndex = 2, optionsIndex = 3 },
		TeleportToPlaceInstance = { placeIdIndex = 1, playersIndex = 3 },
		TeleportToPrivateServer = { placeIdIndex = 1, playersIndex = 3 },
		TeleportToSpawnByName = { placeIdIndex = 1, playersIndex = 3 },
		TeleportPartyAsync = { placeIdIndex = 1, playersIndex = 2 },
	},
	NO_OP_METHODS = { "TeleportCancel", "SetTeleportGui", "GetLocalPlayerTeleportData", "GetArrivingTeleportGui" },
}
Constants.MARKETPLACE = {
	KINDS = { ASSET = "asset", GAME_PASS = "gamePass", PRODUCT = "product", BUNDLE = "bundle", SUBSCRIPTION = "subscription", PREMIUM = "premium" },
	RESULTS = { PLAYER = "player", USER_ID = "userId", PLAYER_ONLY = "playerOnly" },
	SIGNALS = {
		"PromptPurchaseFinished",
		"PromptGamePassPurchaseFinished",
		"PromptProductPurchaseFinished",
		"PromptBundlePurchaseFinished",
		"PromptSubscriptionPurchaseFinished",
		"PromptPremiumPurchaseFinished",
	},
	USER_OWNS_GAME_PASS = "UserOwnsGamePassAsync",
	PLAYER_OWNS_ASSET = "PlayerOwnsAsset",
	PLAYER_OWNS_BUNDLE = "PlayerOwnsBundle",
	SUBSCRIPTION_STATUS = "GetUserSubscriptionStatusAsync",
	SUBSCRIPTION_HISTORY = "GetUserSubscriptionPaymentHistoryAsync",
	PROCESS_RECEIPT = "ProcessReceipt",
}
Constants.MARKETPLACE.PROMPTS = {
	PromptPurchase = { kind = Constants.MARKETPLACE.KINDS.ASSET, infoType = Enum.InfoType.Asset, idIndex = 2, finished = "PromptPurchaseFinished", result = Constants.MARKETPLACE.RESULTS.PLAYER },
	PromptGamePassPurchase = { kind = Constants.MARKETPLACE.KINDS.GAME_PASS, infoType = Enum.InfoType.GamePass, idIndex = 2, finished = "PromptGamePassPurchaseFinished", result = Constants.MARKETPLACE.RESULTS.PLAYER },
	PromptProductPurchase = { kind = Constants.MARKETPLACE.KINDS.PRODUCT, infoType = Enum.InfoType.Product, idIndex = 2, finished = "PromptProductPurchaseFinished", result = Constants.MARKETPLACE.RESULTS.USER_ID, receipt = true },
	PromptBundlePurchase = { kind = Constants.MARKETPLACE.KINDS.BUNDLE, infoType = Enum.InfoType.Bundle, idIndex = 2, finished = "PromptBundlePurchaseFinished", result = Constants.MARKETPLACE.RESULTS.PLAYER },
	PromptSubscriptionPurchase = { kind = Constants.MARKETPLACE.KINDS.SUBSCRIPTION, idIndex = 2, finished = "PromptSubscriptionPurchaseFinished", result = Constants.MARKETPLACE.RESULTS.PLAYER },
	PromptPremiumPurchase = { kind = Constants.MARKETPLACE.KINDS.PREMIUM, finished = "PromptPremiumPurchaseFinished", result = Constants.MARKETPLACE.RESULTS.PLAYER_ONLY },
}
Constants.PROXIMITY_PROMPTS = {
	CLASS_NAME = "ProximityPrompt",
	FOLDER_NAME = "ProximityPrompts",
	ATTACHMENT_CLASS = "Attachment",
	INSTANCE_SIGNALS = { "Triggered", "TriggerEnded", "PromptShown", "PromptHidden", "PromptButtonHoldBegan", "PromptButtonHoldEnded" },
	SERVICE_SIGNALS = { "PromptShown", "PromptHidden", "PromptTriggered", "PromptTriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded" },
	EVENTS = {
		SHOWN = "PromptShown",
		HIDDEN = "PromptHidden",
		TRIGGERED = "Triggered",
		TRIGGER_ENDED = "TriggerEnded",
		HOLD_BEGAN = "PromptButtonHoldBegan",
		HOLD_ENDED = "PromptButtonHoldEnded",
		SERVICE_TRIGGERED = "PromptTriggered",
		SERVICE_TRIGGER_ENDED = "PromptTriggerEnded",
	},
	METHODS = { INPUT_HOLD_BEGIN = "InputHoldBegin", INPUT_HOLD_END = "InputHoldEnd" },
	INPUT_TYPE = Enum.ProximityPromptInputType.Keyboard,
	SCAN_INTERVAL = 0.1,
	WATCHED_PROPERTIES = { "ActionText", "ObjectText", "KeyboardKeyCode", "UIOffset", "HoldDuration" },
	UI = {
		BILLBOARD_SIZE = UDim2.fromOffset(320, 80),
		PILL_HEIGHT = 52,
		PILL_PADDING = 8,
		PILL_COLOR = Color3.fromRGB(0, 0, 0),
		PILL_TRANSPARENCY = 0.35,
		PILL_CORNER = 8,
		KEY_SIZE = 36,
		KEY_CORNER = 6,
		KEY_COLOR = Color3.fromRGB(255, 255, 255),
		KEY_TEXT_COLOR = Color3.fromRGB(0, 0, 0),
		KEY_TEXT_SIZE = 18,
		ACTION_TEXT_SIZE = 16,
		OBJECT_TEXT_SIZE = 13,
		TEXT_COLOR = Color3.fromRGB(255, 255, 255),
		OBJECT_TEXT_COLOR = Color3.fromRGB(210, 210, 210),
		GAP = 10,
		RING_COLOR = Color3.fromRGB(0, 162, 255),
		RING_THICKNESS = 3,
		RING_PADDING = 4,
		RING_CORNER = UDim.new(1, 0),
		RING_HALF_SIZE = UDim2.fromScale(0.5, 1),
		RING_RIGHT_CLIP_POSITION = UDim2.fromScale(0.5, 0),
		RING_CIRCLE_SIZE = UDim2.fromScale(2, 1),
		RING_RIGHT_CIRCLE_POSITION = UDim2.fromScale(-1, 0),
		RING_GRADIENT = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.499, 0), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1) }),
		RING_HALF_TURN = 180,
		RING_FULL_TURN = 360,
	},
}
Constants.OUTPUT = {
	CAPACITY = 400,
	KINDS = { PRINT = "print", INFO = "info", WARN = "warn", ERROR = "error" },
	MESSAGE_TYPES = { MessageOutput = "print", MessageInfo = "info", MessageWarning = "warn", MessageError = "error" },
}
Constants.LOAD_STATES = { RUNNING = "running", FAILED = "failed", DISABLED = "disabled", SKIPPED = "skipped", NOT_STARTED = "notStarted" }
Constants.TRACKED_KINDS = { ACTION = "action", RENDER_BIND = "renderBind" }
Constants.TRACKED_METHODS = { BindToRenderStep = Constants.TRACKED_KINDS.RENDER_BIND }
Constants.LIVE_SESSION_GLOBAL = "LiveSession"

Constants.REMOTE_INVOKE_TIMEOUT_SECONDS = 10
Constants.REMOTE_CLASSES = { RemoteEvent = true, UnreliableRemoteEvent = true, RemoteFunction = true }
Constants.REMOTE_MEMBERS = {
	FIRE_SERVER = "FireServer",
	FIRE_CLIENT = "FireClient",
	FIRE_ALL_CLIENTS = "FireAllClients",
	INVOKE_SERVER = "InvokeServer",
	INVOKE_CLIENT = "InvokeClient",
	ON_SERVER_EVENT = "OnServerEvent",
	ON_CLIENT_EVENT = "OnClientEvent",
	ON_SERVER_INVOKE = "OnServerInvoke",
	ON_CLIENT_INVOKE = "OnClientInvoke",
}
Constants.REMOTE_SLOTS = { SERVER_INVOKE = "serverInvoke", CLIENT_INVOKE = "clientInvoke" }
Constants.REMOTE_MEMBER_CONTEXT = {
	FireServer = Constants.CONTEXTS.CLIENT,
	InvokeServer = Constants.CONTEXTS.CLIENT,
	OnClientEvent = Constants.CONTEXTS.CLIENT,
	OnClientInvoke = Constants.CONTEXTS.CLIENT,
	FireClient = Constants.CONTEXTS.SERVER,
	FireAllClients = Constants.CONTEXTS.SERVER,
	InvokeClient = Constants.CONTEXTS.SERVER,
	OnServerEvent = Constants.CONTEXTS.SERVER,
	OnServerInvoke = Constants.CONTEXTS.SERVER,
}

Constants.CLIENT = {
	ROOT_NAME = "__LiveSessionClient",
	DEFAULT_PLAYER_NAME = "Player1",
	DEFAULT_USER_ID = -1,
	PLAYER_GUI = "PlayerGui",
	BACKPACK = "Backpack",
	PLAYER_SCRIPTS = "PlayerScripts",
	STARTER_PLAYER_SCRIPTS = "StarterPlayerScripts",
	STARTER_CHARACTER_SCRIPTS = "StarterCharacterScripts",
	STARTER_CHARACTER = "StarterCharacter",
	SPAWN_HEIGHT_OFFSET = 5,
	RUN_CONTEXT_CONTAINERS = {
		Workspace = true,
		Lighting = true,
		ReplicatedStorage = true,
		ReplicatedFirst = true,
		StarterGui = true,
		StarterPack = true,
		StarterPlayer = true,
		Teams = true,
		SoundService = true,
		Chat = true,
		TextChatService = true,
	},
	LOCAL_SCRIPT_CONTAINERS = { ReplicatedFirst = true },
	CONTAINER_CLASSES = {
		PlayerGui = { PlayerGui = true, BasePlayerGui = true, Instance = true },
		Backpack = { Backpack = true, Instance = true },
		PlayerScripts = { PlayerScripts = true, Instance = true },
	},
	SERVER_CONTAINERS = { PlayerGui = true, Backpack = true },
	STARTER_CONTAINERS = { StarterGui = true, StarterPack = true, StarterPlayer = true },
	OWNER_NAME = "VirtualPlayer",
	CONTAINER_API = {
		PlayerGui = {
			PROPERTIES = {
				ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor,
				CurrentScreenOrientation = Enum.ScreenOrientation.LandscapeLeft,
			},
			SIGNALS = { TopbarTransparencyChangedSignal = true },
			CONSTANT_METHODS = { GetTopbarTransparency = 0 },
			NO_OP_METHODS = { SetTopbarTransparency = true },
		},
		PlayerScripts = {
			PROPERTIES = {},
			SIGNALS = {},
			CONSTANT_METHODS = {
				GetRegisteredComputerCameraMovementModes = {},
				GetRegisteredTouchCameraMovementModes = {},
				GetRegisteredComputerMovementModes = {},
				GetRegisteredTouchMovementModes = {},
			},
			NO_OP_METHODS = {
				ClearComputerCameraMovementModes = true,
				ClearTouchCameraMovementModes = true,
				ClearComputerMovementModes = true,
				ClearTouchMovementModes = true,
				RegisterComputerCameraMovementMode = true,
				RegisterTouchCameraMovementMode = true,
				RegisterComputerMovementMode = true,
				RegisterTouchMovementMode = true,
			},
		},
	},
}
Constants.PLAYER_MEMBERS = {
	LOCAL_PLAYER = "LocalPlayer",
	GET_PLAYERS = "GetPlayers",
	PLAYER_ADDED = "PlayerAdded",
	PLAYER_REMOVING = "PlayerRemoving",
	GET_PLAYER_FROM_CHARACTER = "GetPlayerFromCharacter",
	GET_PLAYER_BY_USER_ID = "GetPlayerByUserId",
	GET_CHILDREN = "GetChildren",
	GET_DESCENDANTS = "GetDescendants",
	FIND_FIRST_CHILD = "FindFirstChild",
	FIND_FIRST_CHILD_OF_CLASS = "FindFirstChildOfClass",
	FIND_FIRST_CHILD_WHICH_IS_A = "FindFirstChildWhichIsA",
	CHILD_ADDED = "ChildAdded",
	CHILD_REMOVED = "ChildRemoved",
	CLASS_NAME = "ClassName",
	IS_A = "IsA",
	DISPLAY_NAME = "DisplayName",
	USER_ID = "UserId",
	CHARACTER = "Character",
	CHARACTER_ADDED = "CharacterAdded",
	CHARACTER_REMOVING = "CharacterRemoving",
	CHARACTER_APPEARANCE_LOADED = "CharacterAppearanceLoaded",
	LOAD_CHARACTER = "LoadCharacter",
	GET_MOUSE = "GetMouse",
	PARENT = "Parent",
	TEAM = "Team",
	TEAM_COLOR = "TeamColor",
	NEUTRAL = "Neutral",
	RESPAWN_LOCATION = "RespawnLocation",
	KICK = "Kick",
	CHATTED = "Chatted",
	GET_JOIN_DATA = "GetJoinData",
	HAS_APPEARANCE_LOADED = "HasAppearanceLoaded",
	CAMERA_MODE = "CameraMode",
	CAMERA_MIN_ZOOM_DISTANCE = "CameraMinZoomDistance",
	CAMERA_MAX_ZOOM_DISTANCE = "CameraMaxZoomDistance",
	LOCALE_ID = "LocaleId",
	MEMBERSHIP_TYPE = "MembershipType",
}
Constants.PLAYER_API = {
	PROPERTIES = {
		AccountAge = true,
		MembershipType = true,
		FollowUserId = true,
		TeamColor = true,
		Neutral = true,
		RespawnLocation = true,
		CanLoadCharacterAppearance = true,
		CharacterAppearanceId = true,
		LocaleId = true,
		GameplayPaused = true,
		ReplicationFocus = true,
		Guest = true,
		HasVerifiedBadge = true,
		CameraMode = true,
		CameraMaxZoomDistance = true,
		CameraMinZoomDistance = true,
		DevCameraOcclusionMode = true,
		DevComputerCameraMode = true,
		DevComputerMovementMode = true,
		DevTouchCameraMode = true,
		DevTouchMovementMode = true,
		DevEnableMouseLock = true,
		HealthDisplayDistance = true,
		NameDisplayDistance = true,
		AutoJumpEnabled = true,
	},
	STARTER_PROPERTIES = {
		CameraMode = "CameraMode",
		CameraMaxZoomDistance = "CameraMaxZoomDistance",
		CameraMinZoomDistance = "CameraMinZoomDistance",
		DevCameraOcclusionMode = "DevCameraOcclusionMode",
		DevComputerCameraMode = "DevComputerCameraMovementMode",
		DevComputerMovementMode = "DevComputerMovementMode",
		DevTouchCameraMode = "DevTouchCameraMovementMode",
		DevTouchMovementMode = "DevTouchMovementMode",
		DevEnableMouseLock = "EnableMouseLockOption",
		HealthDisplayDistance = "HealthDisplayDistance",
		NameDisplayDistance = "NameDisplayDistance",
		AutoJumpEnabled = "AutoJumpEnabled",
	},
	DEFAULTS = {
		AccountAge = 0,
		MembershipType = Enum.MembershipType.None,
		FollowUserId = 0,
		TeamColor = BrickColor.White(),
		Neutral = true,
		CanLoadCharacterAppearance = true,
		CharacterAppearanceId = 0,
		LocaleId = "en-us",
		GameplayPaused = false,
		Guest = false,
		HasVerifiedBadge = false,
	},
	SIGNALS = { Chatted = true, Idled = true, OnTeleport = true, SimulationRadiusChanged = true },
	METHODS = {
		DISTANCE_FROM_CHARACTER = "DistanceFromCharacter",
		LOAD_CHARACTER_WITH_DESCRIPTION = "LoadCharacterWithHumanoidDescription",
		MOVE = "Move",
		GET_FRIENDS_ONLINE = "GetFriendsOnline",
	},
	CONSTANT_METHODS = {
		IsFriendsWith = false,
		IsInGroup = false,
		GetRankInGroup = 0,
		GetRoleInGroup = "Guest",
		IsVerified = false,
		GetNetworkPing = 0,
	},
	NO_OP_METHODS = {
		"ClearCharacterAppearance",
		"RemoveCharacter",
		"SetAccountAge",
		"SetSuperSafeChat",
		"RequestStreamAroundAsync",
		"SetModerationAccessKey",
	},
}
Constants.PLAYER_MODULE = {
	NAME = "PlayerModule",
	ENABLED_ATTRIBUTE = "ControlsEnabled",
	MOVE_VECTOR_ATTRIBUTE = "MoveVector",
	SOURCE_FORMAT = [[
local ENABLED_ATTRIBUTE = %q
local MOVE_VECTOR_ATTRIBUTE = %q

local activeController = {}

function activeController:IsMoveVectorCameraRelative()
	return true
end

local controls = { activeController = activeController }

function controls:Enable(enable)
	script:SetAttribute(ENABLED_ATTRIBUTE, enable ~= false)
end

function controls:Disable()
	script:SetAttribute(ENABLED_ATTRIBUTE, false)
end

function controls:GetMoveVector()
	return script:GetAttribute(MOVE_VECTOR_ATTRIBUTE) or Vector3.zero
end

local PlayerModule = {}

function PlayerModule:GetControls()
	return controls
end

return PlayerModule
]],
}
Constants.HUMANOID_SETTINGS = {
	{ humanoid = "WalkSpeed", starter = "CharacterWalkSpeed" },
	{ humanoid = "JumpPower", starter = "CharacterJumpPower" },
	{ humanoid = "JumpHeight", starter = "CharacterJumpHeight" },
	{ humanoid = "UseJumpPower", starter = "CharacterUseJumpPower" },
	{ humanoid = "MaxSlopeAngle", starter = "CharacterMaxSlopeAngle" },
	{ humanoid = "HealthDisplayDistance", starter = "HealthDisplayDistance" },
	{ humanoid = "NameDisplayDistance", starter = "NameDisplayDistance" },
}
Constants.RIG = {
	ROOT_NAME = "HumanoidRootPart",
	TORSO_NAME = "Torso",
	HEAD_NAME = "Head",
	LIMBS = {
		{ name = "Left Arm", offset = Vector3.new(-1.5, 0, 0) },
		{ name = "Right Arm", offset = Vector3.new(1.5, 0, 0) },
		{ name = "Left Leg", offset = Vector3.new(-0.5, -2, 0) },
		{ name = "Right Leg", offset = Vector3.new(0.5, -2, 0) },
	},
	TORSO_SIZE = Vector3.new(2, 2, 1),
	HEAD_SIZE = Vector3.new(2, 1, 1),
	LIMB_SIZE = Vector3.new(1, 2, 1),
	HEAD_OFFSET = Vector3.new(0, 1.5, 0),
	ROOT_TRANSPARENCY = 1,
	COLOR = Color3.fromRGB(161, 196, 229),
	RIG_TYPE = Enum.HumanoidRigType.R6,
	MOTOR_FORMAT = "%s",
	ROOT_MOTOR_NAME = "RootJoint",
	NECK_NAME = "Neck",
}
Constants.CONTROLLER = {
	FORWARD_KEYS = { Enum.KeyCode.W, Enum.KeyCode.Up },
	BACK_KEYS = { Enum.KeyCode.S, Enum.KeyCode.Down },
	LEFT_KEYS = { Enum.KeyCode.A, Enum.KeyCode.Left },
	RIGHT_KEYS = { Enum.KeyCode.D, Enum.KeyCode.Right },
	JUMP_KEYS = { Enum.KeyCode.Space },
	ESCAPE_KEY = Enum.KeyCode.Escape,
	ROTATE_BUTTON = Enum.UserInputType.MouseButton2,
	FOCUS_BUTTON = Enum.UserInputType.MouseButton1,
	MOUSE_MOVEMENT = Enum.UserInputType.MouseMovement,
	MOUSE_WHEEL = Enum.UserInputType.MouseWheel,
	KEYBOARD = Enum.UserInputType.Keyboard,
	MOUSE_SENSITIVITY = 0.005,
	ZOOM_STEP = 2,
	FIRST_PERSON_ZOOM = 1,
	DEFAULT_ZOOM = 12.5,
	PITCH_LIMIT = math.rad(80),
	INITIAL_PITCH = math.rad(-15),
	SUBJECT_OFFSET = Vector3.new(0, 1.5, 0),
	CAMERA_TYPE = Enum.CameraType.Scriptable,
	DEFAULT_CAMERA_TYPE = Enum.CameraType.Custom,
	GAME_DRIVEN_CAMERA_TYPE = Enum.CameraType.Scriptable,
	LOCK_BEHAVIOR = Enum.MouseBehavior.LockCenter,
	FREE_BEHAVIOR = Enum.MouseBehavior.Default,
	CAMERA_MODE_FIRST_PERSON = Enum.CameraMode.LockFirstPerson,
	MOVE_EPSILON = 0.001,
}

Constants.FIDELITY_STATUS = { FULL = "completo", PARTIAL = "parcial", NONE = "sem emulação" }
Constants.FIDELITY_MATRIX = {
	{ area = "Personagem e câmera", status = Constants.FIDELITY_STATUS.FULL, note = "Jogador virtual em CoreGui com Players.LocalPlayer; PlayerAdded dispara antes dos LocalScripts e CharacterAdded depois; a câmera padrão segue o Humanoid e cede quando o jogo escolhe Scriptable." },
	{ area = "Física", status = Constants.FIDELITY_STATUS.PARTIAL, note = "Workspace:StepPhysics a 60 Hz (30 Hz em degradação ou Team Create); sem StepPhysics a física não anda e o personagem se move por deslocamento direto." },
	{ area = "Remotes", status = Constants.FIDELITY_STATUS.PARTIAL, note = "RemoteEvent e RemoteFunction em processo: argumentos copiados em profundidade sem metatables, funções viram nil; contexto errado erra como no jogo publicado." },
	{ area = "Animações", status = Constants.FIDELITY_STATUS.FULL, note = "Todo Animator com LoadAnimation recebe StepAnimations a cada quadro; viewmodels, NPCs e personagens animam como no Play." },
	{ area = "PlayerGui", status = Constants.FIDELITY_STATUS.FULL, note = "PlayerGui, Backpack e PlayerScripts são pastas em CoreGui.__LiveSessionClient; clones de StarterGui com ResetOnSpawn respeitado." },
	{ area = "ProximityPrompt", status = Constants.FIDELITY_STATUS.FULL, note = "Distância, linha de visão, exclusividade, MaxPromptsVisible, hold, Style, ClickablePrompt, UIOffset e os seis sinais da instância e do ProximityPromptService." },
	{ area = "ClickDetector", status = Constants.FIDELITY_STATUS.FULL, note = "MouseHoverEnter e MouseHoverLeave, MouseClick e RightMouseClick dentro de MaxActivationDistance, com CursorIcon." },
	{ area = "Tools e hotbar", status = Constants.FIDELITY_STATUS.FULL, note = "StarterPack vai para o Backpack; hotbar 1 a 0; equipar por tecla, clique, Humanoid:EquipTool ou Parent; RightGrip, Equipped(mouse), Activated e Deactivated; Backspace solta." },
	{ area = "ContextActionService", status = Constants.FIDELITY_STATUS.PARTIAL, note = "BindAction, BindActionAtPriority, Unbind, GetBoundActionInfo, prioridade, Sink e Pass, LocalToolEquipped; sem botões de toque." },
	{ area = "UserInputService", status = Constants.FIDELITY_STATUS.FULL, note = "InputBegan, InputChanged, InputEnded e JumpRequest passam pelo pipeline do plugin com gameProcessedEvent fiel e só com o viewport ativo." },
	{ area = "Chat", status = Constants.FIDELITY_STATUS.PARTIAL, note = "TextChatService com RBXGeneral e RBXSystem, OnIncomingMessage, MessageReceived e janela de chat mínima; o Chat legado dispara Chatted; sem filtro de texto nem bolhas." },
	{ area = "CoreGui", status = Constants.FIDELITY_STATUS.PARTIAL, note = "SetCoreGuiEnabled controla hotbar e chat; SetCore(SendNotification) mostra o cartão; os demais SetCore são guardados; sem PlayerList, Health ou EmotesMenu." },
	{ area = "Kick", status = Constants.FIDELITY_STATUS.FULL, note = "Player:Kick mostra a tela de desconexão, remove o jogador virtual e a sessão continua." },
	{ area = "Teleport", status = Constants.FIDELITY_STATUS.FULL, note = "Nenhum teleporte chega ao engine: TeleportInitFailed(Failure) por jogador e erro no Output, como no Play Solo; ReserveServer real sob pcall." },
	{ area = "Messaging", status = Constants.FIDELITY_STATUS.PARTIAL, note = "PublishAsync e SubscribeAsync entregues em memória dentro da própria sessão." },
	{ area = "Marketplace", status = Constants.FIDELITY_STATUS.PARTIAL, note = "Compras pedem confirmação no portão e disparam os eventos de conclusão; UserOwnsGamePassAsync e PlayerOwnsAsset devolvem false." },
	{ area = "Badges", status = Constants.FIDELITY_STATUS.PARTIAL, note = "AwardBadge devolve false; consultas reais sob pcall com padrão false ou tabela vazia; BadgeAwarded nunca dispara." },
	{ area = "Analytics", status = Constants.FIDELITY_STATUS.FULL, note = "Todo método de AnalyticsService devolve nil sem tocar no engine." },
	{ area = "Policy", status = Constants.FIDELITY_STATUS.FULL, note = "GetPolicyInfoForPlayerAsync devolve a tabela permissiva padrão." },
	{ area = "Social", status = Constants.FIDELITY_STATUS.PARTIAL, note = "Prompts são no-op, CanSendGameInviteAsync devolve false e os sinais nunca disparam." },
	{ area = "Voice", status = Constants.FIDELITY_STATUS.FULL, note = "IsVoiceEnabledForUserIdAsync devolve false, como no Play Solo offline." },
	{ area = "Localization", status = Constants.FIDELITY_STATUS.PARTIAL, note = "Tradutores reais pelo locale do jogador virtual; sem tradução automática de UI." },
	{ area = "DragDetector", status = Constants.FIDELITY_STATUS.NONE, note = "Arrastar objetos com DragDetector não é emulado." },
	{ area = "VR e Haptics", status = Constants.FIDELITY_STATUS.NONE, note = "VRService e HapticService não têm dispositivo no Studio." },
}
Constants.TYPE_NAMES = {
	INSTANCE = "Instance",
	USERDATA = "userdata",
	FUNCTION = "function",
	TABLE = "table",
	THREAD = "thread",
	NUMBER = "number",
	STRING = "string",
	BOOLEAN = "boolean",
	NIL = "nil",
	SIGNAL = "RBXScriptSignal",
	CONNECTION = "RBXScriptConnection",
	ENUM_ITEM = "EnumItem",
}
Constants.MODULE_NAMES = { CAPABILITIES = "Capabilities" }
Constants.LOCKED_METATABLE_MESSAGE = "The metatable is locked"
Constants.COROUTINE_STATUS_DEAD = "dead"
Constants.CHUNK_NAME_PREFIX = "="
Constants.OUTPUT_PREFIX_FORMAT = "[%s]"
Constants.CAPABILITY_PROBE_CHUNK = "return marker"
Constants.CAPABILITY_PROBE_MARKER = 1
Constants.REQUIRED_CAPABILITIES = { "loadstring", "setfenv" }
Constants.CAPABILITY_FALLBACKS = {
	stepPhysics = "Workspace:StepPhysics indisponível: a física não será simulada nesta sessão.",
	changeHistoryRecording = "Sinais de gravação do ChangeHistoryService indisponíveis: mudanças em instâncias selecionadas serão tratadas como ambíguas.",
	textDocumentDidChange = "ScriptEditorService.TextDocumentDidChange indisponível: só a propriedade Source será observada.",
	pluginSettings = "Settings do plugin indisponíveis: o journal fica protegido apenas pelo espelho no place.",
	runMode = "RunService.Run indisponível: o Modo Compatibilidade não pode ser usado neste Studio.",
}

Constants.ERRORS = {
	REQUIRE_NON_MODULE = "Attempted to call require with invalid argument(s).",
	MODULE_NO_VALUE = "Module code did not return exactly one value",
	CYCLIC_REQUIRE = "Requested module was required recursively",
	INVALID_SIGNAL_MEMBER = "%s is not a valid member of RBXScriptSignal",
	JOURNAL_NOT_TABLE = "conteúdo não é um objeto",
	JOURNAL_FORMAT = "versão de formato desconhecida: %s",
	JOURNAL_SESSION = "sessionId ausente",
	JOURNAL_ENTRIES = "lista de entradas ausente",
	JOURNAL_ENTRY = "entrada %d inválida",
	JOURNAL_HASH = "hash do journal não confere",
	JOURNAL_CHUNKS = "chunks do journal incompletos",
	UNSUPPORTED_VALUE = "tipo de valor sem codificação: %s",
	NOT_RUNNING = "sessão não está em execução",
	ALREADY_ACTIVE = "já existe uma transição em andamento",
	START_STAGE = "falha em %s: %s",
	STEP_PHYSICS = "StepPhysics falhou: %s",
	REMOTE_TIMEOUT = "%s: nenhum handler de invoke registrado após %d s",
	REMOTE_WRONG_PLAYER = "%s: o jogador informado não está nesta sessão",
	REMOTE_WRONG_CONTEXT = "%s can only be called from the %s",
	RUN_SERVICE_CLIENT_ONLY = "%s can only be used from local scripts",
	STEP_ANIMATIONS = "Animator:StepAnimations falhou em %s: %s",
	PRESERVE_KEY = "LiveSession.preserve espera uma chave em texto",
	PRESERVE_INITIALIZER = "LiveSession.preserve espera uma função inicializadora",
	ON_RELOAD_CALLBACK = "LiveSession.onReload espera uma função",
	HUMANOID_MISSING = "personagem sem Humanoid: %s",
	CHARACTER_BUILD = "falha ao montar o personagem: %s",
	INVALID_ENGINE = "motor desconhecido: %s",
	COMPAT_REVERT_TIMEOUT = "o Studio não reverteu o mundo em %d s",
}

Constants.WARNINGS = {
	MISSING_CAPABILITY = {
		code = "C19",
		severity = "blocking",
		title = "Capacidade essencial ausente",
		happened = "A plataforma não oferece loadstring/setfenv a este plugin.",
		did = "O início da sessão foi bloqueado.",
		action = "Atualize o Studio ou reporte a versão: sem essas APIs o motor hospedado não funciona.",
	},
	CAPABILITY_FALLBACK = {
		code = "C19",
		severity = "alert",
		title = "Capacidade ausente com fallback",
		happened = "Uma API opcional não está disponível.",
		did = "O fallback correspondente foi ativado.",
		action = "Veja o detalhe para saber o que muda nesta sessão.",
	},
	TEAM_CREATE = {
		code = "C20",
		severity = "critical",
		title = "Team Create ativo",
		happened = "O place está aberto em Team Create: mutações de runtime, snapshot e espelho do journal são replicados a todos os colaboradores, e o rascunho na nuvem é salvo automaticamente durante a sessão.",
		did = "A sessão usa um lock compartilhado em ServerStorage.__LiveSession (dono, heartbeat e presença). Edições de colaboradores durante a sessão são gravadas como autoria e preservadas ao encerrar; qualquer colaborador com o plugin pode recuperar o mundo se o dono cair.",
		action = "Avise a equipe, não publique durante a sessão e encerre antes de sair. Este aviso aparece só no primeiro início.",
	},
	TEAM_SESSION_ACTIVE = {
		code = "C20",
		severity = "blocking",
		title = "Sessão de outro colaborador ativa",
		happened = "Existe um lock de sessão com heartbeat recente de outro colaborador neste place.",
		did = "O início foi bloqueado para não rodar dois jogos no mesmo mundo.",
		action = "Aguarde o colaborador encerrar. Se o Studio dele caiu, o lock expira sem heartbeat e o próximo início oferece a recuperação do mundo.",
	},
	TEAM_CLAIM_LOST = {
		code = "C21",
		severity = "critical",
		title = "Início simultâneo",
		happened = "Outro colaborador iniciou uma sessão no mesmo instante e venceu o desempate (início mais antigo, depois menor UserId).",
		did = "Esta sessão foi cancelada com rollback completo antes de tocar o mundo.",
		action = "Aguarde a sessão indicada no detalhe encerrar.",
	},
	TEAM_LOCK_LOST = {
		code = "C22",
		severity = "critical",
		title = "Lock da sessão perdido",
		happened = "A pasta __LiveSession foi removida ou assumida por outro colaborador durante a sessão.",
		did = "O runtime foi interrompido sem restauração: o mundo ficou como estava e o journal foi arquivado.",
		action = "Confira o mundo com a equipe; se a pasta reaparecer, o próximo início oferece a recuperação.",
	},
	TEAM_COLLABORATORS = {
		code = "C23",
		severity = "alert",
		title = "Colaboradores durante a sessão",
		happened = "Há outros colaboradores conectados ao place.",
		did = "Eles veem as mutações do jogo em tempo real; quem tem o plugin aparece como observador e pode assumir se o dono cair.",
		action = "Colaboradores sem o plugin não recebem avisos: combine com a equipe.",
	},
	TEAM_WATCH_LIMIT = {
		code = "C24",
		severity = "alert",
		title = "Atribuição de propriedades limitada",
		happened = "O place tem mais instâncias observadas do que o limite para acompanhar propriedades editadas por colaboradores.",
		did = "Edições de propriedades feitas por colaboradores em instâncias que você não selecionou não serão preservadas ao encerrar.",
		action = "Peça aos colaboradores para evitar edições de propriedades durante a sessão ou selecione as instâncias que eles editam.",
	},
	UNFINISHED_JOURNAL = {
		code = "C05",
		severity = "blocking",
		title = "Sessão anterior não finalizada",
		happened = "Um journal de sessão anterior foi encontrado sem fechamento.",
		did = "A recuperação está pronta para aplicar a autoria registrada.",
		action = "Escolha recuperar agora (restaura o mundo e reaplica a autoria) ou manter para depois.",
	},
	PLACE_SAVED_MID_SESSION = {
		code = "C06",
		severity = "critical",
		title = "Place salvo durante uma sessão",
		happened = "A pasta do plugin existe no place: ele foi salvo com o mundo em execução.",
		did = "O snapshot e o espelho do journal foram preservados para a recuperação.",
		action = "Confirme a recuperação para restaurar o mundo e reaplicar a autoria.",
	},
	SAVE_WARNING_FIRST_START = {
		code = "C06",
		severity = "critical",
		title = "Salvar o place durante a sessão",
		happened = "Durante a sessão o place contém o mundo em execução, o snapshot e o espelho do journal.",
		did = "Se o place for salvo nesse estado, o próximo início oferece restaurar o mundo e reaplicar a autoria.",
		action = "Prefira encerrar a sessão antes de salvar. Este aviso aparece uma vez por place.",
	},
	EXTERNAL_API_RISK = {
		code = "C16",
		severity = "critical",
		title = "APIs reais durante a sessão",
		happened = "Scripts hospedados acessam DataStore, HttpService e MemoryStore reais, como no Play nativo com acesso à API habilitado.",
		did = "Nada foi bloqueado.",
		action = "Revise scripts que escrevem em serviços externos antes de iniciar. Este aviso aparece uma vez por place.",
	},
	SETTINGS_WRITE_FAILED = {
		code = "C07",
		severity = "critical",
		title = "Persistência em disco indisponível",
		happened = "A escrita do journal nos settings do plugin falhou.",
		did = "A sessão continua em estado degradado, protegida apenas pelo espelho no place.",
		action = "Libere espaço em disco ou verifique permissões; salve o place antes de encerrar.",
	},
	LOCK_ALIVE = {
		code = "C08",
		severity = "blocking",
		title = "Outra sessão está ativa",
		happened = "Existe um lock de sessão com heartbeat recente para este place.",
		did = "O início foi bloqueado.",
		action = "Encerre a sessão na outra janela do Studio ou aguarde o lock expirar.",
	},
	NON_ARCHIVABLE = {
		code = "C13",
		severity = "critical",
		title = "Instâncias não arquiváveis",
		happened = "Instâncias com Archivable = false existem nos contêineres de jogo e não puderam entrar no snapshot.",
		did = "Elas foram listadas no detalhe; mudanças nelas não serão restauradas ao encerrar.",
		action = "Marque-as como arquiváveis se precisar restaurá-las.",
	},
	BROKEN_SCRIPT = {
		code = "C01",
		severity = "critical",
		title = "Script sem compilar há muito tempo",
		happened = "Um script permanece com erro de sintaxe além do limite.",
		did = "A última versão boa continua em execução; o texto quebrado está persistido exatamente como escrito.",
		action = "Corrija o script indicado no detalhe.",
	},
	SOURCE_CONFLICT = {
		code = "C12",
		severity = "critical",
		title = "Edição concorrente detectada",
		happened = "A base de uma edição não corresponde ao conteúdo que estava em execução.",
		did = "As duas versões foram guardadas íntegras no journal; a última escrita venceu no runtime.",
		action = "Revise o script indicado para reconciliar as mudanças.",
	},
	UNDO_DURING_SESSION = {
		code = "C15",
		severity = "critical",
		title = "Undo/Redo durante a sessão",
		happened = "Um desfazer ou refazer foi executado com o jogo em execução.",
		did = "Mutações de runtime podem ter sido revertidas junto; o journal garante o resultado final ao encerrar.",
		action = "Evite Undo/Redo durante a sessão. Este aviso aparece uma vez por sessão.",
	},
	START_FAILED = {
		code = "S01",
		severity = "critical",
		title = "Falha ao iniciar",
		happened = "Uma etapa do início falhou.",
		did = "Rollback completo: snapshot parcial apagado, watchers desligados, journal abortado.",
		action = "Veja o detalhe e tente novamente.",
	},
	STOP_FAILED = {
		code = "S02",
		severity = "critical",
		title = "Falha ao encerrar",
		happened = "Uma etapa do encerramento falhou.",
		did = "O journal foi mantido como não finalizado e a pasta do plugin foi preservada para recuperação.",
		action = "Inicie novamente para entrar na recuperação.",
	},
	CLONE_EDITS = {
		code = "S06",
		severity = "blocking",
		title = "Edições em clones não persistidas",
		happened = "Scripts clonados para o jogador virtual (PlayerGui, Backpack, PlayerScripts ou personagem) foram editados durante a sessão.",
		did = "Os clones são descartados ao encerrar: essas edições não estão nos scripts originais.",
		action = "Copie para os originais agora ou descarte. Da próxima vez, edite o original em StarterGui, StarterPack ou StarterPlayer.",
	},
	FREEZE_CONFIRM = {
		code = "S03",
		severity = "blocking",
		title = "Congelar o mundo como está",
		happened = "O encerramento vai manter tudo, inclusive os efeitos do jogo em execução.",
		did = "Nada foi aplicado ainda.",
		action = "Confirme para misturar o estado de runtime ao place, ou cancele para reverter o mundo.",
	},
	RECOVERY_DONE = {
		code = "S04",
		severity = "critical",
		title = "Recuperação concluída",
		happened = "A autoria da sessão anterior foi reaplicada.",
		did = "O relatório está no detalhe.",
		action = "Revise os itens não resolvidos, se houver.",
	},
	UNRESOLVED_AUTHORING = {
		code = "S05",
		severity = "critical",
		title = "Autoria sem destino",
		happened = "Instâncias criadas durante a sessão não encontraram o pai original.",
		did = "Elas foram movidas para a pasta indicada no detalhe.",
		action = "Reposicione-as manualmente.",
	},
	CROSS_REFERENCES = {
		code = "C26",
		severity = "alert",
		title = "Referências cruzadas sem destino",
		happened = "Referências apontavam para instâncias destruídas na restauração e não tinham id estável resolvível.",
		did = "As demais referências foram religadas por id; as listadas no detalhe ficaram nulas.",
		action = "Verifique as referências listadas.",
	},
	JOURNAL_LARGE = {
		code = "C27",
		severity = "alert",
		title = "Journal grande",
		happened = "O journal passou do limite de tamanho configurado.",
		did = "A compactação por histórico continua ativa; o flush fica mais lento.",
		action = "Encerre a sessão para arquivar o journal.",
	},
	COMPAT_MODE = {
		code = "C28",
		severity = "critical",
		title = "Modo Compatibilidade",
		happened = "A sessão vai usar o Run mode nativo do Studio: sem jogador virtual, sem GUI e sem hot reload granular.",
		did = "Scripts e física rodam nativos; a autoria é gravada no journal e reaplicada após a reversão do Studio.",
		action = "Use este modo só quando a fidelidade do motor hospedado não bastar. Este aviso aparece uma vez por place.",
	},
	COMPAT_REVERT_FAILED = {
		code = "C28",
		severity = "critical",
		title = "Reversão do Run mode não detectada",
		happened = "O Studio não sinalizou a reversão do mundo após RunService:Stop().",
		did = "O replay da autoria foi aplicado sobre o estado atual mesmo assim.",
		action = "Confira o mundo e, se necessário, use Undo.",
	},
	UNSUPPORTED_API = {
		code = "F01",
		severity = "alert",
		title = "API sem emulação na sessão",
		happened = "Um script usa uma API que o motor hospedado não emula. O que é emulado (Teleport, Messaging, Marketplace, Badges, Analytics, Policy, Social, Voice, Chat, CoreGui, Kick) não aparece aqui.",
		did = "O script roda mesmo assim; o detalhe indica script, linha e motivo.",
		action = "Veja a matriz de fidelidade antes de confiar nesse trecho.",
	},
	MEMORY_GROWTH = {
		code = "P01",
		severity = "critical",
		title = "Crescimento de memória",
		happened = "A memória Lua da sessão cresceu além do limite desde o início.",
		did = "Nada foi interrompido.",
		action = "Procure conexões ou tabelas que crescem a cada reload e encerre a sessão se o Studio ficar lento.",
	},
	TEST_PURCHASE = {
		code = "M01",
		severity = "blocking",
		title = "Compra de teste",
		happened = "O jogo pediu uma compra para o jogador virtual.",
		did = "Nada é cobrado: como no Play do Studio, a compra é simulada e os eventos de conclusão (e ProcessReceipt, para produtos) disparam conforme a sua escolha.",
		action = "Compre para testar o caminho de sucesso ou cancele para testar a recusa.",
	},
}

Constants.STATUS_KEYS = {
	STATE = "state",
	SESSION = "session",
	FPS = "fps",
	PHYSICS = "physics",
	SCRIPTS = "scripts",
	RELOADS = "reloads",
	LAST_RELOAD = "lastReload",
	RESOURCES = "resources",
	JOURNAL = "journal",
	DEGRADATION = "degradation",
	PROGRESS = "progress",
	CLIENT = "client",
	REMOTES = "remotes",
	ENGINE = "engine",
	COSTS = "costs",
	MEMORY = "memory",
	TEAM = "team",
	OUTPUT = "output",
}

Constants.OPTIONS = {
	CONFIRM = "Entendi",
	CANCEL = "Cancelar",
	RECOVER_NOW = "Recuperar agora",
	KEEP_FOR_LATER = "Manter para depois",
	FREEZE = "Congelar mesmo assim",
	REVERT = "Reverter o mundo",
	COPY_TO_ORIGINALS = "Copiar para os originais",
	DISCARD = "Descartar",
	BUY_TEST = "Comprar (teste)",
}

Constants.UI = {
	TOOLBAR_NAME = "Sessão Viva",
	BUTTON_ID = "LiveSessionToggle",
	BUTTON_TEXT = "Iniciar / Encerrar",
	BUTTON_TOOLTIP = "Iniciar ou encerrar a Sessão Viva (abre o painel)",
	BUTTON_ICON = "",
	PANEL_BUTTON_ID = "LiveSessionPanel",
	PANEL_BUTTON_TEXT = "Painel",
	PANEL_BUTTON_TOOLTIP = "Mostrar ou esconder o painel da Sessão Viva",
	OUTPUT_BUTTON_ID = "LiveSessionOutput",
	OUTPUT_BUTTON_TEXT = "Output",
	OUTPUT_BUTTON_TOOLTIP = "Mostrar ou esconder o Output da Sessão Viva",
	OUTPUT_WIDGET_ID = "LiveSessionOutputPanel",
	OUTPUT_WIDGET_TITLE = "Output · Sessão Viva",
	OUTPUT_WIDGET_WIDTH = 640,
	OUTPUT_WIDGET_HEIGHT = 300,
	OUTPUT_WIDGET_MIN_WIDTH = 360,
	OUTPUT_WIDGET_MIN_HEIGHT = 160,
	OUTPUT_OPEN_TEXT = "Abrir Output",
	OUTPUT_CLEAR_TEXT = "Limpar",
	OUTPUT_FILTER_FORMAT = "[%s] %s",
	OUTPUT_FILTER_LABELS = { error = "Erros", warn = "Alertas", print = "Mensagens" },
	OUTPUT_FILTER_WIDTH = 96,
	OUTPUT_CLEAR_WIDTH = 72,
	OUTPUT_COPY_TEXT = "Copiar",
	OUTPUT_COPY_WIDTH = 72,
	OUTPUT_COPY_HINT = "Tudo selecionado · Ctrl+C copia para a área de transferência",
	OUTPUT_LINE_FORMAT = "%s  %s",
	OUTPUT_TIME_FORMAT = "%H:%M:%S",
	OUTPUT_SUMMARY_FORMAT = "%d erro(s) · %d alerta(s) · %d linha(s)",
	OUTPUT_EMPTY_TEXT = "Nenhuma mensagem nesta sessão.",
	OUTPUT_TEXT_SIZE = 13,
	OUTPUT_SCROLL_TOLERANCE = 24,
	SESSION_START_TEXT = "Iniciar Sessão Viva",
	SESSION_STOP_TEXT = "Encerrar Sessão Viva",
	SESSION_BUSY_FORMAT = "%s…",
	PRIMARY_BUTTON_HEIGHT = 40,
	WIDGET_ID = "LiveSessionStatus",
	WIDGET_TITLE = "Sessão Viva",
	WIDGET_WIDTH = 340,
	WIDGET_HEIGHT = 420,
	WIDGET_MIN_WIDTH = 240,
	WIDGET_MIN_HEIGHT = 200,
	REVIEW_ID = "LiveSessionStopReview",
	REVIEW_TITLE = "Revisão de mudanças ambíguas",
	REVIEW_WIDTH = 520,
	REVIEW_HEIGHT = 420,
	GATE_GUI_NAME = "LiveSessionWarningGate",
	GATE_PANEL_WIDTH = 520,
	GATE_PANEL_HEIGHT = 360,
	GATE_WIDE_PANEL_WIDTH = 960,
	GATE_WIDE_PANEL_HEIGHT = 560,
	GATE_COLUMN_WIDTH_SCALE = 0.495,
	GATE_DISPLAY_ORDER = 1000000,
	REVIEW_INDENT = 16,
	MONO_FONT = Enum.Font.Code,
	ROW_HEIGHT = 22,
	BUTTON_HEIGHT = 32,
	PADDING = 12,
	GAP = 6,
	CORNER_RADIUS = 6,
	FONT = Enum.Font.Gotham,
	FONT_BOLD = Enum.Font.GothamBold,
	TEXT_SIZE = 14,
	TITLE_TEXT_SIZE = 18,
	BACKDROP_TRANSPARENCY = 0.45,
	COLORS = {
		BACKDROP = Color3.fromRGB(0, 0, 0),
		PANEL = Color3.fromRGB(37, 37, 42),
		PANEL_ALT = Color3.fromRGB(46, 46, 52),
		TEXT = Color3.fromRGB(235, 235, 240),
		TEXT_MUTED = Color3.fromRGB(170, 170, 180),
		ACCENT = Color3.fromRGB(0, 162, 255),
		DANGER = Color3.fromRGB(226, 72, 72),
		WARNING = Color3.fromRGB(236, 178, 64),
		OK = Color3.fromRGB(72, 190, 110),
		CHAT_NAME = Color3.fromRGB(120, 190, 255),
		CHAT_SYSTEM = Color3.fromRGB(236, 178, 64),
		HOTBAR_SLOT = Color3.fromRGB(37, 37, 42),
		HOTBAR_SELECTED = Color3.fromRGB(0, 162, 255),
	},
	STATUS_ROWS = {
		{ key = Constants.STATUS_KEYS.STATE, label = "Estado" },
		{ key = Constants.STATUS_KEYS.SESSION, label = "Sessão" },
		{ key = Constants.STATUS_KEYS.TEAM, label = "Team Create" },
		{ key = Constants.STATUS_KEYS.FPS, label = "FPS" },
		{ key = Constants.STATUS_KEYS.PHYSICS, label = "Física" },
		{ key = Constants.STATUS_KEYS.SCRIPTS, label = "Scripts ativos" },
		{ key = Constants.STATUS_KEYS.RELOADS, label = "Reloads" },
		{ key = Constants.STATUS_KEYS.LAST_RELOAD, label = "Último reload" },
		{ key = Constants.STATUS_KEYS.RESOURCES, label = "Recursos rastreados" },
		{ key = Constants.STATUS_KEYS.JOURNAL, label = "Journal" },
		{ key = Constants.STATUS_KEYS.DEGRADATION, label = "Degradação" },
		{ key = Constants.STATUS_KEYS.PROGRESS, label = "Progresso" },
		{ key = Constants.STATUS_KEYS.CLIENT, label = "Cliente" },
		{ key = Constants.STATUS_KEYS.REMOTES, label = "Remotes" },
		{ key = Constants.STATUS_KEYS.ENGINE, label = "Motor" },
		{ key = Constants.STATUS_KEYS.COSTS, label = "Custo por quadro" },
		{ key = Constants.STATUS_KEYS.MEMORY, label = "Memória Lua" },
		{ key = Constants.STATUS_KEYS.OUTPUT, label = "Output" },
	},
	FIDELITY_LABEL = "Matriz de fidelidade",
	FIDELITY_FINDINGS_LABEL = "APIs sem emulação detectadas",
	FIDELITY_ITEM_FORMAT = "%d. %s",
	FIDELITY_AREA_SCALE = 0.3,
	FIDELITY_STATUS_SCALE = 0.18,
	ENGINE_TOGGLE_FORMAT = "[%s] Modo Compatibilidade (Run mode)",
	CONFLICT_LEFT_TITLE = "Em execução · %s",
	CONFLICT_RIGHT_TITLE = "Nova versão · %s",
	REVIEW_FILTER_PLACEHOLDER = "Filtrar por caminho",
	REVIEW_KEEP_ALL = "Manter todos",
	REVIEW_REVERT_ALL = "Reverter todos",
	REVIEW_MIXED = "Misto",
	REVIEW_GROUP_FORMAT = "%s (%d)",
	GATE_TITLE_FORMAT = "%s · %s",
	PARAGRAPH_SEPARATOR = "\n\n",
	LINE_SEPARATOR = "\n",
	EMPTY_TEXT = "",
	FREEZE_TOGGLE_FORMAT = "[%s] Congelar o mundo ao encerrar",
	TOGGLE_ON = "x",
	TOGGLE_OFF = " ",
	FREEZE_TOGGLE_LABEL = "Congelar o mundo ao encerrar",
	ERRORS_LABEL = "Erros recentes",
	WARNINGS_LABEL = "Alertas",
	EMPTY_VALUE = "—",
	REVIEW_KEEP = "Manter",
	REVIEW_REVERT = "Reverter",
	REVIEW_DONE = "Concluir",
	REVIEW_HINT = "Mudanças feitas fora de uma gravação do histórico em instâncias selecionadas. O padrão é manter.",
}
Constants.UI.FIDELITY_COLORS = {
	[Constants.FIDELITY_STATUS.FULL] = Constants.UI.COLORS.OK,
	[Constants.FIDELITY_STATUS.PARTIAL] = Constants.UI.COLORS.WARNING,
	[Constants.FIDELITY_STATUS.NONE] = Constants.UI.COLORS.DANGER,
}

Constants.TEXTS = {
	DEGRADATION_NONE = "nenhuma",
	DEGRADATION_PREFIX = "quadros acima de %d ms por %d s: ",
	DEGRADATION_LEVELS = {
		"física a %d Hz",
		"física a %d Hz · reload com debounce de %.1f s",
		"física a %d Hz · reload com debounce de %.1f s · painel a cada %.1f s",
	},
	COSTS_FORMAT = "física %.1f · servidor %.1f · cliente %.1f · watchers %.1f ms",
	MEMORY_FORMAT = "%d MB (+%d MB)",
	MEMORY_WARN_FORMAT = "memória Lua cresceu %d MB desde o início (limite %d MB)",
	ENGINE_LABELS = { hosted = "Hospedado", compatibility = "Compatibilidade (Run mode)" },
	RESTORE_INCREMENTAL = "restauração incremental: %d de %d raiz(es) trocadas",
	RESTORE_FULL = "restauração completa: %d de %d raiz(es) tocadas, acima de %d%%",
	RESTORE_WITH_TERRAIN = "%s; %s",
	RESTORE_TERRAIN_DONE = "terreno: voxels e propriedades restaurados do snapshot",
	RESTORE_TERRAIN_SKIPPED = "terreno: voxels mantidos (a cópia do terreno não replica no Team Create; confira o terreno se o jogo o alterou)",
	RESTORE_TERRAIN_FAILED = "terreno: falha ao restaurar os voxels (%s)",
	RESTORE_TERRAIN_NOT_CAPTURED = "terreno: não foi copiado no início (%s); voxels mantidos",
	RELINK_REPORT = "relink: %d referência(s) religada(s) · %d sem destino",
	REFERENCE_FORMAT = "%s.%s",
	API_FINDING_FORMAT = "%s linha %d · API sem emulação: %s. %s",
	BATCH_LABEL_FORMAT = "lote de %d scripts",
	SOURCE_COMPACTED = "(versão compactada: só o hash foi mantido)",
	JOURNAL_LARGE_FORMAT = "%d KB (limite %d KB)",
	PROGRESS_BODIES = "corpos",
	STAGE_RUN_MODE = "Run mode",
	PHYSICS_FORMAT = "%d Hz",
	PHYSICS_OFF = "desligada",
	PHYSICS_NATIVE = "nativa (Run mode)",
	RELOAD_REPORT = "%s · %d módulo(s) · %.1f ms · %d recurso(s) liberado(s)",
	RELOAD_STATUS_FORMAT = "%s: %s",
	JOURNAL_FORMAT = "%d entrada(s) · %d KB%s",
	JOURNAL_DEGRADED_SUFFIX = " · só espelho",
	RESOURCES_FORMAT = "%d conexões · %d threads · %d instâncias",
	PROGRESS_FORMAT = "%s %d/%d",
	PROGRESS_IDS = "ids",
	PROGRESS_SNAPSHOT = "snapshot",
	PROGRESS_RESTORE = "restauração",
	PROGRESS_CLEANUP = "limpeza",
	PROGRESS_SCRIPTS = "scripts",
	PROGRESS_INDEX = "índice",
	SESSION_STARTED = "sessão %s iniciada",
	SESSION_STOPPED = "sessão %s encerrada",
	NON_ARCHIVABLE_LIST = "%d instância(s): %s",
	LIST_SEPARATOR = ", ",
	LIST_TRUNCATED = " … (+%d)",
	LIST_MAX_ITEMS = 12,
	RECOVERY_REPORT = "Sessão %s · origem: %s · %d entrada(s) · aplicadas %d · reconstruídas %d · ignoradas %d · falhas %d · não resolvidas %d",
	RESTORE_REPORT = "aplicadas %d · reconstruídas %d · ignoradas %d · falhas %d · não resolvidas %d",
	SOURCE_SETTINGS = "settings",
	SOURCE_MIRROR = "espelho",
	RECOVERY_NO_JOURNAL = "Journal indisponível: nada é revertido, o mundo é mantido como está e a pasta do plugin é removida.",
	UNDO_LABEL = "undo",
	REDO_LABEL = "redo",
	REVIEW_ITEM_PROPERTY = "%s · %s alterado",
	REVIEW_ITEM_DESTROY = "%s · removido",
	LOAD_ERROR_FORMAT = "%s: %s",
	BROKEN_FORMAT = "%s está sem compilar há %d s: %s",
	CONFLICT_FORMAT = "%s: base esperada %s, encontrada %s",
	UNRESOLVED_FORMAT = "%d instância(s) movidas para %s",
	STAGE_PREFLIGHT = "pré-voo",
	STAGE_IDS = "atribuição de ids",
	STAGE_SNAPSHOT = "snapshot",
	STAGE_WATCHERS = "watchers",
	STAGE_SCRIPTS = "início dos scripts",
	STAGE_JOURNAL = "journal",
	STAGE_RESTORE = "restauração",
	STAGE_CLEANUP = "limpeza",
	CLIENT_FORMAT = "%s · personagem %s · %d GUI(s)",
	CLIENT_OFF = "desligado",
	CHARACTER_ALIVE = "vivo",
	CHARACTER_DEAD = "morto",
	CHARACTER_NONE = "ausente",
	REMOTES_FORMAT = "%d remote(s) · %d handler(s) · %d expirado(s)",
	REMOTE_TIMEOUT_STATUS = "remote %s expirou sem handler",
	RELOAD_CALLBACK_FAILED = "%s: callback de onReload falhou: %s",
	INPUT_RELEASED = "entrada devolvida ao Studio (Esc); clique no viewport para retomar",
	TEAM_OFF = "não",
	TEAM_SUMMARY_FORMAT = "%d colaborador(es) · %d com o plugin",
	TEAM_OWN_SUFFIX = " · sessão sua · %d edição(ões) de colaboradores",
	TEAM_FOREIGN_SUFFIX = " · sessão de %s (heartbeat há %d s)",
	TEAM_STALE_SUFFIX = " · sessão de %s sem heartbeat há %d s",
	TEAM_LOCK_FORMAT = "%s (%d) · sessão %s · iniciada às %s · heartbeat há %d s",
	TEAM_STALE_HINT = "o lock expira sem heartbeat por %d s",
	TEAM_FOREIGN_STARTED = "Sessão Viva de %s iniciada",
	TEAM_FOREIGN_ENDED = "Sessão Viva de %s encerrada",
	TEAM_FOLDER_REMOVED = "a pasta %s foi removida do ServerStorage",
	TEAM_TAKEN_BY = "o lock agora pertence a %s",
	TEAM_COLLABORATORS_FORMAT = "%d colaborador(es): %s · %d com o plugin",
	TEAM_WATCH_LIMIT_FORMAT = "%d instância(s) observada(s), limite %d",
	TEAM_NO_COMPAT = "Modo Compatibilidade indisponível em Team Create: o Run mode nativo não é coordenado entre colaboradores; a sessão usa o motor hospedado.",
	DEGRADATION_TEAM = "física a %d Hz por Team Create (colaboradores conectados)",
	RECOVERY_OWNER_FORMAT = "Sessão anterior de %s",
	PROGRESS_WATCH = "propriedades",
	OUTPUT_STATUS_FORMAT = "%d erro(s) · %d alerta(s)",
	LOAD_SUMMARY = "Carga: %d script(s) em execução (%d servidor · %d cliente) · %d com falha · %d desabilitado(s) · %d ignorado(s)",
	LOAD_FAILED_FORMAT = "Não carregou · %s: %s",
	LOAD_NOT_STARTED_FORMAT = "Não executado · %s: %s",
	LOAD_SKIPPED_LIST = "Ignorados (também não rodam no jogo nativo): %s",
	LOAD_SKIPPED_ITEM = "%s (%s)",
	LOAD_REASON_LOCAL_SCRIPT = "LocalScript fora de ReplicatedFirst e dos contêineres do jogador",
	LOAD_REASON_LEGACY = "Script Legacy fora de Workspace/ServerScriptService",
	LOAD_REASON_CLIENT_CONTEXT = "RunContext Client fora de um contêiner replicado",
	LOAD_REASON_PLUGIN_CONTEXT = "RunContext Plugin",
	LOAD_REASON_NO_CLONE = "nenhum clone em execução no jogador virtual (Archivable desligado ou contêiner não montado)",
	LOAD_REASON_UNKNOWN = "nenhum host aceitou o script",
	CLONE_EDIT_FORMAT = "Edição em %s não será persistida: é um clone em execução. Edite o original %s (ao encerrar, o plugin oferece copiar).",
	CLONE_EDITS_DETAIL = "%d script(s): %s",
	CLONE_EDITS_COPIED = "%d edição(ões) em clones copiadas para os originais",
	CLONE_EDITS_DISCARDED = "%d edição(ões) em clones descartadas",
	RUNTIME_EDIT_FORMAT = "Edição em %s não será persistida: o script foi criado durante a sessão (pelo jogo ou fora de uma gravação do histórico) e é removido ao encerrar. Edite a origem dele (o modelo clonado ou o código que o cria).",
	PURCHASE_DETAIL = "%s: %s · %s",
	PURCHASE_PRICE_FORMAT = "R$ %s",
	PURCHASE_PRICE_UNKNOWN = "preço indisponível",
	PURCHASE_PREMIUM = "Assinatura Premium",
	PURCHASE_KINDS = { asset = "Item", gamePass = "Passe", product = "Produto", bundle = "Pacote", subscription = "Assinatura" },
	PURCHASE_NO_RECEIPT = "compra de produto concluída sem MarketplaceService.ProcessReceipt definido no servidor: no jogo publicado a compra ficaria pendente",
	PURCHASE_RECEIPT_FAILED = "ProcessReceipt falhou: %s",
	TELEPORT_STUDIO_FAILED = "Teleport failed because %s (Failure)",
	SHUTDOWN_FAILED = "falha ao encerrar um módulo do cliente: %s",
	KICK_TITLE = "Desconectado",
	KICK_DEFAULT_MESSAGE = "Você foi expulso desta experiência.",
	CHAT_PLACEHOLDER = "Para conversar, clique aqui ou pressione /",
}

Constants.BRIDGES = {
	NONE = table.freeze({}),
	REMOTE = "Remote",
	ANIMATION = "Animation",
	ANIMATION_CLASSES = { "Animator", "Humanoid", "AnimationController" },
	LOAD_ANIMATION = "LoadAnimation",
	HOOKS = { "read", "write", "afterCall" },
	INVALID_MESSAGE = "addBridge expects a table with name (string), matches (function) and optional read, write and afterCall functions",
}

Constants.INPUT = {
	STAGES = { BEGAN = "began", CHANGED = "changed", ENDED = "ended" },
	PRIORITIES = { CONTEXT_ACTIONS = 400, TOOLS = 300, PROMPTS = 200, CLICK_DETECTORS = 100, GAME_SIGNALS = 0 },
	RAY_MAX_DISTANCE = 1000,
	RAY_FILTER_TYPE = Enum.RaycastFilterType.Exclude,
	SIGNALS = { "InputBegan", "InputChanged", "InputEnded", "JumpRequest" },
	STAGE_SIGNALS = { began = "InputBegan", changed = "InputChanged", ended = "InputEnded" },
	JUMP_SIGNAL = "JumpRequest",
	INVALID_LISTENER_MESSAGE = "addListener expects a numeric priority and a listener function",
}

Constants.TEXT_CHAT = {
	OWNER_NAME = "TextChatShim",
	CHANNELS_FOLDER = "TextChannels",
	COMMANDS_FOLDER = "TextChatCommands",
	GENERAL_CHANNEL = "RBXGeneral",
	SYSTEM_CHANNEL = "RBXSystem",
	CHANNEL_CLASS = "TextChannel",
	TEXT_SOURCE_CLASS = "TextSource",
	MESSAGE_CLASS = "TextChatMessage",
	PROPERTIES_CLASS = "TextChatMessageProperties",
	CREATE_DEFAULT_CHANNELS = "CreateDefaultTextChannels",
	SUCCESS_STATUS = Enum.TextChatMessageStatus.Success,
	METHODS = {
		SEND_ASYNC = "SendAsync",
		DISPLAY_SYSTEM_MESSAGE = "DisplaySystemMessage",
		ADD_USER_ASYNC = "AddUserAsync",
		SET_DIRECT_CHAT_REQUESTER = "SetDirectChatRequester",
		DISPLAY_BUBBLE = "DisplayBubble",
	},
	MEMBERS = {
		MESSAGE_RECEIVED = "MessageReceived",
		SENDING_MESSAGE = "SendingMessage",
		ON_INCOMING_MESSAGE = "OnIncomingMessage",
		SHOULD_DELIVER_CALLBACK = "ShouldDeliverCallback",
	},
	TRUE_METHODS = { "CanUserChatAsync", "CanUsersChatAsync", "CanUsersDirectChatAsync" },
	INVALID_TEXT_MESSAGE = "TextChannel expects the message to be a string",
}
Constants.KICK = {
	GUI_NAME = "KickOverlay",
	DISPLAY_ORDER = 1000,
	BACKGROUND_TRANSPARENCY = 0.35,
	PANEL_SIZE = UDim2.fromOffset(360, 0),
}

Constants.CHAT_WINDOW = {
	GUI_NAME = "ChatWindow",
	DISPLAY_ORDER = 900,
	CORE_GUI_TYPE = Enum.CoreGuiType.Chat,
	FOCUS_KEY = Enum.KeyCode.Slash,
	FOCUS_KEY_TEXT = "/",
	FOCUS_PRIORITY = Constants.INPUT.PRIORITIES.GAME_SIGNALS - 1,
	MAX_LENGTH = 200,
	MAX_LINES = 50,
	SIZE = UDim2.fromOffset(360, 200),
	POSITION = UDim2.fromOffset(8, 8),
	INPUT_HEIGHT = 28,
	LINE_GAP = 2,
	SCROLL_BAR_THICKNESS = 4,
	BACKGROUND_TRANSPARENCY = 0.5,
	LINE_FORMAT = '<font color="#%s">%s:</font> %s',
	SYSTEM_LINE_FORMAT = '<font color="#%s">%s</font>',
	RICH_TEXT_PATTERN = "[&<>]",
	RICH_TEXT_ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" },
	BLANK_PATTERN = "^%s*$",
	CONTENT_SIZE_PROPERTY = "AbsoluteContentSize",
}

Constants.CONTEXT_ACTIONS = {
	SERVICE = "ContextActionService",
	DEFAULT_PRIORITY = Enum.ContextActionPriority.Medium.Value,
	INPUT_ENUMS = { Enum.KeyCode, Enum.UserInputType, Enum.PlayerActions },
	PLAYER_ACTION_KEYS = {
		[Enum.PlayerActions.CharacterJump] = "JUMP_KEYS",
		[Enum.PlayerActions.CharacterForward] = "FORWARD_KEYS",
		[Enum.PlayerActions.CharacterBackward] = "BACK_KEYS",
		[Enum.PlayerActions.CharacterLeft] = "LEFT_KEYS",
		[Enum.PlayerActions.CharacterRight] = "RIGHT_KEYS",
	},
	STAGE_STATES = { began = Enum.UserInputState.Begin, changed = Enum.UserInputState.Change, ended = Enum.UserInputState.End },
	PASS_RESULT = Enum.ContextActionResult.Pass,
	SIGNALS = { "LocalToolEquipped", "LocalToolUnequipped", "BoundActionAdded", "BoundActionRemoved", "BoundActionChanged" },
	EVENTS = {
		TOOL_EQUIPPED = "LocalToolEquipped",
		TOOL_UNEQUIPPED = "LocalToolUnequipped",
		ACTION_ADDED = "BoundActionAdded",
		ACTION_REMOVED = "BoundActionRemoved",
		ACTION_CHANGED = "BoundActionChanged",
	},
	METHODS = {
		BIND_ACTION = "BindAction",
		BIND_ACTION_AT_PRIORITY = "BindActionAtPriority",
		UNBIND_ACTION = "UnbindAction",
		UNBIND_ALL_ACTIONS = "UnbindAllActions",
		GET_BOUND_ACTION_INFO = "GetBoundActionInfo",
		GET_ALL_BOUND_ACTION_INFO = "GetAllBoundActionInfo",
		GET_CURRENT_LOCAL_TOOL_ICON = "GetCurrentLocalToolIcon",
	},
	SETTERS = { SetTitle = "title", SetImage = "image", SetDescription = "description", SetPosition = "position" },
	NIL_METHODS = { "GetButton", "BindActivate", "UnbindActivate" },
	ERRORS = {
		INVALID_NAME = "BindAction requires a string action name",
		INVALID_CALLBACK = "BindAction requires a function",
		INVALID_INPUT = "Invalid input type passed to BindAction",
	},
}
Constants.CLICK_DETECTORS = {
	CLASS_NAME = "ClickDetector",
	HOVER_INTERVAL = 0.05,
	DEFAULT_CURSOR = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png",
	SIGNALS = { "MouseClick", "RightMouseClick", "MouseHoverEnter", "MouseHoverLeave" },
	EVENTS = { HOVER_ENTER = "MouseHoverEnter", HOVER_LEAVE = "MouseHoverLeave" },
	BUTTON_EVENTS = { [Enum.UserInputType.MouseButton1] = "MouseClick", [Enum.UserInputType.MouseButton2] = "RightMouseClick" },
}

Constants.TOOLS = {
	CLASS_NAME = "Tool",
	HUMANOID_BRIDGE_NAME = "ToolHumanoid",
	HANDLE_NAME = "Handle",
	GRIP_WELD_NAME = "RightGrip",
	GRIP_PROPERTY = "Grip",
	GRIP_LIMB = { [Enum.HumanoidRigType.R15] = "RightHand", [Enum.HumanoidRigType.R6] = "Right Arm" },
	GRIP_ATTACHMENT = "RightGripAttachment",
	GRIP_C0_R6 = CFrame.new(0, -1, 0, 1, 0, 0, 0, 0, 1, 0, -1, 0),
	DROP_KEY = Enum.KeyCode.Backspace,
	DROP_OFFSET = Vector3.new(0, 0, -3),
	ACTIVATE_BUTTON = Enum.UserInputType.MouseButton1,
	SIGNALS = { "Activated", "Deactivated", "Equipped", "Unequipped" },
	EVENTS = { ACTIVATED = "Activated", DEACTIVATED = "Deactivated", EQUIPPED = "Equipped", UNEQUIPPED = "Unequipped" },
	METHODS = { ACTIVATE = "Activate", DEACTIVATE = "Deactivate" },
	HUMANOID_METHODS = { EQUIP = "EquipTool", UNEQUIP = "UnequipTools" },
}
Constants.HOTBAR = {
	GUI_NAME = "Hotbar",
	MAX_SLOTS = 10,
	SLOT_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero },
	SLOT_LABELS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
	SLOT_SIZE = 56,
	SLOT_GAP = 6,
	SLOT_TRANSPARENCY = 0.2,
	BOTTOM_MARGIN = 12,
	TOOLTIP_OFFSET = 8,
	LABEL_INSET = 4,
	LABEL_TEXT_SIZE = 12,
	NAME_TEXT_SIZE = 12,
	ICON_PADDING = 6,
	DISPLAY_ORDER = 800,
	WATCHED_PROPERTIES = { Name = true, TextureId = true, ToolTip = true },
	CORE_GUI_TYPE = Enum.CoreGuiType.Backpack,
}
Constants.CORE_GUI = {
	GUI_NAME = "Notifications",
	NOTIFICATION_DURATION = 5,
	NOTIFICATION_SIZE = UDim2.fromOffset(280, 72),
	NOTIFICATION_GAP = 6,
	MARGIN = 12,
	ICON_SIZE = 40,
	BUTTON_HEIGHT = 24,
	DISPLAY_ORDER = 950,
	ALL_TYPE = Enum.CoreGuiType.All,
	BINDABLE_FUNCTION_CLASS = "BindableFunction",
	METHODS = {
		SET_CORE = "SetCore",
		GET_CORE = "GetCore",
		SET_CORE_GUI_ENABLED = "SetCoreGuiEnabled",
		GET_CORE_GUI_ENABLED = "GetCoreGuiEnabled",
		SEND_NOTIFICATION = "SendNotification",
		CHAT_SYSTEM_MESSAGE = "ChatMakeSystemMessage",
	},
	NOTIFICATION_FIELDS = { TITLE = "Title", TEXT = "Text", ICON = "Icon", DURATION = "Duration", BUTTON1 = "Button1", BUTTON2 = "Button2", CALLBACK = "Callback" },
	BUTTON_FIELDS = { "Button1", "Button2" },
	DEFAULTS = { ChatActive = false, TopbarEnabled = true, DevConsoleVisible = false, AvatarContextMenuEnabled = false, PointsNotificationsActive = true, BadgesNotificationsActive = true },
	STORED_CORES = { "ResetButtonCallback", "TopbarEnabled", "ChatActive", "ChatBarDisabled", "AvatarContextMenuEnabled", "PromptSendFriendRequest", "PromptBlockPlayer", "DevConsoleVisible" },
}

Constants.LIFECYCLE = {
	STOP = "stop",
	CLEAR = "clear",
	HIDE = "hide",
	DESTROY = "destroy",
	CLEAR_BRIDGES = "clearBridges",
}

 
 
 
Constants.MCP_BRIDGE = {
	VERSION = "1.1.0",
	PROTOCOL = 1,
	FOLDER_NAME = "LiveSessionBridge",
	INVOKE_NAME = "Invoke",
	EVENT_NAME = "Event",
	HEARTBEAT_SECONDS = 2,
	AWAIT_DEFAULT_SECONDS = 3,
	AWAIT_MAX_SECONDS = 20,
	AWAIT_POLL_SECONDS = 0.05,
	JOURNAL_DEFAULT_LIMIT = 50,
	JOURNAL_MAX_LIMIT = 500,
	OUTPUT_DEFAULT_LIMIT = 100,
	OUTPUT_MAX_LIMIT = 400,
	RELOAD_HISTORY = 20,
	LIST_MAX = 200,
	VALUE_PREVIEW = 160,
	 
	 
	IGNORED_TOOL_FOLDERS = { ImportMCP = true },
	EVENTS = { STATE = "state", RELOAD = "reload", GUI_SYNC = "guiSync", RECORD = "record" },
	COMMANDS = {
		PING = "ping",
		STATUS = "status",
		START = "start",
		STOP = "stop",
		VERIFY = "verify",
		AWAIT = "await",
		RESTART = "restart",
		RECORD = "record",
		JOURNAL = "journal",
		OUTPUT = "output",
		RESYNC_GUI = "resyncGui",
	},
}

 
 
Constants.GUI_SYNC = {
	DEBOUNCE_SECONDS = 0.25,
	IGNORED_PROPERTIES = {
		Source = true,
		Archivable = true,
		AbsoluteSize = true,
		AbsolutePosition = true,
		AbsoluteRotation = true,
		AbsoluteCanvasSize = true,
		AbsoluteWindowSize = true,
		AbsoluteContentSize = true,
		AbsoluteCellSize = true,
		AbsoluteCellCount = true,
		TextBounds = true,
		TextFits = true,
		ContentText = true,
		IsLoaded = true,
		GuiState = true,
		LiveSessionId = true,
	},
}

Constants.TEXTS.NOT_RUNNING = Constants.ERRORS.NOT_RUNNING
Constants.TEXTS.MCP_UNKNOWN_COMMAND = "comando desconhecido na ponte da Sessão Viva: %s"
Constants.TEXTS.MCP_REASON_CLONE = "clone em runtime de %s: edite o original (a edição no clone some ao encerrar)"
Constants.TEXTS.MCP_REASON_RUNTIME_SCRIPT = "script criado pelo jogo durante a sessão: some ao encerrar; edite a origem"
Constants.TEXTS.MCP_REASON_RUNTIME_INSTANCE = "instância criada pelo jogo (ou dentro do jogador virtual): some ao encerrar"
Constants.TEXTS.MCP_REASON_JOURNALED = "registrado no journal: persiste ao encerrar"
Constants.TEXTS.MCP_REASON_UNCHANGED = "sem edição nesta sessão"
Constants.TEXTS.MCP_REASON_PENDING = "mudança ainda não processada pelo hot reload"
Constants.TEXTS.MCP_REASON_CREATED = "criada nesta sessão e registrada no journal: persiste ao encerrar"
Constants.TEXTS.MCP_REASON_PREEXISTING = "pré-existente: propriedades editadas pelo MCP entram no journal (record) e persistem"
Constants.TEXTS.MCP_REASON_IGNORED = "fora da observação da Sessão Viva (pasta de ferramenta)"
Constants.TEXTS.MCP_REASON_COMPAT = "Modo Compatibilidade: sem hot reload granular; a mudança entra no journal e vale ao reiniciar a sessão"
Constants.TEXTS.MCP_RECORDED_FORMAT = "MCP · %d propriedade(s) registrada(s) no journal"
Constants.TEXTS.GUI_SYNC_FORMAT = "UI · %s atualizada no PlayerGui (%s)"
Constants.TEXTS.GUI_SYNC_REMOVED_FORMAT = "UI · %s removida do PlayerGui"
Constants.TEXTS.GUI_SYNC_MODE_REMOUNT = "remontada"
Constants.TEXTS.GUI_SYNC_MODE_MIRROR = "propriedade espelhada"

return Constants

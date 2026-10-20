local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")

local Constants = require(script.Parent.Parent.Core.Constants)
local HostedSignal = require(script.Parent.HostedSignal)

local MarketplaceShim = {}
MarketplaceShim.__index = MarketplaceShim

local MARKET = Constants.MARKETPLACE
local KINDS = MARKET.KINDS
local RESULTS = MARKET.RESULTS
local TEXTS = Constants.TEXTS

function MarketplaceShim.new(proxy, tracker, deps)
	local self = setmetatable({
		proxy = proxy,
		tracker = tracker,
		deps = deps,
		signals = {},
		owned = {},
		receiptCallback = nil,
	}, MarketplaceShim)
	for _, name in ipairs(MARKET.SIGNALS) do
		self.signals[name] = HostedSignal.new(tracker)
	end
	for _, kind in pairs(KINDS) do
		self.owned[kind] = {}
	end
	return self
end

function MarketplaceShim:owns(kind, id)
	return self.owned[kind][id] == true
end

function MarketplaceShim:productInfo(config, id)
	if config.kind == KINDS.SUBSCRIPTION then
		local ok, info = pcall(MarketplaceService.GetSubscriptionProductInfoAsync, MarketplaceService, id)
		if ok and info then
			return info.Name, info.DisplayPrice
		end
	elseif config.infoType then
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, config.infoType)
		if ok and info then
			return info.Name, info.PriceInRobux
		end
	end
	return tostring(id), nil
end

function MarketplaceShim:describe(config, id)
	if config.kind == KINDS.PREMIUM then
		return TEXTS.PURCHASE_PREMIUM, 0
	end
	local name, price = self:productInfo(config, id)
	local priceText = price ~= nil and string.format(TEXTS.PURCHASE_PRICE_FORMAT, tostring(price)) or TEXTS.PURCHASE_PRICE_UNKNOWN
	return string.format(TEXTS.PURCHASE_DETAIL, TEXTS.PURCHASE_KINDS[config.kind], name, priceText), tonumber(price) or 0
end

function MarketplaceShim:grantProduct(productId, price)
	local callback = self.receiptCallback
	if not callback then
		self.deps.warn(TEXTS.PURCHASE_NO_RECEIPT)
		return true
	end
	local receipt = {
		PurchaseId = HttpService:GenerateGUID(false),
		PlayerId = self.deps.getUserId(),
		ProductId = productId,
		PlaceIdWherePurchased = game.PlaceId,
		CurrencySpent = price,
		CurrencyType = Enum.CurrencyType.Robux,
	}
	local ok, decision = pcall(callback, receipt)
	if not ok then
		self.deps.warn(string.format(TEXTS.PURCHASE_RECEIPT_FAILED, tostring(decision)))
		return false
	end
	return decision == Enum.ProductPurchaseDecision.PurchaseGranted
end

function MarketplaceShim:finish(config, id, purchased)
	local signal = self.signals[config.finished]
	if config.result == RESULTS.USER_ID then
		signal:fire(self.deps.getUserId(), id, purchased)
	elseif config.result == RESULTS.PLAYER_ONLY then
		signal:fire(self.deps.getPlayer())
	else
		signal:fire(self.deps.getPlayer(), id, purchased)
	end
end

function MarketplaceShim:prompt(config, id)
	task.spawn(function()
		local detail, price = self:describe(config, id)
		local purchased = self.deps.confirm(detail)
		if purchased and config.receipt then
			purchased = self:grantProduct(id, price)
		end
		if purchased and id ~= nil then
			self.owned[config.kind][id] = true
		end
		if purchased and config.kind == KINDS.PREMIUM then
			self.deps.setMembership(Enum.MembershipType.Premium)
		end
		self:finish(config, id, purchased)
	end)
end

function MarketplaceShim:promptMethod(config)
	return function()
		return function(_, ...)
			local arguments = table.pack(...)
			self:prompt(config, arguments[config.idIndex])
		end
	end
end

function MarketplaceShim:ownershipGetters()
	return {
		[MARKET.USER_OWNS_GAME_PASS] = function()
			return function(_, userId, gamePassId)
				if self:owns(KINDS.GAME_PASS, gamePassId) then
					return true
				end
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, gamePassId)
				return ok and owns == true
			end
		end,
		[MARKET.PLAYER_OWNS_ASSET] = function()
			return function(_, _, assetId)
				return self:owns(KINDS.ASSET, assetId)
			end
		end,
		[MARKET.PLAYER_OWNS_BUNDLE] = function()
			return function(_, _, bundleId)
				return self:owns(KINDS.BUNDLE, bundleId)
			end
		end,
		[MARKET.SUBSCRIPTION_STATUS] = function()
			return function(_, _, subscriptionId)
				local subscribed = self:owns(KINDS.SUBSCRIPTION, subscriptionId)
				return { IsSubscribed = subscribed, IsRenewing = subscribed }
			end
		end,
		[MARKET.SUBSCRIPTION_HISTORY] = function()
			return function()
				return {}
			end
		end,
	}
end

function MarketplaceShim:install()
	local getters = self:ownershipGetters()
	for name, config in pairs(MARKET.PROMPTS) do
		getters[name] = self:promptMethod(config)
	end
	for name, signal in pairs(self.signals) do
		getters[name] = function()
			return signal:interface()
		end
	end
	getters[MARKET.PROCESS_RECEIPT] = function()
		return self.receiptCallback
	end
	self.proxy:override(MarketplaceService, getters, {
		[MARKET.PROCESS_RECEIPT] = function(callback)
			self.receiptCallback = callback
		end,
	})
end

function MarketplaceShim:clear()
	for _, signal in pairs(self.signals) do
		signal:clear()
	end
	for _, kind in pairs(KINDS) do
		self.owned[kind] = {}
	end
	self.receiptCallback = nil
	self.proxy:clearOverrides(MarketplaceService)
end

return MarketplaceShim

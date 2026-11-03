--[[
	PassService: game passes from GameData.GamePasses (IDs set there; 0 = not set up yet).
	Ownership is mirrored to player attributes Pass_<key> (e.g. Pass_DoubleCoins).
	  DoubleCoins  - PlayerData.addCoins doubles every positive amount
	  ExtraSlots   - +6 team capacity (BaseManager.recalcCapacity)
	  RainbowTrail - a rainbow Trail on the character
	  DoubleXP     - BattleService.grantXP doubles battle XP
	  VIP          - bundle pass: switches on every pass in its `grants` list (PremiumDecor, RainbowTrail, Gladiator)
	Developer products (GameData.Products, bought every use; receipts go through DecorService.processReceipt,
	which records each PurchaseId in the player's save so a retried receipt is never granted twice):
	  InstantHeal  - heals the whole team (after the battle, if bought mid-battle; saved as pending.heal
	                 so leaving mid-battle still delivers it on next join)
	  SummonRare   - starts the rare spawn event for the whole server (fixed pick, never random). Counted in
	                 pending.summons until it actually appears, so a shutdown or leaving while queued
	                 re-summons it on next join (PassService.onLoaded)
	  boost        - timed personal 2x (Boost_<key> attribute, read by GameData.hasBoost)
	  serverBoost  - timed 2x for the whole server (ReplicatedStorage ServerBoost_<key>)
	  items        - item packs straight into the Bag
	The shop menu (client) prompts purchases; ownership is re-checked when a purchase finishes.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local BaseManager = require(script.Parent.BaseManager)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local PassService = {}

local function addTrail(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild("RainbowTrail") then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, 0.8, 0.4)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -1.2, 0.4)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "RainbowTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.LightEmission = 0.4
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 50)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 70)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 100)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 90, 255)),
	})
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = root
end

local apply
function apply(player: Player, key: string)
	local pass = GameData.GamePasses[key]
	if pass and pass.grants then
		-- bundle pass (VIP): switch on every pass it includes
		for _, k in pass.grants do
			player:SetAttribute("Pass_" .. k, true)
			apply(player, k)
		end
	end
	if key == "ExtraSlots" then
		BaseManager.recalcCapacity(player)
	elseif key == "RainbowTrail" and player.Character then
		addTrail(player.Character)
	end
end

function PassService.check(player: Player)
	for key, pass in GameData.GamePasses do
		if pass.id and pass.id > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns then
				player:SetAttribute("Pass_" .. key, true)
				apply(player, key)
			end
		end
	end
end

function PassService.onCharacter(player: Player, character: Model)
	if player:GetAttribute("Pass_RainbowTrail") then
		character:WaitForChild("HumanoidRootPart", 10)
		addTrail(character)
	end
end

local function heal(player)
	BaseManager.healAll(player)
	Notify:FireClient(player, "Instant Heal! Your whole team is back to full health.", "success")
end

local function requestSave(player)
	local SaveService = require(script.Parent.SaveService)
	SaveService.requestSave(player)
end

-- Deliver paid items owed from an earlier session (call after the save has loaded)
function PassService.onLoaded(player: Player)
	local PlayerData = require(script.Parent.PlayerData)
	local BattleService = require(script.Parent.BattleService)
	local RareEventService = require(script.Parent.RareEventService)
	task.delay(4, function()
		if not player.Parent then
			return
		end
		if PlayerData.getPending(player, "heal") and not BattleService.isInBattle(player) then
			PlayerData.setPending(player, "heal", nil)
			heal(player)
			requestSave(player)
		end
		local owed = PlayerData.getPending(player, "summons")
		if type(owed) == "number" and owed > 0 then
			Notify:FireClient(player, ("You had %d Summon Rare Spawn%s waiting. Summoning now!"):format(owed, owed > 1 and "s" or ""), "success")
			for _ = 1, owed do
				RareEventService.summon(player, true)
			end
		end
	end)
end

local function setupProducts()
	local DecorService = require(script.Parent.DecorService)
	local BattleService = require(script.Parent.BattleService)
	local RareEventService = require(script.Parent.RareEventService)
	local P = GameData.Products
	local PlayerData = require(script.Parent.PlayerData)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	-- data-driven products: timed boosts, server boosts and item packs (all fixed, nothing random)
	for key, prod in P do
		if prod.boost then
			DecorService.registerProduct(prod.id, prod.name, function(player)
				if not PlayerData.addBoost(player, prod.boost.key, prod.boost.minutes) then
					return false
				end
				Notify:FireClient(player, ("%s active! %d minutes added."):format(prod.name, prod.boost.minutes), "success")
				return true
			end)
		elseif prod.serverBoost then
			DecorService.registerProduct(prod.id, prod.name, function(player)
				local now = workspace:GetServerTimeNow()
				local attr = "ServerBoost_" .. prod.serverBoost.key
				local current = ReplicatedStorage:GetAttribute(attr)
				local base = (type(current) == "number" and current > now) and current or now
				ReplicatedStorage:SetAttribute(attr, base + prod.serverBoost.minutes * 60)
				Notify:FireAllClients(("%s boosted the server: 2x coins for everyone for %d minutes!"):format(player.DisplayName, prod.serverBoost.minutes), "announce")
				return true
			end)
		elseif prod.items then
			DecorService.registerProduct(prod.id, prod.name, function(player)
				for itemId, n in prod.items do
					PlayerData.addItem(player, itemId, n)
				end
				Notify:FireClient(player, ("Thanks! %s added to your Bag."):format(prod.name), "success")
				return true
			end)
		end
	end
	DecorService.registerProduct(P.InstantHeal.id, P.InstantHeal.name, function(player)
		if BattleService.isInBattle(player) then
			PlayerData.setPending(player, "heal", true) -- saved with the receipt
			Notify:FireClient(player, "Instant Heal bought! Your team heals the moment this battle ends.", "info")
		else
			heal(player)
		end
		return true
	end)
	DecorService.registerProduct(P.SummonRare.id, P.SummonRare.name, function(player)
		-- count it as owed first; it's cleared only once the creature actually appears
		local owed = PlayerData.getPending(player, "summons")
		PlayerData.setPending(player, "summons", (type(owed) == "number" and owed or 0) + 1)
		if RareEventService.summon(player) == false then
			PlayerData.setPending(player, "summons", (type(owed) == "number" and owed or 0))
			return false
		end
		return true
	end)
	RareEventService.setPaidHandler(function(player)
		local owed = PlayerData.getPending(player, "summons")
		PlayerData.setPending(player, "summons", (type(owed) == "number" and owed or 1) - 1)
		requestSave(player)
	end)
	BattleService.onReleased(function(player)
		if PlayerData.getPending(player, "heal") then
			PlayerData.setPending(player, "heal", nil)
			heal(player)
			requestSave(player)
		end
	end)
end

function PassService.init()
	setupProducts()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in GameData.GamePasses do
			if pass.id > 0 and pass.id == passId then
				player:SetAttribute("Pass_" .. key, true)
				apply(player, key)
				Notify:FireClient(player, ("Thanks! %s is now active."):format(pass.name), "success")
			end
		end
	end)
end

return PassService

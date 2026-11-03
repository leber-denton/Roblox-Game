--[[
	SaveService: saves and loads each player's progress with a DataStore.
	Saved: coins, trainer level/XP, items, badges, stats, daily streak + quests, index rewards claimed,
	the team, the Creature Index, the base expansion, dungeon floor and whether the tutorial is done.
	Autosaves every 2 minutes, on leave, and when the server shuts down.
	If loading fails (for example API access is off in Studio), that player's data is NOT saved,
	so a failed load can never wipe a real save.
	In Studio: Game Settings > Security > Enable Studio Access to API Services.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local PlayerData = require(script.Parent.PlayerData)
local BaseManager = require(script.Parent.BaseManager)

local SaveService = {}

local VERSION = 1
local store
do
	local ok, result = pcall(function()
		-- Key keeps the game's original name on purpose: changing it would wipe every player's save.
		return DataStoreService:GetDataStore("SnatchThemAll_Save_v1")
	end)
	if ok then
		store = result
	else
		warn("SaveService: DataStore unavailable, progress won't save:", result)
	end
end

local loaded = {} -- [Player] = true once a load succeeded (only then do we save)

-- Other modules can add their own section to the save (DecorService uses "decor").
-- hooks: serialize(player) -> table, load(player, saved), release(player) after the leave-save
local sections = {}
function SaveService.register(key: string, hooks)
	sections[key] = hooks
end

function SaveService.isLoaded(player: Player): boolean
	return loaded[player] == true
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function retry(fn)
	local ok, result
	for attempt = 1, 3 do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		-- API access turned off (Studio): retrying won't help
		if tostring(result):find("API") then
			break
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	return false, result
end

--[[
	Session lock: the save records which server (JobId) is using it. If a player hops servers
	faster than the old server can save, the new server waits for the old one to finish
	instead of loading stale data (which would lose or duplicate progress). A lock older than
	LOCK_STALE seconds is treated as abandoned (that server crashed).
]]
local LOCK_STALE = 150
local JOB = game.JobId ~= "" and game.JobId or "studio"

local Notify = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Notify")

-- Claim the save for this server and return it. Returns ok, saved.
local function claim(player: Player)
	for attempt = 1, 6 do
		local busy = false
		local ok, result = retry(function()
			return store:UpdateAsync(key(player), function(old)
				local lock = typeof(old) == "table" and old.lock
				if lock and lock.job ~= JOB and os.time() - (lock.t or 0) < LOCK_STALE and attempt < 6 then
					busy = true
					return nil -- leave it alone; the other server is still saving
				end
				old = typeof(old) == "table" and old or {}
				old.lock = { job = JOB, t = os.time() }
				return old, { player.UserId }
			end)
		end)
		if not ok then
			return false, result
		end
		if not busy then
			return true, result
		end
		task.wait(3)
		if not player.Parent then
			return false, "left"
		end
	end
	return false, "locked"
end

-- Loads and applies the save. Returns true if the player had saved progress.
function SaveService.load(player: Player): boolean
	if not store then
		return false
	end
	local ok, saved = claim(player)
	if not ok then
		warn("SaveService: couldn't load", player.Name, saved)
		player:SetAttribute("SaveStatus", "failed")
		if not RunService:IsStudio() then
			task.delay(8, function()
				if player.Parent then
					Notify:FireClient(player, "Your saved progress couldn't load, so nothing will save this session. Please rejoin.", "fail")
				end
			end)
		end
		return false
	end
	if not player.Parent then
		-- left while loading: hand the lock straight back so their next server isn't kept waiting
		pcall(function()
			store:UpdateAsync(key(player), function(old)
				if typeof(old) == "table" and old.lock and old.lock.job == JOB then
					old.lock = nil
					return old, { player.UserId }
				end
				return nil
			end)
		end)
		return false
	end
	loaded[player] = true
	player:SetAttribute("SaveStatus", "ok")
	if typeof(saved) ~= "table" then
		return false
	end
	PlayerData.load(player, saved.player)
	BaseManager.restore(player, saved.base)
	for key, hooks in sections do
		if hooks.load and saved[key] ~= nil then
			local ok, err = pcall(hooks.load, player, saved[key])
			if not ok then
				warn("SaveService: loading", key, "failed:", err)
			end
		end
	end
	if tonumber(saved.dungeonFloor) then
		player:SetAttribute("DungeonFloor", saved.dungeonFloor)
	end
	if saved.tutorialDone or #BaseManager.getTeam(player) > 0 then
		player:SetAttribute("TutorialStep", "done")
	end
	return true
end

-- release = true when the player is leaving (frees the lock for their next server)
function SaveService.save(player: Player, release: boolean?): boolean
	if not store or not loaded[player] then
		return false
	end
	-- admin test sessions don't save (unless the admin turned saving back on)
	if player:GetAttribute("NoSave") then
		if release then
			-- still hand the session lock back so the next join isn't delayed
			pcall(function()
				store:UpdateAsync(key(player), function(old)
					if typeof(old) == "table" and old.lock and old.lock.job == JOB then
						old.lock = nil
						return old, { player.UserId }
					end
					return nil
				end)
			end)
		end
		return false
	end
	local p = PlayerData.serialize(player)
	if not p then
		return false
	end
	local data = {
		v = VERSION,
		player = p,
		base = BaseManager.serialize(player),
		dungeonFloor = player:GetAttribute("DungeonFloor") or 1,
		tutorialDone = player:GetAttribute("TutorialStep") == "done" or #BaseManager.getTeam(player) > 0,
		savedAt = os.time(),
	}
	for key, hooks in sections do
		if hooks.serialize then
			local ok, section = pcall(hooks.serialize, player)
			if ok then
				data[key] = section
			else
				warn("SaveService: saving", key, "failed:", section)
			end
		end
	end
	data.lock = (not release) and { job = JOB, t = os.time() } or nil
	local stolen = false
	local ok, err = retry(function()
		store:UpdateAsync(key(player), function(old)
			-- another server took over this save (we were presumed crashed): don't overwrite it
			local lock = typeof(old) == "table" and old.lock
			if lock and lock.job ~= JOB then
				stolen = true
				return nil
			end
			return data, { player.UserId }
		end)
	end)
	if not ok then
		warn("SaveService: couldn't save", player.Name, err)
	elseif stolen then
		warn("SaveService: another server owns", player.Name, "- not saving here")
		loaded[player] = nil
		return false
	end
	return ok
end

-- Save soon after something worth keeping happens (a catch, a win), at most once per
-- QUICK_GAP seconds per player so busy players stay inside DataStore limits.
local QUICK_GAP = 30
local lastSave, queued = {}, {}
function SaveService.requestSave(player: Player)
	if not loaded[player] or queued[player] then
		return
	end
	queued[player] = true
	local wait = math.max(0, QUICK_GAP - (os.clock() - (lastSave[player] or -math.huge)))
	task.delay(wait, function()
		queued[player] = nil
		if player.Parent and loaded[player] then
			lastSave[player] = os.clock()
			SaveService.save(player)
		end
	end)
end

-- Save, then free the player's base and data
function SaveService.onLeave(player: Player)
	SaveService.save(player, true)
	loaded[player] = nil
	lastSave[player], queued[player] = nil, nil
	for _, hooks in sections do
		if hooks.release then
			pcall(hooks.release, player)
		end
	end
	BaseManager.release(player)
	PlayerData.remove(player)
end

function SaveService.init()
	Players.PlayerRemoving:Connect(SaveService.onLeave)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				task.spawn(SaveService.save, player)
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				SaveService.save(player, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
end

return SaveService

--!nocheck
--[[
	SaveAndPurchaseTests: checks the save/load path, the session lock, purchase receipts, pass
	ownership and the Coliseum watch list, using the REAL source of each module.

	Run from Studio's Command Bar in edit mode (paste this whole file). No Play needed.

	SAFE BY DESIGN
	  * Every DataStore is an in-memory fake. The real "SnatchThemAll_Save_v1" store is never opened.
	  * Purchases use fake product ids and a fake MarketplaceService. No Robux, no real receipts.
	  * Players are plain tables, so no real player's data is touched.

	Output: PASS / FAIL per check, GAP for behavior that works but is worth fixing, NOT TESTED for
	what this script cannot cover (see the manual steps at the bottom).
]]

-- LOCAL_HARNESS is only set by an offline runner (never in Studio); it supplies sources and Roblox globals.
local BASE_ENV = LOCAL_HARNESS and LOCAL_HARNESS.env or getfenv()
local IN_STUDIO = typeof(game) == "Instance"

----------------------------------------------------------------------------------------------
-- tiny test framework
----------------------------------------------------------------------------------------------
local passed, failed = 0, 0
local gaps, notTested = {}, {}

local function check(name: string, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("PASS  " .. name)
	else
		failed += 1
		print("FAIL  " .. name .. "\n        " .. tostring(err))
	end
end

local function gap(name: string, detail: string)
	table.insert(gaps, name .. ": " .. detail)
	print("GAP   " .. name .. " | " .. detail)
end

local function untested(name: string, why: string)
	table.insert(notTested, name .. ": " .. why)
	print("SKIP  " .. name .. " | " .. why)
end

local function eq(actual, expected, msg: string?)
	if actual ~= expected then
		error(((msg or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)), 2)
	end
end

local function truthy(v, msg: string?)
	if not v then
		error(msg or "expected a truthy value", 2)
	end
end

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function deepEqual(a, b): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------------------------------
-- loading real source with fake dependencies
----------------------------------------------------------------------------------------------
local function sourceOf(path: string): string
	if IN_STUDIO then
		local inst = game
		for part in string.gmatch(path, "[^/]+") do
			inst = inst:FindFirstChild(part)
			assert(inst, "missing in Studio: " .. path)
		end
		return inst.Source
	end
	return assert(LOCAL_HARNESS.sources[path], "no source for " .. path)
end

local function compile(src: string, name: string, env)
	local fn, err = loadstring(src, "=" .. name)
	assert(fn, err)
	setfenv(fn, setmetatable(env, { __index = BASE_ENV }))
	return fn
end

local function runModule(path: string, env)
	return compile(sourceOf(path), path, env)()
end

-- Runs only the part of a file between two markers (used for local functions that aren't exported)
local function runSlice(path: string, startMarker: string, endMarker: string, env, suffix: string)
	local src = sourceOf(path)
	local a = string.find(src, startMarker, 1, true)
	assert(a, "marker not found in " .. path .. ": " .. startMarker)
	local b = string.find(src, endMarker, a, true)
	assert(b, "end marker not found in " .. path .. ": " .. endMarker)
	return compile(string.sub(src, a, b - 1) .. suffix, path .. " (slice)", env)()
end

----------------------------------------------------------------------------------------------
-- fake world
----------------------------------------------------------------------------------------------
local clock = 1_000_000
local notices = {}

local fakeTask = {
	wait = function(n)
		clock += (n or 0)
		return n or 0
	end,
	spawn = function(f, ...)
		f(...)
	end,
	defer = function(f, ...)
		f(...)
	end,
	delay = function() end, -- delayed work is not needed for these checks
}
local fakeOs = setmetatable({ time = function() return clock end }, { __index = os })
local fakeWorkspace = { GetServerTimeNow = function() return clock end }

local fakeNotify = {
	FireClient = function(_, _, msg)
		table.insert(notices, msg)
	end,
	FireAllClients = function() end,
}
local fakeRS = { _attrs = {}, Shared = {} }
function fakeRS:GetAttribute(k)
	return self._attrs[k]
end
function fakeRS:SetAttribute(k, v)
	self._attrs[k] = v
end
function fakeRS:WaitForChild(name)
	if name == "Remotes" then
		return {
			WaitForChild = function()
				return fakeNotify
			end,
		}
	end
	return self[name]
end

local function makeGame(extraServices, jobId)
	local services = {
		ReplicatedStorage = fakeRS,
		HttpService = { JSONEncode = function() return "[]" end },
		Players = { PlayerRemoving = { Connect = function() end }, GetPlayers = function() return {} end },
		RunService = { IsStudio = function() return true end },
	}
	for k, v in extraServices or {} do
		services[k] = v
	end
	return {
		JobId = jobId or "",
		GetService = function(_, name)
			return services[name] or error("check tried to use an unfaked service: " .. name)
		end,
	}
end

local function fakeRequire(m)
	return m
end

local nextUser = 5000
local function newPlayer(name: string?, userId: number?)
	nextUser += 1
	local p = { Name = name or ("Tester" .. nextUser), UserId = userId or nextUser, Parent = true, _attrs = {} }
	p.DisplayName = p.Name
	function p:SetAttribute(k, v)
		self._attrs[k] = v
	end
	function p:GetAttribute(k)
		return self._attrs[k]
	end
	function p:GetAttributeChangedSignal()
		return { Connect = function() end }
	end
	return p
end

-- in-memory DataStore: UpdateAsync with real "return nil cancels" behavior, plus failure injection
local function newBackend()
	local b = { names = {}, data = {}, failures = 0, failMsg = "503: simulated throttle", updates = 0 }
	local store = {}
	function store:UpdateAsync(key, fn)
		b.updates += 1
		if b.failures > 0 then
			b.failures -= 1
			error(b.failMsg)
		end
		local old = deepCopy(b.data[key])
		local new = fn(old)
		if new == nil then
			return old
		end
		b.data[key] = deepCopy(new)
		return deepCopy(new)
	end
	b.service = {
		GetDataStore = function(_, name)
			table.insert(b.names, name)
			return store
		end,
	}
	return b
end

local function newBaseManager()
	local bm = { released = 0, restored = nil, team = {}, recalc = 0 }
	function bm.restore(_, saved)
		bm.restored = saved
	end
	function bm.serialize()
		return { team = deepCopy(bm.team) }
	end
	function bm.getTeam()
		return bm.team
	end
	function bm.release()
		bm.released += 1
	end
	function bm.recalcCapacity()
		bm.recalc += 1
	end
	function bm.healAll() end
	return bm
end

-- GameData and PlayerData are shared by every check (PlayerData keeps per-player state in a table)
local GameData = runModule("ReplicatedStorage/Shared/GameData", { game = makeGame(), workspace = fakeWorkspace })
fakeRS.Shared.GameData = GameData

local function loadPlayerData()
	return runModule("ServerScriptService/Modules/PlayerData", {
		game = makeGame(),
		workspace = fakeWorkspace,
		require = fakeRequire,
	})
end

-- One "server": its own SaveService module bound to a shared fake store and its own JobId
local function newServer(backend, jobId: string, PlayerData)
	local bm = newBaseManager()
	local SaveService = runModule("ServerScriptService/Modules/SaveService", {
		game = makeGame({ DataStoreService = backend.service }, jobId),
		script = { Parent = { PlayerData = PlayerData, BaseManager = bm } },
		require = fakeRequire,
		task = fakeTask,
		os = fakeOs,
	})
	return { Save = SaveService, Base = bm, PlayerData = PlayerData }
end

local function join(server, player)
	server.PlayerData.init(player)
	return server.Save.load(player)
end

local LEGACY_KEY = "SnatchThemAll_Save_v1"

----------------------------------------------------------------------------------------------
-- 1. SAVE / LOAD
----------------------------------------------------------------------------------------------
print("\n=== 1. Save and load (fake DataStore) ===")

check("save key keeps the legacy SnatchThemAll name (renaming it would wipe every save)", function()
	local backend = newBackend()
	newServer(backend, "A", loadPlayerData())
	eq(#backend.names, 1, "number of DataStores opened")
	eq(backend.names[1], LEGACY_KEY, "DataStore name")
end)

check("full round trip: coins, level, items, badges, stats, boosts, pending, trainers all survive", function()
	local backend = newBackend()
	local server = newServer(backend, "A", loadPlayerData())
	local PD = server.PlayerData
	local p1 = newPlayer("Round", 7001)
	join(server, p1)
	local d = PD.get(p1)
	d.coins, d.xp, d.level = 1234, 56, 9
	d.items = { LoopBall = -1, Potion = 4 }
	d.badges = { "Boulder Badge", "Cascade Badge" }
	d.stats.caught, d.stats.bp = 31, 12
	d.settings.boosts = { DoubleCoins = clock + 600 }
	d.settings.pending = { heal = true, summons = 2 }
	d.beatenTrainers = { "route1_a", "route1_b" }
	d.claimedRegions = { Maple = true }
	truthy(server.Save.save(p1, true), "save returned false")
	eq(backend.data["u_7001"].v, 1, "saved format version")

	local PD2 = loadPlayerData()
	local server2 = newServer(backend, "B", PD2)
	local p2 = newPlayer("Round", 7001)
	truthy(join(server2, p2), "load reported no saved progress")
	local e = PD2.get(p2)
	eq(e.coins, 1234, "coins")
	eq(e.xp, 56, "xp")
	eq(e.level, 9, "level")
	eq(e.items.Potion, 4, "potions")
	eq(e.items.LoopBall, -1, "unlimited LoopBall")
	truthy(deepEqual(e.badges, d.badges), "badges")
	eq(e.stats.caught, 31, "caught stat")
	eq(e.stats.bp, 12, "battle points")
	eq(e.settings.boosts.DoubleCoins, clock + 600, "timed boost end time")
	eq(e.settings.pending.heal, true, "pending Instant Heal")
	eq(e.settings.pending.summons, 2, "pending Summon Rare count")
	truthy(deepEqual(e.beatenTrainers, d.beatenTrainers), "beaten route trainers")
	truthy(e.claimedRegions.Maple, "claimed region reward")
end)

check("old or partial saves load with defaults filled in (no crash, nothing nil)", function()
	local backend = newBackend()
	backend.data["u_7002"] = { v = 1, player = { coins = 50 } } -- written long before most fields existed
	local server = newServer(backend, "A", loadPlayerData())
	local p = newPlayer("Old", 7002)
	truthy(join(server, p), "load reported no saved progress")
	local d = server.PlayerData.get(p)
	eq(d.coins, 50, "coins")
	eq(d.level, 1, "default level")
	eq(d.items.LoopBall, -1, "default LoopBall")
	eq(type(d.badges), "table", "badges default")
	eq(type(d.beatenTrainers), "table", "beatenTrainers default")
	eq(type(d.settings), "table", "settings default")
end)

check("corrupt values are cleaned on load (NaN, infinity, negatives, junk items)", function()
	local backend = newBackend()
	backend.data["u_7003"] = {
		v = 1,
		player = {
			coins = 0 / 0,
			xp = -40,
			level = -3,
			items = { Potion = 0 / 0, Ether = -5, Great = math.huge, Good = 3.7, [5] = 2 },
			stats = { caught = "lots" },
			settings = { boosts = { DoubleXP = math.huge, [1] = 5 }, pending = { heal = "yes", summons = -1 } },
		},
	}
	local server = newServer(backend, "A", loadPlayerData())
	local p = newPlayer("Corrupt", 7003)
	join(server, p)
	local d = server.PlayerData.get(p)
	eq(d.coins, 0, "NaN coins reset to default")
	eq(d.xp, 0, "negative xp clamped")
	eq(d.level, 1, "negative level clamped")
	eq(d.items.Potion, nil, "NaN item count dropped")
	eq(d.items.Ether, nil, "negative item count dropped")
	eq(d.items.Great, nil, "infinite item count dropped")
	eq(d.items.Good, 3, "fractional item count floored")
	eq(d.stats.caught, 0, "non-numeric stat reset")
	eq(d.settings.boosts.DoubleXP, nil, "infinite boost end time dropped")
	eq(d.settings.pending.heal, nil, "non-boolean pending dropped")
	eq(d.settings.pending.summons, nil, "negative pending dropped")
end)

check("retired items convert into their replacements on load", function()
	local old, new = next(GameData.RetiredItems)
	local backend = newBackend()
	backend.data["u_7004"] = { v = 1, player = { items = { [old] = 3, [new] = 2 } } }
	local server = newServer(backend, "A", loadPlayerData())
	local p = newPlayer("Retire", 7004)
	join(server, p)
	local d = server.PlayerData.get(p)
	eq(d.items[old], nil, "retired item removed")
	eq(d.items[new], 5, "replacement stacked with existing count")
end)

check("a record from a NEWER save version still loads (no crash)", function()
	local backend = newBackend()
	backend.data["u_7005"] = { v = 99, player = { coins = 77 }, someFutureSection = { x = 1 } }
	local server = newServer(backend, "A", loadPlayerData())
	local p = newPlayer("Future", 7005)
	truthy(join(server, p))
	eq(server.PlayerData.get(p).coins, 77, "coins")
end)
gap(
	"No save-version gate or migration hook",
	"SaveService writes v=1 but never reads it, so a future format change has nothing to branch on, and a rollback to older code would load newer saves blindly and overwrite them on the next save."
)

check("tutorialDone sets the returning-player flag; a new player has none", function()
	local backend = newBackend()
	backend.data["u_7006"] = { v = 1, player = { coins = 1 }, tutorialDone = true }
	local server = newServer(backend, "A", loadPlayerData())
	local returning, fresh = newPlayer("Ret", 7006), newPlayer("Fresh", 7007)
	join(server, returning)
	join(server, fresh)
	eq(returning:GetAttribute("TutorialStep"), "done", "returning player")
	eq(fresh:GetAttribute("TutorialStep"), nil, "new player")
end)

check("a section whose serialize hook throws does not stop the rest of the save", function()
	local backend = newBackend()
	local server = newServer(backend, "A", loadPlayerData())
	server.Save.register("broken", {
		serialize = function()
			error("boom")
		end,
	})
	server.Save.register("good", {
		serialize = function()
			return { ok = true }
		end,
	})
	local p = newPlayer("Hook", 7008)
	join(server, p)
	server.PlayerData.get(p).coins = 321
	truthy(server.Save.save(p, true), "save should still succeed")
	eq(backend.data["u_7008"].player.coins, 321, "core data saved")
	truthy(backend.data["u_7008"].good.ok, "healthy section saved")
	eq(backend.data["u_7008"].broken, nil, "broken section skipped")
end)

----------------------------------------------------------------------------------------------
-- 2. FAILURE SAFETY (a failed load must never wipe a real save)
----------------------------------------------------------------------------------------------
print("\n=== 2. Failure safety ===")

check("failed load: reports failure, and later saves can NOT overwrite the real save", function()
	local backend = newBackend()
	backend.data["u_7010"] = { v = 1, player = { coins = 777 } }
	local server = newServer(backend, "A", loadPlayerData())
	backend.failures = 99
	local p = newPlayer("Fail", 7010)
	eq(join(server, p), false, "load result")
	eq(p:GetAttribute("SaveStatus"), "failed", "SaveStatus")
	backend.failures = 0
	server.PlayerData.get(p).coins = 1 -- the player plays a whole session on defaults
	eq(server.Save.save(p, true), false, "save must refuse after a failed load")
	eq(backend.data["u_7010"].player.coins, 777, "real save untouched")
end)

check("transient save errors are retried and succeed", function()
	local backend = newBackend()
	local server = newServer(backend, "A", loadPlayerData())
	local p = newPlayer("Retry", 7011)
	join(server, p)
	server.PlayerData.get(p).coins = 900
	backend.failures = 2
	truthy(server.Save.save(p), "should succeed on the third attempt")
	eq(backend.data["u_7011"].player.coins, 900, "coins saved after retries")
end)

check("save that keeps failing returns false and does not corrupt the stored record", function()
	local backend = newBackend()
	local server = newServer(backend, "A", loadPlayerData())
	local p = newPlayer("Down", 7012)
	join(server, p)
	server.PlayerData.get(p).coins = 5
	truthy(server.Save.save(p))
	server.PlayerData.get(p).coins = 6
	backend.failures = 99
	eq(server.Save.save(p), false, "save result")
	eq(backend.data["u_7012"].player.coins, 5, "last good save intact")
end)

check("'API access off' errors are not retried (Studio without API services)", function()
	local backend = newBackend()
	backend.failMsg = "StudioAccessToApisNotAllowed: enable API access"
	local server = newServer(backend, "A", loadPlayerData())
	backend.failures = 99
	local before = backend.updates
	join(server, newPlayer("NoApi", 7013))
	eq(backend.updates - before, 1, "attempts made")
end)

check("saving a player who never loaded does nothing", function()
	local backend = newBackend()
	local server = newServer(backend, "A", loadPlayerData())
	local p = newPlayer("Never", 7014)
	server.PlayerData.init(p)
	eq(server.Save.save(p), false)
	eq(backend.data["u_7014"], nil, "nothing written")
end)

check("admin NoSave sessions never write progress, but still hand the session lock back", function()
	local backend = newBackend()
	backend.data["u_7015"] = { v = 1, player = { coins = 42 } }
	local server = newServer(backend, "A", loadPlayerData())
	local p = newPlayer("Admin", 7015)
	join(server, p)
	p:SetAttribute("NoSave", true)
	server.PlayerData.get(p).coins = 999999
	eq(server.Save.save(p, true), false)
	eq(backend.data["u_7015"].player.coins, 42, "progress not overwritten")
	eq(backend.data["u_7015"].lock, nil, "lock released")
end)

----------------------------------------------------------------------------------------------
-- 3. SESSION LOCK (two servers, one player)
----------------------------------------------------------------------------------------------
print("\n=== 3. Session lock ===")

check("clean leave frees the lock, so the next server joins instantly with the saved data", function()
	local backend = newBackend()
	local a = newServer(backend, "A", loadPlayerData())
	local pa = newPlayer("Hop", 7020)
	join(a, pa)
	a.PlayerData.get(pa).coins = 250
	a.Save.onLeave(pa)
	eq(backend.data["u_7020"].lock, nil, "lock cleared on leave")
	local b = newServer(backend, "B", loadPlayerData())
	local pb = newPlayer("Hop", 7020)
	local t0 = clock
	truthy(join(b, pb))
	eq(clock, t0, "no waiting needed")
	eq(b.PlayerData.get(pb).coins, 250, "coins carried over")
end)

local stolenBackend, stolenA, stolenPa
check("server hop before the old server saved: new server takes over, old server cannot overwrite it", function()
	stolenBackend = newBackend()
	stolenA = newServer(stolenBackend, "A", loadPlayerData())
	stolenPa = newPlayer("Race", 7021)
	join(stolenA, stolenPa)
	stolenA.PlayerData.get(stolenPa).coins = 100
	truthy(stolenA.Save.save(stolenPa)) -- A holds a fresh lock and has saved 100
	local b = newServer(stolenBackend, "B", loadPlayerData())
	local pb = newPlayer("Race", 7021)
	local t0 = clock
	truthy(join(b, pb), "B should load")
	eq(b.PlayerData.get(pb).coins, 100, "B sees A's last save")
	b.PlayerData.get(pb).coins = 150
	truthy(b.Save.save(pb))
	-- A is still running and tries its autosave with stale data
	stolenA.PlayerData.get(stolenPa).coins = 100
	eq(stolenA.Save.save(stolenPa), false, "A must not overwrite B")
	eq(stolenBackend.data["u_7021"].player.coins, 150, "B's progress survives")
	stolenBackend.waitedSeconds = clock - t0
end)
check("takeover wait is shorter than the documented stale-lock time", function()
	truthy(stolenBackend and stolenBackend.waitedSeconds, "previous check did not run")
	if stolenBackend.waitedSeconds < 150 then
		gap(
			"Session lock is stolen after ~" .. stolenBackend.waitedSeconds .. "s, not the 150s LOCK_STALE",
			"claim() ignores a live lock on its 6th attempt, so a player hopping servers can claim the save while the old server is still running; the old server's unsaved progress in that window is dropped (no corruption, but lost progress)."
		)
	end
end)

----------------------------------------------------------------------------------------------
-- 4. PURCHASE RECEIPTS (real processReceipt code, fake Robux)
----------------------------------------------------------------------------------------------
print("\n=== 4. Purchase receipts ===")

local DECOR_PATH = "ServerScriptService/Modules/DecorService"
local DECOR_START = "local extraProducts = {}"
local DECOR_END = "----------------------------------------------------------------------------------------------\n-- lifecycle"

-- fakeSave: { isLoaded = fn, save = fn } so receipt logic can be driven against success AND failure
local function newReceiptHarness(fakeSave, isStudio: boolean)
	local h = { players = {}, state = {}, grants = 0, studio = isStudio }
	local DecorService = {}
	local env = {
		DecorService = DecorService,
		Players = {
			GetPlayerByUserId = function(_, id)
				return h.players[id]
			end,
		},
		state = h.state,
		productById = {},
		MAX_RECEIPTS = 60,
		SaveService = fakeSave,
		RunService = { IsStudio = function() return h.studio end },
		giveProduct = function()
			return function() end
		end,
		sync = function() end,
		Notify = fakeNotify,
		warn = function() end,
		table = table,
		Enum = BASE_ENV.Enum,
	}
	h.process = runSlice(DECOR_PATH, DECOR_START, DECOR_END, env, "\nreturn processReceipt")
	h.DecorService = DecorService
	h.env = env
	function h.addPlayer(p)
		h.players[p.UserId] = p
		h.state[p] = { receipts = {} }
	end
	return h
end

local DECISION = BASE_ENV.Enum.ProductPurchaseDecision
local GRANTED, NOT_YET = DECISION.PurchaseGranted, DECISION.NotProcessedYet

local function simpleSave(loaded: boolean, saveResult: boolean)
	local s = { saves = 0 }
	function s.isLoaded()
		return loaded
	end
	function s.save()
		s.saves += 1
		return saveResult
	end
	return s
end

check("unknown product id is not processed (and grants nothing)", function()
	local h = newReceiptHarness(simpleSave(true, true), true)
	local p = newPlayer("Buyer", 7030)
	h.addPlayer(p)
	eq(h.process({ ProductId = 424242, PlayerId = 7030, PurchaseId = "x" }), NOT_YET)
end)

check("receipt for a player whose save has not loaded is deferred, handler not run", function()
	local h = newReceiptHarness(simpleSave(false, true), true)
	local p = newPlayer("Buyer", 7031)
	h.addPlayer(p)
	local ran = 0
	h.DecorService.registerProduct(900, "Test", function() ran += 1 return true end)
	eq(h.process({ ProductId = 900, PlayerId = 7031, PurchaseId = "p1" }), NOT_YET)
	eq(ran, 0, "handler ran")
end)

check("receipt for a player who already left is deferred", function()
	local h = newReceiptHarness(simpleSave(true, true), true)
	h.DecorService.registerProduct(900, "Test", function() return true end)
	eq(h.process({ ProductId = 900, PlayerId = 99999, PurchaseId = "gone" }), NOT_YET)
end)

check("same PurchaseId delivered twice grants ONCE and both calls resolve as granted", function()
	local save = simpleSave(true, true)
	local h = newReceiptHarness(save, true)
	local p = newPlayer("Buyer", 7032)
	h.addPlayer(p)
	local ran = 0
	h.DecorService.registerProduct(901, "Test", function() ran += 1 return true end)
	local info = { ProductId = 901, PlayerId = 7032, PurchaseId = "dup" }
	eq(h.process(info), GRANTED)
	eq(h.process(info), GRANTED)
	eq(h.process(info), GRANTED)
	eq(ran, 1, "times granted")
	eq(save.saves, 1, "saved once, right after the grant")
end)

check("handler error rolls the receipt back so Roblox retry can succeed", function()
	local h = newReceiptHarness(simpleSave(true, true), true)
	local p = newPlayer("Buyer", 7033)
	h.addPlayer(p)
	local attempts = 0
	h.DecorService.registerProduct(902, "Flaky", function()
		attempts += 1
		if attempts == 1 then
			error("transient")
		end
		return true
	end)
	local info = { ProductId = 902, PlayerId = 7033, PurchaseId = "retry" }
	eq(h.process(info), NOT_YET, "first attempt")
	eq(#h.state[p].receipts, 0, "receipt rolled back")
	eq(h.process(info), GRANTED, "second attempt")
	eq(attempts, 2)
end)

check("handler returning false (could not deliver) is retried, not consumed", function()
	local h = newReceiptHarness(simpleSave(true, true), true)
	local p = newPlayer("Buyer", 7034)
	h.addPlayer(p)
	h.DecorService.registerProduct(903, "Nope", function() return false end)
	eq(h.process({ ProductId = 903, PlayerId = 7034, PurchaseId = "no" }), NOT_YET)
	eq(#h.state[p].receipts, 0, "receipt rolled back")
end)

check("receipt history is capped at MAX_RECEIPTS, newest kept", function()
	local h = newReceiptHarness(simpleSave(true, true), true)
	local p = newPlayer("Buyer", 7035)
	h.addPlayer(p)
	h.DecorService.registerProduct(904, "Many", function() return true end)
	for i = 1, 75 do
		eq(h.process({ ProductId = 904, PlayerId = 7035, PurchaseId = "id" .. i }), GRANTED)
	end
	eq(#h.state[p].receipts, 60, "stored receipts")
	eq(h.state[p].receipts[60], "id75", "newest kept")
	eq(h.state[p].receipts[1], "id16", "oldest dropped")
end)

check("coin/bundle products undo the grant and retry when the save fails (live servers)", function()
	local h = newReceiptHarness(simpleSave(true, false), false) -- not Studio, save fails
	local p = newPlayer("Buyer", 7036)
	h.addPlayer(p)
	local undone = 0
	h.env.productById[905] = { coins = 1000, label = "Pouch" }
	h.env.giveProduct = function()
		return function() undone += 1 end
	end
	eq(h.process({ ProductId = 905, PlayerId = 7036, PurchaseId = "coin1" }), NOT_YET)
	eq(undone, 1, "grant undone")
	eq(#h.state[p].receipts, 0, "receipt removed")
end)

check("receipt survives a real save + rejoin, so a Roblox retry after rejoin is not granted twice", function()
	local backend = newBackend()
	local given = 0
	-- one "session" = a fresh server (own SaveService + DecorService receipt code) with the buyer joined
	local function session(jobId: string)
		local PDx = loadPlayerData()
		local server = newServer(backend, jobId, PDx)
		local h = newReceiptHarness(server.Save, true)
		server.Save.register("decor", {
			serialize = function(pl)
				return h.state[pl]
			end,
			load = function(pl, saved)
				h.state[pl].receipts = saved.receipts
			end,
		})
		h.DecorService.registerProduct(906, "Pack", function(pl)
			given += 1
			PDx.addCoinsRaw(pl, 500)
			return true
		end)
		local p = newPlayer("Buyer", 7037)
		h.addPlayer(p)
		join(server, p)
		return server, h, p, PDx
	end
	local info = { ProductId = 906, PlayerId = 7037, PurchaseId = "rejoin" }
	local s1, h1, p1, PD1 = session("A")
	eq(h1.process(info), GRANTED, "first delivery")
	eq(PD1.coins(p1), 500, "coins granted")
	s1.Save.onLeave(p1)
	-- rejoin on a new server, then Roblox re-delivers the same receipt
	local _, h2, p2, PD2 = session("B")
	eq(PD2.coins(p2), 500, "coins persisted")
	eq(h2.process(info), GRANTED, "re-delivered receipt")
	eq(given, 1, "granted exactly once across the rejoin")
end)

-- GAP probe: extra products (Instant Heal, Summon Rare, boosts, packs) ignore a failed save
do
	local save = simpleSave(true, false)
	local h = newReceiptHarness(save, false)
	local p = newPlayer("Buyer", 7038)
	h.addPlayer(p)
	h.DecorService.registerProduct(907, "Boost", function() return true end)
	local result = h.process({ ProductId = 907, PlayerId = 7038, PurchaseId = "gap" })
	if result == GRANTED and #h.state[p].receipts == 1 then
		gap(
			"Boosts, packs, Instant Heal and Summon Rare finish as 'granted' even if the save fails",
			"unlike coin bundles, the extra-product branch of processReceipt ignores SaveService.save's result. If the save fails and the server then crashes before the next 2-minute autosave, the player has paid and the receipt AND the item are lost. Fix: treat a failed save like the coin branch (undo + NotProcessedYet) outside Studio."
		)
	end
end

----------------------------------------------------------------------------------------------
-- 5. PASSES AND BOOSTS (server-side ownership)
----------------------------------------------------------------------------------------------
print("\n=== 5. Passes and boosts ===")

local function newPassHarness(ownedIds, throwOnCheck: boolean?)
	local queried = {}
	local passes = deepCopy(GameData.GamePasses)
	passes.DoubleCoins.id, passes.DoubleXP.id, passes.ExtraSlots.id, passes.VIP.id = 111, 222, 333, 444
	local fakeGameData = { GamePasses = passes, Products = GameData.Products, hasBoost = GameData.hasBoost }
	local market = {
		UserOwnsGamePassAsync = function(_, _, id)
			table.insert(queried, id)
			if throwOnCheck then
				error("HTTP 500")
			end
			return ownedIds[id] == true
		end,
	}
	local bm = newBaseManager()
	fakeRS.Shared.GameData = fakeGameData
	local PassService = runModule("ServerScriptService/Modules/PassService", {
		game = makeGame({ MarketplaceService = market, Players = { GetPlayers = function() return {} end } }),
		script = { Parent = { BaseManager = bm } },
		require = function(m)
			return m
		end,
	})
	fakeRS.Shared.GameData = GameData
	return PassService, queried, bm
end

check("owning the 2x XP pass sets only Pass_DoubleXP", function()
	local PassService = newPassHarness({ [222] = true })
	local p = newPlayer("PassA", 7040)
	PassService.check(p)
	eq(p:GetAttribute("Pass_DoubleXP"), true)
	eq(p:GetAttribute("Pass_DoubleCoins"), nil)
	eq(p:GetAttribute("Pass_VIP"), nil)
end)

check("VIP bundle also switches on every pass it grants", function()
	local PassService = newPassHarness({ [444] = true })
	local p = newPlayer("PassB", 7041)
	PassService.check(p)
	eq(p:GetAttribute("Pass_VIP"), true)
	for _, k in GameData.GamePasses.VIP.grants do
		eq(p:GetAttribute("Pass_" .. k), true, "granted pass " .. k)
	end
end)

check("a failed ownership lookup grants nothing and does not throw", function()
	local PassService = newPassHarness({ [222] = true }, true)
	local p = newPlayer("PassC", 7042)
	PassService.check(p)
	eq(p:GetAttribute("Pass_DoubleXP"), nil)
end)

check("passes with id 0 (not created yet) are never queried or granted", function()
	local PassService, queried = newPassHarness({ [0] = true })
	local p = newPlayer("PassD", 7043)
	PassService.check(p)
	eq(table.find(queried, 0), nil, "id 0 was queried")
	eq(p:GetAttribute("Pass_RainbowTrail"), nil)
	eq(p:GetAttribute("Pass_DoubleBP"), nil)
end)

check("ExtraSlots pass recalculates team capacity", function()
	local PassService, _, bm = newPassHarness({ [333] = true })
	PassService.check(newPlayer("PassE", 7044))
	eq(bm.recalc, 1, "recalcCapacity calls")
end)

check("hasBoost: pass, live timed boost, expired boost, server-wide boost", function()
	local p = newPlayer("Boost", 7045)
	eq(GameData.hasBoost(p, "DoubleXP"), false, "nothing active")
	p:SetAttribute("Boost_DoubleXP", clock + 60)
	eq(GameData.hasBoost(p, "DoubleXP"), true, "live boost")
	p:SetAttribute("Boost_DoubleXP", clock - 1)
	eq(GameData.hasBoost(p, "DoubleXP"), false, "expired boost")
	p:SetAttribute("Boost_DoubleXP", nil)
	fakeRS:SetAttribute("ServerBoost_DoubleXP", clock + 60)
	eq(GameData.hasBoost(p, "DoubleXP"), true, "server boost")
	fakeRS:SetAttribute("ServerBoost_DoubleXP", clock - 1)
	eq(GameData.hasBoost(p, "DoubleXP"), false, "expired server boost")
	p:SetAttribute("Pass_DoubleXP", true)
	eq(GameData.hasBoost(p, "DoubleXP"), true, "owned pass")
end)

check("every product the shop sells is fixed and non-random (no gacha products)", function()
	for key, prod in GameData.Products do
		truthy(prod.boost or prod.serverBoost or prod.items or key == "InstantHeal" or key == "SummonRare", key .. " has no fixed effect")
	end
end)

----------------------------------------------------------------------------------------------
-- 6. ECONOMY VALIDATION (server authority)
----------------------------------------------------------------------------------------------
print("\n=== 6. Economy validation ===")

local PD = loadPlayerData()
local function econPlayer()
	local p = newPlayer()
	PD.init(p)
	return p
end

check("coins: NaN, infinity and zero are ignored; spend rejects overspend, negatives and NaN", function()
	local p = econPlayer()
	PD.addCoins(p, 100)
	PD.addCoins(p, 0 / 0)
	PD.addCoins(p, math.huge)
	PD.addCoins(p, -math.huge)
	eq(PD.coins(p), 100, "coins after bad adds")
	eq(PD.spend(p, 101), false, "overspend")
	eq(PD.spend(p, -50), false, "negative spend (would mint coins)")
	eq(PD.spend(p, 0 / 0), false, "NaN spend")
	eq(PD.coins(p), 100, "coins after bad spends")
	eq(PD.spend(p, 40), true)
	eq(PD.coins(p), 60)
end)

check("2x Coins pass doubles earned coins but never Robux-bought coins", function()
	local p = econPlayer()
	p:SetAttribute("Pass_DoubleCoins", true)
	PD.addCoins(p, 100)
	eq(PD.coins(p), 200, "earned coins doubled")
	PD.addCoinsRaw(p, 1000)
	eq(PD.coins(p), 1200, "bought coins not doubled")
	PD.addCoins(p, -50)
	eq(PD.coins(p), 1150, "spending/negative adds are not doubled")
end)

check("Battle Points: doubled by the timed boost, can't be spent past zero or negatively", function()
	local p = econPlayer()
	eq(PD.addBP(p, 10), 10, "base BP")
	p:SetAttribute("Boost_DoubleBP", clock + 60)
	eq(PD.addBP(p, 10), 20, "boosted BP")
	eq(PD.addBP(p, -5), 0, "negative BP ignored")
	eq(PD.addBP(p, 0 / 0), 0, "NaN BP ignored")
	eq(PD.spendBP(p, 31), false, "overspend")
	eq(PD.spendBP(p, -1), false, "negative spend")
	eq(PD.spendBP(p, 30), true)
	eq(PD.get(p).stats.bp, 0, "balance")
end)

check("timed boosts stack minutes, reject bad input", function()
	local p = econPlayer()
	local first = PD.addBoost(p, "DoubleCoins", 30)
	eq(first, clock + 1800, "first boost end")
	eq(PD.addBoost(p, "DoubleCoins", 30), clock + 3600, "stacked")
	eq(PD.addBoost(p, "DoubleCoins", 0), nil, "zero minutes")
	eq(PD.addBoost(p, "DoubleCoins", -5), nil, "negative minutes")
	eq(PD.addBoost(p, "DoubleCoins", 0 / 0), nil, "NaN minutes")
end)

check("items: unlimited stays unlimited, takeItem can't go negative, bad counts ignored", function()
	local p = econPlayer()
	PD.addItem(p, "LoopBall", 50)
	eq(PD.get(p).items.LoopBall, -1, "unlimited ball")
	eq(PD.takeItem(p, "Nothing"), false)
	PD.addItem(p, "Potion", 2)
	PD.addItem(p, "Potion", 0 / 0)
	eq(PD.get(p).items.Potion, 2, "NaN count ignored")
	eq(PD.takeItem(p, "Potion"), true)
	eq(PD.takeItem(p, "Potion"), true)
	eq(PD.takeItem(p, "Potion"), false, "third potion")
	eq(PD.get(p).items.Potion, nil, "removed at zero")
end)

----------------------------------------------------------------------------------------------
-- 7. COLISEUM WATCH LIST
----------------------------------------------------------------------------------------------
print("\n=== 7. Coliseum public battle list ===")

local battles = {}
local BattleStub = {}
runSlice(
	"ServerScriptService/Modules/BattleService",
	"function BattleService.getPublicBattle",
	"\n-- Shared checks before any battle",
	{ BattleService = BattleStub, battles = battles, snapshot = function(x) return x end },
	""
)

local function listFor(players)
	return runSlice(
		"ServerScriptService/Modules/ColiseumService",
		"local function publicBattles()",
		"local function refreshBoards()",
		{ BattleService = BattleStub, Players = { GetPlayers = function() return players end }, table = table },
		"\nreturn publicBattles"
	)()
end

check("getPublicBattle exists in BattleService and Coliseum calls it", function()
	truthy(string.find(sourceOf("ServerScriptService/Modules/BattleService"), "function BattleService.getPublicBattle", 1, true))
	truthy(string.find(sourceOf("ServerScriptService/Modules/ColiseumService"), "BattleService.getPublicBattle", 1, true))
	eq(type(BattleStub.getPublicBattle), "function")
end)

check("getPublicBattle: idle player and non-PvP battles are private", function()
	local idle = newPlayer("Idle", 7050)
	eq(BattleStub.getPublicBattle(idle), nil, "idle")
	local wild = newPlayer("Wild", 7051)
	battles[wild] = { pvp = false, trainer = {} }
	eq(BattleStub.getPublicBattle(wild), nil, "wild/trainer battle must stay private")
	battles[wild] = nil
end)

check("watch list shows a live PvP match exactly once (not once per player)", function()
	local a, b = newPlayer("Ana", 7060), newPlayer("Ben", 7061)
	battles[a] = { pvp = true, trainer = { opponent = b }, ally = { name = "X" }, wild = { name = "Y" } }
	battles[b] = { pvp = true, trainer = { opponent = a }, ally = { name = "Y" }, wild = { name = "X" } }
	local list = listFor({ a, b })
	eq(#list, 1, "entries")
	eq(list[1].userId, 7060, "listed under the lower user id")
	eq(list[1].opponent, "Ben")
	battles[a], battles[b] = nil, nil
end)

check("watch list is empty when nobody is in PvP", function()
	local list = listFor({ newPlayer("A", 7070), newPlayer("B", 7071) })
	eq(#list, 0)
end)

----------------------------------------------------------------------------------------------
-- summary
----------------------------------------------------------------------------------------------
untested("Real multiplayer replication", "needs 2+ live clients; see manual steps below")
untested("Real DataStore (published place)", "this script uses fakes by design; do the 2-account publish test below")
untested("Real Robux purchase", "IDs are still 0 and Studio can't complete real purchases")
untested("BattleService.grantXP doubling", "local function inside a 1,500-line module; the hasBoost gate it reads IS tested")
untested("Trading, Coliseum ranked queue/spectate UI, full playthrough", "interactive; see manual steps below")
untested("PassService.init purchase-prompt handlers", "needs real MarketplaceService events")

print("\n================ SUMMARY ================")
print(("PASS: %d   FAIL: %d   GAPS: %d   NOT TESTED: %d"):format(passed, failed, #gaps, #notTested))
for _, g in gaps do
	print("  GAP  " .. g)
end
for _, n in notTested do
	print("  SKIP " .. n)
end
print([[

MANUAL STEPS this script cannot do (run after it passes):
 1. Multiplayer: Studio > Test tab > Clients and Servers > Server & 2 Players > Start. In both windows finish the
    tutorial, then check each player sees the other's creature effects and that two players can't claim the same wild.
 2. Trading: with both clients, open the Trade Plaza portal, trade a creature, then rejoin and confirm each side kept
    exactly what the trade promised (no duplicates, nothing lost).
 3. Coliseum: both clients enter the Coliseum, queue Ranked, fight one match. A third client (or the first after it
    ends) opens the watch list, spectates, and confirms the list is empty again after the match.
 4. Real save (needs the PUBLISHED place and a test account, never your main): play 2 minutes, leave, rejoin, confirm
    coins, team, badges and tutorial state all came back. Then hop between two servers quickly and confirm no rollback.
 5. Real purchase (after creating the products and pasting their IDs): buy the cheapest product once with a test
    account, confirm delivery, leave and rejoin, confirm it was not granted twice.
]])

if LOCAL_HARNESS then
	LOCAL_HARNESS.failures = failed
end

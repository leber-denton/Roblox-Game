--[[
	WeeklyEventService: the weekly appointment event (GameData.WeeklyEvent, "Rare Storm").
	Every week at the same time (Saturday 10:00 Pacific by default) the server goes wild for an hour:
	  - a rare spawn every rareEverySeconds (if one isn't already out)
	  - server-wide boosts (2x coins + 2x XP) through ReplicatedStorage ServerBoost_<key>
	  - countdown warnings to everyone at warnMinutes before it starts
	ReplicatedStorage attributes for the HUD (StarterPlayerScripts.EventHUD):
	  WeeklyEventName, WeeklyEventNext (server time it next starts), WeeklyEventEnds (while it's live)
	WeeklyEventService.startNow(minutes) runs one right away (admin command "storm").
	Tip: to use it as the "admin abuse" hype before an update, set hourPacific to the hour before you publish.
	The time is Pacific local time; US daylight saving (2nd Sunday of March to 1st Sunday of November)
	is worked out here, so the event never drifts by an hour.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage.Shared.GameData)
local RareEventService = require(script.Parent.RareEventService)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")
local Config = GameData.WeeklyEvent

local WeeklyEventService = {}

local manualEnds = nil -- set by startNow

-- Days since 1970-01-01 for a calendar date (proleptic Gregorian, no time zone involved)
local function daysFromCivil(y: number, m: number, d: number): number
	if m <= 2 then
		y -= 1
	end
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = math.floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

-- Day of the month of the nth Sunday in a month
local function nthSunday(y: number, m: number, n: number): number
	local wday1 = (daysFromCivil(y, m, 1) + 4) % 7 -- 0 = Sunday (1970-01-01 was a Thursday)
	return 1 + (7 - wday1) % 7 + (n - 1) * 7
end

-- Is a Pacific calendar date on daylight time (for times after 2:00 local)?
local function pacificDST(y: number, m: number, d: number): boolean
	if m < 3 or m > 11 then
		return false
	end
	if m > 3 and m < 11 then
		return true
	end
	if m == 3 then
		return d >= nthSunday(y, 3, 2)
	end
	return d < nthSunday(y, 11, 1)
end
WeeklyEventService._pacificDST = pacificDST -- exposed for testing

-- Next start time (UTC epoch) at or after `now`, and whether one is running at `now`
local function schedule(now: number): (number, number?)
	local dur = Config.minutes * 60
	local hour = Config.hourPacific or 10
	now = math.floor(now)
	for d = -1, 8 do
		-- that day's Pacific calendar date (standard time is close enough to pick the date)
		local t = os.date("!*t", now + d * 86400 - 8 * 3600)
		if t.wday == Config.weekday then
			local offset = pacificDST(t.year, t.month, t.day) and 7 or 8
			local start = daysFromCivil(t.year, t.month, t.day) * 86400 + (hour + offset) * 3600
			if now >= start and now < start + dur then
				return start, start + dur
			end
			if start > now then
				return start, nil
			end
		end
	end
	return now + 7 * 86400, nil
end
WeeklyEventService._schedule = schedule -- exposed for testing

local function setBoosts(ends: number)
	for _, key in Config.boosts do
		local attr = "ServerBoost_" .. key
		local current = ReplicatedStorage:GetAttribute(attr)
		if type(current) ~= "number" or current < ends then
			ReplicatedStorage:SetAttribute(attr, ends)
		end
	end
end

function WeeklyEventService.startNow(minutes: number?)
	manualEnds = workspace:GetServerTimeNow() + (minutes or Config.minutes) * 60
end

function WeeklyEventService.init()
	ReplicatedStorage:SetAttribute("WeeklyEventName", Config.name)
	task.spawn(function()
		local wasLive = false
		local warned = {}
		local lastRare = 0
		while true do
			local now = workspace:GetServerTimeNow()
			local nextStart, liveEnds = schedule(now)
			if manualEnds and manualEnds > now then
				liveEnds = math.max(liveEnds or 0, manualEnds)
			end
			ReplicatedStorage:SetAttribute("WeeklyEventNext", nextStart)
			ReplicatedStorage:SetAttribute("WeeklyEventEnds", liveEnds)
			if liveEnds then
				if not wasLive then
					wasLive = true
					lastRare = 0
					Notify:FireAllClients(("The %s has begun! Rare spawns every %d minutes and 2x coins & XP for everyone!"):format(
						Config.name, math.floor(Config.rareEverySeconds / 60)), "announce")
				end
				setBoosts(liveEnds)
				if now - lastRare >= Config.rareEverySeconds and not RareEventService.isLive() then
					lastRare = now
					RareEventService.trigger()
				end
			else
				if wasLive then
					wasLive = false
					manualEnds = nil
					Notify:FireAllClients(("The %s is over. Same time next week!"):format(Config.name), "announce")
				end
				local minsLeft = math.ceil((nextStart - now) / 60)
				for _, m in Config.warnMinutes do
					if minsLeft == m and not warned[nextStart .. ":" .. m] then
						warned[nextStart .. ":" .. m] = true
						Notify:FireAllClients(("The %s starts in %d minute%s!"):format(Config.name, m, m == 1 and "" or "s"), "announce")
					end
				end
			end
			task.wait(5)
		end
	end)
end

return WeeklyEventService

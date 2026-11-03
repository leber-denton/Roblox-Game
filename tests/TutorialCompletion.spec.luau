-- Run from Studio's Command Bar after applying Tutorial.client.luau.
-- Exercises the actual completion listener with simulated attribute replication.
-- Does not touch real player state, DataStores, or instances.
local source = game.StarterPlayer.StarterPlayerScripts.Tutorial.Source
local startAt = assert(source:find("-- Celebrate progress made this session", 1, true), "Tutorial fix missing")
local endAt = assert(source:find("-- Dialogue box", startAt, true))
local listenerSource = source:sub(startAt, endAt - 1)
local cases = {
	{ name = "returning player already loaded", initial = "done", changes = { "done" }, expected = 0 },
	{ name = "returning save arrives late", changes = { "done" }, expected = 0 },
	{ name = "new player finishes guide", changes = { "meet_prof", "choose_starter", "battle_nibbit", "heal", "guide_shop", "guide_tower", "guide_regions", "done" }, expected = 1 },
	{ name = "resumed guide finishes", initial = "guide_regions", changes = { "done" }, expected = 1 },
	{ name = "duplicate completion event", initial = "guide_regions", changes = { "done", "done", "done" }, expected = 1 },
}
for _, case in cases do
	local step = case.initial
	local onChanged
	local celebrations = 0
	local fakePlayer = {}
	function fakePlayer:GetAttribute(name)
		assert(name == "TutorialStep")
		return step
	end
	function fakePlayer:GetAttributeChangedSignal(name)
		assert(name == "TutorialStep")
		return { Connect = function(_, callback) onChanged = callback end }
	end
	local function fakeNew(className, props, parent)
		local result = { Destroy = function() end }
		if className == "TextLabel" then
			assert(props.Text == "TUTORIAL COMPLETE!")
			celebrations += 1
		elseif className == "UIStroke" then
			parent.UIStroke = result
		end
		return result
	end
	local env = setmetatable({
		player = fakePlayer, new = fakeNew, play = function() end,
		task = { wait = function() end }, gui = {},
		FONT = Enum.Font.FredokaOne, GOLD = Color3.new(1, 1, 0),
	}, { __index = getfenv() })
	local run = assert(loadstring(listenerSource, "TutorialCompletionListener"))
	setfenv(run, env)
	run()
	assert(onChanged, "Listener did not connect")
	for _, nextStep in case.changes do
		step = nextStep
		onChanged()
	end
	assert(celebrations == case.expected, case.name .. ": expected " .. case.expected .. ", got " .. celebrations)
	print("PASS TutorialCompletion: " .. case.name)
end
print("PASS TutorialCompletion: all " .. #cases .. " cases")

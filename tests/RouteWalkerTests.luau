--!nocheck
-- RouteWalker gate-canopy regression. Run in Play, on the server (the canopies only exist after
-- NPCAnimator.buildQuestWorld has run): paste into the server command bar, or run through MCP execute_luau
-- with the Server datamodel. Everything it adds is removed again before it returns.
--
-- It proves the cover/roof rays only look past the real gate canopy, and that anything standing beneath a real
-- canopy, or merely named like one, still fails the gate.

local W = require(game.ServerStorage.RouteWalker)
local map = workspace.Map
local passages = map.WorldPolish.RoutePassages

local results, added = {}, {}
local function record(name, ok, detail)
	table.insert(results, ("%s  %s%s"):format(ok and "PASS" or "FAIL", name, detail and ("  [" .. detail .. "]") or ""))
end

local function block(name, size, pos, parent)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, pos
	p.Anchored, p.CanCollide = true, true
	p.Parent = parent or workspace
	table.insert(added, p)
	return p
end

local function clear()
	for _, p in added do
		p:Destroy()
	end
	table.clear(added)
end

local function kinds(res)
	local c = {}
	for _, i in res.issues do
		c[i.kind] = (c[i.kind] or 0) + 1
	end
	return c
end

-- A lane with a real canopy that one of its cross-sections (z0 + 20, every 40) passes under.
local lane, canopy, crossZ
for _, name in W.ORDER do
	local route = W.ROUTES[name]
	for _, c in passages:GetChildren() do
		if c.Name == "GateCanopy" and math.abs(c.Position.X - route.x) < 2 then
			for z = route.z0 + 20, route.z1 - 20, 40 do
				if math.abs(z - c.Position.Z) <= c.Size.Z / 2 then -- only Shadow Woods' section grazes its canopy (the edge)
					lane, canopy, crossZ = name, c, z
				end
			end
		end
	end
	if lane then
		break
	end
end
assert(lane, "no lane has a cross-section under a gate canopy")
local route = W.ROUTES[lane]

local ok, err = pcall(function()
	local base = W.walk(lane)
	local roadY = base.base
	local pass0 = W.gate(base)
	record("baseline: " .. lane .. " passes with its real canopy overhead", pass0, table.concat(select(2, W.gate(base)), " "))
	record("real canopy is recognised", W.isGateCanopy(canopy, roadY))
	local direct = workspace:Raycast(Vector3.new(route.x, 300, crossZ), Vector3.new(0, -400, 0))
	record("the cross-section ray really meets the canopy first", direct ~= nil and direct.Instance == canopy)

	-- 1. a hill-sized block standing beneath the real canopy (cover only counts parts over 60 studs corner to corner)
	block("RegressionHill", Vector3.new(44, 40, 24), Vector3.new(route.x + 22, roadY + 20, crossZ))
	local c = kinds(W.walk(lane))
	record("big obstruction beneath the canopy is COVER", (c.COVER or 0) > 0)
	clear()

	-- 2. a block on the road itself, beneath the canopy
	local pts = W.path(lane)
	-- the road sample nearest the canopy's middle; never the first sample, which has no step before it
	local onRoad
	for i = 2, #pts do
		local pt = pts[i]
		if math.abs(pt.Z - canopy.Position.Z) < 12 and (not onRoad or math.abs(pt.Z - canopy.Position.Z) < math.abs(onRoad.Z - canopy.Position.Z)) then
			onRoad = pt
		end
	end
	if onRoad then
		block("RegressionRoadBlock", Vector3.new(14, 10, 6), Vector3.new(onRoad.X, roadY + 5, onRoad.Z))
		c = kinds(W.walk(lane))
		record("road block beneath the canopy is BLOCKED", (c.BLOCKED or 0) > 0)
		clear()
	else
		record("road block beneath the canopy is BLOCKED", false, "no road sample under the canopy")
	end

	-- a mid-route cross-section away from any gate
	local midZ = route.z0 + 20 + 40 * 5

	-- 3. impostor: right name only (wrong parent, place and height)
	block("GateCanopy", canopy.Size, Vector3.new(route.x, roadY + 40, midZ))
	record("impostor is not recognised", not W.isGateCanopy(added[1], roadY))
	c = kinds(W.walk(lane))
	record("name-only impostor mid-route is COVER", (c.COVER or 0) > 0)
	clear()

	-- 4. impostor in the right folder at the right height and size, but not at a gate
	block("GateCanopy", canopy.Size, Vector3.new(route.x, canopy.Position.Y, midZ), passages)
	c = kinds(W.walk(lane))
	record("canopy-shaped part away from a gate is COVER", (c.COVER or 0) > 0)
	clear()

	-- 5. impostor in the right folder at the gate, but hanging low beneath the real canopy
	block("GateCanopy", canopy.Size, Vector3.new(route.x, roadY + 40, canopy.Position.Z), passages)
	c = kinds(W.walk(lane))
	record("low canopy-named part beneath the real one is COVER", (c.COVER or 0) > 0)
	clear()

	-- 6. a GateRidge-named part inside the corridor gets no exemption
	block("GateRidge", Vector3.new(60, 82, 27), Vector3.new(route.x + 33, 40, midZ), passages)
	c = kinds(W.walk(lane))
	record("GateRidge-named part inside the corridor is COVER", (c.COVER or 0) > 0)
	clear()

	-- 7. clean again, and every route still passes
	local again = W.gate(W.walk(lane))
	record("lane passes again after cleanup", again)
	local failed = {}
	for _, res in W.walkAll() do
		local good, reasons = W.gate(res)
		if not good then
			table.insert(failed, res.lane .. ": " .. table.concat(reasons, " "))
		end
	end
	record("all 16 routes pass the gate", #failed == 0, table.concat(failed, "; "))
end)
clear()
if not ok then
	record("test run", false, tostring(err))
end

local out = "RouteWalker canopy regression on " .. lane .. " (canopy z " .. math.floor(canopy.Position.Z) .. ", cross-section z " .. crossZ .. ")\n" .. table.concat(results, "\n")
print(out)
return out

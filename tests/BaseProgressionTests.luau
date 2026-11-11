-- Pure fixture suite: load in Studio and call .run(Shared.BaseProgressionData, GameData, DecorData).
local Tests = {}
function Tests.run(P, G, D)
	local checks = 0
	local function check(condition, message)
		assert(condition, message)
		checks += 1
	end
	check(P.normalize(nil) == 1, "New save defaults to Starter Yard")
	check(P.normalize({ expansion = false }) == 1, "Old unexpanded save")
	check(P.normalize({ expansion = true }) == 2, "Old expanded save")
	check(P.normalize({ expansion = true, baseStage = 1 }) == 2, "Legacy ownership wins over lower stage")
	for _, invalid in { 0, -1, 5, 2.5, math.huge, -math.huge, 0 / 0, "4", true } do
		check(P.normalize({ baseStage = invalid }) == 1, "Reject malformed stage")
	end
	for stage = 1, 4 do
		local saved = { baseStage = stage, expansion = stage >= 2 }
		check(P.normalize(saved) == stage, "Repeated round trip retains stage")
	end
	local ok, _, cost = P.nextGoal(1, 0, false, 0, 0, G.Economy.expansionCost)
	check(not ok and cost == 500, "New expansion needs a badge and retains price")
	check(P.nextGoal(1, 1, false, 0, 0, 500), "First badge opens purchase gate")
	check(not P.nextGoal(2, 16, true, 50, 50, 500), "Unapproved balcony price never purchasable")
	check(not P.nextGoal(3, 16, false, 50, 50, 500), "Terrace needs Champion")
	check(not P.nextGoal(3, 16, true, 49, 50, 500), "Terrace needs collection")
	check(not P.nextGoal(3, 16, true, 0, 0, 500), "Empty milestone config fails closed")
	check(P.nextGoal(3, 8, true, 50, 50, 500), "Champion plus collection opens terrace")
	local index = {}
	for _, region in G.IndexRegions do
		if table.find(P.RegionOneGroups, region.id) then
			for _, name in region.creatures do index[name] = { count = 1 } end
		end
	end
	local caught, total = P.collection(index, G.IndexRegions)
	check(caught == total and total > 0, "Region 1 collection derives from existing species")
	check(not D.inBounds(-130, 10, 4, 4, true, 5, 3), "Terrace placement locked before stage 4")
	check(D.inBounds(-130, 10, 4, 4, true, 5, 4), "Terrace ground supports decorations")
	check(D.inBounds(0, 0, 4, 4, false, 1, 1), "Legacy floor coordinates still valid")
	check(D.inBounds(-60, 0, 4, 4, true, 1, 2), "Legacy expansion coordinates still valid")
	check(not D.inBounds(-160, 0, 4, 4, true, 5, 4), "No out-of-base placement")
	for badges = 0, 16 do
		local battleCap = G.levelCap(badges, badges >= 8)
		check(G.BaseTraining.levelCap(badges, badges >= 8) <= battleCap - 3, "Training remains below battle cap")
	end
	check(D.CanopyTiers[2].share == 0.1 and D.CanopyTiers[6].share == 0.5, "Canopy shares preserved")
	check(D.CanopyTiers[2].cost == 300 and D.CanopyTiers[6].cost == 9000, "Canopy prices preserved")
	return checks
end
return Tests

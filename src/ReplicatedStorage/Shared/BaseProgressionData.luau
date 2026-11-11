-- Homestead stages are cosmetic progression, independent of decor levels and saved Canopy tiers.
local Progression = {}
Progression.Names = { "Starter Yard", "Habitat Garden", "XP Balcony", "Champion Terrace" }
Progression.XPBalconyCost = "OWNER_CONFIRMATION_REQUIRED"
Progression.RegionOneGroups = { "Meadow", "Whisperwood", "Boulder", "TideCoast", "VoltPlains", "EmberRidge", "FrostPeak", "ShadowWoods", "SkySpire" }

function Progression.normalize(saved)
	local stage = typeof(saved) == "table" and saved.baseStage or nil
	if typeof(stage) ~= "number" or stage ~= stage or stage % 1 ~= 0 or stage < 1 or stage > #Progression.Names then
		stage = 1
	end
	if typeof(saved) == "table" and saved.expansion == true then
		stage = math.max(2, stage)
	end
	return stage
end

function Progression.collection(index, regions)
	local caught, total = 0, 0
	local seen = {}
	for _, region in regions do
		if table.find(Progression.RegionOneGroups, region.id) then
			for _, name in region.creatures do
				if not seen[name] then
					seen[name] = true
					total += 1
					if index[name] then
						caught += 1
					end
				end
			end
		end
	end
	return caught, total
end

-- Returns eligibility, player-facing reason, and coin cost. Never accepts client requirements.
function Progression.nextGoal(stage, badges, champion, caught, total, expansionCost)
	if stage == 1 then
		return badges >= 1, ("1 badge + %d coins"):format(expansionCost), expansionCost
	elseif stage == 2 then
		local cost = Progression.XPBalconyCost
		if typeof(cost) ~= "number" or cost ~= cost or cost < 0 or cost == math.huge or cost % 1 ~= 0 then
			return false, "3 badges · balcony construction coming soon", nil
		end
		return badges >= 3, ("3 badges + %d coins"):format(cost), cost
	elseif stage == 3 then
		return champion and total > 0 and caught >= total, ("Champion + Region 1 Index (%d/%d)"):format(caught, total), 0
	end
	return false, "Homestead complete · collect and decorate!", nil
end

return Progression

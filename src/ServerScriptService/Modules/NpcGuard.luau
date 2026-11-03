--[[
	NpcGuard: every NPC model in Workspace.Map carries a HomePos attribute (its correct spot, stamped in
	Studio). On server start, any NPC more than MAX_DRIFT studs from HomePos is warned about in the output
	and snapped back, before any other system reads NPC positions.
	Why: earlier edits moved the Summit Clerk/Nurse and all League NPCs tens of thousands of studs away.
	When you move an NPC on purpose in Studio, run in the command bar:
	  require(game.ServerScriptService.Modules.NpcGuard).stamp()
	to record the new homes (otherwise it gets snapped back to the old spot on the next server start).
]]

local NpcGuard = {}
local MAX_DRIFT = 150

local function npcs()
	local list = {}
	for _, h in workspace.Map:GetDescendants() do
		if h:IsA("Humanoid") and h.Parent:IsA("Model") and h.Parent.PrimaryPart then
			table.insert(list, h.Parent)
		end
	end
	return list
end

-- Studio only: record every NPC's current spot as its home
function NpcGuard.stamp(): number
	local n = 0
	for _, m in npcs() do
		m:SetAttribute("HomePos", m:GetPivot().Position)
		n += 1
	end
	return n
end

function NpcGuard.run()
	local moved, missing = 0, 0
	for _, m in npcs() do
		local home = m:GetAttribute("HomePos")
		if typeof(home) ~= "Vector3" then
			missing += 1
		else
			local pivot = m:GetPivot()
			local drift = (pivot.Position - home).Magnitude
			if drift > MAX_DRIFT then
				warn(("[NpcGuard] %s was %.0f studs from home; moved back to %s"):format(m:GetFullName(), drift, tostring(home)))
				m:PivotTo(pivot.Rotation + home)
				moved += 1
			end
		end
	end
	if missing > 0 then
		warn(("[NpcGuard] %d NPC(s) have no HomePos yet; run NpcGuard.stamp() in Studio"):format(missing))
	end
	return moved
end

return NpcGuard

--!nocheck
-- Fix-Mountains.luau : paste into the Studio COMMAND BAR (View > Command Bar) in EDIT mode.
-- Mountains are voxel Terrain, so they cannot be selected or dragged. This carves the terrain
-- ABOVE each route's road surface (plus a margin) to air, leaving the road ground and the rest
-- of the perimeter ridge alone. One Ctrl+Z undoes the whole run.
-- Run once with APPLY = false (dry run: prints what it would clear), then set APPLY = true.

local APPLY       = false
local MARGIN      = 45     -- studs cleared beside each path part (raise to open more view)
local HEIGHT      = 500    -- studs cleared upward from the road surface
local LIFT        = 2      -- start clearing this far above the road top so the road stays
local MIN_SIZE    = 12     -- ignore small parts (decor, signs)
local NAME_HINTS  = { "path", "road", "lane", "route", "plaza", "ground" }  -- lowercase substrings
local SKIP_HINTS  = { "decor", "tree", "rock", "fence", "sign", "mountain", "bounds", "gym" }

local CHS = game:GetService("ChangeHistoryService")
local terrain = workspace.Terrain
local map = workspace:FindFirstChild("Map") or workspace

local function hasAny(name, list)
    name = name:lower()
    for _, h in ipairs(list) do if name:find(h, 1, true) then return true end end
    return false
end

local function skipped(inst)
    local p = inst
    while p and p ~= map do
        if hasAny(p.Name, SKIP_HINTS) then return true end
        p = p.Parent
    end
    return false
end

local targets = {}
for _, d in ipairs(map:GetDescendants()) do
    if d:IsA("BasePart") and d.Size.X >= MIN_SIZE and d.Size.Z >= MIN_SIZE
        and hasAny(d.Name, NAME_HINTS) and not skipped(d) then
        table.insert(targets, d)
    end
end
print(("Fix-Mountains: %d route parts matched (APPLY=%s)"):format(#targets, tostring(APPLY)))

if APPLY then CHS:SetWaypoint("Before Fix-Mountains") end
for i, part in ipairs(targets) do
    local size = Vector3.new(part.Size.X + 2 * MARGIN, HEIGHT, part.Size.Z + 2 * MARGIN)
    local cf = part.CFrame * CFrame.new(0, part.Size.Y / 2 + LIFT + HEIGHT / 2, 0)
    if APPLY then
        terrain:FillBlock(cf, size, Enum.Material.Air)
    elseif i <= 25 then
        print("would clear", part:GetFullName(), size)
    end
end
if APPLY then
    CHS:SetWaypoint("After Fix-Mountains")
    print("Fix-Mountains done. Ctrl+Z to undo. Save the place (File > Save to Roblox) to keep it.")
else
    print("Dry run only. Set APPLY = true and run again if the list looks right.")
end

-- If you also see Parts named like MountainHints you cannot move: select them in Explorer and
-- untick Locked in Properties (Locked=true blocks the mouse). Or run:
--   for _, p in ipairs(workspace.Map.MountainHints:GetDescendants()) do if p:IsA("BasePart") then p.Locked = false end end
-- Note: those are marker parts only; the real mountains are Terrain, handled above.

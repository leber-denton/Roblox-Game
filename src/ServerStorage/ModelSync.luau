--[[
	ModelSync: edit a model once in the showcase, then push it to the real copies.

	Workflow (run these in Studio's command bar, Edit mode):
	  local MS = require(game.ServerStorage.ModelSync)
	  MS.list()                    -- every showcase model name, by category
	  MS.audit()                   -- checks the lookup table against the place (run after adding models)
	  -- ...now edit the model in Workspace.ShowcaseArea (move parts, recolor, resize...)
	  MS.preview("OakTree")        -- shows what apply would replace, changes nothing
	  MS.apply("OakTree")          -- replaces every OakTree in the map with your edited version
	  MS.addToMap("OakTree", Vector3.new(0, 5, 0))   -- adds one more copy to the map
	  MS.restore("OakTree")        -- puts back the last backed-up originals (call again to step back further)

	Where the real copies are comes from ServerStorage.ModelSyncLookup (see that file):
	  * Trainers, gym leaders and other NPCs: exact map paths, plus the NPCBackup copy if there is one.
	  * Balls, creatures, companions: no copies in the map. They are spawned from a template, so apply
	    updates that template (ReplicatedStorage.CreatureMeshes.X, Shared.BallModels.X, ...).
	  * Decorations: every copy with that name under the map, plus ServerStorage.DecorMeshes.<name>.
	  * Map props: every copy with that name under Workspace.Map.Decor.
	  * Models not in the lookup fall back to the old rules: match by name in Workspace.Map, and the
	    template comes from the showcase model's ShowcaseSource attribute.

	How apply works:
	  * Every real copy is swapped for a clone of the showcase model, keeping that copy's position,
	    rotation and scale (same pivot), parent, name, attributes (HomePos, TrainerId, ...) and tags.
	  * The template is replaced too, so anything that spawns it later uses the new version.
	  * Replaced originals are moved to ServerStorage.ModelSyncBackups, never deleted.
	  * Keep the model's pivot where it started (move parts, not the pivot), or copies will shift.
	  * Plain parts outside a model can't be scaled, so they keep the edited part's size.
	  * Nothing changes until apply() runs. Showcase models must come from ShowcaseBuilder.build() (format 2).
	This is clone-based, not Roblox Packages: it only updates this place when you run apply.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Lookup = require(script.Parent:WaitForChild("ModelSyncLookup"))

local ModelSync = {}

ModelSync.lookup = Lookup
-- Extra/temporary entries (tests use this). Checked before the real table.
ModelSync.overrides = {}

-- Only these services are ever searched or resolved. Never iterate `game` itself: it contains
-- services Roblox locks (CoreGui, Stats, ...) and touching them throws.
local SAFE_SERVICES = {
	"Workspace",
	"ServerStorage",
	"ReplicatedStorage",
	"ServerScriptService",
	"ReplicatedFirst",
	"StarterPack",
	"StarterGui",
	"StarterPlayer",
	"Lighting",
}
local SAFE_LOOKUP = {}
for _, n in ipairs(SAFE_SERVICES) do
	SAFE_LOOKUP[n] = true
end

local SHOWCASE_FORMAT = 2
local ATTR_NOT_CARRIED = { OriginalParent = true, ModelSyncBatch = true }
local SHOWCASE_ATTRS = { "ShowcaseUnanchored", "ShowcaseEnabled", "ShowcaseTags", "ShowcaseSource", "ShowcaseSourceScale" }

local function safeRoots()
	local roots = {}
	for _, n in ipairs(SAFE_SERVICES) do
		local s = game:FindFirstChild(n)
		if s then
			table.insert(roots, s)
		end
	end
	return roots
end

local function resolvePath(fullName)
	if not fullName then
		return nil
	end
	local first, rest = fullName:match("^([^%.]+)%.?(.*)$")
	if not first or not SAFE_LOOKUP[first] then
		return nil
	end
	local node = game:FindFirstChild(first)
	for part in rest:gmatch("[^%.]+") do
		node = node and node:FindFirstChild(part)
	end
	return node
end

local function backups()
	local f = ServerStorage:FindFirstChild("ModelSyncBackups")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ModelSyncBackups"
		f.Parent = ServerStorage
	end
	return f
end

local function showcaseArea()
	return workspace:FindFirstChild("ShowcaseArea")
end

local function showcaseModels()
	local area = showcaseArea()
	local found = {}
	if area then
		for _, cat in ipairs(area:GetChildren()) do
			if cat:IsA("Folder") then
				for _, m in ipairs(cat:GetChildren()) do
					if m:GetAttribute("ShowcaseSource") then
						found[m.Name] = { inst = m, category = cat.Name }
					end
				end
			end
		end
	end
	return found
end

local function getShowcase(name)
	local entry = showcaseModels()[name]
	assert(entry, ("No showcase model named %q. Run ModelSync.list() to see names."):format(name))
	local area = showcaseArea()
	assert(
		area and area:GetAttribute("ShowcaseFormat") == SHOWCASE_FORMAT,
		"The showcase was built by an older ShowcaseBuilder (it lost anchoring and tags). Run require(game.ServerStorage.ShowcaseBuilder).build() first."
	)
	return entry.inst
end

-- Entry for a showcase model: override > lookup table > nil (legacy rules).
local function entryFor(name)
	return ModelSync.overrides[name] or Lookup.entries[name]
end

local function isReference(name, edited)
	local e = entryFor(name)
	if e then
		return e.reference == true
	end
	local src = edited:GetAttribute("ShowcaseSource")
	return src ~= nil and src:sub(1, 22) == "Workspace.ModelGallery"
end

-- Walks "Workspace_Map_BrookGym_Coralie" down from the map, one child name at a time (legacy NPC rule).
local function resolveNpcPath(name)
	local rest = name:match("^Workspace_Map_(.+)$")
	if not rest then
		return nil
	end
	local node = workspace.Map
	while rest ~= "" and node do
		local nextNode
		for _, c in ipairs(node:GetChildren()) do
			if rest == c.Name or rest:sub(1, #c.Name + 1) == c.Name .. "_" then
				nextNode = c
				rest = rest == c.Name and "" or rest:sub(#c.Name + 2)
				break
			end
		end
		node = nextNode
	end
	return node
end

local function isShowcaseOrGallery(inst)
	local area = showcaseArea()
	return (area ~= nil and inst:IsDescendantOf(area))
		or (workspace:FindFirstChild("ModelGallery") ~= nil and inst:IsDescendantOf(workspace.ModelGallery))
end

local function nameHits(name, rootInst, foldersOnly)
	local hits = {}
	for _, d in ipairs(rootInst:GetDescendants()) do
		if d.Name == name and (d:IsA("Model") or d:IsA("BasePart")) and not isShowcaseOrGallery(d) then
			-- skip parts nested inside another match (e.g. a part named like its parent model)
			local nested = d.Parent and d.Parent.Name == name
			if not nested and (not foldersOnly or (d.Parent and d.Parent:IsA("Folder"))) then
				table.insert(hits, d)
			end
		end
	end
	return hits
end

-- Returns the live copies to replace, and the template (or nil).
local function findTargets(name, opts)
	local entry = entryFor(name)
	local hits, seen = {}, {}
	local function add(inst)
		if inst and not seen[inst] and not isShowcaseOrGallery(inst) then
			seen[inst] = true
			table.insert(hits, inst)
		end
	end
	local missing = {}
	local template
	if entry then
		for _, path in ipairs(entry.map or {}) do
			local inst = resolvePath(path)
			if inst then
				add(inst)
			else
				table.insert(missing, path)
			end
		end
		if entry.byName then
			local root = resolvePath(entry.byName)
			if root then
				for _, h in ipairs(nameHits(name, root, entry.propsFolderOnly)) do
					add(h)
				end
			else
				table.insert(missing, entry.byName)
			end
		end
		if entry.template then
			template = resolvePath(entry.template)
			if not template and not entry.softTemplate then
				table.insert(missing, entry.template)
			end
		end
	else
		local direct = resolveNpcPath(name)
		if direct then
			add(direct)
		else
			for _, root in ipairs(opts and opts.roots or { workspace.Map }) do
				for _, h in ipairs(nameHits(name, root, false)) do
					add(h)
				end
			end
		end
		local edited = showcaseModels()[name]
		template = edited and resolvePath(edited.inst:GetAttribute("ShowcaseSource"))
	end
	if opts and opts.roots and entry then
		-- caller restricted the search: keep only copies under those roots
		local kept = {}
		for _, h in ipairs(hits) do
			for _, r in ipairs(opts.roots) do
				if h:IsDescendantOf(r) then
					table.insert(kept, h)
					break
				end
			end
		end
		hits = kept
	end
	return hits, template, missing
end

local function scaleOf(inst)
	return inst:IsA("Model") and inst:GetScale() or 1
end

-- A copy of the showcase model, ready to live in the game: showcase helpers removed, and the anchoring,
-- script state and tags that ShowcaseBuilder changed (to keep showcase models inert) put back.
local function cleanClone(edited)
	local c = edited:Clone()
	for _, d in ipairs(c:GetDescendants()) do
		if d.Name == "LabelAnchor" or d.Name == "NameTag" then
			d:Destroy()
		end
	end
	local all = { c }
	for _, d in ipairs(c:GetDescendants()) do
		table.insert(all, d)
	end
	for _, d in ipairs(all) do
		if d:IsA("BasePart") and d:GetAttribute("ShowcaseUnanchored") then
			d.Anchored = false
		end
		if d:IsA("BaseScript") and d:GetAttribute("ShowcaseEnabled") then
			d.Enabled = true
		end
		local tags = d:GetAttribute("ShowcaseTags")
		if tags then
			for tag in tags:gmatch("[^\n]+") do
				CollectionService:AddTag(d, tag)
			end
		end
		for _, a in ipairs(SHOWCASE_ATTRS) do
			d:SetAttribute(a, nil)
		end
	end
	return c
end

-- Scale the showcase model was cloned at, so each copy keeps its own size relative to that.
local function referenceScale(edited, template, old)
	return edited:GetAttribute("ShowcaseSourceScale") or scaleOf(template or old)
end

local function makeReplacement(edited, old, template)
	local new = cleanClone(edited)
	new.Name = old.Name
	-- the copy's own data (HomePos, TrainerId, ...) wins over whatever the showcase clone had
	for k, v in pairs(old:GetAttributes()) do
		-- RBX_* attributes are reserved by Roblox (scripts can't set them) and already came with the clone
		if not ATTR_NOT_CARRIED[k] and k:sub(1, 3) ~= "RBX" then
			new:SetAttribute(k, v)
		end
	end
	for _, tag in ipairs(CollectionService:GetTags(old)) do
		CollectionService:AddTag(new, tag)
	end
	if new:IsA("Model") then
		new:ScaleTo(scaleOf(old) / referenceScale(edited, template, old) * scaleOf(new))
	end
	new:PivotTo(old:GetPivot())
	return new
end

local function parentRef(old)
	-- an ObjectValue survives duplicate sibling names; the path string is the fallback
	local ref = Instance.new("ObjectValue")
	ref.Name = "ModelSyncParentRef"
	ref.Value = old.Parent
	ref.Parent = old
end

function ModelSync.list()
	local byCat = {}
	for name, e in pairs(showcaseModels()) do
		byCat[e.category] = byCat[e.category] or {}
		table.insert(byCat[e.category], name)
	end
	for cat, names in pairs(byCat) do
		table.sort(names)
		print(cat .. " (" .. #names .. "): " .. table.concat(names, ", "))
	end
	return byCat
end

function ModelSync.preview(name, opts)
	local edited = getShowcase(name)
	if isReference(name, edited) then
		print(("%s: reference-only model (no real copies). apply() will refuse."):format(name))
		return 0
	end
	local hits, template, missing = findTargets(name, opts)
	print(("%s: %d copies would be replaced; template %s"):format(name, #hits, template and template:GetFullName() or "none"))
	for i, h in ipairs(hits) do
		if i <= 10 then
			print("  " .. h:GetFullName())
		end
	end
	if #hits > 10 then
		print(("  ...and %d more"):format(#hits - 10))
	end
	for _, m in ipairs(missing) do
		warn(("  lookup path not found: %s"):format(m))
	end
	return #hits
end

function ModelSync.apply(name, opts)
	opts = opts or {}
	local edited = getShowcase(name)
	assert(not isReference(name, edited), name .. " is a reference-only gallery model: there is nothing real to update.")
	local hits, template, missing = findTargets(name, opts)
	assert(#missing == 0 or opts.allowMissing, ("Lookup paths not found, nothing changed: %s"):format(table.concat(missing, ", ")))
	local useTemplate = template and not opts.skipTemplate
	assert(#hits > 0 or useTemplate, name .. ": no copies and no template found, nothing to update.")

	local stamp = os.date("%Y-%m-%d %H%M%S")
	while backups():FindFirstChild(name .. " " .. stamp) do
		stamp ..= "b" -- two applies in the same second: keep the names unique and sorted in order
	end
	local backup = Instance.new("Folder")
	backup.Name = name .. " " .. stamp
	backup.Parent = backups()

	local replaced = 0
	for _, old in ipairs(hits) do
		local new = makeReplacement(edited, old, template)
		new:SetAttribute("ModelSyncBatch", backup.Name)
		new.Parent = old.Parent
		old:SetAttribute("OriginalParent", old.Parent:GetFullName())
		parentRef(old)
		old.Parent = backup
		replaced += 1
	end

	local templateUpdated = false
	if useTemplate then
		local parent = template.Parent
		local copy = cleanClone(edited)
		copy.Name = template.Name
		copy:SetAttribute("ModelSyncBatch", backup.Name)
		copy:PivotTo(template:GetPivot())
		template.Name = template.Name .. "_old"
		template:SetAttribute("OriginalParent", parent:GetFullName())
		parentRef(template)
		template.Parent = backup
		copy.Parent = parent
		templateUpdated = true
		edited:SetAttribute("ShowcaseSource", copy:GetFullName())
	end
	print(
		("ModelSync.apply %s: replaced %d copies, template updated: %s. Originals are in %s"):format(
			name,
			replaced,
			tostring(templateUpdated),
			backup:GetFullName()
		)
	)
	return replaced
end

function ModelSync.addToMap(name, where, parent)
	local edited = getShowcase(name)
	local new = cleanClone(edited)
	local cf = typeof(where) == "Vector3" and CFrame.new(where) or where
	new:PivotTo(cf)
	new.Parent = parent or workspace.Map:FindFirstChild("Decor") or workspace.Map
	print("Added " .. new:GetFullName())
	return new
end

-- Puts back whatever the most recent apply() for this name moved into ModelSyncBackups.
function ModelSync.restore(name)
	local latest
	for _, f in ipairs(backups():GetChildren()) do
		if f.Name:sub(1, #name + 1) == name .. " " and (not latest or f.Name > latest.Name) then
			latest = f
		end
	end
	assert(latest, "No backup found for " .. name)
	-- remove the edited copies this batch created, then put the originals back.
	-- Only the safe services are scanned (see SAFE_SERVICES); never `game`.
	local created = {}
	for _, root in ipairs(safeRoots()) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:GetAttribute("ModelSyncBatch") == latest.Name and not d:IsDescendantOf(latest) then
				table.insert(created, d)
			end
		end
	end
	for _, d in ipairs(created) do
		d:Destroy()
	end
	local restored = 0
	for _, old in ipairs(latest:GetChildren()) do
		local pathStr = old:GetAttribute("OriginalParent")
		local ref = old:FindFirstChild("ModelSyncParentRef")
		local parent = ref and ref.Value or resolvePath(pathStr)
		if parent and parent ~= latest then
			if ref then
				ref:Destroy()
			end
			if old.Name:sub(-4) == "_old" then
				old.Name = old.Name:sub(1, -5)
			end
			old:SetAttribute("OriginalParent", nil)
			old.Parent = parent
			restored += 1
		end
	end
	if #latest:GetChildren() == 0 then
		latest:Destroy() -- so the next restore() steps back to the previous apply
	end
	print(("Restored %d items from %s."):format(restored, latest.Name))
	return restored
end

-- Compares the lookup table, the showcase and the template folders. Prints problems; returns them.
function ModelSync.audit()
	local problems = {}
	local function bad(msg)
		table.insert(problems, msg)
		warn("audit: " .. msg)
	end
	local showcase = showcaseModels()
	local names = {}
	for name in pairs(Lookup.entries) do
		names[name] = true
	end
	for name in pairs(ModelSync.overrides) do
		names[name] = true
	end
	for name in pairs(names) do
		local e = entryFor(name)
		if not showcase[name] then
			bad(("%s is in the lookup but not in the showcase (rebuild it, or the source is missing)"):format(name))
		end
		for _, path in ipairs(e.map or {}) do
			if not resolvePath(path) then
				bad(("%s: map path not found: %s"):format(name, path))
			end
		end
		if e.byName and not resolvePath(e.byName) then
			bad(("%s: byName root not found: %s"):format(name, e.byName))
		end
		if e.template and not e.softTemplate and not resolvePath(e.template) then
			bad(("%s: template not found: %s"):format(name, e.template))
		end
	end
	for name, s in pairs(showcase) do
		if not names[name] and not isReference(name, s.inst) then
			bad(("%s is in the showcase but not in the lookup (it falls back to name matching)"):format(name))
		end
	end
	local byTemplate = {}
	for _, e in pairs(Lookup.entries) do
		if e.template then
			byTemplate[e.template] = true
		end
	end
	for _, folderPath in ipairs(Lookup.TEMPLATE_FOLDERS) do
		local folder = resolvePath(folderPath)
		if not folder then
			bad("template folder not found: " .. folderPath)
		else
			for _, c in ipairs(folder:GetChildren()) do
				if (c:IsA("Model") or c:IsA("BasePart")) and not byTemplate[folderPath .. "." .. c.Name] then
					bad(("%s.%s has no lookup entry"):format(folderPath, c.Name))
				end
			end
		end
	end
	local map = workspace:FindFirstChild("Map")
	if map then
		local known = {}
		for _, e in pairs(Lookup.entries) do
			for _, p in ipairs(e.map or {}) do
				known[p] = true
			end
		end
		for _, d in ipairs(map:GetDescendants()) do
			if d:IsA("Humanoid") and d.Parent:IsA("Model") and not known[d.Parent:GetFullName()] then
				bad(("NPC %s has no lookup entry"):format(d.Parent:GetFullName()))
			end
		end
	end
	print(#problems == 0 and "audit: lookup, showcase and templates agree." or ("audit: %d problem(s)."):format(#problems))
	return problems
end

return ModelSync

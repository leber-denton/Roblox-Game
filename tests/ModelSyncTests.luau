--[[
	ModelSyncTests: run by hand in Studio's command bar (Edit mode). Not synced.
	  local ok, lines = require(game.ServerStorage.ModelSyncTests).run(require(game.ServerStorage.ModelSync))
	Put this file in ServerStorage as a ModuleScript named ModelSyncTests (temporarily copy it into
	src/ServerStorage so Rojo syncs it, then remove it again), then call run(ModelSync).
	run() returns ok, results. Set ModelSync.__source to the ModelSync source text to include the
	"never iterates game" check.

	Everything happens on throwaway copies in Workspace.__MSTest (plus a __TEST folder inside
	Workspace.ShowcaseArea). Nothing under Workspace.Map or the real template folders is touched; the test
	compares counts and positions of those before and after to prove it. Cleans up after itself.

	Covers: decorations by name (rotate/scale variants), NPCs with several map paths (attributes, tags,
	anchoring), template-only balls and creatures, reference-only gallery models, the old name-match
	fallback, preview dry run, addToMap, restore stepping back through two applies, and the restore
	regression (it once iterated `game` and hit a locked Roblox service).
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Tests = {}

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-3)
end

local function sameCF(a, b)
	local ca, cb = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		if not near(ca[i], cb[i], 1e-2) then
			return false
		end
	end
	return true
end

local function pivotOf(i)
	return i:GetPivot()
end

local function scaleOf(i)
	return i:IsA("Model") and i:GetScale() or 1
end

local function snapshotReal()
	local sum, count = Vector3.zero, 0
	for _, d in ipairs(workspace.Map:GetDescendants()) do
		if d:IsA("BasePart") then
			count += 1
			sum += d.Position
		end
	end
	local function n(i)
		return i and #i:GetDescendants() or -1
	end
	return {
		mapParts = count,
		mapSum = sum,
		creatures = n(game.ReplicatedStorage.CreatureMeshes),
		balls = n(game.ReplicatedStorage.Shared.BallModels),
		decor = n(ServerStorage.DecorMeshes),
		npcBackup = n(ServerStorage.NPCBackup),
		backups = #ServerStorage.ModelSyncBackups:GetChildren(),
	}
end

function Tests.run(ModelSync)
	local results, failures = {}, 0
	local function check(name, cond, detail)
		table.insert(results, ("%s %s%s"):format(cond and "PASS" or "FAIL", name, detail and (" -- " .. tostring(detail)) or ""))
		if not cond then
			failures += 1
		end
	end
	local function section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			check(name .. " (threw)", false, err)
		end
	end

	local before = snapshotReal()
	local gallery = workspace.ShowcaseArea
	local realShowcase = {
		slate = gallery["GYM LEADERS"].Workspace_Map_MeadowGym_Slate,
		ball = gallery.BALLS.TideBall,
		creature = gallery.CREATURES.Blazefox,
		boulder = gallery.DECORATIONS.Boulder,
	}

	-- throwaway scene
	local T = Instance.new("Folder")
	T.Name = "__MSTest"
	T.Parent = workspace
	local tMap = Instance.new("Folder")
	tMap.Name = "Map"
	tMap.Parent = T
	local tGym = Instance.new("Folder")
	tGym.Name = "Gym"
	tGym.Parent = tMap
	local tDecor = Instance.new("Folder")
	tDecor.Name = "Decor"
	tDecor.Parent = tMap
	local tTemplates = Instance.new("Folder")
	tTemplates.Name = "Templates"
	tTemplates.Parent = T
	local tShow = Instance.new("Folder")
	tShow.Name = "__TEST"
	tShow.Parent = gallery

	local function showcaseModel(from, name, sourcePath, recolorPart)
		local c = from:Clone()
		c.Name = name
		c:SetAttribute("ShowcaseSource", sourcePath)
		c.Parent = tShow
		-- the "edit": recolor (never move the pivot)
		local p = recolorPart and c:FindFirstChild(recolorPart, true)
		if not p then
			p = c:IsA("BasePart") and c or c:FindFirstChildWhichIsA("BasePart", true)
		end
		p.Color = Color3.fromRGB(255, 0, 0)
		return c, p
	end

	local function template(from, realFromSource, name, at)
		local t = realFromSource:Clone()
		t.Name = name
		t.Parent = tTemplates
		t:PivotTo(at)
		return t
	end

	-- ============ A. decorations by name: rotate/scale variants ============
	section("A decor", function()
		local srcBoulder = game.ServerStorage.DecorMeshes.Boulder
		local tmpl = template(nil, srcBoulder, "TestRock", CFrame.new(5000, 0, 0))
		local tmplPivot = tmpl:GetPivot()
		local variants = {
			{ pos = Vector3.new(0, 0, 0), rot = 0, scale = 0.6 },
			{ pos = Vector3.new(60, 0, 10), rot = 45, scale = 1 },
			{ pos = Vector3.new(120, 0, -30), rot = 137, scale = 1.7 },
		}
		local olds = {}
		for i, v in ipairs(variants) do
			local c = srcBoulder:Clone()
			c.Name = "TestRock"
			c.Parent = tDecor
			if c:IsA("Model") then
				c:ScaleTo(v.scale)
			end
			c:PivotTo(CFrame.new(v.pos) * CFrame.Angles(0, math.rad(v.rot), 0))
			c:SetAttribute("Tag" .. i, i)
			olds[i] = { inst = c, pivot = c:GetPivot(), scale = scaleOf(c), parent = c.Parent }
		end
		local sc, edited = showcaseModel(realShowcase.boulder, "TestRock", tmpl:GetFullName())
		ModelSync.overrides.TestRock =
			{ category = "DECORATIONS", map = {}, byName = "Workspace.__MSTest.Map", template = tmpl:GetFullName() }

		local count0 = #T:GetDescendants()
		local n = ModelSync.preview("TestRock")
		check("A preview counts 3 copies", n == 3, n)
		check("A preview changed nothing", #T:GetDescendants() == count0 and olds[1].inst.Parent == tDecor and tmpl.Parent == tTemplates)

		local replaced = ModelSync.apply("TestRock")
		check("A apply replaced 3", replaced == 3, replaced)
		local news = {}
		for _, c in ipairs(tDecor:GetChildren()) do
			if c:GetAttribute("ModelSyncBatch") then
				table.insert(news, c)
			end
		end
		check("A 3 new copies in same parent", #news == 3, #news)
		for i, o in ipairs(olds) do
			-- match each new copy to the old one by position
			local m
			for _, c in ipairs(news) do
				if (c:GetPivot().Position - o.pivot.Position).Magnitude < 0.5 then
					m = c
				end
			end
			check(("A variant %d exists"):format(i), m ~= nil)
			if m then
				check(("A variant %d pivot kept"):format(i), sameCF(m:GetPivot(), o.pivot))
				check(("A variant %d name/parent kept"):format(i), m.Name == "TestRock" and m.Parent == o.parent)
				if m:IsA("Model") then
					check(
						("A variant %d scale kept"):format(i),
						near(m:GetScale(), o.scale, 0.01),
						("%s vs %s"):format(m:GetScale(), o.scale)
					)
				end
				check(("A variant %d attribute kept"):format(i), m:GetAttribute("Tag" .. i) == i)
				check(("A variant %d edit applied"):format(i), m:FindFirstChildWhichIsA("BasePart", true) ~= nil)
				check(
					("A variant %d no showcase leftovers"):format(i),
					m:FindFirstChild("LabelAnchor", true) == nil and m:GetAttribute("ShowcaseSource") == nil
				)
			end
		end
		local newTemplate = tTemplates:FindFirstChild("TestRock")
		check("A template replaced", newTemplate ~= nil and newTemplate ~= tmpl and newTemplate:GetAttribute("ModelSyncBatch") ~= nil)
		check("A template pivot kept", newTemplate ~= nil and sameCF(newTemplate:GetPivot(), tmplPivot))
		check("A originals backed up", olds[1].inst:IsDescendantOf(ServerStorage.ModelSyncBackups))

		local restored = ModelSync.restore("TestRock")
		check("A restore returned 4 (3 copies + template)", restored == 4, restored)
		for i, o in ipairs(olds) do
			check(("A original %d is back (same instance)"):format(i), o.inst.Parent == tDecor and sameCF(o.inst:GetPivot(), o.pivot))
		end
		check("A template restored (same instance, name)", tmpl.Parent == tTemplates and tmpl.Name == "TestRock")
		local stray = 0
		for _, c in ipairs(T:GetDescendants()) do
			if c:GetAttribute("ModelSyncBatch") then
				stray += 1
			end
		end
		check("A edited copies removed", stray == 0, stray)
		check("A second restore refuses (nothing left)", not pcall(ModelSync.restore, "TestRock"))
		ModelSync.overrides.TestRock = nil
		sc:Destroy()
	end)

	-- ============ B. NPC with two map paths ============
	section("B NPC multi-path", function()
		local liveSlate = workspace.Map.MeadowGym.Slate
		local tmpl = template(nil, liveSlate, "TestSlate", CFrame.new(5000, 0, 100))
		local function mapCopy(name, pos, rot, scale, extraTag)
			local c = liveSlate:Clone()
			c.Name = name
			c.Parent = tGym
			c:ScaleTo(scale)
			c:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(rot), 0))
			c:SetAttribute("HomePos", pos)
			c:SetAttribute("TrainerId", name)
			CollectionService:AddTag(c, extraTag)
			return c
		end
		local a = mapCopy("TestSlateA", Vector3.new(0, 7, 0), 30, 1.2, "TestTagA")
		local b = mapCopy("TestSlateB", Vector3.new(40, 7, 20), 200, 0.8, "TestTagB")
		local oldUn = 0
		for _, d in ipairs(a:GetDescendants()) do
			if d:IsA("BasePart") and not d.Anchored then
				oldUn += 1
			end
		end
		local pa, pb, sa, sb = a:GetPivot(), b:GetPivot(), a:GetScale(), b:GetScale()
		local sc, p = showcaseModel(realShowcase.slate, "TestSlate", tmpl:GetFullName(), "Belt")
		ModelSync.overrides.TestSlate = {
			category = "GYM LEADERS",
			map = { a:GetFullName(), b:GetFullName() },
			template = tmpl:GetFullName(),
		}
		check("B preview sees 2", ModelSync.preview("TestSlate") == 2)
		check("B preview changed nothing", a.Parent == tGym and b.Parent == tGym)
		local replaced = ModelSync.apply("TestSlate")
		check("B apply replaced 2", replaced == 2, replaced)
		local na, nb
		for _, c in ipairs(tGym:GetChildren()) do
			if c:GetAttribute("ModelSyncBatch") then
				if c.Name == "TestSlateA" then
					na = c
				elseif c.Name == "TestSlateB" then
					nb = c
				end
			end
		end
		check("B both replacements exist with own names", na ~= nil and nb ~= nil)
		if na and nb then
			check("B pivots kept", sameCF(na:GetPivot(), pa) and sameCF(nb:GetPivot(), pb))
			check(
				"B scales kept",
				near(na:GetScale(), sa, 0.01) and near(nb:GetScale(), sb, 0.01),
				("%s %s"):format(na:GetScale(), nb:GetScale())
			)
			check(
				"B HomePos/TrainerId carried",
				na:GetAttribute("HomePos") == Vector3.new(0, 7, 0) and nb:GetAttribute("TrainerId") == "TestSlateB"
			)
			check(
				"B own tags carried",
				CollectionService:HasTag(na, "TestTagA")
					and CollectionService:HasTag(nb, "TestTagB")
					and not CollectionService:HasTag(na, "TestTagB")
			)
			local un = 0
			for _, d in ipairs(na:GetDescendants()) do
				if d:IsA("BasePart") and not d.Anchored then
					un += 1
				end
			end
			check("B limb anchoring restored (animations can move)", un == oldUn and un > 0, ("%d vs %d"):format(un, oldUn))
			check("B edit applied", na:FindFirstChild("Belt").Color == Color3.fromRGB(255, 0, 0))
			check("B humanoid kept", na:FindFirstChildOfClass("Humanoid") ~= nil)
			check(
				"B no showcase attrs/helpers",
				na:GetAttribute("ShowcaseSource") == nil
					and na:FindFirstChild("NameTag", true) == nil
					and na:FindFirstChild("LabelAnchor", true) == nil
			)
		end
		check("B template updated", tTemplates:FindFirstChild("TestSlate") ~= tmpl and tTemplates:FindFirstChild("TestSlate") ~= nil)
		ModelSync.restore("TestSlate")
		check("B originals back", a.Parent == tGym and b.Parent == tGym and sameCF(a:GetPivot(), pa) and tmpl.Parent == tTemplates)
		check("B only originals remain", #tGym:GetChildren() == 2)
		ModelSync.overrides.TestSlate = nil
		sc:Destroy()
	end)

	-- ============ C. ball template (BasePart, tag, template-only) ============
	section("C ball template-only", function()
		local srcBall = game.ReplicatedStorage.Shared.BallModels.TideBall
		local tmpl = template(nil, srcBall, "TestBall", CFrame.new(5000, 0, 200))
		local pivot0 = tmpl:GetPivot()
		local origTags = CollectionService:GetTags(tmpl)
		local sc, p = showcaseModel(realShowcase.ball, "TestBall", tmpl:GetFullName())
		ModelSync.overrides.TestBall = { category = "BALLS", map = {}, template = tmpl:GetFullName() }
		check("C preview sees 0 copies", ModelSync.preview("TestBall") == 0)
		local replaced = ModelSync.apply("TestBall")
		check("C apply: 0 copies, template updated", replaced == 0)
		local nt = tTemplates:FindFirstChild("TestBall")
		check("C new template exists", nt ~= nil and nt ~= tmpl)
		if nt then
			check(
				"C CapturePickup tag restored",
				CollectionService:HasTag(nt, "CapturePickup"),
				table.concat(CollectionService:GetTags(nt), ",")
			)
			check("C Pickup attribute kept", nt:GetAttribute("Pickup") == true)
			check(
				"C ball anchoring matches the original template",
				nt:IsA("BasePart") and nt.Anchored == tmpl.Anchored,
				("%s vs %s"):format(tostring(nt.Anchored), tostring(tmpl.Anchored))
			)
			check("C edit applied", nt.Color == Color3.fromRGB(255, 0, 0))
			check("C template pivot kept", sameCF(nt:GetPivot(), pivot0))
		end
		check("C original template had the tag too", #origTags > 0)
		ModelSync.restore("TestBall")
		check("C original template back", tmpl.Parent == tTemplates and tmpl.Name == "TestBall" and #tTemplates:GetChildren() >= 1)
		check("C no extra template copies", #tTemplates:GetChildren() == 3, #tTemplates:GetChildren())
		ModelSync.overrides.TestBall = nil
		sc:Destroy()
	end)

	-- ============ D. creature template-only ============
	section("D creature template-only", function()
		local srcC = game.ReplicatedStorage.CreatureMeshes.Blazefox
		local tmpl = template(nil, srcC, "TestCreature", CFrame.new(5000, 0, 300))
		local sc = showcaseModel(realShowcase.creature, "TestCreature", tmpl:GetFullName())
		ModelSync.overrides.TestCreature = { category = "CREATURES", map = {}, template = tmpl:GetFullName() }
		local replaced = ModelSync.apply("TestCreature")
		check("D creature apply: template only", replaced == 0 and tTemplates:FindFirstChild("TestCreature") ~= tmpl)
		ModelSync.restore("TestCreature")
		check("D creature restored", tmpl.Parent == tTemplates and tmpl.Name == "TestCreature")
		ModelSync.overrides.TestCreature = nil
		sc:Destroy()
	end)

	-- ============ E. reference-only and missing paths ============
	section("E reference + missing", function()
		local gal = gallery.TRAINERS:FindFirstChild("Trainer v1")
		check("E gallery trainer is in showcase", gal ~= nil)
		check("E apply refuses gallery trainer", not pcall(ModelSync.apply, "Trainer v1"))
		check("E preview of gallery trainer is a no-op", ModelSync.preview("Trainer v1") == 0)
		local sc = showcaseModel(realShowcase.creature, "TestMissing", "Workspace.__MSTest.Templates.NoSuch")
		ModelSync.overrides.TestMissing =
			{ category = "CREATURES", map = { "Workspace.__MSTest.Map.NoSuch" }, template = "Workspace.__MSTest.Templates.NoSuch" }
		local backups0 = #ServerStorage.ModelSyncBackups:GetChildren()
		check(
			"E apply with missing paths refuses and changes nothing",
			not pcall(ModelSync.apply, "TestMissing") and #ServerStorage.ModelSyncBackups:GetChildren() == backups0
		)
		-- locked-service path: must be refused by the lookup, never resolved
		ModelSync.overrides.TestMissing = { category = "CREATURES", map = { "CoreGui.RobloxGui" }, template = "Stats.Anything" }
		check("E locked-service paths refused without error", not pcall(ModelSync.apply, "TestMissing"))
		check("E preview with locked paths does not throw", pcall(ModelSync.preview, "TestMissing"))
		ModelSync.overrides.TestMissing = nil
		sc:Destroy()
	end)

	-- ============ F. old name-match fallback (no lookup entry) ============
	section("F legacy fallback", function()
		local srcBoulder = game.ServerStorage.DecorMeshes.Boulder
		local tmpl = template(nil, srcBoulder, "TestLegacy", CFrame.new(5000, 0, 400))
		local c = srcBoulder:Clone()
		c.Name = "TestLegacy"
		c.Parent = tDecor
		c:PivotTo(CFrame.new(300, 0, 300))
		local pv = c:GetPivot()
		local sc = showcaseModel(realShowcase.boulder, "TestLegacy", tmpl:GetFullName())
		check("F has no lookup entry", ModelSync.lookup.entries.TestLegacy == nil and ModelSync.overrides.TestLegacy == nil)
		check("F opts.roots limits the search", ModelSync.preview("TestLegacy", { roots = { tDecor } }) == 1)
		ModelSync.apply("TestLegacy", { roots = { tDecor } })
		local made
		for _, x in ipairs(tDecor:GetChildren()) do
			if x:GetAttribute("ModelSyncBatch") then
				made = x
			end
		end
		check("F legacy replacement keeps pivot", made ~= nil and sameCF(made:GetPivot(), pv))
		ModelSync.restore("TestLegacy")
		check("F legacy restore", c.Parent == tDecor and tmpl.Parent == tTemplates)
		sc:Destroy()
	end)

	-- ============ G. two applies, two restores step back in order ============
	section("G stacked applies", function()
		local srcBoulder = game.ServerStorage.DecorMeshes.Boulder
		local tmpl = template(nil, srcBoulder, "TestStack", CFrame.new(5000, 0, 500))
		local c = srcBoulder:Clone()
		c.Name = "TestStack"
		c.Parent = tDecor
		c:PivotTo(CFrame.new(500, 0, 500))
		local sc = showcaseModel(realShowcase.boulder, "TestStack", tmpl:GetFullName())
		ModelSync.overrides.TestStack =
			{ category = "DECORATIONS", map = {}, byName = "Workspace.__MSTest.Map", template = tmpl:GetFullName() }
		ModelSync.apply("TestStack")
		ModelSync.apply("TestStack") -- same second on purpose
		local backupsFor = 0
		for _, f in ipairs(ServerStorage.ModelSyncBackups:GetChildren()) do
			if f.Name:sub(1, 10) == "TestStack " then
				backupsFor += 1
			end
		end
		check("G two distinct backup folders", backupsFor == 2, backupsFor)
		ModelSync.restore("TestStack")
		check("G first restore leaves one backup", #ServerStorage.ModelSyncBackups:GetChildren() == before.backups + 1)
		ModelSync.restore("TestStack")
		check("G second restore brings the true original back", c.Parent == tDecor and tmpl.Parent == tTemplates)
		check("G backups cleaned", #ServerStorage.ModelSyncBackups:GetChildren() == before.backups)
		ModelSync.overrides.TestStack = nil
		sc:Destroy()
	end)

	-- ============ H. restore regression: never touches a locked service ============
	section("H restore safety", function()
		local src = ModelSync.__source
		-- a backup whose recorded parent is a locked service and has no reference: must be skipped, not thrown
		local f = Instance.new("Folder")
		f.Name = "TestLocked 2000-01-01 000000"
		f.Parent = ServerStorage.ModelSyncBackups
		local orphan = Instance.new("Part")
		orphan.Name = "Orphan"
		orphan:SetAttribute("OriginalParent", "CoreGui.RobloxGui")
		orphan.Parent = f
		local ok, res = pcall(ModelSync.restore, "TestLocked")
		check("H restore with locked-service parent does not throw", ok, res)
		check("H orphan stayed in backup (not moved into a locked service)", orphan.Parent == f)
		f:Destroy()
		if src then
			check(
				"H ModelSync source never iterates game",
				not src:find("game:GetDescendants", 1, true) and not src:find("game%.GetDescendants")
			)
		end
	end)

	-- ============ I. addToMap on every kind (into the throwaway map, not the real one) ============
	section("I addToMap", function()
		local sc1, _ = showcaseModel(realShowcase.slate, "TestAddNPC", "Workspace.__MSTest.Templates.x")
		local sc2 = showcaseModel(realShowcase.ball, "TestAddBall", "Workspace.__MSTest.Templates.x")
		local n1 = ModelSync.addToMap("TestAddNPC", Vector3.new(700, 5, 700), tGym)
		local n2 = ModelSync.addToMap("TestAddBall", CFrame.new(720, 5, 700), tGym)
		check("I NPC added at requested spot", (n1:GetPivot().Position - Vector3.new(700, 5, 700)).Magnitude < 0.5 and n1.Parent == tGym)
		check(
			"I added NPC has no showcase helpers",
			n1:FindFirstChild("NameTag", true) == nil and n1:FindFirstChild("LabelAnchor", true) == nil
		)
		local free = 0
		for _, d in ipairs(n1:GetDescendants()) do
			if d:IsA("BasePart") and not d.Anchored then
				free += 1
			end
		end
		check("I added NPC limbs unanchored", free > 0, free)
		check("I added ball keeps its tag", CollectionService:HasTag(n2, "CapturePickup"))
		sc1:Destroy()
		sc2:Destroy()
	end)

	-- ============ J. audit ============
	section("J audit", function()
		local problems = ModelSync.audit()
		check("J audit finds nothing wrong with the real place", #problems == 0, table.concat(problems, " | "):sub(1, 400))
	end)

	-- cleanup
	tShow:Destroy()
	T:Destroy()
	for _, f in ipairs(ServerStorage.ModelSyncBackups:GetChildren()) do
		if f.Name:sub(1, 4) == "Test" then
			f:Destroy()
		end
	end

	local after = snapshotReal()
	check("real map unchanged (part count)", after.mapParts == before.mapParts, ("%d -> %d"):format(before.mapParts, after.mapParts))
	check("real map unchanged (position checksum)", (after.mapSum - before.mapSum).Magnitude < 0.01)
	check(
		"real CreatureMeshes/BallModels/DecorMeshes/NPCBackup unchanged",
		after.creatures == before.creatures
			and after.balls == before.balls
			and after.decor == before.decor
			and after.npcBackup == before.npcBackup
	)
	check("ModelSyncBackups back to starting contents", after.backups == before.backups, ("%d -> %d"):format(before.backups, after.backups))
	check("throwaway scene gone", workspace:FindFirstChild("__MSTest") == nil and gallery:FindFirstChild("__TEST") == nil)

	table.insert(results, ("%d failure(s)"):format(failures))
	return failures == 0, results
end

return Tests

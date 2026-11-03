-- TEMPORARY build helper: moves freshly generated models from workspace into the libraries,
-- centred at the origin and turned so they face -Z (the game's forward). Delete after building.
return function()
	local RS = game.ReplicatedStorage
	local lib = RS:FindFirstChild("CreatureMeshes") or Instance.new("Folder")
	lib.Name = "CreatureMeshes"
	lib.Parent = RS
	local decor = game.ServerStorage:FindFirstChild("DecorMeshes") or Instance.new("Folder")
	decor.Name = "DecorMeshes"
	decor.Parent = game.ServerStorage
	local function find(m, word)
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Name:lower():find(word) then
				return p
			end
		end
	end
	local function orient(m)
		local cf, size = m:GetBoundingBox()
		local center = cf.Position
		local dir
		local head, tail = find(m, "head") or find(m, "face"), find(m, "tail")
		if head then
			local v = head.Position - center
			dir = Vector3.new(v.X, 0, v.Z)
			if dir.Magnitude < size.Magnitude * 0.06 then
				dir = nil
			end
		end
		if not dir and tail then
			local v = center - tail.Position
			dir = Vector3.new(v.X, 0, v.Z)
			if dir.Magnitude < size.Magnitude * 0.06 then
				dir = nil
			end
		end
		if dir then
			dir = dir.Unit
			local yaw = math.atan2(dir.X, -dir.Z)
			local snapped = math.floor(yaw / (math.pi / 2) + 0.5) * (math.pi / 2)
			m:PivotTo(CFrame.new(center) * CFrame.Angles(0, snapped, 0) * CFrame.new(-center) * m:GetPivot())
			return math.deg(snapped)
		end
		return "?"
	end
	local moved = {}
	for _, c in workspace:GetChildren() do
		if c:IsA("Model") then
			local creature = c.Name:match("^(%w+):")
			local dec = c.Name:match("^DECOR_(%w+):")
			if creature or dec then
				local cf = c:GetBoundingBox()
				-- drop the model's own rotation, centre at the origin
				c:PivotTo(cf:Inverse() * c:GetPivot())
				for _, d in c:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				if dec then
					c.Name = dec
					c.Parent = decor
					table.insert(moved, "decor " .. dec)
				else
					if lib:FindFirstChild(creature) then
						lib[creature]:Destroy()
					end
					-- generator faces +Z; flip, then fine-tune from the head/tail
					c:PivotTo(CFrame.Angles(0, math.pi, 0) * c:GetPivot())
					local turned = orient(c)
					c.Name = creature
					c.Parent = lib
					table.insert(moved, creature .. "(" .. tostring(turned) .. ")")
				end
			end
		end
	end
	return moved, #lib:GetChildren(), #decor:GetChildren()
end

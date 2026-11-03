--[[
	Sfx: one-shot sound effects from GameData.Audio.sfx, played only for this player.
	Sfx.play("hit")
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))

local Sfx = {}
local cache = {}

function Sfx.play(name: string)
	local def = GameData.Audio and GameData.Audio.sfx[name]
	if not def or not def.id or def.id == 0 then
		return
	end
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Sfx_" .. name
		sound.SoundId = "rbxassetid://" .. def.id
		sound.Volume = def.volume or 0.5
		sound.Parent = SoundService
		cache[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

return Sfx

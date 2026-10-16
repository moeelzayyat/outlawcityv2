-- Audio (S2.6): the shipped config is valid and only plays approved Roblox-owned IDs; positional
-- sounds fade with distance; engine pitch and tyre squeal follow speed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AudioRules = require(ReplicatedStorage.Shared.Rules.AudioRules)
local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local Assert = require(script.Parent.Assert)

local function def(id: string, positional: boolean)
	return { SoundId = id, Volume = 0.5, Looped = false, Positional = positional, RollOffMin = 20, RollOffMax = 300 }
end

return {
	["the shipped audio config is valid; every ID in use is approved"] = function()
		local problems = AudioRules.validate(AudioConfig.Sounds, AudioConfig.ApprovedIds)
		Assert.equal(#problems, 0, table.concat(problems, "; "))
		for name in { Siren = true, Engine = true, Tyre = true, Alarm = true, Bank = true, Bust = true } do
			Assert.truthy(AudioConfig.Sounds[name], `{name} configured`)
		end
		for _, id in AudioConfig.ApprovedIds do
			Assert.truthy(AudioRules.isAssetId(id), `approved {id} is an asset id`)
		end
	end,
	["only an approved asset id plays; pending or unlisted ids never do"] = function()
		local approved = { "rbxassetid://123" }
		Assert.equal(AudioRules.playable(def("rbxassetid://123", true), approved), true)
		Assert.equal(AudioRules.playable(def("", true), approved), false, "pending")
		Assert.equal(AudioRules.playable(def("rbxassetid://456", true), approved), false, "not approved")
		Assert.equal(AudioRules.playable(def("http://evil/123", true), { "http://evil/123" }), false, "not an asset id")
		local problems = AudioRules.validate({ A = def("rbxassetid://456", true), B = def("abc", false) }, approved)
		Assert.equal(#problems, 2)
	end,
	["positional sounds fade from RollOffMin to silence at RollOffMax; 2D sounds don't"] = function()
		local props = AudioRules.soundProps(def("rbxassetid://123", true))
		Assert.equal(props.RollOffMode, Enum.RollOffMode.InverseTapered)
		Assert.equal(props.RollOffMinDistance, 20)
		Assert.equal(props.RollOffMaxDistance, 300)
		local flat = AudioRules.soundProps(def("rbxassetid://123", false))
		Assert.equal(flat.RollOffMode, nil)
		local bad = def("", true)
		bad.RollOffMin, bad.RollOffMax = 300, 20
		Assert.equal(#AudioRules.validate({ X = bad }, {}), 1, "min must be below max")
		for name, d in AudioConfig.Sounds do
			if d.Positional then
				Assert.truthy((d.RollOffMax :: number) <= 500, `{name} fades out within 500 studs`)
			end
		end
	end,
	["engine pitch rises with speed; tyres squeal only when sliding"] = function()
		Assert.near(AudioRules.enginePitch(0, 120, 0.8, 1.6), 0.8, 1e-9)
		Assert.near(AudioRules.enginePitch(60, 120, 0.8, 1.6), 1.2, 1e-9)
		Assert.near(AudioRules.enginePitch(-500, 120, 0.8, 1.6), 1.6, 1e-9, "reverse and overspeed clamp")
		Assert.near(AudioRules.enginePitch(0 / 0, 120, 0.8, 1.6), 0.8, 1e-9)
		Assert.equal(AudioRules.tyreLevel(5, 12, 30), 0)
		Assert.near(AudioRules.tyreLevel(-21, 12, 30), 0.5, 1e-9)
		Assert.equal(AudioRules.tyreLevel(99, 12, 30), 1)
		Assert.equal(AudioRules.tyreLevel(20, 30, 12), 0, "bad curve is silent")
	end,
}

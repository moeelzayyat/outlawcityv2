-- First session (S2.8): a player's first spree gets a dispatch head start; the nearest crime
-- site is marked with its status; spawn-to-crime and crime-to-safehouse distances stay short.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PoliceDispatchRules = require(ServerScriptService.Server.Police.PoliceDispatchRules)
local CityLayout = require(ServerScriptService.Server.World.CityLayout)
local SpreeConfig = require(ReplicatedStorage.Shared.Config.SpreeConfig)
local OnboardingRules = require(ReplicatedStorage.Shared.Onboarding.OnboardingRules)
local Assert = require(script.Parent.Assert)

local DELAY = SpreeConfig.FirstSpreeDispatchDelay

return {
	["a first spree holds dispatch for the delay; later sprees never do"] = function()
		Assert.equal(DELAY, 10)
		Assert.equal(PoliceDispatchRules.firstSpreeHeld(0, 0, DELAY), true)
		Assert.equal(PoliceDispatchRules.firstSpreeHeld(0, DELAY - 0.25, DELAY), true)
		Assert.equal(PoliceDispatchRules.firstSpreeHeld(0, DELAY, DELAY), false, "the delay runs out")
		Assert.equal(PoliceDispatchRules.firstSpreeHeld(nil, 3, DELAY), true, "unknown counts as new")
		Assert.equal(PoliceDispatchRules.firstSpreeHeld(1, 0, DELAY), false, "banked once: no protection")
		Assert.equal(PoliceDispatchRules.firstSpreeHeld(0, 0 / 0, DELAY), false, "bad time: no protection")
	end,
	["the nearest site wins on flat distance; empty lists give none"] = function()
		local points = { Vector3.new(0, 0, -122), Vector3.new(0, 50, 122), Vector3.new(122, 0, 0) }
		Assert.equal(OnboardingRules.nearestIndex(points, Vector3.new(0, 0, 100)), 2, "height ignored")
		Assert.equal(OnboardingRules.nearestIndex(points, Vector3.new(100, 0, 10)), 3)
		Assert.equal(OnboardingRules.nearestIndex({}, Vector3.zero), nil)
	end,
	["crime site markers say open, busy or when ready"] = function()
		Assert.equal(OnboardingRules.siteStatus(nil, false, 100, "Open: smash it"), "Open: smash it")
		Assert.equal(OnboardingRules.siteStatus(-math.huge, false, 100, "Open: smash it"), "Open: smash it")
		Assert.equal(OnboardingRules.siteStatus(190, false, 100, "x"), "Ready in 1:30")
		Assert.equal(OnboardingRules.siteStatus(190, true, 100, "x"), "Being robbed")
	end,
	["from the plaza spawn a crime is close and a safehouse is reachable"] = function()
		-- Walking speed 16 studs/s; the first-crime budget is 60 s including finding it.
		local spawnAt = Vector3.zero
		local nearestCrime = math.huge
		for _, site in CityLayout.crimeSites() do
			nearestCrime = math.min(nearestCrime, (site.Prompt.Position * Vector3.new(1, 0, 1) - spawnAt).Magnitude)
		end
		Assert.truthy(nearestCrime / 16 <= 15, `nearest crime {math.floor(nearestCrime)} studs from spawn`)
		local farthestBank = 0
		for _, site in CityLayout.crimeSites() do
			local best = math.huge
			for _, house in CityLayout.safehouses() do
				local centre = (house.Zone.Min + house.Zone.Max) / 2
				best = math.min(best, (Vector3.new(centre.X, 0, centre.Z) - Vector3.new(site.Prompt.Position.X, 0, site.Prompt.Position.Z)).Magnitude)
			end
			farthestBank = math.max(farthestBank, best)
		end
		-- Driving at the Coupe's cruise (~60 studs/s) any crime site is under 30 s from a safehouse.
		Assert.truthy(farthestBank / 60 <= 30, `farthest crime-to-safehouse {math.floor(farthestBank)} studs`)
	end,
}

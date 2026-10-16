-- Safehouses (S2.4): the two buildings sit clear of the city, their zones hold a player inside;
-- banking needs BankSeconds in a zone with no sight, pays once per spree id, and the stars then
-- fall to 0 over StarCooldownSeconds with no escape reward.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ReplicatedStorage.Shared
local CityLayout = require(ServerScriptService.Server.World.CityLayout)
local SafeZoneRules = require(Shared.Zones.SafeZoneRules)
local SpreeRules = require(Shared.Rules.SpreeRules)
local SpreeConfig = require(Shared.Config.SpreeConfig)
local SafehouseConfig = require(Shared.Config.SafehouseConfig)
local WantedRules = require(Shared.Wanted.WantedRules)
local WantedConfig = require(Shared.Config.WantedConfig)
local EconomyRules = require(Shared.Economy.EconomyRules)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Assert = require(script.Parent.Assert)

local DT = 0.25

type Box = { Min: Vector3, Max: Vector3, Name: string }

local function box(name: string, center: Vector3, size: Vector3): Box
	return { Min = center - size / 2, Max = center + size / 2, Name = name }
end

-- Footprints only (X and Z).
local function overlaps(a: Box, b: Box): boolean
	return a.Min.X < b.Max.X and a.Max.X > b.Min.X and a.Min.Z < b.Max.Z and a.Max.Z > b.Min.Z
end

local function spreeWithCash()
	local spree = SpreeRules.new(SpreeConfig)
	SpreeRules.addCrime(spree, "s1", 800, 1, 0, SpreeConfig)
	return spree
end

local INSIDE = { InSafehouse = true, Seen = false, Observed = false, Jailed = false }

-- Steps bank progress `steps` times with `facts`; returns the step that first came back true.
local function stepFor(spree, steps: number, facts): number?
	for i = 1, steps do
		if SpreeRules.stepBank(spree, DT, facts, SpreeConfig.BankSeconds) then
			return i
		end
	end
	return nil
end

return {
	["two safehouses with unique ids; each zone sits inside its walls under its marker"] = function()
		local houses = CityLayout.safehouses()
		Assert.equal(#houses, 2)
		Assert.truthy(houses[1].Id ~= houses[2].Id, "unique ids")
		for _, house in houses do
			Assert.equal(house.Zone.Name, house.Id)
			local back, header
			for _, part in house.Parts do
				if part.Name == `{house.Id}WallBack` then
					back = part
				elseif part.Name == `{house.Id}Header` then
					header = part
				end
			end
			Assert.truthy(back and header, `{house.Id} has a back wall and a header`)
			Assert.truthy(house.Zone.Min.X >= back.Center.X + back.Size.X / 2, `{house.Id} zone starts inside the back wall`)
			Assert.truthy(math.abs(house.Marker.X - header.Center.X) < 1, `{house.Id} marker over the opening`)
			Assert.truthy(house.Marker.Y > header.Center.Y, `{house.Id} marker above the roof line`)
			local clearance = header.Center.Y - header.Size.Y / 2
			Assert.truthy(clearance >= 10, `{house.Id} opening {clearance} studs tall fits a car`)
		end
	end,
	["safehouses clear buildings, roads, the store, the dealership, the jail, crime sites and parked cars"] = function()
		local solid: { Box } = {}
		for _, part in CityLayout.createBlueprint().Parts do
			if part.Group == "Buildings" or part.Group == "Roads" or part.Group == "Barriers" or part.Group == "Highway" then
				table.insert(solid, box(part.Name, part.Center, part.Size))
			end
		end
		for _, group in { CityLayout.store().Parts, CityLayout.dealership().Parts, CityLayout.jail().Parts } do
			for _, part in group do
				table.insert(solid, box(part.Name, part.Center, part.Size))
			end
		end
		for _, site in CityLayout.crimeSites() do
			for _, part in site.Parts do
				table.insert(solid, box(part.Name, part.Center, part.Size))
			end
		end
		for _, spot in CityLayout.parkedCars() do
			table.insert(solid, box(spot.Name, spot.CFrame.Position, Vector3.new(12, 5, 12)))
		end
		for _, house in CityLayout.safehouses() do
			for _, part in house.Parts do
				local b = box(part.Name, part.Center, part.Size)
				for _, other in solid do
					Assert.truthy(not overlaps(b, other), `{part.Name} overlaps {other.Name}`)
				end
			end
		end
	end,
	["a zone holds a player inside and lets them leave past the margin"] = function()
		local house = CityLayout.safehouses()[1]
		local zones = { house.Zone }
		local centre = (house.Zone.Min + house.Zone.Max) / 2
		local standing = Vector3.new(centre.X, 3, centre.Z)
		local inside, id = SafeZoneRules.update(false, zones, standing, SafehouseConfig.ExitMargin)
		Assert.equal(inside, true)
		Assert.equal(id, house.Id)
		local justOut = Vector3.new(house.Zone.Max.X + 1, 3, centre.Z)
		Assert.equal((SafeZoneRules.update(false, zones, justOut, SafehouseConfig.ExitMargin)), false, "entering needs the zone itself")
		Assert.equal((SafeZoneRules.update(true, zones, justOut, SafehouseConfig.ExitMargin)), true, "inside keeps the margin")
		local away = Vector3.new(house.Zone.Max.X + 10, 3, centre.Z)
		Assert.equal((SafeZoneRules.update(true, zones, away, SafehouseConfig.ExitMargin)), false)
	end,
	["banking needs BankSeconds in a zone with no sight; sight restarts it"] = function()
		local steps = math.floor(SpreeConfig.BankSeconds / DT + 0.5)
		local spree = spreeWithCash()
		Assert.equal(stepFor(spree, steps, INSIDE), steps, "ready on the last step")
		local seen = spreeWithCash()
		stepFor(seen, steps - 1, INSIDE)
		Assert.equal(SpreeRules.stepBank(seen, DT, { InSafehouse = true, Seen = true, Observed = false, Jailed = false }, SpreeConfig.BankSeconds), false)
		Assert.equal(seen.BankProgress, 0, "police sight restarts the count")
		Assert.equal(stepFor(seen, steps, INSIDE), steps, "a fresh full count is needed")
		local outside = spreeWithCash()
		Assert.equal(stepFor(outside, steps * 2, { InSafehouse = false, Seen = false, Observed = false, Jailed = false }), nil)
	end,
	["observed, jailed or empty-handed players never bank"] = function()
		local steps = math.floor(SpreeConfig.BankSeconds / DT + 0.5) * 2
		Assert.equal(stepFor(spreeWithCash(), steps, { InSafehouse = true, Seen = false, Observed = true, Jailed = false }), nil)
		Assert.equal(stepFor(spreeWithCash(), steps, { InSafehouse = true, Seen = false, Observed = false, Jailed = true }), nil)
		Assert.equal(stepFor(SpreeRules.new(SpreeConfig), steps, INSIDE), nil, "no spree, nothing to bank")
	end,
	["a spree banks once and a repeated claim of its id is refused"] = function()
		local spree = spreeWithCash()
		local result = SpreeRules.bank(spree, 30, SpreeConfig)
		Assert.truthy(result, "first bank")
		Assert.equal(SpreeRules.bank(spree, 31, SpreeConfig), nil, "the spree ended with the bank")
		local profile = EconomyRules.newProfile(EconomyConfig)
		local tx = `spree:{(result :: any).SpreeId}`
		Assert.equal((EconomyRules.bankSpree(profile, (result :: any).Amount, (result :: any).Reputation, tx, EconomyConfig)), true)
		local ok, err = EconomyRules.bankSpree(profile, (result :: any).Amount, (result :: any).Reputation, tx, EconomyConfig)
		Assert.equal(ok, false)
		Assert.equal(err, "DuplicateTransaction")
		Assert.equal(profile.Cash, EconomyConfig.StartingCash + 800, "paid exactly once")
	end,
	["after a bank, stars fall to 0 over the cool-down even in sight, with no escape"] = function()
		local state = WantedRules.new()
		WantedRules.applyCrime(state, "StoreRobbery", 0, WantedConfig)
		Assert.equal(state.Stars, 2)
		Assert.equal(WantedRules.coolDown(state, SafehouseConfig.StarCooldownSeconds), true)
		local now, escaped = 0, false
		local steps = math.floor(SafehouseConfig.StarCooldownSeconds / DT + 0.5)
		for i = 1, steps + 1 do
			now += DT
			local result = WantedRules.step(state, now, DT, true, WantedConfig)
			escaped = escaped or result.Escaped
			if i == steps // 2 then
				Assert.near(state.Heat, 35, 0.01, "half the heat gone halfway")
			end
		end
		Assert.equal(state.Heat, 0)
		Assert.equal(state.Stars, 0)
		Assert.equal(state.CoolDownRate, nil)
		Assert.equal(escaped, false, "banking is not an escape")
	end,
	["a crime during the cool-down cancels it; bad cool-downs are refused"] = function()
		local state = WantedRules.new()
		Assert.equal(WantedRules.coolDown(state, 10), false, "no heat, nothing to cool")
		WantedRules.applyCrime(state, "StoreRobbery", 0, WantedConfig)
		Assert.equal(WantedRules.coolDown(state, 0 / 0), false)
		Assert.equal(WantedRules.coolDown(state, 0), false)
		WantedRules.coolDown(state, 10)
		WantedRules.step(state, 1, 1, true, WantedConfig)
		WantedRules.applyCrime(state, "AtmSmash", 1, WantedConfig)
		Assert.equal(state.CoolDownRate, nil)
		local heat = state.Heat
		WantedRules.step(state, 2, 1, true, WantedConfig)
		Assert.equal(state.Heat, heat, "in sight again: no decay")
	end,
}

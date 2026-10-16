-- CrimeConfig + CrimeRules (S2.3): the catalogue is valid and matches STATS.md; every holdout
-- crime runs the RobberyRules engine (start / validate / complete / fail); alarm rolls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrimeConfig = require(ReplicatedStorage.Shared.Config.CrimeConfig)
local CrimeRules = require(ReplicatedStorage.Shared.Rules.CrimeRules)
local RobberyRules = require(ReplicatedStorage.Shared.Robbery.RobberyRules)
local WantedConfig = require(ReplicatedStorage.Shared.Config.WantedConfig)
local WantedRules = require(ReplicatedStorage.Shared.Wanted.WantedRules)
local Assert = require(script.Parent.Assert)

local C = CrimeConfig.Crimes
local FACTS = { Alive = true, Jailed = false, InSafeZone = false, InVehicle = false, DistanceToRegister = 2, HasActiveSession = false, CashReady = true }
local OK_TICK = { Connected = true, Alive = true, Jailed = false, InArea = true }

local function starsFor(crime: string): number
	return WantedRules.starsForHeat(WantedConfig.Crimes[crime].Heat, WantedConfig)
end

return {
	["the catalogue is valid"] = function()
		local problems = CrimeRules.validate(C, WantedConfig.Crimes)
		Assert.equal(#problems, 0, table.concat(problems, "; "))
	end,
	["bad definitions are caught"] = function()
		local bad = {
			Broken = { Name = "", Holdout = true, HoldSeconds = 0, Reward = -1, WantedCrime = "Nope", InProgressCrime = "Nope", AlarmChance = 2, CooldownSeconds = 0, PromptDistance = 0, DistanceSlack = -1 },
		}
		local problems = CrimeRules.validate(bad, WantedConfig.Crimes)
		Assert.truthy(#problems >= 7, `found {#problems}: {table.concat(problems, "; ")}`)
	end,
	["numbers match the design table"] = function()
		Assert.equal(C.StoreRobbery.HoldSeconds, 15)
		Assert.equal(C.StoreRobbery.Reward, 2000)
		Assert.equal(C.StoreRobbery.CooldownSeconds, 120)
		Assert.equal(starsFor(C.StoreRobbery.WantedCrime), 2)
		Assert.equal(C.AtmSmash.HoldSeconds, 6)
		Assert.equal(C.AtmSmash.Reward, 800)
		Assert.equal(C.AtmSmash.AlarmChance, 0.5)
		Assert.equal(starsFor(C.AtmSmash.WantedCrime), 1)
		Assert.equal(C.GasStation.HoldSeconds, 12)
		Assert.equal(C.GasStation.Reward, 1500)
		Assert.equal(starsFor(C.GasStation.WantedCrime), 2)
		Assert.equal(C.CarTheft.Reward, 500)
		Assert.equal(C.CarTheft.AlarmChance, 0.3)
		Assert.equal(starsFor(C.CarTheft.WantedCrime), 1)
	end,
	["each holdout crime starts, completes after its hold, and cools down"] = function()
		for id, crime in C do
			if not crime.Holdout then
				continue
			end
			local site = RobberyRules.newStore()
			Assert.equal((RobberyRules.canStart(site, FACTS, 100, crime)), true, id)
			local session = RobberyRules.start(site, "s", 1, id, 100, crime)
			Assert.equal(session.Reward, crime.Reward, id)
			Assert.equal((RobberyRules.tick(session, site, OK_TICK, 100 + crime.HoldSeconds - 0.1, crime)), nil, id .. " still holding")
			Assert.equal((RobberyRules.tick(session, site, OK_TICK, 100 + crime.HoldSeconds, crime)), "HoldComplete", id)
			local ok, err = RobberyRules.canStart(site, FACTS, 101 + crime.HoldSeconds, crime)
			Assert.equal(ok, false, id)
			Assert.equal(err, "StoreCooldown", id)
			Assert.equal((RobberyRules.canStart(site, FACTS, 100 + crime.CooldownSeconds, crime)), true, id .. " reopens")
		end
	end,
	["each holdout crime fails when the player leaves its area or is too far to start"] = function()
		for id, crime in C do
			if not crime.Holdout then
				continue
			end
			local site = RobberyRules.newStore()
			local far = table.clone(FACTS)
			far.DistanceToRegister = crime.PromptDistance + crime.DistanceSlack + 1
			local ok, err = RobberyRules.canStart(site, far, 0, crime)
			Assert.equal(ok, false, id)
			Assert.equal(err, "TooFar", id)
			local session = RobberyRules.start(site, "s", 1, id, 0, crime)
			local out = table.clone(OK_TICK)
			out.InArea = false
			local event, reason = RobberyRules.tick(session, site, out, 1, crime)
			Assert.equal(event, "Failed", id)
			Assert.equal(reason, "LeftArea", id)
			Assert.truthy(site.CooldownUntil <= (crime.FailedCooldownSeconds or crime.CooldownSeconds), id .. " shorter cooldown after a failure")
		end
	end,
	["the alarm trips below its chance"] = function()
		Assert.equal(CrimeRules.alarmTrips(1, 0.999), true)
		Assert.equal(CrimeRules.alarmTrips(0.5, 0.49), true)
		Assert.equal(CrimeRules.alarmTrips(0.5, 0.5), false)
		Assert.equal(CrimeRules.alarmTrips(0, 0), false)
	end,
}

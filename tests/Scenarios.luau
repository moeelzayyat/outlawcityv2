--!strict
-- Studio-only multi-client scenarios (D-007). The command bar or a plugin calls
-- StudioTestService:ExecuteMultiplayerTestAsync(n, "<name>"); Main runs Scenarios.run(name) on
-- the test server, which drives the live services, prints its evidence and ends the session
-- with EndTest("PASS …" | "FAIL …" | "ERROR …"), the value ExecuteMultiplayerTestAsync returns.
-- Not a *.spec, so the unit runner skips it; it only runs inside a Studio test session.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")

local Services = ServerScriptService.Server.Services

local Scenarios = {}

local function log(text: string)
	print(`[Scenario] {text}`)
end

local function waitForPlayers(count: number, timeout: number): { Player }
	local started = os.clock()
	while os.clock() - started < timeout do
		local ready = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				table.insert(ready, player)
			end
		end
		if #ready >= count then
			table.sort(ready, function(a, b)
				return a.UserId < b.UserId
			end)
			return ready
		end
		task.wait(0.5)
	end
	return Players:GetPlayers()
end

local function place(player: Player, position: Vector3)
	local CharacterValidationService = require(Services.CharacterValidationService) :: any
	CharacterValidationService.authorizeMove(player)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position))
	end
end

local function heatOf(player: Player): number
	return tonumber(player:GetAttribute("WantedHeat")) or 0
end

local registry: { [string]: () -> (boolean, string) } = {}

-- R1.6: A becomes wanted and gets the unit; B robs while the only unit is on A. B's heat must
-- not decay while no unit is assigned to B, and the unit must re-target to B once A is done.
registry["R1.6-Dispatch"] = function()
	local WantedService = require(Services.WantedService) :: any
	local PoliceService = require(Services.PoliceService) :: any
	local players = waitForPlayers(2, 60)
	if #players < 2 then
		return false, `only {#players} player(s) joined`
	end
	local a, b = players[1], players[2]
	-- Road intersections far apart; A shuttles between two of them so the unit chases but can't
	-- bust A early (which would cut B's unassigned window short).
	local aSpots = { Vector3.new(100, 4, 300), Vector3.new(300, 4, 300) }
	place(a, aSpots[1])
	place(b, Vector3.new(-300, 4, -300))
	task.wait(2)
	WantedService.reportCrime(a, "RammingPolice")
	task.wait(2.1)
	WantedService.reportCrime(a, "RammingPolice")
	local waited = 0
	while PoliceService.getTarget() ~= a and waited < 15 do
		task.wait(0.25)
		waited += 0.25
	end
	if PoliceService.getTarget() ~= a then
		return false, "the unit was never assigned to A"
	end
	log(`unit assigned to A ({a.Name}) after {waited} s; A stars {WantedService.getStars(a)}`)
	WantedService.reportCrime(b, "StoreRobbery")
	local startHeat = heatOf(b)
	local minHeat = startHeat
	local unassignedSeconds = 0
	local retargetAfter: number? = nil
	for i = 1, 240 do -- up to 60 s
		task.wait(0.25)
		if i % 12 == 0 and i <= 48 then -- shuttle for 12 s, then A stands still and is busted or escapes
			place(a, aSpots[(i // 12) % 2 + 1])
		end
		if PoliceService.getTarget() == b then
			retargetAfter = i * 0.25
			break
		end
		unassignedSeconds = i * 0.25
		minHeat = math.min(minHeat, heatOf(b))
	end
	log(string.format("B (%s) heat %.1f at the crime; lowest while unassigned %.1f over %.1f s; re-targeted after %s s", b.Name, startHeat, minHeat, unassignedSeconds, tostring(retargetAfter)))
	if minHeat < startHeat then
		return false, string.format("B's heat decayed while unassigned (%.1f -> %.1f)", startHeat, minHeat)
	end
	if not retargetAfter then
		return false, string.format("the unit never re-targeted to B (B unassigned %.1f s, heat held at %.1f)", unassignedSeconds, minHeat)
	end
	if unassignedSeconds < 8 then
		return false, string.format("B was unassigned only %.1f s, shorter than the 8 s decay delay: decay freeze not exercised", unassignedSeconds)
	end
	return true, string.format("B heat held at %.1f for %.1f s while the unit chased A; unit re-targeted to B after %.1f s", startHeat, unassignedSeconds, retargetAfter :: number)
end

-- S2.3: one player runs each new crime through the live services. ATM1 completes, ATM2 fails by
-- leaving its area (no cash), Gas1 completes, Parked3 is stolen. Each completion must add to the
-- spree; the failure must not. Wanted is reset between crimes so the unit can't bust mid-run.
registry["S2.3-Crimes"] = function()
	local WantedService = require(Services.WantedService) :: any
	local CrimeService = require(Services.CrimeService) :: any
	local ParkedCarService = require(Services.ParkedCarService) :: any
	local SpreeService = require(Services.SpreeService) :: any
	local VehicleService = require(Services.VehicleService) :: any
	local CityLayout = require(ServerScriptService.Server.World.CityLayout) :: any
	local p = waitForPlayers(1, 60)[1]
	if not p then
		return false, "no player joined"
	end
	local siteIds = table.concat(CrimeService.getSiteIds(), ",")
	local spotIds = table.concat(ParkedCarService.getSpotIds(), ",")
	log(`sites {siteIds}; parked spots {spotIds}`)
	if siteIds ~= "ATM1,ATM2,ATM3,ATM4,Gas1,Store1" then
		return false, `unexpected sites {siteIds}`
	end
	local areas = {}
	for _, site in CityLayout.crimeSites() do
		areas[site.Id] = site.Area.Center
	end
	local function spree(): (number, number)
		local s = SpreeService.get(p)
		return if s then s.Crimes else 0, if s then s.Unbanked else 0
	end
	local function holdout(siteId: string, holdSeconds: number, leaveAt: Vector3?): (boolean, string)
		CrimeService.clearCooldownsForTesting()
		WantedService.resetWanted(p)
		place(p, areas[siteId])
		task.wait(1.5)
		local ok, err = CrimeService.tryStart(p, siteId)
		if not ok then
			return false, `{siteId} refused: {err}`
		end
		local stars = WantedService.getStars(p)
		if leaveAt then
			task.wait(1)
			place(p, leaveAt)
		end
		local waited = 0
		while CrimeService.isBusy(p) and waited < holdSeconds + 5 do
			task.wait(0.25)
			waited += 0.25
		end
		return true, `{siteId} ended after {waited} s (stars at start {stars})`
	end

	local c0, u0 = spree()
	local ok, detail = holdout("ATM1", 6)
	if not ok then
		return false, detail
	end
	local c1, u1 = spree()
	log(`{detail}; spree {c0}->{c1} crimes, unbanked {u0}->{u1}`)
	if c1 ~= c0 + 1 or u1 <= u0 then
		return false, "ATM1 completion did not reach the spree"
	end

	ok, detail = holdout("ATM2", 6, Vector3.new(0, 4, 90))
	if not ok then
		return false, detail
	end
	local c2, u2 = spree()
	log(`{detail}; spree {c1}->{c2} crimes, unbanked {u1}->{u2}`)
	if c2 ~= c1 or u2 ~= u1 then
		return false, "a failed ATM smash changed the spree"
	end

	ok, detail = holdout("Gas1", 12)
	if not ok then
		return false, detail
	end
	local c3, u3 = spree()
	log(`{detail}; spree {c2}->{c3} crimes, unbanked {u2}->{u3}`)
	if c3 ~= c2 + 1 or u3 <= u2 then
		return false, "the gas station completion did not reach the spree"
	end

	WantedService.resetWanted(p)
	local spot
	for _, s in CityLayout.parkedCars() do
		if s.Name == "Parked3" then
			spot = s
		end
	end
	place(p, spot.CFrame.Position + Vector3.new(0, 4, 0) + spot.CFrame.RightVector * 5)
	task.wait(1.5)
	local stole, stealErr = ParkedCarService.trySteal(p, "Parked3")
	if not stole then
		return false, `Parked3 refused: {stealErr}`
	end
	local c4, u4 = spree()
	local car = VehicleService.getVehicleOf(p)
	local owned = car ~= nil and car:GetAttribute("OwnerUserId") == p.UserId
	log(`Parked3 stolen (stars {WantedService.getStars(p)}); spree {c3}->{c4} crimes, unbanked {u3}->{u4}; getaway car owned {owned}`)
	if c4 ~= c3 + 1 or u4 <= u3 or not owned then
		return false, "car theft did not reach the spree or the car"
	end
	local again = ParkedCarService.trySteal(p, "Parked3")
	if again then
		return false, "the same spot was stolen twice"
	end
	WantedService.resetWanted(p)
	return true, `3 crimes completed (spree {c4} crimes, {u4} unbanked), failed ATM paid nothing, empty spot refused`
end

function Scenarios.run(name: string)
	local scenario = registry[name]
	if not scenario then
		return
	end
	log(`{name}: started with {#Players:GetPlayers()} player(s)`)
	local ok, passed, detail = pcall(scenario)
	local verdict = if not ok then `ERROR {passed}` elseif passed then `PASS {detail}` else `FAIL {detail}`
	log(`{name}: {verdict}`)
	StudioTestService:EndTest(verdict)
end

return Scenarios

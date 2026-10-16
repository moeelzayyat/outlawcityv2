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

-- R1.6 (updated for the S2.5 unit pool, D-002): A becomes wanted and gets units; then B robs.
-- B's heat must not decay before B has a unit, and B gets its own unit while A keeps theirs
-- (no more waiting for A's pursuit to end).
registry["R1.6-Dispatch"] = function()
	local WantedService = require(Services.WantedService) :: any
	local PoliceService = require(Services.PoliceService) :: any
	local players = waitForPlayers(2, 60)
	if #players < 2 then
		return false, `only {#players} player(s) joined`
	end
	local a, b = players[1], players[2]
	-- A shuttles between two intersections so the units chase but can't bust A.
	local aSpots = { Vector3.new(100, 4, 300), Vector3.new(300, 4, 300) }
	place(a, aSpots[1])
	place(b, Vector3.new(-300, 4, -300))
	task.wait(2)
	WantedService.reportCrime(a, "RammingPolice")
	task.wait(2.1)
	WantedService.reportCrime(a, "RammingPolice")
	local waited = 0
	while PoliceService.unitsOn(a) == 0 and waited < 15 do
		task.wait(0.25)
		waited += 0.25
	end
	if PoliceService.unitsOn(a) == 0 then
		return false, "no unit was ever assigned to A"
	end
	log(`A ({a.Name}) has {PoliceService.unitsOn(a)} unit(s) after {waited} s; A stars {WantedService.getStars(a)}`)
	WantedService.reportCrime(b, "StoreRobbery")
	local startHeat = heatOf(b)
	local minHeat = startHeat
	local assignedAfter: number? = nil
	for i = 1, 40 do -- up to 10 s
		task.wait(0.25)
		if i % 8 == 0 then
			place(a, aSpots[(i // 8) % 2 + 1])
		end
		minHeat = math.min(minHeat, heatOf(b))
		if PoliceService.unitsOn(b) > 0 then
			assignedAfter = i * 0.25
			break
		end
	end
	local aUnits = PoliceService.unitsOn(a)
	log(string.format("B (%s) heat %.1f at the crime, lowest %.1f before assignment; B assigned after %s s; A still has %d unit(s)", b.Name, startHeat, minHeat, tostring(assignedAfter), aUnits))
	if minHeat < startHeat then
		return false, string.format("B's heat decayed before B had a unit (%.1f -> %.1f)", startHeat, minHeat)
	end
	if not assignedAfter or assignedAfter > 2 then
		return false, `B was not given a unit within 2 s (after {tostring(assignedAfter)} s)`
	end
	if aUnits == 0 then
		return false, "A lost its units when B became wanted"
	end
	WantedService.resetWanted(a)
	WantedService.resetWanted(b)
	return true, string.format("B heat held at %.1f; B got its own unit after %.2f s while A kept %d", startHeat, assignedAfter :: number, aUnits)
end

-- S2.5: three players at 3, 2 and 1 stars get 3, 2 and 1 units (the server cap of 6) and a
-- roadblock goes up ahead of the 3-star player. When A is cleared and C rises to 3 stars, A's
-- recalled units are re-targeted to C without ever exceeding the cap. Players shuttle between two
-- spots every 2 s (no unit can finish a bust) and their heat is re-set so stars hold. Records the
-- police budget: raycasts per physics frame and step time for all units.
registry["S2.5-Escalation"] = function()
	local WantedService = require(Services.WantedService) :: any
	local PoliceService = require(Services.PoliceService) :: any
	local players = waitForPlayers(3, 90)
	if #players < 3 then
		return false, `only {#players} player(s) joined`
	end
	local a, b, c = players[1], players[2], players[3]
	local spots = {
		[a] = { Vector3.new(300, 4, 200), Vector3.new(300, 4, 140) }, -- facing -Z on D Ave: the roadblock goes ahead
		[b] = { Vector3.new(-300, 4, 200), Vector3.new(-300, 4, 140) },
		[c] = { Vector3.new(-200, 4, -300), Vector3.new(-140, 4, -300) },
	}
	local heat = { [a] = 120, [b] = 60, [c] = 20 }
	local maxTotal = 0
	local function hold(seconds: number)
		for i = 1, seconds * 4 do
			if i % 8 == 1 then
				for player, pair in spots do
					place(player, pair[(i // 8) % 2 + 1])
					if heat[player] > 0 then
						WantedService.setHeatForTesting(player, heat[player])
					end
				end
			end
			maxTotal = math.max(maxTotal, PoliceService.getBudget().Units)
			task.wait(0.25)
		end
	end
	PoliceService.resetBudget()
	hold(12)
	local ua, ub, uc = PoliceService.unitsOn(a), PoliceService.unitsOn(b), PoliceService.unitsOn(c)
	local blockA = PoliceService.hasRoadblock(a)
	log(`phase 1: stars {WantedService.getStars(a)}/{WantedService.getStars(b)}/{WantedService.getStars(c)} -> units {ua}/{ub}/{uc}; roadblock for A {blockA}; max units on the server {maxTotal}`)
	if ua ~= 3 or ub ~= 2 or uc ~= 1 then
		return false, `units by stars wrong: {ua}/{ub}/{uc}`
	end
	if not blockA then
		return false, "no roadblock for the 3-star player"
	end
	heat[a] = 0
	WantedService.resetWanted(a)
	heat[c] = 120
	hold(6)
	ua, ub, uc = PoliceService.unitsOn(a), PoliceService.unitsOn(b), PoliceService.unitsOn(c)
	local budget = PoliceService.getBudget()
	log(string.format("phase 2: A cleared, C at 3 stars -> units %d/%d/%d; roadblock A %s, C %s; max units %d", ua, ub, uc, tostring(PoliceService.hasRoadblock(a)), tostring(PoliceService.hasRoadblock(c)), maxTotal))
	log(string.format("budget: frames %d, avg %.3f ms, max %.3f ms per frame, max %d raycasts per frame, max units %d", budget.Frames, budget.AvgFrameMs, budget.MaxFrameMs, budget.MaxRaysPerFrame, budget.MaxUnits))
	for player in spots do
		WantedService.resetWanted(player)
	end
	if ua ~= 0 or ub ~= 2 or uc ~= 3 then
		return false, `re-assignment wrong: {ua}/{ub}/{uc}`
	end
	if maxTotal > 6 or budget.MaxUnits > 6 then
		return false, `server cap exceeded ({math.max(maxTotal, budget.MaxUnits)} units)`
	end
	if PoliceService.hasRoadblock(a) then
		return false, "A's roadblock stayed after A was cleared"
	end
	if budget.MaxRaysPerFrame > 50 or budget.AvgFrameMs > 2 then
		return false, string.format("budget missed: %d raycasts/frame, %.3f ms avg", budget.MaxRaysPerFrame, budget.AvgFrameMs)
	end
	return true, string.format("3/2/1 units + roadblock at 3 stars; A's units re-targeted to C (0/2/3), never above 6; %d raycasts/frame max, %.3f ms avg, %.3f ms max per frame", budget.MaxRaysPerFrame, budget.AvgFrameMs, budget.MaxFrameMs)
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

-- S2.4: one player banks at each safehouse. Garage: an ATM spree banks after BankSeconds inside.
-- Warehouse: with 1 star and police sight on, banking is blocked; once sight drops it banks, the
-- stars fall to 0 over the cool-down with no escape, and a repeated claim is refused. Dispatch is
-- held so the unit can't interfere.
registry["S2.4-Safehouses"] = function()
	local WantedService = require(Services.WantedService) :: any
	local CrimeService = require(Services.CrimeService) :: any
	local SpreeService = require(Services.SpreeService) :: any
	local PoliceService = require(Services.PoliceService) :: any
	local EconomyService = require(Services.EconomyService) :: any
	local CityLayout = require(ServerScriptService.Server.World.CityLayout) :: any
	local EventBus = require(game:GetService("ReplicatedStorage").Shared.Util.EventBus) :: any
	local p = waitForPlayers(1, 60)[1]
	if not p then
		return false, "no player joined"
	end
	PoliceService.setDispatchHold(p, true)
	local escapes = 0
	EventBus.subscribe("Escaped", function(payload)
		if payload.UserId == p.UserId then
			escapes += 1
		end
	end)
	local areas, houses = {}, {}
	for _, site in CityLayout.crimeSites() do
		areas[site.Id] = site.Area.Center
	end
	for _, house in CityLayout.safehouses() do
		houses[house.Id] = Vector3.new((house.Zone.Min.X + house.Zone.Max.X) / 2, 4, (house.Zone.Min.Z + house.Zone.Max.Z) / 2)
	end
	local function cash(): number
		return tonumber(p:GetAttribute("Cash")) or 0
	end
	local function smash(siteId: string): (boolean, string)
		CrimeService.clearCooldownsForTesting()
		place(p, areas[siteId])
		task.wait(1.5)
		local ok, err = CrimeService.tryStart(p, siteId)
		if not ok then
			return false, `{siteId} refused: {err}`
		end
		local waited = 0
		while CrimeService.isBusy(p) and waited < 12 do
			task.wait(0.25)
			waited += 0.25
		end
		local spree = SpreeService.get(p)
		if not (spree and spree.Active) then
			return false, `{siteId} did not start a spree`
		end
		WantedService.resetWanted(p)
		PoliceService.setDispatchHold(p, true) -- an alarmed holdout releases its own hold at the end
		return true, ""
	end
	-- Waits until the spree is banked; returns the seconds waited (or nil on timeout).
	local function waitBanked(timeout: number): number?
		local waited = 0
		while waited < timeout do
			local spree = SpreeService.get(p)
			if not (spree and spree.Active) then
				return waited
			end
			task.wait(0.25)
			waited += 0.25
		end
		return nil
	end

	-- Garage
	local ok, err = smash("ATM1")
	if not ok then
		return false, err
	end
	local unbanked = SpreeService.get(p).Unbanked
	local before = cash()
	place(p, houses.Garage)
	local took = waitBanked(15)
	task.wait(1) -- the save completes
	log(`Garage: banked {unbanked} after {took} s inside; cash {before} -> {cash()}; InSafehouse={p:GetAttribute("InSafehouse")}`)
	if not took or took < 4.5 or cash() ~= before + unbanked then
		return false, `garage bank wrong (took {took}, cash {before} -> {cash()}, expected +{unbanked})`
	end
	local garageTook = took :: number

	-- Warehouse with stars and sight
	ok, err = smash("ATM2")
	if not ok then
		return false, err
	end
	local spreeId = SpreeService.get(p).Id
	unbanked = SpreeService.get(p).Unbanked
	before = cash()
	WantedService.reportCrime(p, "AtmSmash")
	WantedService.setPoliceSightForTesting(p, true)
	place(p, houses.Warehouse)
	task.wait(4)
	local blocked, progress = p:GetAttribute("BankBlocked"), p:GetAttribute("BankProgress")
	local stillActive = SpreeService.get(p).Active
	log(`Warehouse in sight: BankBlocked={blocked} BankProgress={progress} spree active={stillActive}`)
	if blocked ~= "Seen" or progress ~= 0 or not stillActive then
		return false, "banking was not blocked by police sight"
	end
	WantedService.setPoliceSightForTesting(p, false)
	took = waitBanked(15)
	local bankedAt = os.clock()
	local starsAtBank = WantedService.getStars(p)
	local zeroAfter: number? = nil
	while os.clock() - bankedAt < 14 do
		if WantedService.getStars(p) == 0 and tonumber(p:GetAttribute("WantedHeat")) == 0 then
			zeroAfter = os.clock() - bankedAt
			break
		end
		task.wait(0.25)
	end
	log(string.format("Warehouse: banked %d after %s s without sight; cash %d -> %d; stars %d at bank, 0 after %s s; escapes %d", unbanked, tostring(took), before, cash(), starsAtBank, tostring(zeroAfter), escapes))
	if not took or cash() ~= before + unbanked then
		return false, "warehouse bank wrong"
	end
	-- zeroAfter counts from the spree ending, so it includes the bank save before the cool-down starts.
	if starsAtBank < 1 or not zeroAfter or zeroAfter > 12 or escapes ~= 0 then
		return false, string.format("stars did not cool down to 0 without an escape (stars at bank %d, 0 after %s s, escapes %d)", starsAtBank, tostring(zeroAfter), escapes)
	end
	local again, againErr = SpreeService.bank(p)
	local dupPaid, dupErr = EconomyService.bankSpree(p, spreeId, unbanked, 0)
	log(`repeat: SpreeService.bank -> {again} {againErr}; bankSpree same id -> {dupPaid} {dupErr}; cash {cash()}`)
	if again or dupPaid or dupErr ~= "DuplicateTransaction" or cash() ~= before + unbanked then
		return false, "a repeated claim was not refused"
	end
	PoliceService.setDispatchHold(p, false)
	return true, string.format("garage banked after %.2f s, warehouse blocked in sight then banked after %.2f s, stars 0 after %.2f s, 0 escapes, repeat claims refused", garageTook, took :: number, zeroAfter :: number)
end

-- S2.8: a player with no banked spree who becomes wanted gets no unit for the first-spree delay;
-- the same player with one banked spree gets units at once. The profile's spree count is set in
-- memory for the test and put back afterwards.
registry["S2.8-FirstSpree"] = function()
	local WantedService = require(Services.WantedService) :: any
	local PoliceService = require(Services.PoliceService) :: any
	local EconomyService = require(Services.EconomyService) :: any
	local p = waitForPlayers(1, 60)[1]
	if not p then
		return false, "no player joined"
	end
	local function timeToUnit(limit: number): number?
		local started = os.clock()
		while os.clock() - started < limit do
			if PoliceService.unitsOn(p) > 0 then
				return os.clock() - started
			end
			task.wait(0.1)
		end
		return nil
	end
	local original = EconomyService.setSpreesForTesting(p, 0)
	if original == nil then
		return false, "profile not loaded"
	end
	place(p, Vector3.new(-300, 4, -300))
	task.wait(1)
	WantedService.reportCrime(p, "StoreRobbery")
	local first = timeToUnit(15)
	WantedService.resetWanted(p)
	task.wait(4) -- units recalled and despawned
	EconomyService.setSpreesForTesting(p, 1)
	WantedService.reportCrime(p, "StoreRobbery")
	local later = timeToUnit(5)
	WantedService.resetWanted(p)
	EconomyService.setSpreesForTesting(p, original)
	log(string.format("first spree: first unit after %s s; with a banked spree: after %s s (profile sprees put back to %d)", tostring(first), tostring(later), original))
	if not first or first < 9.5 or first > 11 then
		return false, `first-spree dispatch came after {tostring(first)} s, expected about 10`
	end
	if not later or later > 1 then
		return false, `dispatch after a banked spree took {tostring(later)} s`
	end
	return true, string.format("first spree: unit after %.1f s (delay 10 s); later spree: unit after %.1f s", first, later)
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

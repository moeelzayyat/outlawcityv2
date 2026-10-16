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

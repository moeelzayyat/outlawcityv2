--!strict
-- Error isolation for service loops (architecture §9, audit F7). Every iteration runs in pcall,
-- so one throw can never end a loop for the server's lifetime. The first failure of a streak (or
-- a new message) is reported once; repeats are only counted; while failing the loop backs off
-- BackoffSeconds. step() is the testable core; run() owns the thread.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local LoopGuard = {}

LoopGuard.BackoffSeconds = 1

export type Reporter = (name: string, message: string) -> ()

export type Guard = {
	Name: string,
	Iterations: number,
	Failures: number,
	Reported: number,
	Streak: number,
	LastError: string?,
	Faults: number,
	Announce: boolean,
	Reporter: Reporter,
}

local function defaultReporter(name: string, message: string)
	warn(`[Loop] {name} iteration failed: {message}`)
end

-- Replaceable sink for every guard without its own reporter (AnalyticsService hooks in at R1.7).
LoopGuard.report = defaultReporter :: Reporter

local guards: { [string]: Guard } = {}

function LoopGuard.new(name: string, reporter: Reporter?): Guard
	return {
		Name = name,
		Iterations = 0,
		Failures = 0,
		Reported = 0,
		Streak = 0,
		LastError = nil,
		Faults = 0,
		Announce = reporter == nil,
		Reporter = reporter or function(n: string, m: string)
			LoopGuard.report(n, m)
		end,
	}
end

-- Runs one iteration. Returns whether it succeeded and how long the caller should back off.
function LoopGuard.step(guard: Guard, fn: (...any) -> (), ...: any): (boolean, number)
	guard.Iterations += 1
	local ok, err
	if guard.Faults > 0 then
		guard.Faults -= 1
		ok, err = false, "injected fault"
	else
		ok, err = pcall(fn, ...)
	end
	if ok then
		if guard.Streak > 0 and guard.Announce then
			print(`[Loop] {guard.Name} recovered after {guard.Streak} failed iteration(s)`)
		end
		guard.Streak = 0
		guard.LastError = nil
		return true, 0
	end
	local message = tostring(err)
	guard.Failures += 1
	guard.Streak += 1
	if guard.Streak == 1 or message ~= guard.LastError then
		guard.Reported += 1
		guard.Reporter(guard.Name, message)
	end
	guard.LastError = message
	return false, if guard.Streak >= 2 then LoopGuard.BackoffSeconds else 0
end

local control: BindableFunction? = nil

-- Studio-only bridge for the command bar, which has its own require cache. Server-side only;
-- never created outside Studio.
local function ensureControl()
	if control or not RunService:IsStudio() then
		return
	end
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "LoopGuardControl"
	bindable.OnInvoke = function(command: string, name: string?, count: number?): any
		if command == "inject" and name then
			return LoopGuard.injectFaultsForTesting(name, count or 1)
		elseif command == "stats" then
			local stats = {}
			for guardName, guard in guards do
				stats[guardName] = {
					Iterations = guard.Iterations,
					Failures = guard.Failures,
					Reported = guard.Reported,
					Streak = guard.Streak,
					Faults = guard.Faults,
				}
			end
			return stats
		end
		return nil
	end
	bindable.Parent = ServerStorage
	control = bindable
end

-- Spawns `while true do wait(interval); fn(dt) end` with every iteration isolated.
function LoopGuard.run(name: string, interval: number, fn: (dt: number) -> ()): Guard
	local guard = LoopGuard.new(name)
	guards[name] = guard
	ensureControl()
	task.spawn(function()
		while true do
			local dt = task.wait(interval)
			local _, backoff = LoopGuard.step(guard, fn, dt)
			if backoff > 0 then
				task.wait(backoff)
			end
		end
	end)
	return guard
end

function LoopGuard.get(name: string): Guard?
	return guards[name]
end

-- Studio-only: make the next `count` iterations of a running loop fail (play-test evidence).
function LoopGuard.injectFaultsForTesting(name: string, count: number): boolean
	local guard = guards[name]
	if not RunService:IsStudio() or not guard then
		return false
	end
	guard.Faults = math.max(0, math.floor(count))
	return true
end

return LoopGuard

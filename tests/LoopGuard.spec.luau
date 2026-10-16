local ServerScriptService = game:GetService("ServerScriptService")
local LoopGuard = require(ServerScriptService.Server.Util.LoopGuard)
local Assert = require(script.Parent.Assert)

local function recorder()
	local reports = {}
	return reports, function(name: string, message: string)
		table.insert(reports, { name, message })
	end
end

return {
	["a passing iteration needs no backoff"] = function()
		local reports, reporter = recorder()
		local guard = LoopGuard.new("T", reporter)
		local ok, backoff = LoopGuard.step(guard, function() end)
		Assert.equal(ok, true)
		Assert.equal(backoff, 0)
		Assert.equal(guard.Iterations, 1)
		Assert.equal(#reports, 0)
	end,
	["a failure streak is reported once and backs off from the second failure"] = function()
		local reports, reporter = recorder()
		local guard = LoopGuard.new("T", reporter)
		local backoffs = {}
		for _ = 1, 5 do
			local ok, backoff = LoopGuard.step(guard, function()
				error("boom")
			end)
			Assert.equal(ok, false)
			table.insert(backoffs, backoff)
		end
		Assert.equal(#reports, 1, "reports")
		Assert.equal(reports[1][1], "T")
		Assert.truthy(string.find(reports[1][2], "boom", 1, true), "message")
		Assert.equal(backoffs[1], 0)
		Assert.equal(backoffs[2], LoopGuard.BackoffSeconds)
		Assert.equal(backoffs[5], LoopGuard.BackoffSeconds)
		Assert.equal(guard.Failures, 5)
		Assert.equal(guard.Streak, 5)
	end,
	["a different error inside a streak is reported"] = function()
		local reports, reporter = recorder()
		local guard = LoopGuard.new("T", reporter)
		LoopGuard.step(guard, function()
			error("first")
		end)
		LoopGuard.step(guard, function()
			error("second")
		end)
		Assert.equal(#reports, 2)
	end,
	["recovery resets the streak so the next failure is reported again"] = function()
		local reports, reporter = recorder()
		local guard = LoopGuard.new("T", reporter)
		local fail = function()
			error("boom")
		end
		LoopGuard.step(guard, fail)
		LoopGuard.step(guard, fail)
		local ok, backoff = LoopGuard.step(guard, function() end)
		Assert.equal(ok, true)
		Assert.equal(backoff, 0)
		Assert.equal(guard.Streak, 0)
		LoopGuard.step(guard, fail)
		Assert.equal(#reports, 2)
	end,
	["the loop keeps running through failing iterations"] = function()
		local _, reporter = recorder()
		local guard = LoopGuard.new("T", reporter)
		local calls = 0
		for i = 1, 10 do
			LoopGuard.step(guard, function()
				calls += 1
				if i >= 3 and i <= 5 then
					error("boom")
				end
			end)
		end
		Assert.equal(calls, 10)
		Assert.equal(guard.Iterations, 10)
		Assert.equal(guard.Failures, 3)
		Assert.equal(guard.Streak, 0)
	end,
	["arguments reach the iteration and it may yield"] = function()
		local _, reporter = recorder()
		local guard = LoopGuard.new("T", reporter)
		local seen = 0
		local ok = LoopGuard.step(guard, function(dt: number)
			task.wait()
			seen = dt
		end, 0.25)
		Assert.equal(ok, true)
		Assert.equal(seen, 0.25)
	end,
	["injected faults fail without running the iteration and report once"] = function()
		local reports, reporter = recorder()
		local guard = LoopGuard.new("T", reporter)
		guard.Faults = 3
		local calls = 0
		for _ = 1, 4 do
			LoopGuard.step(guard, function()
				calls += 1
			end)
		end
		Assert.equal(calls, 1)
		Assert.equal(guard.Failures, 3)
		Assert.equal(#reports, 1)
		Assert.equal(guard.Faults, 0)
	end,
	["fault injection is refused for unknown loops"] = function()
		Assert.equal(LoopGuard.injectFaultsForTesting("NoSuchLoop", 2), false)
	end,
}

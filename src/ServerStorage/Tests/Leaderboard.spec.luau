-- Biggest Spree boards (S2.9): scopes per UTC day / Monday week, resets on schedule, Studio
-- never writes live scopes, the stored best only goes up, and rows skip bad entries.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LeaderboardRules = require(ReplicatedStorage.Shared.Rules.LeaderboardRules)
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local Assert = require(script.Parent.Assert)

-- 2026-10-16 12:00:00 UTC (a Friday) = day 20742.
local FRIDAY_NOON = 20742 * 86400 + 12 * 3600

return {
	["daily and weekly scopes change on schedule; all-time never does"] = function()
		local t = FRIDAY_NOON
		Assert.equal(LeaderboardRules.scope("Daily", t, false, "studio-"), "daily-20742")
		Assert.equal(LeaderboardRules.scope("Daily", t + 12 * 3600 - 1, false, "studio-"), "daily-20742", "same day until midnight UTC")
		Assert.equal(LeaderboardRules.scope("Daily", t + 12 * 3600, false, "studio-"), "daily-20743", "new day at midnight UTC")
		local week = LeaderboardRules.scope("Weekly", t, false, "studio-")
		Assert.equal(LeaderboardRules.scope("Weekly", t + 2 * 86400, false, "studio-"), week, "Sunday is the same week")
		Assert.truthy(LeaderboardRules.scope("Weekly", t + 3 * 86400, false, "studio-") ~= week, "Monday starts a new week")
		Assert.equal(LeaderboardRules.scope("AllTime", t, false, "studio-"), "alltime")
		Assert.equal(LeaderboardRules.scope("AllTime", t + 400 * 86400, false, "studio-"), "alltime")
		Assert.equal(LeaderboardRules.scope("Monthly", t, false, "studio-"), nil)
	end,
	["reset countdowns land on midnight and on Monday"] = function()
		Assert.equal(LeaderboardRules.secondsToReset("Daily", FRIDAY_NOON), 12 * 3600)
		Assert.equal(LeaderboardRules.secondsToReset("Weekly", FRIDAY_NOON), 2 * 86400 + 12 * 3600)
		Assert.equal(LeaderboardRules.secondsToReset("AllTime", FRIDAY_NOON), nil)
	end,
	["Studio always writes to studio scopes"] = function()
		for _, board in LeaderboardConfig.Boards do
			local scope = LeaderboardRules.scope(board, FRIDAY_NOON, true, LeaderboardConfig.StudioScopePrefix) :: string
			Assert.truthy(string.sub(scope, 1, #LeaderboardConfig.StudioScopePrefix) == LeaderboardConfig.StudioScopePrefix, `{board}: {scope}`)
		end
	end,
	["the stored best only goes up; only whole positive amounts count"] = function()
		Assert.equal(LeaderboardRules.merge(nil, 500), 500)
		Assert.equal(LeaderboardRules.merge(900, 500), 900)
		Assert.equal(LeaderboardRules.merge(900, 4000), 4000)
		Assert.equal(LeaderboardRules.merge(0 / 0, 300), 300)
		Assert.equal(LeaderboardRules.validAmount(4050), true)
		Assert.equal(LeaderboardRules.validAmount(0), false)
		Assert.equal(LeaderboardRules.validAmount(10.5), false)
		Assert.equal(LeaderboardRules.validAmount(0 / 0), false)
	end,
	["rows rank valid entries, name players and stop at the limit"] = function()
		local entries = {
			{ key = "11", value = 9000 },
			{ key = "bad", value = 8000 },
			{ key = "22", value = 0 / 0 },
			{ key = "33", value = 7000 },
			{ key = "44", value = 6000 },
		}
		local rows = LeaderboardRules.rows(entries, { [11] = "Ace" }, 2)
		Assert.equal(#rows, 2)
		Assert.equal(rows[1].Name, "Ace")
		Assert.equal(rows[1].Rank, 1)
		Assert.equal(rows[2].UserId, 33)
		Assert.equal(rows[2].Rank, 2)
		Assert.equal(rows[2].Name, "Player 33")
	end,
}

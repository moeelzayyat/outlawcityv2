--!strict
-- Biggest Spree boards (S2.9, architecture §13, D-016). Each board is an OrderedDataStore scope:
-- daily and weekly scopes change with the UTC day / Monday-start week, so a board "resets" by
-- reading a new scope; all-time never resets. Studio writes go to "studio-" scopes so test
-- sprees never reach the live boards. Read-only at runtime.
local LeaderboardConfig = table.freeze({
	StoreName = "BiggestSpree",
	Boards = table.freeze({ "Daily", "Weekly", "AllTime" }),
	Rows = 10, -- top N shown
	RefreshSeconds = 60, -- how often the server re-reads the boards (OnLeaderboard rate)
	SubmitRetries = 3, -- tries per submission before giving up (logged)
	StudioScopePrefix = "studio-",
})

return LeaderboardConfig

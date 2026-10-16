--!strict
-- Pure Biggest Spree board rules (S2.9): which scope a board writes to at a given time, when it
-- resets, and how a submission merges with the stored best. Numbers and strings only.
-- Unit-tested in Leaderboard.spec.
local LeaderboardRules = {}

local DAY = 86400

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Whole UTC days since 1970-01-01.
function LeaderboardRules.dayIndex(unixTime: number): number
	return math.floor(unixTime / DAY)
end

-- Weeks since the Monday before 1970-01-01 (a Thursday): a week runs Monday 00:00 UTC to Monday.
function LeaderboardRules.weekIndex(unixTime: number): number
	return math.floor((LeaderboardRules.dayIndex(unixTime) + 3) / 7)
end

-- The OrderedDataStore scope for `board` at `unixTime` ("daily-20377", "weekly-2911", "alltime").
function LeaderboardRules.scope(board: string, unixTime: number, studio: boolean, studioPrefix: string): string?
	local scope: string
	if board == "Daily" then
		scope = `daily-{LeaderboardRules.dayIndex(unixTime)}`
	elseif board == "Weekly" then
		scope = `weekly-{LeaderboardRules.weekIndex(unixTime)}`
	elseif board == "AllTime" then
		scope = "alltime"
	else
		return nil
	end
	return if studio then studioPrefix .. scope else scope
end

-- Seconds until `board` starts a new scope (nil: never).
function LeaderboardRules.secondsToReset(board: string, unixTime: number): number?
	if board == "Daily" then
		return (LeaderboardRules.dayIndex(unixTime) + 1) * DAY - unixTime
	elseif board == "Weekly" then
		local nextWeekDay = (LeaderboardRules.weekIndex(unixTime) + 1) * 7 - 3
		return nextWeekDay * DAY - unixTime
	end
	return nil
end

-- A banked amount worth submitting: a whole number above zero.
function LeaderboardRules.validAmount(amount: any): boolean
	return finite(amount) and amount > 0 and amount % 1 == 0
end

-- The value to store: the better of the stored best and the new amount (UpdateAsync transform).
function LeaderboardRules.merge(stored: any, amount: number): number
	if finite(stored) and stored >= amount then
		return stored
	end
	return amount
end

export type Row = { Rank: number, UserId: number, Name: string, Amount: number }

-- Rows from sorted entries ({key = "<userId>", value}) and a name lookup; bad entries skipped.
function LeaderboardRules.rows(entries: { { key: string, value: any } }, names: { [number]: string }, limit: number): { Row }
	local rows: { Row } = {}
	for _, entry in entries do
		local userId = tonumber(entry.key)
		if userId and LeaderboardRules.validAmount(entry.value) and #rows < limit then
			table.insert(rows, { Rank = #rows + 1, UserId = userId, Name = names[userId] or `Player {userId}`, Amount = entry.value })
		end
	end
	return rows
end

return LeaderboardRules

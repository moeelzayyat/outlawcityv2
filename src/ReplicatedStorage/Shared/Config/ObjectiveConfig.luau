--!strict
-- The daily objective (S2.9, architecture §13, D-016): one per UTC day, rotating through this
-- list; no streak, nothing lost by skipping a day. Paid once per day through the reward ledger
-- (tx "objective:<day>:<id>"). Read-only at runtime; the public test tunes the numbers.
export type Objective = {
	Id: string,
	Text: string,
	Kind: "Banks" | "Crimes" | "BankAmount", -- what counts: banked sprees, completed crimes, one banked amount
	Target: number,
	Reward: number,
}

local ObjectiveConfig = table.freeze({
	Daily = table.freeze({
		table.freeze({ Id = "Bank3", Text = "Bank 3 sprees", Kind = "Banks", Target = 3, Reward = 1500 }) :: Objective,
		table.freeze({ Id = "Crimes8", Text = "Complete 8 crimes", Kind = "Crimes", Target = 8, Reward = 1500 }) :: Objective,
		table.freeze({ Id = "Big5k", Text = "Bank a $5,000 spree", Kind = "BankAmount", Target = 5000, Reward = 2000 }) :: Objective,
	}),
})

return ObjectiveConfig

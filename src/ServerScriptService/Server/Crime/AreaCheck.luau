--!strict
-- Server-side "is this character inside the crime area" check (R1.4, audit F1). Uses the
-- server's spatial query over the character's own parts, not the root position alone: the root
-- must be inside the area box AND at least half of the character's parts must overlap it, so a
-- root separated from its body can't hold a store on its own. Unit-tested in AreaCheck.spec.
local Workspace = game:GetService("Workspace")

local AreaCheck = {}

-- Pure decision: root inside and a majority of the character's parts inside.
function AreaCheck.decide(rootInside: boolean, partsInside: number, partsTotal: number): boolean
	return rootInside and partsTotal > 0 and partsInside * 2 >= partsTotal
end

function AreaCheck.characterInside(area: BasePart, character: Model): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local total = 0
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			total += 1
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { character }
	local hits = Workspace:GetPartBoundsInBox(area.CFrame, area.Size, params)
	return AreaCheck.decide(table.find(hits, root) ~= nil, #hits, total)
end

return AreaCheck

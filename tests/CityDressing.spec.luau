-- City dressing (P1, D-022): deterministic, within a phone-friendly part budget, solid props
-- off roads, buildings and every gameplay site, facades on their buildings, hills at the edge.
local ServerScriptService = game:GetService("ServerScriptService")
local CityDressing = require(ServerScriptService.Server.World.CityDressing)
local CityLayout = require(ServerScriptService.Server.World.CityLayout)
local Assert = require(script.Parent.Assert)

local BUDGET = 4000 -- dressing parts

local function overlaps(aMin: Vector3, aMax: Vector3, bMin: Vector3, bMax: Vector3): boolean
	return aMin.X < bMax.X and aMax.X > bMin.X and aMin.Z < bMax.Z and aMax.Z > bMin.Z
end

-- A spec's flat footprint (upright cylinders: Size.X is the height).
local function footprint(s: CityDressing.DressSpec): (Vector3, Vector3)
	local size = s.Size
	if s.Shape == Enum.PartType.Cylinder and s.Rotation and s.Rotation.Z == 90 then
		size = Vector3.new(size.Y, size.X, size.Z)
	end
	return s.Center - size / 2, s.Center + size / 2
end

return {
	["the same city every time, inside the part budget, unique names"] = function()
		local a, b = CityDressing.specs(), CityDressing.specs()
		Assert.equal(#a, #b)
		Assert.truthy(#a > 300, `dressing has {#a} parts`)
		Assert.truthy(#a <= BUDGET, `{#a} parts > {BUDGET}`)
		local names = {}
		for i, s in a do
			Assert.truthy(not names[s.Name], `duplicate {s.Name}`)
			names[s.Name] = true
			Assert.equal(s.Center, b[i].Center)
		end
	end,
	["every group is present"] = function()
		local groups = {}
		for _, s in CityDressing.specs() do
			groups[s.Group] = (groups[s.Group] or 0) + 1
		end
		for _, g in { "Facade", "Roof", "Lamp", "Tree", "Furniture", "Park", "Hill", "Site", "SiteProp" } do
			Assert.truthy((groups[g] or 0) > 0, `{g} missing`)
		end
	end,
	["solid props stay off roads, buildings and gameplay sites"] = function()
		local clear = CityDressing.keepClear()
		for _, s in CityDressing.specs() do
			if s.Solid and s.Group ~= "Hill" and s.Group ~= "SiteProp" then
				local mn, mx = footprint(s)
				for _, box in clear do
					Assert.truthy(not overlaps(mn, mx, box.Min, box.Max), `{s.Name} blocks a road, building or site`)
				end
			end
		end
	end,
	["facades hug their buildings and nothing decorative is solid"] = function()
		local buildings = {}
		for _, part in CityLayout.createBlueprint().Parts do
			if part.Group == "Buildings" then
				buildings[part.Name] = part
			end
		end
		for _, s in CityDressing.specs() do
			if s.Group == "Facade" or s.Group == "Roof" then
				Assert.equal(s.Solid, false, `{s.Name} must not be solid`)
				local owner = buildings[string.match(s.Name, "^(Building_%d+_%d+_%d+)_") or ""]
				Assert.truthy(owner, `{s.Name} belongs to a building`)
				local half = owner.Size / 2 + Vector3.new(4, 20, 4)
				local d = s.Center - owner.Center
				Assert.truthy(math.abs(d.X) <= half.X and math.abs(d.Z) <= half.Z and math.abs(d.Y) <= half.Y, `{s.Name} floats away from its building`)
			end
		end
	end,
	["safehouse props sit inside by the walls and leave the driving lane clear"] = function()
		local props = 0
		for _, s in CityDressing.specs() do
			if s.Group == "SiteProp" then
				props += 1
				local home
				for _, h in CityLayout.SAFEHOUSES do
					if string.sub(s.Name, 1, #h.Id + 1) == h.Id .. "_" then
						home = h
					end
				end
				Assert.truthy(home, `{s.Name} belongs to a safehouse`)
				local mn, mx = footprint(s)
				local back = home.X - home.Depth / 2
				Assert.truthy(mn.X >= back + 1 and mx.X <= home.X + home.Depth / 2 and mn.Z >= home.Z - home.Width / 2 + 1 and mx.Z <= home.Z + home.Width / 2 - 1, `{s.Name} pokes through the walls`)
				local byWall = math.min(math.abs(mn.Z - home.Z), math.abs(mx.Z - home.Z)) >= home.Width / 2 - 6
				local atBack = s.Center.X <= back + 4
				Assert.truthy(byWall or atBack, `{s.Name} blocks the driving lane`)
			end
		end
		Assert.truthy(props >= 6, "safehouse props")
	end,
	["crime sites and safehouses carry their signs"] = function()
		local labels = {}
		for _, s in CityDressing.specs() do
			if s.Label then
				labels[s.Label.Text] = (labels[s.Label.Text] or 0) + 1
				Assert.equal(s.Solid, false, `{s.Name} sign is decoration`)
			end
		end
		Assert.equal(labels.ATM, #CityLayout.ATM_SITES)
		Assert.equal(labels.SAFEHOUSE, #CityLayout.SAFEHOUSES)
		Assert.truthy(labels["GAS 24/7"] == 1 and labels.FUEL == 1 and labels.OPEN == 1, "gas station signs")
	end,
	["hills ring the map beyond the highway ends"] = function()
		local hills = 0
		local clear = CityDressing.keepClear()
		for _, s in CityDressing.specs() do
			if s.Group == "Hill" then
				hills += 1
				local flat = Vector3.new(s.Center.X, 0, s.Center.Z).Magnitude
				Assert.truthy(flat - s.Size.X / 2 >= CityLayout.GRID_EXTENT + 400, `{s.Name} reaches into the city`)
				local mn, mx = footprint(s)
				for _, box in clear do
					Assert.truthy(not overlaps(mn, mx, box.Min, box.Max), `{s.Name} crosses the highway`)
				end
			end
		end
		Assert.truthy(hills >= 12, "a full ring of hills")
	end,
}

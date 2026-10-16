-- Crime sites and parked cars (S2.3): ids unique, crimes known, nothing overlapping buildings,
-- the store, the dealership, the jail or the roads; every holdout area contains its prompt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CityLayout = require(ServerScriptService.Server.World.CityLayout)
local CrimeConfig = require(ReplicatedStorage.Shared.Config.CrimeConfig)
local Assert = require(script.Parent.Assert)

type Box = { Min: Vector3, Max: Vector3, Name: string }

local function box(name: string, center: Vector3, size: Vector3): Box
	return { Min = center - size / 2, Max = center + size / 2, Name = name }
end

-- Footprints only (X and Z): a thin road slab still counts as "in the way".
local function overlaps(a: Box, b: Box): boolean
	return a.Min.X < b.Max.X and a.Max.X > b.Min.X and a.Min.Z < b.Max.Z and a.Max.Z > b.Min.Z
end

-- Everything solid a new site must keep clear of.
local function obstacles(groups: { [string]: boolean }): { Box }
	local result = {}
	for _, part in CityLayout.createBlueprint().Parts do
		if groups[part.Group] then
			table.insert(result, box(part.Name, part.Center, part.Size))
		end
	end
	for _, part in CityLayout.store().Parts do
		table.insert(result, box(part.Name, part.Center, part.Size))
	end
	for _, part in CityLayout.dealership().Parts do
		table.insert(result, box(part.Name, part.Center, part.Size))
	end
	for _, part in CityLayout.jail().Parts do
		table.insert(result, box(part.Name, part.Center, part.Size))
	end
	return result
end

local function inside(point: Vector3, center: Vector3, size: Vector3): boolean
	local d = point - center
	return math.abs(d.X) <= size.X / 2 and math.abs(d.Y) <= size.Y / 2 and math.abs(d.Z) <= size.Z / 2
end

return {
	["site and spot ids are unique and crimes are known"] = function()
		local seen = {}
		for _, site in CityLayout.crimeSites() do
			Assert.truthy(not seen[site.Id], `duplicate {site.Id}`)
			seen[site.Id] = true
			local crime = CrimeConfig.Crimes[site.CrimeId]
			Assert.truthy(crime and crime.Holdout, `{site.Id}: holdout crime {site.CrimeId}`)
		end
		Assert.truthy(seen.Store1 == nil, "the store keeps its own builder")
		for _, spot in CityLayout.parkedCars() do
			Assert.truthy(not seen[spot.Name], `duplicate {spot.Name}`)
			seen[spot.Name] = true
		end
		Assert.equal(#CityLayout.atms(), 4)
		Assert.equal(#CityLayout.parkedCars(), 6)
	end,
	["crime site parts clear buildings, the store, the dealership, the jail and the roads"] = function()
		local solid = obstacles({ Buildings = true, Roads = true, Barriers = true, Highway = true })
		for _, site in CityLayout.crimeSites() do
			for _, part in site.Parts do
				local b = box(part.Name, part.Center, part.Size)
				for _, other in solid do
					Assert.truthy(not overlaps(b, other), `{part.Name} overlaps {other.Name}`)
				end
			end
		end
	end,
	["each prompt sits inside its holdout area and on its anchor"] = function()
		for _, site in CityLayout.crimeSites() do
			Assert.truthy(inside(site.Prompt.Position, site.Area.Center, site.Area.Size), `{site.Id} prompt in area`)
			local anchor
			for _, part in site.Parts do
				if part.Name == site.Anchor then
					anchor = part
				end
			end
			Assert.truthy(anchor, `{site.Id} anchor part {site.Anchor}`)
			Assert.truthy((site.Prompt.Position - anchor.Center).Magnitude < 3, `{site.Id} prompt near its anchor`)
		end
	end,
	["parked cars clear buildings and roads"] = function()
		local solid = obstacles({ Buildings = true, Roads = true, Barriers = true, Highway = true })
		for _, sites in { CityLayout.crimeSites() } do
			for _, site in sites do
				for _, part in site.Parts do
					if part.Name ~= "GasLot" then
						table.insert(solid, box(part.Name, part.Center, part.Size))
					end
				end
			end
		end
		for _, spot in CityLayout.parkedCars() do
			-- A Coupe footprint: 6 wide, 12 long along the car's own Z, 5 tall.
			local size = spot.CFrame:VectorToWorldSpace(Vector3.new(6, 5, 12))
			local footprint = box(spot.Name, spot.CFrame.Position, Vector3.new(math.abs(size.X), 5, math.abs(size.Z)))
			for _, other in solid do
				Assert.truthy(not overlaps(footprint, other), `{spot.Name} overlaps {other.Name}`)
			end
		end
	end,
}

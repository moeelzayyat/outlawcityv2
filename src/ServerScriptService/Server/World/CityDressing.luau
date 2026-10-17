--!strict
-- City dressing (P1 polish, D-022): data-only detail added around the existing blueprint so the
-- city stops reading as plain boxes. Building facades (window bands per floor, storefronts with
-- awnings on road faces, parapets, rooftop units), street furniture (lamps, trees, hydrants,
-- benches, bins), small parks on empty lots, plaza trees, crime-site and safehouse details
-- (signs, fascia, shutters, lights, props), and a ring of hills on the horizon.
-- Everything is project-built parts (no outside assets), seeded so every server builds the same
-- city. CityBuilder.buildDressing turns the specs into parts; CityDressing.spec checks them.
local CityLayout = require(script.Parent.CityLayout)

local CityDressing = {}

export type DressSpec = {
	Name: string,
	Group: string, -- Facade | Roof | Lamp | Tree | Furniture | Park | Hill
	Center: Vector3,
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	CanCollide: boolean,
	Shape: Enum.PartType?, -- Block when nil
	Rotation: Vector3?, -- degrees (cylinders stand upright with Z = 90)
	Ellipsoid: boolean?, -- a SpecialMesh sphere stretched to Size (hills); collision stays the box
	Solid: boolean, -- blocks walking/driving: kept clear of roads, buildings and gameplay sites
	Label: { Text: string, Face: Enum.NormalId, Color: Color3 }?, -- sign text (SurfaceGui)
}

local SEED = 20261017
local CURB = CityLayout.CURB_TOP
local FLOOR = 8 -- studs per storey
local UPRIGHT = Vector3.new(0, 0, 90) -- a Cylinder's axis is X; this stands it up

local COLORS = {
	Glass = Color3.fromRGB(52, 70, 92),
	Storefront = Color3.fromRGB(70, 96, 118),
	Parapet = Color3.fromRGB(70, 68, 66),
	RoofUnit = Color3.fromRGB(150, 152, 155),
	Pole = Color3.fromRGB(45, 48, 52),
	LampHead = Color3.fromRGB(255, 236, 190),
	Trunk = Color3.fromRGB(96, 70, 48),
	Leaves = { Color3.fromRGB(74, 128, 62), Color3.fromRGB(62, 112, 56), Color3.fromRGB(88, 140, 70) },
	Hydrant = Color3.fromRGB(196, 40, 40),
	Bench = Color3.fromRGB(120, 84, 52),
	Bin = Color3.fromRGB(40, 72, 50),
	Grass = Color3.fromRGB(86, 128, 66),
	Hills = { Color3.fromRGB(78, 110, 62), Color3.fromRGB(92, 120, 70), Color3.fromRGB(70, 98, 58) },
	Awnings = { Color3.fromRGB(176, 52, 52), Color3.fromRGB(40, 104, 150), Color3.fromRGB(46, 130, 80), Color3.fromRGB(214, 150, 40) },
}

local function spec(name: string, group: string, center: Vector3, size: Vector3, color: Color3, material: Enum.Material, solid: boolean, shape: Enum.PartType?, rotation: Vector3?): DressSpec
	return {
		Name = name,
		Group = group,
		Center = center,
		Size = size,
		Color = color,
		Material = material,
		CanCollide = solid,
		Shape = shape,
		Rotation = rotation,
		Solid = solid,
	}
end

type Box = { Min: Vector3, Max: Vector3 }

local function boxOf(center: Vector3, size: Vector3, margin: number): Box
	local half = size / 2 + Vector3.new(margin, 0, margin)
	return { Min = center - half, Max = center + half }
end

-- Footprints only (X and Z).
local function overlaps(a: Box, b: Box): boolean
	return a.Min.X < b.Max.X and a.Max.X > b.Min.X and a.Min.Z < b.Max.Z and a.Max.Z > b.Min.Z
end

-- Everything a solid prop must stay off: roads, buildings, the store, dealership, jail, crime
-- sites, safehouses, parked cars and every spawn.
function CityDressing.keepClear(): { Box }
	local blueprint = CityLayout.createBlueprint()
	local clear: { Box } = {}
	for _, part in blueprint.Parts do
		if part.Group == "Roads" or part.Group == "Buildings" or part.Group == "Barriers" or part.Group == "Highway" then
			table.insert(clear, boxOf(part.Center, part.Size, 1))
		end
	end
	for _, group in { CityLayout.store().Parts, CityLayout.dealership().Parts, CityLayout.jail().Parts } do
		for _, part in group do
			table.insert(clear, boxOf(part.Center, part.Size, 3))
		end
	end
	for _, site in CityLayout.crimeSites() do
		for _, part in site.Parts do
			table.insert(clear, boxOf(part.Center, part.Size, 3))
		end
		table.insert(clear, boxOf(site.Area.Center, site.Area.Size, 2))
	end
	for _, house in CityLayout.safehouses() do
		for _, part in house.Parts do
			table.insert(clear, boxOf(part.Center, part.Size, 3))
		end
		-- The open side faces +X: keep a driveway clear in front of it.
		local zone = house.Zone
		table.insert(clear, { Min = Vector3.new(zone.Max.X, -10, zone.Min.Z - 2), Max = Vector3.new(zone.Max.X + 30, 40, zone.Max.Z + 2) })
	end
	for _, spot in CityLayout.parkedCars() do
		table.insert(clear, boxOf(spot.CFrame.Position, Vector3.new(14, 6, 14), 2))
	end
	for _, list in { blueprint.Spawns, blueprint.CivilianSpawns } do
		for _, s in list do
			table.insert(clear, boxOf(s.CFrame.Position, Vector3.new(14, 6, 14), 3))
		end
	end
	return clear
end

local function blocked(clear: { Box }, center: Vector3, size: Vector3): boolean
	local b = boxOf(center, size, 0)
	for _, other in clear do
		if overlaps(b, other) then
			return true
		end
	end
	return false
end

-- Facades for one building: a glass band per floor on every face, a storefront and awning on the
-- faces toward the roads, a parapet ring and a rooftop unit.
local function facade(out: { DressSpec }, name: string, center: Vector3, size: Vector3, blockCenter: Vector3, rng: Random)
	local bottom = center.Y - size.Y / 2
	local top = center.Y + size.Y / 2
	local hx, hz = size.X / 2, size.Z / 2
	local faces = {
		{ Axis = "X", Sign = 1 },
		{ Axis = "X", Sign = -1 },
		{ Axis = "Z", Sign = 1 },
		{ Axis = "Z", Sign = -1 },
	}
	local awning = COLORS.Awnings[rng:NextInteger(1, #COLORS.Awnings)]
	for _, face in faces do
		local alongX = face.Axis == "Z" -- the face's width runs along X
		local width = (if alongX then size.X else size.Z) - 3
		local function onFace(outward: number, y: number, w: number, h: number, depth: number): (Vector3, Vector3)
			if face.Axis == "X" then
				return Vector3.new(center.X + face.Sign * (hx + outward), y, center.Z), Vector3.new(depth, h, w)
			end
			return Vector3.new(center.X, y, center.Z + face.Sign * (hz + outward)), Vector3.new(w, h, depth)
		end
		local towardRoad = if face.Axis == "X" then math.sign(center.X - blockCenter.X) == face.Sign else math.sign(center.Z - blockCenter.Z) == face.Sign
		local firstFloor = bottom + 1
		if towardRoad then
			local c, s = onFace(0.15, bottom + 3.6, width, 5, 0.4)
			table.insert(out, spec(`{name}_Store{face.Axis}{face.Sign}`, "Facade", c, s, COLORS.Storefront, Enum.Material.Glass, false))
			c, s = onFace(1.4, bottom + 6.9, width, 0.5, 2.8)
			table.insert(out, spec(`{name}_Awning{face.Axis}{face.Sign}`, "Facade", c, s, awning, Enum.Material.Fabric, false))
			firstFloor = bottom + FLOOR + 1
		end
		local floor = 0
		local y = firstFloor + 2.5
		while y + 2.5 < top - 3 do
			floor += 1
			local c, s = onFace(0.15, y, width, 3.4, 0.4)
			table.insert(out, spec(`{name}_Win{face.Axis}{face.Sign}_{floor}`, "Facade", c, s, COLORS.Glass, Enum.Material.Glass, false))
			y += FLOOR
		end
	end
	-- Parapet ring and a rooftop unit.
	table.insert(out, spec(`{name}_ParapetN`, "Roof", Vector3.new(center.X, top + 0.6, center.Z - hz + 0.4), Vector3.new(size.X, 1.2, 0.8), COLORS.Parapet, Enum.Material.Concrete, false))
	table.insert(out, spec(`{name}_ParapetS`, "Roof", Vector3.new(center.X, top + 0.6, center.Z + hz - 0.4), Vector3.new(size.X, 1.2, 0.8), COLORS.Parapet, Enum.Material.Concrete, false))
	table.insert(out, spec(`{name}_ParapetW`, "Roof", Vector3.new(center.X - hx + 0.4, top + 0.6, center.Z), Vector3.new(0.8, 1.2, size.Z - 1.6), COLORS.Parapet, Enum.Material.Concrete, false))
	table.insert(out, spec(`{name}_ParapetE`, "Roof", Vector3.new(center.X + hx - 0.4, top + 0.6, center.Z), Vector3.new(0.8, 1.2, size.Z - 1.6), COLORS.Parapet, Enum.Material.Concrete, false))
	local ux = (rng:NextNumber() - 0.5) * (size.X - 12)
	local uz = (rng:NextNumber() - 0.5) * (size.Z - 12)
	table.insert(out, spec(`{name}_RoofUnit`, "Roof", Vector3.new(center.X + ux, top + 1.6, center.Z + uz), Vector3.new(7, 3.2, 5), COLORS.RoofUnit, Enum.Material.DiamondPlate, false))
	if size.Y > 60 then
		table.insert(out, spec(`{name}_Mast`, "Roof", Vector3.new(center.X - ux * 0.5, top + 7, center.Z - uz * 0.5), Vector3.new(14, 0.6, 0.6), COLORS.Pole, Enum.Material.Metal, false, Enum.PartType.Cylinder, UPRIGHT))
	end
end

local function lamp(out: { DressSpec }, name: string, at: Vector3, toward: Vector3)
	-- toward: unit vector from the lamp to the road.
	local pole = Vector3.new(at.X, CURB + 7, at.Z)
	table.insert(out, spec(`{name}_Pole`, "Lamp", pole, Vector3.new(14, 0.5, 0.5), COLORS.Pole, Enum.Material.Metal, true, Enum.PartType.Cylinder, UPRIGHT))
	local armCenter = Vector3.new(at.X + toward.X * 1.6, CURB + 13.8, at.Z + toward.Z * 1.6)
	local armSize = if math.abs(toward.X) > 0 then Vector3.new(3.4, 0.3, 0.3) else Vector3.new(0.3, 0.3, 3.4)
	table.insert(out, spec(`{name}_Arm`, "Lamp", armCenter, armSize, COLORS.Pole, Enum.Material.Metal, false))
	local headCenter = Vector3.new(at.X + toward.X * 3.1, CURB + 13.4, at.Z + toward.Z * 3.1)
	table.insert(out, spec(`{name}_Head`, "Lamp", headCenter, Vector3.new(1.4, 0.4, 1.4), COLORS.LampHead, Enum.Material.Neon, false))
end

local function tree(out: { DressSpec }, name: string, at: Vector3, base: number, rng: Random)
	local scale = 0.85 + rng:NextNumber() * 0.4
	local leaves = COLORS.Leaves[rng:NextInteger(1, #COLORS.Leaves)]
	table.insert(out, spec(`{name}_Trunk`, "Tree", Vector3.new(at.X, base + 3.5 * scale, at.Z), Vector3.new(7 * scale, 0.9, 0.9), COLORS.Trunk, Enum.Material.Wood, true, Enum.PartType.Cylinder, UPRIGHT))
	table.insert(out, spec(`{name}_Crown`, "Tree", Vector3.new(at.X, base + 8.5 * scale, at.Z), Vector3.new(6.5, 6.5, 6.5) * scale, leaves, Enum.Material.Grass, false, Enum.PartType.Ball))
	table.insert(out, spec(`{name}_Top`, "Tree", Vector3.new(at.X + 0.6, base + 11 * scale, at.Z - 0.4), Vector3.new(4.6, 4.6, 4.6) * scale, leaves, Enum.Material.Grass, false, Enum.PartType.Ball))
end

local function bench(out: { DressSpec }, name: string, at: Vector3, base: number, alongX: boolean)
	local seat = if alongX then Vector3.new(4.5, 0.4, 1.4) else Vector3.new(1.4, 0.4, 4.5)
	table.insert(out, spec(`{name}_Seat`, "Furniture", Vector3.new(at.X, base + 1.3, at.Z), seat, COLORS.Bench, Enum.Material.Wood, true))
	local back = if alongX then Vector3.new(4.5, 1.2, 0.3) else Vector3.new(0.3, 1.2, 4.5)
	local backOffset = if alongX then Vector3.new(0, 0, 0.6) else Vector3.new(0.6, 0, 0)
	table.insert(out, spec(`{name}_Back`, "Furniture", Vector3.new(at.X, base + 2.1, at.Z) + backOffset, back, COLORS.Bench, Enum.Material.Wood, false))
	table.insert(out, spec(`{name}_Legs`, "Furniture", Vector3.new(at.X, base + 0.55, at.Z), seat - Vector3.new(0.6, 0, 0.6) + Vector3.new(0, 0.7, 0), COLORS.Pole, Enum.Material.Metal, false))
end

local function hydrant(out: { DressSpec }, name: string, at: Vector3)
	table.insert(out, spec(`{name}_Body`, "Furniture", Vector3.new(at.X, CURB + 1.1, at.Z), Vector3.new(2.2, 1, 1), COLORS.Hydrant, Enum.Material.Metal, true, Enum.PartType.Cylinder, UPRIGHT))
	table.insert(out, spec(`{name}_Cap`, "Furniture", Vector3.new(at.X, CURB + 2.35, at.Z), Vector3.new(0.8, 0.8, 0.8), COLORS.Hydrant, Enum.Material.Metal, false, Enum.PartType.Ball))
end

local function bin(out: { DressSpec }, name: string, at: Vector3, base: number)
	table.insert(out, spec(`{name}`, "Furniture", Vector3.new(at.X, base + 1.3, at.Z), Vector3.new(2.6, 1.6, 1.6), COLORS.Bin, Enum.Material.Metal, true, Enum.PartType.Cylinder, UPRIGHT))
end

-- Sign plate text: which face of a thin plate looks along `facing`.
local function faceToward(facing: Vector3): Enum.NormalId
	if facing.X > 0.5 then
		return Enum.NormalId.Right
	elseif facing.X < -0.5 then
		return Enum.NormalId.Left
	elseif facing.Z > 0.5 then
		return Enum.NormalId.Back
	end
	return Enum.NormalId.Front
end

local function labelled(s: DressSpec, text: string, face: Enum.NormalId, color: Color3): DressSpec
	s.Label = { Text = text, Face = face, Color = color }
	return s
end

-- Crime sites and safehouses (P1 batch 2): signs and details so each place reads at a glance.
-- Decoration is never solid; props inside the safehouses are, but stay by the walls so the
-- driving lane in is clear (CityDressing.spec).
local function sites(out: { DressSpec })
	local base = CURB
	for _, a in CityLayout.ATM_SITES do
		local forwardV = Vector3.new(a.FaceX, 0, a.FaceZ)
		local acrossX = a.FaceX == 0
		local function at(forward: number, up: number, across: number, height: number, depth: number): (Vector3, Vector3)
			local center = Vector3.new(a.X, base + up, a.Z) + forwardV * forward
			local size = if acrossX then Vector3.new(across, height, depth) else Vector3.new(depth, height, across)
			return center, size
		end
		local c, s = at(1.25, 6.3, 3, 0.55, 0.1)
		table.insert(out, labelled(spec(`{a.Id}_Sign`, "Site", c, s, Color3.fromRGB(30, 120, 70), Enum.Material.SmoothPlastic, false), "ATM", faceToward(forwardV), Color3.new(1, 1, 1)))
		c, s = at(1.35, 5.0, 2.6, 0.2, 0.7)
		table.insert(out, spec(`{a.Id}_Hood`, "Site", c, s, Color3.fromRGB(40, 42, 48), Enum.Material.Metal, false))
		c, s = at(1.1, 2.7, 0.9, 0.6, 0.25)
		table.insert(out, spec(`{a.Id}_Keypad`, "Site", c, s, Color3.fromRGB(150, 152, 158), Enum.Material.Metal, false))
		c, s = at(1.05, 3.25, 0.7, 0.08, 0.2)
		table.insert(out, spec(`{a.Id}_Slot`, "Site", c, s, Color3.fromRGB(90, 255, 140), Enum.Material.Neon, false))
		c, s = at(0, 0.15, 3.8, 0.3, 2.8)
		table.insert(out, spec(`{a.Id}_Plinth`, "Site", c, s, Color3.fromRGB(120, 120, 124), Enum.Material.Concrete, false))
	end

	-- Gas station: canopy fascia with the brand, a price pylon by the road, pump displays, the
	-- kiosk's OPEN sign and parking bays.
	local g = CityLayout.GAS_CENTER
	local top = CityLayout.ROAD_TOP
	local white = Color3.fromRGB(240, 240, 240)
	local red = Color3.fromRGB(200, 40, 40)
	table.insert(out, labelled(spec("Gas_FasciaW", "Site", Vector3.new(g.X - 27.25, top + 14.2, g.Z), Vector3.new(0.5, 1.6, 22.4), white, Enum.Material.SmoothPlastic, false), "FUEL", Enum.NormalId.Left, red))
	table.insert(out, spec("Gas_FasciaE", "Site", Vector3.new(g.X - 0.75, top + 14.2, g.Z), Vector3.new(0.5, 1.6, 22.4), white, Enum.Material.SmoothPlastic, false))
	table.insert(out, spec("Gas_FasciaN", "Site", Vector3.new(g.X - 14, top + 14.2, g.Z - 11.25), Vector3.new(26.4, 1.6, 0.5), white, Enum.Material.SmoothPlastic, false))
	table.insert(out, spec("Gas_FasciaS", "Site", Vector3.new(g.X - 14, top + 14.2, g.Z + 11.25), Vector3.new(26.4, 1.6, 0.5), white, Enum.Material.SmoothPlastic, false))
	table.insert(out, spec("Gas_PylonPole", "Site", Vector3.new(g.X - 27, top + 6, g.Z + 31), Vector3.new(12, 0.8, 0.8), COLORS.Pole, Enum.Material.Metal, false, Enum.PartType.Cylinder, UPRIGHT))
	table.insert(out, labelled(spec("Gas_PylonBoard", "Site", Vector3.new(g.X - 27, top + 14, g.Z + 31), Vector3.new(0.6, 5, 8), red, Enum.Material.SmoothPlastic, false), "GAS 24/7", Enum.NormalId.Left, white))
	for i, z in { -5, 5 } do
		table.insert(out, spec(`Gas_PumpCap{i}`, "Site", Vector3.new(g.X - 14, top + 5.15, g.Z + z), Vector3.new(2.3, 0.3, 1.7), red, Enum.Material.Neon, false))
		table.insert(out, spec(`Gas_PumpScreen{i}`, "Site", Vector3.new(g.X - 15.05, top + 3.8, g.Z + z), Vector3.new(0.1, 1, 1.1), Color3.fromRGB(30, 34, 40), Enum.Material.Glass, false))
		table.insert(out, spec(`Gas_PumpHose{i}`, "Site", Vector3.new(g.X - 12.85, top + 2.6, g.Z + z), Vector3.new(4, 0.25, 0.25), Color3.fromRGB(25, 25, 28), Enum.Material.Rubber, false, Enum.PartType.Cylinder, UPRIGHT))
	end
	table.insert(out, labelled(spec("Gas_OpenSign", "Site", Vector3.new(g.X + 11.8, top + 9.2, g.Z), Vector3.new(0.2, 1.4, 4), Color3.fromRGB(25, 25, 30), Enum.Material.SmoothPlastic, false), "OPEN", Enum.NormalId.Left, Color3.fromRGB(110, 255, 140)))
	for i, z in { 15, 21, 27, 33 } do
		table.insert(out, spec(`Gas_Bay{i}`, "Site", Vector3.new(g.X + 8, top + 0.03, g.Z + z), Vector3.new(10, 0.05, 0.3), white, Enum.Material.SmoothPlastic, false))
	end

	-- Safehouses: a SAFEHOUSE plate over the opening, a half-raised shutter, work lights, a wall
	-- lamp, a hazard strip at the door, and props along the walls.
	for _, h in CityLayout.SAFEHOUSES do
		local front = h.X + h.Depth / 2
		local back = h.X - h.Depth / 2
		local n = h.Id
		table.insert(out, labelled(spec(`{n}_Sign`, "Site", Vector3.new(front + 0.15, h.Height - 1.5, h.Z), Vector3.new(0.2, 2.2, h.Width * 0.6), Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic, false), "SAFEHOUSE", Enum.NormalId.Right, Color3.fromRGB(255, 205, 70)))
		table.insert(out, spec(`{n}_Shutter`, "Site", Vector3.new(front - 0.6, h.Height - 4, h.Z), Vector3.new(0.4, 2, h.Width - 2.2), Color3.fromRGB(150, 150, 146), Enum.Material.CorrodedMetal, false))
		for i, x in { h.X - h.Depth / 4, h.X + h.Depth / 4 } do
			table.insert(out, spec(`{n}_Light{i}`, "Site", Vector3.new(x, h.Height - 0.8, h.Z), Vector3.new(0.6, 0.3, h.Width * 0.5), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, false))
		end
		table.insert(out, spec(`{n}_WallLamp`, "Site", Vector3.new(front + 0.6, h.Height - 4.5, h.Z + h.Width / 2 - 3), Vector3.new(0.8, 0.6, 0.8), Color3.fromRGB(255, 220, 150), Enum.Material.Neon, false))
		table.insert(out, spec(`{n}_Hazard`, "Site", Vector3.new(front - 1.5, CityLayout.ROAD_TOP + 0.03, h.Z), Vector3.new(1.2, 0.05, h.Width - 2), Color3.fromRGB(240, 190, 40), Enum.Material.SmoothPlastic, false))
		local side = h.Width / 2 - 2.5
		if h.Id == "Garage" then
			for i, z in { -side, side } do
				table.insert(out, spec(`{n}_Tyres{i}`, "SiteProp", Vector3.new(back + 3, CityLayout.ROAD_TOP + 1.2, h.Z + z), Vector3.new(2.4, 3, 3), Color3.fromRGB(28, 28, 30), Enum.Material.Rubber, true, Enum.PartType.Cylinder, UPRIGHT))
				table.insert(out, spec(`{n}_Drum{i}`, "SiteProp", Vector3.new(h.X, CityLayout.ROAD_TOP + 1.5, h.Z + z), Vector3.new(3, 2, 2), if i == 1 then Color3.fromRGB(170, 50, 40) else Color3.fromRGB(40, 80, 150), Enum.Material.Metal, true, Enum.PartType.Cylinder, UPRIGHT))
			end
			table.insert(out, spec(`{n}_Bench`, "SiteProp", Vector3.new(back + 2, CityLayout.ROAD_TOP + 1.5, h.Z), Vector3.new(2, 3, 8), Color3.fromRGB(110, 80, 52), Enum.Material.Wood, true))
		else
			local crate = Color3.fromRGB(150, 112, 64)
			for i, x in { h.X - h.Depth / 4, h.X + h.Depth / 8 } do
				for j, z in { -side + 0.5, side - 0.5 } do
					table.insert(out, spec(`{n}_Crate{i}{j}`, "SiteProp", Vector3.new(x, CityLayout.ROAD_TOP + 2, h.Z + z), Vector3.new(4, 4, 4), crate, Enum.Material.WoodPlanks, true))
					if i == 1 then
						table.insert(out, spec(`{n}_CrateTop{i}{j}`, "SiteProp", Vector3.new(x + 0.3, CityLayout.ROAD_TOP + 6, h.Z + z), Vector3.new(3.4, 4, 3.4), crate, Enum.Material.WoodPlanks, true))
					end
				end
			end
			table.insert(out, spec(`{n}_Pallet`, "SiteProp", Vector3.new(back + 3, CityLayout.ROAD_TOP + 0.3, h.Z), Vector3.new(4, 0.6, 5), Color3.fromRGB(140, 104, 64), Enum.Material.Wood, true))
		end
	end
end

-- Every dressing spec, in a fixed order (same city on every server).
function CityDressing.specs(): { DressSpec }
	local rng = Random.new(SEED)
	local blueprint = CityLayout.createBlueprint()
	local clear = CityDressing.keepClear()
	local out: { DressSpec } = {}

	-- Blocks (sidewalk slabs) and the buildings on them.
	local blocks: { { Name: string, Center: Vector3, Size: Vector3 } } = {}
	local buildings: { { Name: string, Center: Vector3, Size: Vector3 } } = {}
	for _, part in blueprint.Parts do
		if part.Group == "Sidewalks" then
			table.insert(blocks, { Name = part.Name, Center = part.Center, Size = part.Size })
		elseif part.Group == "Buildings" then
			table.insert(buildings, { Name = part.Name, Center = part.Center, Size = part.Size })
		end
	end
	table.sort(blocks, function(a, b)
		return a.Name < b.Name
	end)
	table.sort(buildings, function(a, b)
		return a.Name < b.Name
	end)

	local function blockOf(point: Vector3): Vector3
		for _, block in blocks do
			if math.abs(point.X - block.Center.X) <= block.Size.X / 2 and math.abs(point.Z - block.Center.Z) <= block.Size.Z / 2 then
				return block.Center
			end
		end
		return Vector3.new(point.X, 0, point.Z)
	end

	for _, b in buildings do
		facade(out, b.Name, b.Center, b.Size, blockOf(b.Center), rng)
	end

	-- Street furniture along every block edge, 3 studs in from the curb.
	local offsets = { -60, -40, -20, 0, 20, 40, 60 }
	for _, block in blocks do
		local half = block.Size.X / 2
		for _, side in { { X = 1, Z = 0 }, { X = -1, Z = 0 }, { X = 0, Z = 1 }, { X = 0, Z = -1 } } do
			for i, offset in offsets do
				local at = if side.X ~= 0
					then Vector3.new(block.Center.X + side.X * (half - 3), CURB, block.Center.Z + offset)
					else Vector3.new(block.Center.X + offset, CURB, block.Center.Z + side.Z * (half - 3))
				local id = `{block.Name}_{side.X}{side.Z}_{i}`
				if i % 2 == 1 then
					if not blocked(clear, at, Vector3.new(2, 4, 2)) then
						lamp(out, `Lamp_{id}`, at, Vector3.new(side.X, 0, side.Z))
					end
				elseif not blocked(clear, at, Vector3.new(3, 4, 3)) then
					tree(out, `Tree_{id}`, at, CURB, rng)
				end
			end
			-- A hydrant near one corner of each side.
			local corner = if side.X ~= 0
				then Vector3.new(block.Center.X + side.X * (half - 2.5), CURB, block.Center.Z + 72 * (if side.X > 0 then 1 else -1))
				else Vector3.new(block.Center.X + 72 * (if side.Z > 0 then -1 else 1), CURB, block.Center.Z + side.Z * (half - 2.5))
			if not blocked(clear, corner, Vector3.new(2, 3, 2)) then
				hydrant(out, `Hydrant_{block.Name}_{side.X}{side.Z}`, corner)
			end
		end

		-- Empty building lots become small parks: lawn, trees, a bench and a bin.
		for qx = -1, 1, 2 do
			for qz = -1, 1, 2 do
				local lot = block.Center + Vector3.new(qx * 41, 0, qz * 41)
				local lotSize = Vector3.new(60, 2, 60)
				if not blocked(clear, lot, lotSize) then
					local lawnTop = CURB + 0.15
					local lotName = `Park_{block.Name}_{qx}{qz}`
					table.insert(out, spec(`{lotName}_Lawn`, "Park", Vector3.new(lot.X, CURB + 0.075, lot.Z), Vector3.new(56, 0.15, 56), COLORS.Grass, Enum.Material.Grass, false))
					for t = 1, 5 do
						local p = lot + Vector3.new((rng:NextNumber() - 0.5) * 44, 0, (rng:NextNumber() - 0.5) * 44)
						tree(out, `{lotName}_Tree{t}`, p, lawnTop, rng)
					end
					bench(out, `{lotName}_Bench`, lot + Vector3.new(0, 0, 6), lawnTop, true)
					bin(out, `{lotName}_Bin`, lot + Vector3.new(4, 0, 6), lawnTop)
				end
			end
		end
	end

	-- Plaza: trees and benches around the edge (the middle stays clear for spawns and driving).
	for _, part in blueprint.Parts do
		if part.Group == "Plaza" then
			local half = part.Size.X / 2 - 6
			local top = part.Center.Y + part.Size.Y / 2
			for i, offset in { -60, -30, 30, 60 } do
				for _, side in { { X = 1, Z = 0 }, { X = -1, Z = 0 }, { X = 0, Z = 1 }, { X = 0, Z = -1 } } do
					local at = if side.X ~= 0 then part.Center + Vector3.new(side.X * half, 0, offset) else part.Center + Vector3.new(offset, 0, side.Z * half)
					if not blocked(clear, at, Vector3.new(4, 4, 4)) then
						if i % 2 == 1 then
							tree(out, `PlazaTree_{side.X}{side.Z}_{i}`, at, top, rng)
						else
							bench(out, `PlazaBench_{side.X}{side.Z}_{i}`, at, top, side.X == 0)
						end
					end
				end
			end
		end
	end

	sites(out)

	-- Hills on the horizon, at the baseplate's edge: a soft boundary around the whole map.
	for i = 1, 20 do
		local angle = (i - 1) / 20 * math.pi * 2
		local radius = 1030
		local size = 220 + rng:NextNumber() * 80 -- inner edge stays past the highway's end plazas
		local height = size * (0.45 + rng:NextNumber() * 0.25)
		local center = Vector3.new(math.cos(angle) * radius, -height * 0.25, math.sin(angle) * radius)
		local color = COLORS.Hills[rng:NextInteger(1, #COLORS.Hills)]
		if not blocked(clear, center, Vector3.new(size, height, size)) then -- never across the highway
			local hill = spec(`Hill_{i}`, "Hill", center, Vector3.new(size, height, size), color, Enum.Material.Grass, true)
			hill.Ellipsoid = true
			table.insert(out, hill)
		end
	end
	return out
end

CityDressing.Ground = table.freeze({ Color = COLORS.Grass, Material = Enum.Material.Grass })

return CityDressing

--!strict
-- Owns the driving test area. Uses Workspace.City if it already exists in the place
-- (built in edit mode), otherwise builds it from CityLayout at server start.
local Workspace = game:GetService("Workspace")

local World = script.Parent.Parent.World
local CityLayout = require(World.CityLayout)
local CityBuilder = require(World.CityBuilder)

local WorldService = {}

local city: Instance? = nil

function WorldService.init()
	city = Workspace:FindFirstChild("City")
	if not city then
		city = CityBuilder.build(CityLayout.createBlueprint(), Workspace)
	elseif not city:FindFirstChild("CivilianSpawns") then
		CityBuilder.buildCivilianSpawns(CityLayout.createBlueprint(), city)
	end
	if city and not city:FindFirstChild("Jail") then
		CityBuilder.buildJail(city)
	end
	if city and not city:FindFirstChild("Store") then
		CityBuilder.buildStore(city)
	end
	if city and not city:FindFirstChild("Dealership") then
		CityBuilder.buildDealership(city)
	end
	if city then
		CityBuilder.buildCrimeSites(city) -- adds only missing sites (S2.3)
		CityBuilder.buildSafehouses(city) -- adds only missing safehouses (S2.4)
	end
	if city then
		CityBuilder.buildStreetSigns(city) -- adds only missing signs
	end
end

-- The dealership folder (City.Dealership), if built.
function WorldService.getDealership(): Folder?
	local folder = city and city:FindFirstChild("Dealership")
	return if folder and folder:IsA("Folder") then folder else nil
end

-- The robbable store folder (City.Store), if built.
function WorldService.getStore(): Folder?
	local store = city and city:FindFirstChild("Store")
	return if store and store:IsA("Folder") then store else nil
end

export type CrimeSite = { Id: string, CrimeId: string, Folder: Instance, Anchor: BasePart, Area: BasePart, Prompt: ProximityPrompt }

-- Every holdout crime site: the store (its register and RobPrompt) and City.CrimeSites (S2.3).
function WorldService.getCrimeSites(): { CrimeSite }
	local result: { CrimeSite } = {}
	local function addSite(folder: Instance, id: any, crimeId: string, anchorName: string)
		local anchor = folder:FindFirstChild(anchorName)
		local area = folder:FindFirstChild("Area")
		local prompt = anchor and anchor:FindFirstChildWhichIsA("ProximityPrompt", true)
		if type(id) == "string" and anchor and anchor:IsA("BasePart") and area and area:IsA("BasePart") and prompt then
			table.insert(result, { Id = id, CrimeId = crimeId, Folder = folder, Anchor = anchor, Area = area, Prompt = prompt :: ProximityPrompt })
		else
			warn(`[World] crime site {folder:GetFullName()} is incomplete; skipped`)
		end
	end
	local store = WorldService.getStore()
	if store then
		addSite(store, store:GetAttribute("StoreId"), "StoreRobbery", "StoreRegister")
	end
	local sites = city and city:FindFirstChild("CrimeSites")
	if sites then
		for _, spec in CityLayout.crimeSites() do
			local folder = sites:FindFirstChild(spec.Id)
			if folder then
				addSite(folder, folder:GetAttribute("SiteId"), spec.CrimeId, spec.Anchor)
			end
		end
	end
	return result
end

-- Jail cell standing spots, in slot order.
function WorldService.getJailSlots(): { CFrame }
	local result = {}
	local slots = city and city:FindFirstChild("Jail") and city.Jail:FindFirstChild("Slots")
	if slots then
		for index = 1, #slots:GetChildren() do
			local marker = slots:FindFirstChild(`Slot{index}`)
			if marker and marker:IsA("BasePart") then
				table.insert(result, marker.CFrame)
			end
		end
	end
	return result
end

function WorldService.start() end

-- Spawn pad CFrames at road surface height, facing the direction the car should face.
function WorldService.getVehicleSpawnCFrames(): { CFrame }
	local result = {}
	local spawns = city and city:FindFirstChild("VehicleSpawns")
	if spawns then
		for _, pad in spawns:GetChildren() do
			if pad:IsA("BasePart") then
				table.insert(result, pad.CFrame - Vector3.new(0, pad.CFrame.Y - CityLayout.ROAD_TOP, 0))
			end
		end
	end
	return result
end

-- SpawnLocations where civilian characters appear, in a stable order.
function WorldService.getCivilianSpawns(): { SpawnLocation }
	local result = {}
	local folder = city and city:FindFirstChild("CivilianSpawns")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("SpawnLocation") then
				table.insert(result, child)
			end
		end
	end
	table.sort(result, function(a, b)
		return a.Name < b.Name
	end)
	return result
end

return WorldService

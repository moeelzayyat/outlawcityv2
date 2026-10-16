-- AreaCheck (R1.4): the holdout area test uses the server's bounds query over the character's
-- parts; a root inside the box with the body outside does not count.
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local AreaCheck = require(ServerScriptService.Server.Crime.AreaCheck)
local Assert = require(script.Parent.Assert)

local AREA_CFRAME = CFrame.new(0, -500, 0) -- far below the city
local AREA_SIZE = Vector3.new(20, 16, 20)

-- A stand-in character: a root plus four body parts at the given offsets from the area centre.
local function character(rootOffset: Vector3, bodyOffset: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "AreaCheckSpecCharacter"
	local function part(name: string, offset: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = AREA_CFRAME + offset
		p.Parent = model
	end
	part("HumanoidRootPart", rootOffset)
	for i = 1, 4 do
		part(`Body{i}`, bodyOffset + Vector3.new(0, i, 0))
	end
	model.Parent = Workspace
	return model
end

local function area(): BasePart
	local p = Instance.new("Part")
	p.CFrame = AREA_CFRAME
	p.Size = AREA_SIZE
	return p -- never parented: only its box is used
end

return {
	["the decision needs the root inside and a majority of parts"] = function()
		Assert.equal(AreaCheck.decide(true, 5, 5), true)
		Assert.equal(AreaCheck.decide(true, 3, 6), true)
		Assert.equal(AreaCheck.decide(true, 2, 6), false)
		Assert.equal(AreaCheck.decide(false, 6, 6), false)
		Assert.equal(AreaCheck.decide(true, 0, 0), false)
	end,
	["a character standing in the area is inside"] = function()
		local model = character(Vector3.zero, Vector3.new(1, -3, 1))
		local ok, inside = pcall(AreaCheck.characterInside, area(), model)
		model:Destroy()
		Assert.equal(ok, true, tostring(inside))
		Assert.equal(inside, true)
	end,
	["a root inside with the body outside is not inside"] = function()
		local model = character(Vector3.zero, Vector3.new(60, 0, 0))
		local inside = AreaCheck.characterInside(area(), model)
		model:Destroy()
		Assert.equal(inside, false)
	end,
	["a character outside the area is not inside"] = function()
		local model = character(Vector3.new(60, 0, 0), Vector3.new(60, -3, 0))
		local inside = AreaCheck.characterInside(area(), model)
		model:Destroy()
		Assert.equal(inside, false)
	end,
}

-- Vehicle models (P1 batch 3, D-022): only the chassis collides and carries mass; every detail
-- part is a massless, non-colliding, non-query visual held on by a weld, and stays close to the
-- chassis. Each model keeps its own look (police livery, muscle stripes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local VehicleFactory = require(ServerScriptService.Server.Vehicle.VehicleFactory)
local Assert = require(script.Parent.Assert)

local REACH = 1.5 -- studs a visual may stick out past the chassis box (mirrors, plates, push bar)

local function build(id: string): Model
	local stats = VehicleConfig.get(id)
	assert(stats, id)
	return VehicleFactory.build(id, stats)
end

local function count(model: Model, name: string): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end

return {
	["only the chassis collides; details are welded massless visuals near the body"] = function()
		for _, id in VehicleConfig.getIds() do
			local model = build(id)
			local chassis = model.PrimaryPart :: BasePart
			Assert.truthy(chassis and chassis.Name == "Chassis", `{id} chassis`)
			local half = chassis.Size / 2 + Vector3.new(REACH, 2.6, REACH)
			local parts = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d ~= chassis then
					parts += 1
					Assert.equal(d.CanCollide, false, `{id}.{d.Name} collides`)
					Assert.equal(d.Massless, true, `{id}.{d.Name} has mass`)
					if not d:IsA("Seat") then
						Assert.equal(d.CanQuery, false, `{id}.{d.Name} is queryable`)
					end
					local held = d:FindFirstChildOfClass("WeldConstraint") ~= nil or chassis:FindFirstChild(`WheelMotor{string.match(d.Name, "^Wheel(%d+)$") or ""}`) ~= nil
					Assert.truthy(held, `{id}.{d.Name} is not attached`)
					local p = chassis.CFrame:PointToObjectSpace(d.Position)
					Assert.truthy(math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and p.Y <= half.Y and p.Y >= -half.Y - 1, `{id}.{d.Name} sticks out`)
				end
			end
			Assert.truthy(parts >= 30 and parts <= 50, `{id} has {parts} visual parts`)
			Assert.equal(chassis.CanCollide, true)
			Assert.equal(chassis.Massless, false)
			model:Destroy()
		end
	end,
	["every car has plates, mirrors and rims; each model keeps its look"] = function()
		for _, id in VehicleConfig.getIds() do
			local model = build(id)
			Assert.equal(count(model, "Plate"), 2, `{id} plates`)
			Assert.equal(count(model, "Mirror"), 2, `{id} mirrors`)
			Assert.equal(count(model, "Rim"), 4, `{id} rims`)
			model:Destroy()
		end
		local police = build("Police")
		Assert.equal(count(police, "DoorPanel"), 2)
		local texts = {}
		for _, d in police:GetDescendants() do
			if d:IsA("TextLabel") then
				texts[d.Text] = (texts[d.Text] or 0) + 1
			end
		end
		Assert.equal(texts.POLICE, 2)
		police:Destroy()
		local muscle = build("Muscle")
		Assert.equal(count(muscle, "Stripe"), 3)
		Assert.equal(count(muscle, "Spoiler"), 1)
		muscle:Destroy()
		local coupe = build("Coupe")
		Assert.equal(count(coupe, "DoorPanel") + count(coupe, "Stripe"), 0)
		coupe:Destroy()
	end,
}

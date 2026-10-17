--!strict
-- Builds a vehicle Model from VehicleStats. Only the chassis collides and carries mass;
-- body panels, seat and wheels are massless visuals. Wheels hang off Motor6Ds so the
-- simulating client can animate suspension travel, steering and spin locally. Detail parts
-- (grille, pillars, mirrors, plates, rims, per-model livery) are welded visuals too (P1, D-022).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

local VehicleFactory = {}

local TRIM_COLOR = Color3.fromRGB(25, 25, 28)
local GLASS_COLOR = Color3.fromRGB(150, 190, 220)
local DARK_COLOR = Color3.fromRGB(40, 40, 44)
local CHROME_COLOR = Color3.fromRGB(190, 192, 198)
local PLATE_COLOR = Color3.fromRGB(235, 235, 225)
local PLATE_TEXT = "OUTLAW"

-- Per-model looks (P1 batch 3). Visual only: handling stays in VehicleConfig.
type Style = {
	Stripe: Color3?,
	Spoiler: boolean?,
	RoofColor: Color3?,
	DoorColor: Color3?,
	DoorText: string?,
	DoorTextColor: Color3?,
	PushBar: boolean?,
}
local NO_STYLE: Style = {}
local STYLES: { [string]: Style } = {
	Muscle = { Stripe = Color3.fromRGB(240, 240, 240), Spoiler = true },
	Police = {
		RoofColor = Color3.fromRGB(240, 240, 240),
		DoorColor = Color3.fromRGB(240, 240, 240),
		DoorText = "POLICE",
		DoorTextColor = Color3.fromRGB(25, 35, 80),
		PushBar = true,
	},
}

-- Text on one face of a part (plates, door livery).
local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.TextColor3 = color
	textLabel.Parent = gui
	gui.Parent = part
end

local function weldedPart(
	model: Model,
	chassis: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = chassis.CFrame * offset
	part.Color = color
	part.Material = material
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- Spring length at rest, measured from the suspension anchor to the wheel centre.
function VehicleFactory.getStaticSpringLength(stats: Types.VehicleStats): number
	return stats.SuspensionRestLength * (1 - stats.StaticCompressionRatio)
end

-- Height of the chassis centre above flat ground when the car rests on its springs.
function VehicleFactory.getRideHeight(stats: Types.VehicleStats): number
	return stats.WheelRadius + VehicleFactory.getStaticSpringLength(stats) - stats.WheelOffsets[1].Y
end

function VehicleFactory.build(vehicleId: string, stats: Types.VehicleStats): Model
	local model = Instance.new("Model")
	model.Name = vehicleId
	model:SetAttribute("VehicleId", vehicleId)

	local size = stats.ChassisSize
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = size
	chassis.CFrame = CFrame.identity
	chassis.Color = stats.BodyColor
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0, 1, 1)
	chassis.RootPriority = 10
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.Parent = model
	model.PrimaryPart = chassis

	local halfY, halfZ = size.Y / 2, size.Z / 2
	local plastic = Enum.Material.SmoothPlastic
	weldedPart(model, chassis, "Hood", Vector3.new(size.X - 0.2, 0.5, 4.2), CFrame.new(0, halfY + 0.25, -halfZ + 2.3), stats.BodyColor, plastic)
	weldedPart(model, chassis, "Trunk", Vector3.new(size.X - 0.2, 0.5, 2.6), CFrame.new(0, halfY + 0.25, halfZ - 1.5), stats.BodyColor, plastic)
	weldedPart(model, chassis, "Cabin", Vector3.new(size.X - 0.8, 1.7, 5.6), CFrame.new(0, halfY + 0.85, 0.8), GLASS_COLOR, Enum.Material.Glass).Transparency = 0.55
	weldedPart(model, chassis, "Roof", Vector3.new(size.X - 0.6, 0.3, 4.4), CFrame.new(0, halfY + 1.85, 1.0), (STYLES[vehicleId] or NO_STYLE).RoofColor or stats.BodyColor, plastic)
	weldedPart(model, chassis, "BumperFront", Vector3.new(size.X + 0.2, 0.7, 0.6), CFrame.new(0, -0.1, -halfZ - 0.2), TRIM_COLOR, plastic)
	weldedPart(model, chassis, "BumperRear", Vector3.new(size.X + 0.2, 0.7, 0.6), CFrame.new(0, -0.1, halfZ + 0.2), TRIM_COLOR, plastic)
	for _, side in { -1, 1 } do
		weldedPart(model, chassis, "Headlight", Vector3.new(1.4, 0.4, 0.2), CFrame.new(side * 2.4, 0.4, -halfZ - 0.05), Color3.fromRGB(255, 250, 225), Enum.Material.Neon)
		weldedPart(model, chassis, "Taillight", Vector3.new(1.4, 0.4, 0.2), CFrame.new(side * 2.4, 0.4, halfZ + 0.05), Color3.fromRGB(200, 20, 20), Enum.Material.Neon)
	end

	-- Detail (P1 batch 3, D-022): grille, window pillars, mirrors, door seams and handles, plates
	-- and an exhaust on every car, plus each model's style (stripes and a spoiler, police livery).
	-- All massless visuals; VehicleFactory.spec keeps them that way.
	local style = STYLES[vehicleId] or NO_STYLE
	local halfX = size.X / 2
	local cabinFront, cabinBack = 0.8 - 2.8, 0.8 + 2.8
	weldedPart(model, chassis, "Grille", Vector3.new(2.6, 0.55, 0.12), CFrame.new(0, 0.4, -halfZ - 0.06), DARK_COLOR, Enum.Material.DiamondPlate)
	for _, side in { -1, 1 } do
		local x = side * halfX
		for _, z in { cabinFront + 0.2, cabinBack - 0.2 } do
			weldedPart(model, chassis, "Pillar", Vector3.new(0.4, 1.7, 0.35), CFrame.new(side * (halfX - 0.5), halfY + 0.85, z), style.RoofColor or stats.BodyColor, plastic)
		end
		weldedPart(model, chassis, "Mirror", Vector3.new(0.6, 0.45, 0.3), CFrame.new(x + side * 0.3, halfY + 1.0, cabinFront + 0.3), stats.BodyColor, plastic)
		weldedPart(model, chassis, "DoorSeam", Vector3.new(0.05, 1.0, 0.08), CFrame.new(x + side * 0.02, 0, 0.8), DARK_COLOR, plastic)
		weldedPart(model, chassis, "DoorHandle", Vector3.new(0.08, 0.15, 0.6), CFrame.new(x + side * 0.08, 0.35, -0.4), CHROME_COLOR, Enum.Material.Metal)
		if style.DoorColor then
			local door = weldedPart(model, chassis, "DoorPanel", Vector3.new(0.06, 1.15, 4.6), CFrame.new(x + side * 0.04, 0.05, 0.5), style.DoorColor, plastic)
			if style.DoorText and style.DoorTextColor then
				label(door, if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left, style.DoorText, style.DoorTextColor)
			end
		end
	end
	for _, rear in { false, true } do
		local plate = weldedPart(model, chassis, "Plate", Vector3.new(1.6, 0.5, 0.08), CFrame.new(0, -0.1, if rear then halfZ + 0.54 else -halfZ - 0.54), PLATE_COLOR, plastic)
		label(plate, if rear then Enum.NormalId.Back else Enum.NormalId.Front, PLATE_TEXT, Color3.fromRGB(30, 40, 90))
	end
	weldedPart(model, chassis, "Exhaust", Vector3.new(0.9, 0.35, 0.35), CFrame.new(-halfX + 1.6, -0.5, halfZ + 0.35) * CFrame.Angles(0, math.rad(90), 0), CHROME_COLOR, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	if style.Stripe then
		weldedPart(model, chassis, "Stripe", Vector3.new(1.4, 0.04, 4.2), CFrame.new(0, halfY + 0.52, -halfZ + 2.3), style.Stripe, plastic)
		weldedPart(model, chassis, "Stripe", Vector3.new(1.4, 0.04, 4.4), CFrame.new(0, halfY + 2.02, 1.0), style.Stripe, plastic)
		weldedPart(model, chassis, "Stripe", Vector3.new(1.4, 0.04, 2.6), CFrame.new(0, halfY + 0.52, halfZ - 1.5), style.Stripe, plastic)
	end
	if style.Spoiler then
		weldedPart(model, chassis, "Spoiler", Vector3.new(size.X - 1, 0.2, 0.9), CFrame.new(0, halfY + 1.15, halfZ - 0.7), TRIM_COLOR, plastic)
		for _, side in { -1, 1 } do
			weldedPart(model, chassis, "SpoilerPost", Vector3.new(0.25, 0.6, 0.3), CFrame.new(side * (halfX - 1.2), halfY + 0.8, halfZ - 0.7), TRIM_COLOR, plastic)
		end
	end
	if style.PushBar then
		weldedPart(model, chassis, "PushBar", Vector3.new(3.6, 0.25, 0.25), CFrame.new(0, 0.6, -halfZ - 0.75), TRIM_COLOR, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			weldedPart(model, chassis, "PushBarPost", Vector3.new(0.25, 1.4, 0.25), CFrame.new(side * 1.5, 0.1, -halfZ - 0.75), TRIM_COLOR, Enum.Material.Metal)
		end
	end

	-- Driver seat (left-hand drive). The server seats players through Seat:Sit or the prompt.
	local seat = Instance.new("Seat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.3, 2)
	seat.CFrame = chassis.CFrame * CFrame.new(-1.4, halfY + 0.15, 1.2)
	seat.Color = TRIM_COLOR
	seat.Massless = true
	seat.CanCollide = false
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = seat
	seat.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Drive"
	prompt.ObjectText = stats.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat

	-- Wheels: visual only, positioned at static ride height; clients animate Motor6D.Transform.
	local staticLength = VehicleFactory.getStaticSpringLength(stats)
	for index, offset in stats.WheelOffsets do
		local wheel = Instance.new("Part")
		wheel.Name = `Wheel{index}`
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(stats.WheelWidth, stats.WheelRadius * 2, stats.WheelRadius * 2)
		wheel.Color = TRIM_COLOR
		wheel.Material = plastic
		wheel.Massless = true
		wheel.CanCollide = false
		wheel.CanQuery = false
		wheel.CanTouch = false
		local c0 = CFrame.new(offset - Vector3.yAxis * staticLength)
		wheel.CFrame = chassis.CFrame * c0
		local motor = Instance.new("Motor6D")
		motor.Name = `WheelMotor{index}`
		motor.Part0 = chassis
		motor.Part1 = wheel
		motor.C0 = c0
		motor.Parent = chassis
		wheel.Parent = model
		local rim = Instance.new("Part")
		rim.Name = "Rim"
		rim.Shape = Enum.PartType.Cylinder
		rim.Size = Vector3.new(stats.WheelWidth + 0.06, stats.WheelRadius * 1.1, stats.WheelRadius * 1.1)
		rim.Color = CHROME_COLOR
		rim.Material = Enum.Material.Metal
		rim.Massless = true
		rim.CanCollide = false
		rim.CanQuery = false
		rim.CanTouch = false
		rim.CFrame = wheel.CFrame
		local rimWeld = Instance.new("WeldConstraint")
		rimWeld.Part0 = wheel
		rimWeld.Part1 = rim
		rimWeld.Parent = rim
		rim.Parent = model
	end

	return model
end

return VehicleFactory

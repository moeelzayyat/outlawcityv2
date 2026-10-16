--!strict
-- Safehouses (S2.4, architecture §2.2 / §10). Two zones from CityLayout.safehouses(): a player
-- with an unbanked spree who stays inside one with no police sight for SpreeConfig.BankSeconds
-- banks it through SpreeService.bank (one idempotent grant per "spree:<id>"); their stars then
-- fall to 0 over SafehouseConfig.StarCooldownSeconds. Observed or jailed players can't bank.
-- Publishes InSafehouse / BankProgress / BankBlocked for the client's markers and progress bar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local SafehouseConfig = require(Shared.Config.SafehouseConfig)
local SafeZoneRules = require(Shared.Zones.SafeZoneRules)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local Server = script.Parent.Parent
local CityLayout = require(Server.World.CityLayout)
local LoopGuard = require(Server.Util.LoopGuard)
local SpreeService = require(script.Parent.SpreeService)
local WantedService = require(script.Parent.WantedService)
local PoliceService = require(script.Parent.PoliceService)
local JailService = require(script.Parent.JailService)
local CharacterValidationService = require(script.Parent.CharacterValidationService)

local SafehouseService = {}

local zones: { Types.SafeZone } = {}

local function set(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function bankNow(player: Player, zoneId: string)
	local ok, err = SpreeService.bank(player)
	if ok then
		WantedService.coolDown(player, SafehouseConfig.StarCooldownSeconds)
		print(`[Safehouse] {player.Name} banked at {zoneId}`)
	else
		print(`[Safehouse] {player.Name}: bank at {zoneId} refused ({tostring(err)})`)
	end
end

local function check(player: Player, dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local wasInside = player:GetAttribute(PlayerAttributes.InSafehouse) ~= nil
	local inside, zoneId = false, nil
	if root and root:IsA("BasePart") then
		inside, zoneId = SafeZoneRules.update(wasInside, zones, root.Position, SafehouseConfig.ExitMargin)
	end
	local seen = PoliceService.sees(player) or WantedService.isDevSighted(player)
	local observed = CharacterValidationService.isObserved(player)
	local jailed = JailService.isJailed(player)
	local ready = SpreeService.stepBank(player, dt, { InSafehouse = inside, Seen = seen, Observed = observed, Jailed = jailed })
	local spree = SpreeService.get(player)
	local banking = inside and spree ~= nil and spree.Active and spree.Unbanked > 0
	set(player, PlayerAttributes.InSafehouse, if inside then zoneId else nil)
	set(player, PlayerAttributes.BankProgress, if banking and spree then math.floor(spree.BankProgress * 10 + 0.5) / 10 else nil)
	local blocked = if jailed then "Jailed" elseif seen then "Seen" elseif observed then "Observed" else nil
	set(player, PlayerAttributes.BankBlocked, if banking then blocked else nil)
	if ready then
		task.spawn(bankNow, player, zoneId :: string) -- the save yields; the loop must not
	end
end

function SafehouseService.getZones(): { Types.SafeZone }
	return zones
end

function SafehouseService.init()
	for _, safehouse in CityLayout.safehouses() do
		table.insert(zones, safehouse.Zone)
	end
end

function SafehouseService.start()
	LoopGuard.run("Safehouse", SafehouseConfig.TickInterval, function(dt: number)
		for _, player in Players:GetPlayers() do
			check(player, dt)
		end
	end)
end

return SafehouseService

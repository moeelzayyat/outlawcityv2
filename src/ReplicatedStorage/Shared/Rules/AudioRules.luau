--!strict
-- Pure audio rules (S2.6): which configured sounds may play, their distance fade, and the engine
-- pitch / tyre squeal curves. Plain tables and numbers only. Unit-tested in AudioRules.spec.
local AudioRules = {}

export type SoundDef = {
	SoundId: string,
	Volume: number,
	Looped: boolean,
	Positional: boolean,
	RollOffMin: number?,
	RollOffMax: number?,
}

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function AudioRules.isAssetId(id: any): boolean
	return type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

-- A sound plays only when it has an ID and that ID is on the approved list.
function AudioRules.playable(def: SoundDef, approved: { string }): boolean
	return AudioRules.isAssetId(def.SoundId) and table.find(approved, def.SoundId) ~= nil
end

-- Problems with the configured sounds (empty when valid). An empty SoundId is allowed (pending).
function AudioRules.validate(sounds: { [string]: SoundDef }, approved: { string }): { string }
	local problems = {}
	for name, def in sounds do
		if def.SoundId ~= "" and not AudioRules.isAssetId(def.SoundId) then
			table.insert(problems, `{name}: SoundId must be "" or rbxassetid://<digits>`)
		elseif def.SoundId ~= "" and not table.find(approved, def.SoundId) then
			table.insert(problems, `{name}: {def.SoundId} is not in ApprovedIds (assets/ART_SOURCES.md)`)
		end
		if not finite(def.Volume) or def.Volume < 0 or def.Volume > 1 then
			table.insert(problems, `{name}: Volume must be 0..1`)
		end
		if def.Positional then
			local lo, hi = def.RollOffMin, def.RollOffMax
			if not finite(lo) or not finite(hi) or (lo :: number) <= 0 or (lo :: number) >= (hi :: number) then
				table.insert(problems, `{name}: positional sounds need 0 < RollOffMin < RollOffMax`)
			end
		end
	end
	table.sort(problems)
	return problems
end

-- Properties for a Sound instance. Positional sounds fade (inverse tapered) from RollOffMin to
-- silence at RollOffMax.
function AudioRules.soundProps(def: SoundDef): { [string]: any }
	local props: { [string]: any } = {
		SoundId = def.SoundId,
		Volume = def.Volume,
		Looped = def.Looped,
	}
	if def.Positional then
		props.RollOffMode = Enum.RollOffMode.InverseTapered
		props.RollOffMinDistance = def.RollOffMin
		props.RollOffMaxDistance = def.RollOffMax
	end
	return props
end

-- Engine pitch rises linearly with speed up to topSpeed.
function AudioRules.enginePitch(speed: number, topSpeed: number, minPitch: number, maxPitch: number): number
	if not finite(speed) or not finite(topSpeed) or topSpeed <= 0 then
		return minPitch
	end
	local t = math.clamp(math.abs(speed) / topSpeed, 0, 1)
	return minPitch + (maxPitch - minPitch) * t
end

-- Tyre squeal volume factor (0..1) from sideways speed: silent below slip, full at full.
function AudioRules.tyreLevel(lateralSpeed: number, slip: number, full: number): number
	if not finite(lateralSpeed) or full <= slip then
		return 0
	end
	return math.clamp((math.abs(lateralSpeed) - slip) / (full - slip), 0, 1)
end

return AudioRules

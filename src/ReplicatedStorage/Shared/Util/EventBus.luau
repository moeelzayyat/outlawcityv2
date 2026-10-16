--!strict
-- Server-side event bus (architecture §5, docs/EVENTS.md). Cross-system reactions publish and
-- subscribe here instead of wiring callbacks between services. Event names come from one
-- catalog, so a typo is an error, not a silent no-op. Payloads are plain tables of numbers,
-- strings and booleans that always carry a UserId (never Instances). Every handler runs in its
-- own thread under pcall: one failing consumer can't break the publisher or other consumers.
-- Unit-tested in ServerStorage.Tests.EventBus.spec.
local EventBus = {}

EventBus.Events = table.freeze({
	PlayerJoined = true,
	PlayerLeft = true,
	StarsChanged = true,
	Escaped = true,
	PoliceSight = true,
	PoliceDispatched = true,
	PoliceRecalled = true,
	RoadblockPlaced = true,
	Busted = true,
	Jailed = true,
	Released = true,
	CrimeStarted = true,
	CrimeCompleted = true,
	CrimeFailed = true,
	CashChanged = true,
	PurchaseMade = true,
	VehicleSpawned = true,
	CharacterObserved = true,
	SpreeStarted = true,
	SpreeUpdated = true,
	SpreeBanked = true,
	SpreeLost = true,
})

export type Payload = { [string]: any }
export type Handler = (Payload) -> ()
export type Bus = {
	subscribe: (event: string, handler: Handler) -> () -> (),
	publish: (event: string, payload: Payload) -> (),
	setErrorHandler: (handler: (event: string, message: string) -> ()) -> (),
}

local function check(event: string)
	if type(event) ~= "string" or not EventBus.Events[event] then
		error(`unknown event "{tostring(event)}"`, 3)
	end
end

local function checkPayload(event: string, payload: Payload)
	if type(payload) ~= "table" or type(payload.UserId) ~= "number" then
		error(`{event}: payload needs a numeric UserId`, 3)
	end
	for key, value in payload do
		local kind = type(value)
		if type(key) ~= "string" or (kind ~= "number" and kind ~= "string" and kind ~= "boolean") then
			error(`{event}: payload field {tostring(key)} must be a number, string or boolean`, 3)
		end
	end
end

-- A separate bus with the same API (tests use their own so they never reach live services).
function EventBus.new(): Bus
	local handlers: { [string]: { Handler } } = {}
	local onError = function(event: string, message: string)
		warn(`[EventBus] {event} handler failed: {message}`)
	end
	local bus = {}

	function bus.subscribe(event: string, handler: Handler): () -> ()
		check(event)
		local list = handlers[event]
		if not list then
			list = {}
			handlers[event] = list
		end
		table.insert(list, handler)
		return function()
			local index = table.find(list, handler)
			if index then
				table.remove(list, index)
			end
		end
	end

	function bus.publish(event: string, payload: Payload)
		check(event)
		checkPayload(event, payload)
		local frozen = table.freeze(table.clone(payload))
		for _, handler in table.clone(handlers[event] or {}) do
			task.spawn(function()
				local ok, err = pcall(handler, frozen)
				if not ok then
					onError(event, tostring(err))
				end
			end)
		end
	end

	function bus.setErrorHandler(handler: (event: string, message: string) -> ())
		onError = handler
	end

	return bus :: Bus
end

local default = EventBus.new()
EventBus.subscribe = default.subscribe
EventBus.publish = default.publish
EventBus.setErrorHandler = default.setErrorHandler

return EventBus

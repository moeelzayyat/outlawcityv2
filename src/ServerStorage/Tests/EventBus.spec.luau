-- EventBus (R1.7): catalog-checked names, plain payloads, isolated handlers. Each test uses its
-- own bus so nothing reaches live services.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventBus = require(ReplicatedStorage.Shared.Util.EventBus)
local Assert = require(script.Parent.Assert)

local function settle()
	task.wait() -- handlers run in their own threads
end

return {
	["subscribers receive the payload; unsubscribe stops delivery"] = function()
		local bus = EventBus.new()
		local got = {}
		local stop = bus.subscribe("StarsChanged", function(p)
			table.insert(got, p.Stars)
		end)
		bus.publish("StarsChanged", { UserId = 1, Stars = 2, Heat = 70 })
		settle()
		stop()
		bus.publish("StarsChanged", { UserId = 1, Stars = 3, Heat = 100 })
		settle()
		Assert.equal(#got, 1)
		Assert.equal(got[1], 2)
	end,
	["unknown event names are errors"] = function()
		local bus = EventBus.new()
		Assert.throws(function()
			bus.publish("StarChanged", { UserId = 1 })
		end, "publish typo")
		Assert.throws(function()
			bus.subscribe("Nope", function() end)
		end, "subscribe typo")
	end,
	["payloads must be plain values with a UserId"] = function()
		local bus = EventBus.new()
		Assert.throws(function()
			bus.publish("Jailed", { Seconds = 12 })
		end, "no UserId")
		Assert.throws(function()
			bus.publish("Jailed", { UserId = 1, Player = workspace })
		end, "Instance field")
		Assert.throws(function()
			bus.publish("Jailed", { UserId = 1, List = {} })
		end, "table field")
	end,
	["a failing handler is reported and the others still run"] = function()
		local bus = EventBus.new()
		local reported, ran = {}, 0
		bus.setErrorHandler(function(event, message)
			table.insert(reported, event .. ":" .. message)
		end)
		bus.subscribe("Busted", function()
			error("consumer broke")
		end)
		bus.subscribe("Busted", function()
			ran += 1
		end)
		bus.publish("Busted", { UserId = 1, Stars = 2, Unbanked = 0 })
		settle()
		Assert.equal(ran, 1)
		Assert.equal(#reported, 1)
		Assert.truthy(string.find(reported[1], "consumer broke", 1, true))
	end,
	["handlers can't change what other handlers see"] = function()
		local bus = EventBus.new()
		local seen
		bus.subscribe("CashChanged", function(p)
			pcall(function()
				(p :: any).Delta = 999999
			end)
		end)
		bus.subscribe("CashChanged", function(p)
			seen = p.Delta
		end)
		bus.publish("CashChanged", { UserId = 1, Delta = 2000, Reason = "robbery", TxId = "t" })
		settle()
		Assert.equal(seen, 2000)
	end,
}

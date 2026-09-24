--!strict
local Signal = require("Core.Signal")
local EventBus = require("Core.EventBus")
local Maid = require("Core.Maid")
local StateMachine = require("Architecture.StateMachine")
local Cache = require("Performance.Cache")
local Logger = require("Core.Logger")

local UnitTests = {}

function UnitTests:RunAll(): (boolean, { [string]: boolean })
    local results = {}

    -- 1. Signal Test
    local sig = Signal.new()
    local sigFired = false
    local conn = sig:Connect(function(val)
        if val == "TestValue" then sigFired = true end
    end)
    sig:Fire("TestValue")
    conn:Disconnect()
    sig:Fire("Ignored")
    sig:Destroy()
    results["SignalTest"] = sigFired

    -- 2. EventBus Test
    local ebReceived = false
    local ebConn = EventBus:Subscribe("Test.Event", function(data)
        if data == 123 then ebReceived = true end
    end)
    EventBus:Publish("Test.Event", 123)
    ebConn:Disconnect()
    results["EventBusTest"] = ebReceived

    -- 3. Maid Test
    local maid = Maid.new()
    local cleaned = false
    maid:GiveTask(function() cleaned = true end)
    maid:DoCleaning()
    results["MaidTest"] = cleaned

    -- 4. FSM Priority & Transition Test
    StateMachine:RegisterState("TEST_HIGH", { Priority = 100 })
    StateMachine:RegisterState("TEST_LOW",  { Priority = 10 })
    StateMachine:TransitionTo("TEST_HIGH", nil, true)
    local lowBlocked = not StateMachine:CanTransitionTo("TEST_LOW", nil)
    StateMachine:TransitionTo("IDLE", nil, true)
    results["FSMTest"] = lowBlocked

    -- 5. Cache Invalidation Test
    Cache:Clear()
    results["CacheTest"] = (Cache.Stats.Hits == 0 and Cache.Stats.Misses == 0)

    local allPassed = true
    for name, passed in pairs(results) do
        if not passed then
            allPassed = false
            Logger:Error("UnitTests", "FAILED: " .. name)
        else
            Logger:Info("UnitTests", "PASSED: " .. name)
        end
    end

    return allPassed, results
end

return UnitTests

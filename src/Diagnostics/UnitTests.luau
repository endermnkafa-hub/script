--!strict
local Signal = require("Core.Signal")
local EventBus = require("Core.EventBus")
local Maid = require("Core.Maid")
local Scheduler = require("Core.Scheduler")
local ServiceContainer = require("Core.ServiceContainer")
local StateMachine = require("Architecture.StateMachine")
local FeatureManager = require("Architecture.FeatureManager")
local CacheEngine = require("Performance.Cache")
local ObjectPool = require("Performance.ObjectPool")
local Profiler = require("Performance.Profiler")
local Logger = require("Core.Logger")

local UnitTests = {}

function UnitTests.RunAll(): (boolean, { [string]: boolean })
    local results = {}
    local logger = Logger.new(3)

    -- 1. Signal Test
    local sig = Signal.new()
    local sigVal = nil
    local conn = sig:Connect(function(v) sigVal = v end)
    sig:Fire(42)
    conn:Disconnect()
    sig:Fire(99)
    sig:Destroy()
    results["SignalTest"] = (sigVal == 42)

    -- 2. EventBus Test
    local eb = EventBus.new()
    local ebReceived = false
    local ebConn = eb:Subscribe("Test.Event", function(d) if d == "OK" then ebReceived = true end end)
    eb:Publish("Test.Event", "OK")
    ebConn:Disconnect()
    eb:Clear()
    results["EventBusTest"] = ebReceived

    -- 3. Maid Resource Cleanup Test
    local maid = Maid.new()
    local cleaned = false
    maid:GiveTask(function() cleaned = true end)
    maid:DoCleaning()
    results["MaidTest"] = cleaned

    -- 4. Isolated FSM Priority Enforcement Test
    local isolatedFSM = StateMachine.new("IDLE", logger)
    isolatedFSM:RegisterState("LOW_STATE",  { Priority = 20 })
    isolatedFSM:RegisterState("HIGH_STATE", { Priority = 90 })

    isolatedFSM:TransitionTo("HIGH_STATE", nil)
    local lowBlocked = not isolatedFSM:CanTransitionTo("LOW_STATE", nil)
    isolatedFSM:TransitionTo("IDLE", nil, true)
    results["FSM_PriorityEnforcementTest"] = lowBlocked

    -- 5. Isolated FSM Rollback Test
    isolatedFSM:TransitionTo("LOW_STATE", nil)
    isolatedFSM:Rollback(nil)
    results["FSM_RollbackTest"] = (isolatedFSM.CurrentState == "IDLE")

    -- 6. Isolated Scheduler Test
    local sched = Scheduler.new()
    local schedCount = 0
    sched:Register("FastTask", "Fast", function() schedCount += 1 end)
    sched:Step(0.016)
    results["SchedulerTest"] = (schedCount == 1)

    -- 7. ServiceContainer True Factory DI & Cycle Detection Test
    local container = ServiceContainer.new()
    container:Register("ServiceA", function(c) return { Name = "A" } end)
    container:Register("ServiceB", function(c) return { Dep = c:Get("ServiceA") } end)
    local resolvedB = container:Get("ServiceB")
    results["DependencyInjectionTest"] = (resolvedB and resolvedB.Dep and resolvedB.Dep.Name == "A")

    -- 8. ObjectPool Recycling Test
    local pool = ObjectPool.new(function() return { active = true } end, function(o) o.active = false end, 2)
    local item = pool:Acquire()
    pool:Release(item)
    results["ObjectPoolTest"] = (item.active == false and pool.Acquisitions == 1 and pool.Releases == 1)

    -- 9. Cache Adaptive TTL & Filter Hashing Test
    local cache = CacheEngine.new(0.08)
    cache:Clear()
    local partA = Instance.new("Part")
    local partB = Instance.new("Part")
    local los1 = cache:CachedRaycast(Vector3.new(0,0,0), Vector3.new(0,10,0), { partA })
    local los2 = cache:CachedRaycast(Vector3.new(0,0,0), Vector3.new(0,10,0), { partB })
    results["Cache_FilterHashTest"] = (cache.RaycastStats.Misses == 2)
    partA:Destroy()
    partB:Destroy()

    -- 10. FeatureManager Lifecycle & Throttling Test
    local profiler = Profiler.new()
    local fm = FeatureManager.new(logger, profiler)
    local featStarted = false
    local feat = fm:Register({
        Name = "TestFeature",
        Phase = "Heartbeat",
        Priority = 50,
        Start = function() featStarted = true end,
    })
    fm:SetEnabled("TestFeature", true, nil)
    fm:SetEnabled("TestFeature", false, nil)
    results["FeatureManager_LifecycleTest"] = featStarted

    local allPassed = true
    for name, passed in pairs(results) do
        if not passed then
            allPassed = false
            logger:Error("UnitTests", "FAILED: " .. name)
        else
            logger:Info("UnitTests", "PASSED: " .. name)
        end
    end

    return allPassed, results
end

return UnitTests

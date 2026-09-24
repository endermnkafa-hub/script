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
local ConfigManager = require("Config.ConfigManager")
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

    -- 4. Isolated Strict Whitelist FSM Test (Unregistered transition rejected)
    local isolatedFSM = StateMachine.new("IDLE", logger)
    isolatedFSM:RegisterState("LOW_STATE",  { Priority = 20 })
    isolatedFSM:RegisterState("HIGH_STATE", { Priority = 90 })

    -- Should reject unregistered transition
    local unregBlocked = not isolatedFSM:CanTransitionTo("HIGH_STATE", nil)
    isolatedFSM:RegisterTransition("IDLE", "HIGH_STATE")
    local regAllowed = isolatedFSM:CanTransitionTo("HIGH_STATE", nil)
    isolatedFSM:TransitionTo("HIGH_STATE", nil)

    -- Lower priority override blocked
    isolatedFSM:RegisterTransition("HIGH_STATE", "LOW_STATE")
    local lowBlocked = not isolatedFSM:CanTransitionTo("LOW_STATE", nil)
    isolatedFSM:TransitionTo("IDLE", nil, true)
    results["FSM_StrictWhitelistAndPriorityTest"] = (unregBlocked and regAllowed and lowBlocked)

    -- 5. Isolated FSM Rollback Test
    isolatedFSM:RegisterTransition("IDLE", "LOW_STATE")
    isolatedFSM:TransitionTo("LOW_STATE", nil)
    isolatedFSM:Rollback(nil)
    results["FSM_RollbackTest"] = (isolatedFSM.CurrentState == "IDLE")

    -- 6. Isolated 60 Hz Scheduler Test
    local sched = Scheduler.new()
    local schedCount = 0
    sched:Register("FastTask", "Fast", function() schedCount += 1 end)
    sched:Step(0.0166)
    results["Scheduler_60HzTest"] = (schedCount == 1)

    -- 7. ServiceContainer True Factory DI & DAG Topological Sort Test
    local container = ServiceContainer.new()
    container:Register("ServiceA", function(c) return { Name = "A" } end, {})
    container:Register("ServiceB", function(c) return { Dep = c:Get("ServiceA") } end, { "ServiceA" })
    local order, noCycles = container:TopologicalSort()
    local resolvedB = container:Get("ServiceB")
    results["DependencyGraph_TopologicalSortTest"] = (noCycles and resolvedB.Dep.Name == "A")

    -- 8. ObjectPool Recycling Test
    local pool = ObjectPool.new(function() return { active = true } end, function(o) o.active = false end, 2)
    local item = pool:Acquire()
    pool:Release(item)
    results["ObjectPoolTest"] = (item.active == false and pool.Acquisitions == 1 and pool.Releases == 1)

    -- 9. Cache Safe Instance Hash & Filter Hash Test
    local cache = CacheEngine.new(0.08)
    cache:Clear()
    local partA = Instance.new("Part")
    local partB = Instance.new("Part")
    local los1 = cache:CachedRaycast(Vector3.new(0,0,0), Vector3.new(0,10,0), { partA })
    local los2 = cache:CachedRaycast(Vector3.new(0,0,0), Vector3.new(0,10,0), { partB })
    results["Cache_SafeFilterHashTest"] = (cache.RaycastStats.Misses == 2)
    partA:Destroy()
    partB:Destroy()

    -- 10. Profiler EMA Rolling Window Budget Test
    local profiler = Profiler.new()
    local pStart = profiler:Begin("BudgetTask", 0.001) -- 1 microsecond budget
    task.wait(0.005) -- will exceed budget
    profiler:End("BudgetTask", pStart)
    local metric = profiler.Metrics["BudgetTask"]
    results["Profiler_RollingBudgetTest"] = (metric and metric.Status == "OVER_BUDGET")

    -- 11. Config Schema Runtime Clamping Test
    local cfg = ConfigManager.new(logger)
    local dirtyData = {
        World = {
            FOVValue = 99999, -- Exceeds Max: 120
            FullBright = "NotABool", -- Invalid Type
        }
    }
    cfg:ValidateAndClamp(dirtyData)
    results["Config_SchemaClampingTest"] = (dirtyData.World.FOVValue == 120 and dirtyData.World.FullBright == false)

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

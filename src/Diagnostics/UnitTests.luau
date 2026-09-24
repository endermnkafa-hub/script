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

    -- 4. Isolated Strict Whitelist FSM Test
    local isolatedFSM = StateMachine.new("IDLE", logger)
    isolatedFSM:RegisterState("LOW_STATE",  { Priority = 20 })
    isolatedFSM:RegisterState("HIGH_STATE", { Priority = 90 })

    local unregBlocked = not isolatedFSM:CanTransitionTo("HIGH_STATE", nil)
    isolatedFSM:RegisterTransition("IDLE", "HIGH_STATE")
    local regAllowed = isolatedFSM:CanTransitionTo("HIGH_STATE", nil)
    isolatedFSM:TransitionTo("HIGH_STATE", nil, "Test Enter", "UnitTest")

    isolatedFSM:RegisterTransition("HIGH_STATE", "LOW_STATE")
    local lowBlocked = not isolatedFSM:CanTransitionTo("LOW_STATE", nil)
    isolatedFSM:TransitionTo("IDLE", nil, "Reset", "UnitTest", true)
    results["FSM_StrictWhitelistAndPriorityTest"] = (unregBlocked and regAllowed and lowBlocked and #isolatedFSM.TelemetryLogs >= 2)

    -- 5. Isolated 60 Hz Scheduler Test
    local sched = Scheduler.new()
    local schedCount = 0
    sched:Register("FastTask", "Fast", function() schedCount += 1 end)
    sched:Step(0.0166)
    results["Scheduler_60HzTest"] = (schedCount == 1)

    -- 6. ServiceContainer True Factory DI & DAG Topological Sort Test
    local container = ServiceContainer.new()
    container:Register("ServiceA", function(c) return { Name = "A" } end, {})
    container:Register("ServiceB", function(c) return { Dep = c:Get("ServiceA") } end, { "ServiceA" })
    local order, noCycles = container:TopologicalSort()
    local resolvedB = container:Get("ServiceB")
    results["DependencyGraph_TopologicalSortTest"] = (noCycles and resolvedB.Dep.Name == "A")

    -- 7. ObjectPool Double-Release Guard & Telemetry Test
    local pool = ObjectPool.new(function() return { active = true } end, function(o) o.active = false end, 2, 10)
    local item = pool:Acquire()
    pool:Release(item)
    pool:Release(item) -- Double-release attempt
    local telem = pool:GetTelemetry()
    results["ObjectPool_DoubleReleaseGuardTest"] = (item.active == false and telem.InvalidReleases == 1 and telem.AcquireCount == 1)
    pool:Destroy()

    -- 8. Cache Weak-Key Instance ID Map Test
    local cache = CacheEngine.new(0.08)
    cache:Clear()
    local partA = Instance.new("Part")
    local partB = Instance.new("Part")
    local los1 = cache:CachedRaycast(Vector3.new(0,0,0), Vector3.new(0,10,0), { partA })
    local los2 = cache:CachedRaycast(Vector3.new(0,0,0), Vector3.new(0,10,0), { partB })
    results["Cache_WeakKeyFilterHashTest"] = (cache.RaycastStats.Misses == 2)
    partA:Destroy()
    partB:Destroy()

    -- 9. Profiler Hysteresis Test
    local profiler = Profiler.new()
    local pStart = profiler:Begin("BudgetTask", 0.001)
    task.wait(0.004)
    profiler:End("BudgetTask", pStart)
    local metric = profiler.Metrics["BudgetTask"]
    results["Profiler_HysteresisTest"] = (metric and metric.Status == "OVER_BUDGET")

    -- 10. Config EnumItem Runtime Validation Test
    local cfg = ConfigManager.new(logger)
    local dirtyData = {
        World = { FOVValue = 99999 },
        Keybinds = { ToggleFly = "CorruptedString" } -- Should reset to Default Enum.KeyCode.F5
    }
    cfg:ValidateAndClamp(dirtyData)
    results["Config_EnumValidationTest"] = (dirtyData.World.FOVValue == 120 and typeof(dirtyData.Keybinds.ToggleFly) == "EnumItem")

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

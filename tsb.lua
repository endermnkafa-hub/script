-- // ========================================================================================
-- // ⚡ 4080 CUSTOM HUB v9.0 - SPECIALIST PRODUCTION FRAMEWORK
-- // Architecture: Modular Luau Service Architecture + IoC Container + FSM & Telemetry
-- // Pipeline: Automated CI/CD Verified Build
-- // ========================================================================================

local __modules = {}
local __cache = {}

local function require(modName)
    local normalized = modName:gsub("%.luau$", ""):gsub("%.lua$", ""):gsub("^src/", "")
    normalized = normalized:gsub("/", ".")
    
    -- Exact or normalized match
    local modFunc = __modules[normalized] or __modules[modName] or __modules[normalized:gsub("%.", "/")]
    if not modFunc then
        for k, v in pairs(__modules) do
            if k:lower() == normalized:lower() or k:lower() == modName:lower() then
                modFunc = v
                normalized = k
                break
            end
        end
    end

    if not modFunc then
        error(string.format("[Bundler] Module '%s' not found!", tostring(modName)))
    end

    if not __cache[normalized] then
        __cache[normalized] = modFunc()
    end
    return __cache[normalized]
end

-- ============================================================================
-- Module: Architecture.FeatureManager
-- ============================================================================
__modules["Architecture.FeatureManager"] = function()
--!strict
local Maid = require("Core.Maid")

export type Feature = {
    Name: string,
    Phase: string,
    Priority: number,
    Budget: number,
    Dependencies: { string },
    Enabled: boolean,
    Status: string, -- "INITIALIZED", "RUNNING", "STOPPED", "DEGRADED", "THROTTLED"
    DegradedReason: string?,
    OverBudgetCount: number,
    Maid: any,
    Init: ((self: Feature, ctx: any) -> ())?,
    Start: ((self: Feature, ctx: any) -> ())?,
    Update: ((self: Feature, dt: number, ctx: any) -> ())?,
    Stop: ((self: Feature, ctx: any) -> ())?,
    Destroy: ((self: Feature) -> ())?,
}

local FeatureManager = {}
FeatureManager.__index = FeatureManager

function FeatureManager.new(logger: any, profiler: any)
    local self = setmetatable({
        _logger = logger,
        _profiler = profiler,
        _features = {},
        _renderPipeline = {},
        _steppedPipeline = {},
        _heartbeatPipeline = {},
    }, FeatureManager)
    return self
end

function FeatureManager:Register(def: any): Feature
    assert(type(def.Name) == "string", "Feature must have a unique Name")
    local feat: Feature = {
        Name = def.Name,
        Phase = def.Phase or "Heartbeat",
        Priority = def.Priority or 50,
        Budget = def.Budget or 2.0, -- in ms
        Dependencies = def.Dependencies or {},
        Enabled = def.Enabled or false,
        Status = "INITIALIZED",
        DegradedReason = nil,
        OverBudgetCount = 0,
        Maid = Maid.new(),
        Init = def.Init,
        Start = def.Start,
        Update = def.Update,
        Stop = def.Stop,
        Destroy = def.Destroy,
    }

    self._features[feat.Name] = feat

    local list = self._heartbeatPipeline
    if feat.Phase == "RenderStepped" then list = self._renderPipeline
    elseif feat.Phase == "Stepped" then list = self._steppedPipeline end

    table.insert(list, feat)
    table.sort(list, function(a, b) return a.Priority > b.Priority end)
    return feat
end

function FeatureManager:ValidateDependencies(container: any): (boolean, { [string]: string })
    local report = {}
    local allValid = true

    for name, feat in pairs(self._features) do
        for _, dep in ipairs(feat.Dependencies) do
            if not container:Has(dep) and not self._features[dep] then
                local reason = string.format("Missing Required Dependency '%s'", dep)
                report[name] = reason
                feat.Status = "DEGRADED"
                feat.DegradedReason = reason
                feat.Enabled = false -- Isolate and prevent execution
                allValid = false
            end
        end
    end

    return allValid, report
end

function FeatureManager:InitAll(ctx: any)
    for name, feat in pairs(self._features) do
        if feat.Status == "DEGRADED" then
            self._logger:Warn("FeatureManager", string.format("Skipping Degraded Feature '%s': %s", name, tostring(feat.DegradedReason)))
            continue
        end

        if feat.Init then
            self._logger:SafeCall(name .. ".Init", feat.Init, feat, ctx)
        end

        if feat.Enabled then
            feat.Status = "RUNNING"
            if feat.Start then
                self._logger:SafeCall(name .. ".Start", feat.Start, feat, ctx)
            end
        end
    end
end

function FeatureManager:SetEnabled(name: string, enabled: boolean, ctx: any)
    local feat = self._features[name]
    if not feat or feat.Enabled == enabled then return end

    if feat.Status == "DEGRADED" and enabled then
        self._logger:Warn("FeatureManager", string.format("Cannot enable Degraded Feature '%s': %s", name, tostring(feat.DegradedReason)))
        return
    end

    feat.Enabled = enabled
    if enabled then
        feat.Status = "RUNNING"
        if feat.Start then
            self._logger:SafeCall(name .. ".Start", feat.Start, feat, ctx)
        end
    else
        feat.Status = "STOPPED"
        feat.Maid:DoCleaning()
        if feat.Stop then
            self._logger:SafeCall(name .. ".Stop", feat.Stop, feat, ctx)
        end
    end
end

function FeatureManager:ExecutePipeline(phase: string, dt: number, ctx: any)
    local list = self._heartbeatPipeline
    if phase == "RenderStepped" then list = self._renderPipeline
    elseif phase == "Stepped" then list = self._steppedPipeline end

    for _, feat in ipairs(list) do
        if feat.Enabled and feat.Status ~= "DEGRADED" and feat.Update then
            -- Active Throttling with Hysteresis
            local metric = self._profiler and self._profiler.Metrics[feat.Name]
            if metric and metric.Status == "OVER_BUDGET" then
                feat.OverBudgetCount += 1
                if feat.OverBudgetCount > 3 then
                    feat.Status = "THROTTLED"
                    if (feat.OverBudgetCount % 2) == 0 then
                        continue -- Frame skip
                    end
                end
            else
                feat.OverBudgetCount = 0
                if feat.Status == "THROTTLED" then
                    feat.Status = "RUNNING"
                end
            end

            local start = self._profiler and self._profiler:Begin(feat.Name, feat.Budget)
            self._logger:SafeCall(feat.Name .. ".Update", feat.Update, feat, dt, ctx)
            if self._profiler then
                self._profiler:End(feat.Name, start)
            end
        end
    end
end

function FeatureManager:DestroyAll()
    for _, feat in pairs(self._features) do
        feat.Enabled = false
        feat.Maid:DoCleaning()
        if feat.Destroy then
            pcall(feat.Destroy, feat)
        end
    end
    table.clear(self._features)
    table.clear(self._renderPipeline)
    table.clear(self._steppedPipeline)
    table.clear(self._heartbeatPipeline)
end

return FeatureManager

end
__modules["Architecture/FeatureManager"] = __modules["Architecture.FeatureManager"]

-- ============================================================================
-- Module: Architecture.StateMachine
-- ============================================================================
__modules["Architecture.StateMachine"] = function()
--!strict
local Signal = require("Core.Signal")

export type StateDefinition = {
    Priority: number?,
    Timeout: number?, -- Max duration in seconds before auto-recovering to fallback
    FallbackState: string?,
    OnEnter: ((self: any, prevState: string, ctx: any, reason: string?) -> ())?,
    OnUpdate: ((self: any, dt: number, ctx: any) -> ())?,
    OnExit: ((self: any, nextState: string, ctx: any) -> ())?,
    CanEnter: ((self: any, ctx: any) -> boolean)?,
    CanExit: ((self: any, ctx: any) -> boolean)?,
}

export type TransitionTelemetry = {
    From: string,
    To: string,
    Reason: string,
    Source: string,
    Timestamp: number,
    DurationInPrev: number,
}

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(initialState: string?, logger: any?)
    local self = setmetatable({
        CurrentState = initialState or "IDLE",
        PreviousState = "NONE",
        StateStartTime = os.clock(),
        TransitionsCount = 0,
        History = {},
        TelemetryLogs = {}, -- Structured Transition Telemetry
        MaxTelemetryLogs = 50,
        StateChanged = Signal.new(),
        _logger = logger,
        _states = {},
        _transitions = {},
        _priorities = {
            EMERGENCY_STOP = 100,
            SKY_ESCAPE     = 90,
            SKY_DODGE      = 80,
            VOID_KILL      = 70,
            MASS_BRING     = 60,
            BEHIND_TP      = 50,
            COMBAT         = 30,
            IDLE           = 0,
        },
    }, StateMachine)

    self:RegisterDefaultTransitions()
    return self
end

function StateMachine:RegisterState(name: string, def: StateDefinition)
    self._states[name] = def
    if def.Priority then
        self._priorities[name] = def.Priority
    end
end

function StateMachine:RegisterTransition(fromState: string | { string }, toState: string, condition: ((ctx: any) -> boolean)?)
    local fromList = type(fromState) == "table" and fromState or { fromState }
    for _, f in ipairs(fromList) do
        local key = f .. "->" .. toState
        self._transitions[key] = {
            From = f,
            To = toState,
            Condition = condition,
        }
    end
end

function StateMachine:RegisterDefaultTransitions()
    -- Explicit Strict Whitelist Transitions Graph
    self:RegisterTransition("IDLE", "COMBAT")
    self:RegisterTransition("IDLE", "BEHIND_TP")
    self:RegisterTransition("IDLE", "MASS_BRING")
    self:RegisterTransition("IDLE", "VOID_KILL")
    self:RegisterTransition("IDLE", "SKY_DODGE")
    self:RegisterTransition("IDLE", "SKY_ESCAPE")
    self:RegisterTransition("IDLE", "EMERGENCY_STOP")

    self:RegisterTransition("COMBAT", "IDLE")
    self:RegisterTransition("COMBAT", "BEHIND_TP")
    self:RegisterTransition("COMBAT", "MASS_BRING")
    self:RegisterTransition("COMBAT", "VOID_KILL")
    self:RegisterTransition("COMBAT", "SKY_DODGE")
    self:RegisterTransition("COMBAT", "SKY_ESCAPE")
    self:RegisterTransition("COMBAT", "EMERGENCY_STOP")

    self:RegisterTransition("BEHIND_TP", "IDLE")
    self:RegisterTransition("BEHIND_TP", "COMBAT")
    self:RegisterTransition("BEHIND_TP", "SKY_DODGE")
    self:RegisterTransition("BEHIND_TP", "SKY_ESCAPE")
    self:RegisterTransition("BEHIND_TP", "EMERGENCY_STOP")

    self:RegisterTransition("MASS_BRING", "IDLE")
    self:RegisterTransition("MASS_BRING", "COMBAT")
    self:RegisterTransition("MASS_BRING", "EMERGENCY_STOP")

    self:RegisterTransition("VOID_KILL", "IDLE")
    self:RegisterTransition("VOID_KILL", "EMERGENCY_STOP")

    self:RegisterTransition("SKY_DODGE", "IDLE")
    self:RegisterTransition("SKY_DODGE", "COMBAT")
    self:RegisterTransition("SKY_DODGE", "EMERGENCY_STOP")

    self:RegisterTransition("SKY_ESCAPE", "IDLE")
    self:RegisterTransition("SKY_ESCAPE", "EMERGENCY_STOP")

    self:RegisterTransition("EMERGENCY_STOP", "IDLE")
end

function StateMachine:CanTransitionTo(targetState: string, ctx: any): boolean
    if self.CurrentState == targetState then return false end

    if targetState == "EMERGENCY_STOP" then return true end
    if self.CurrentState == "EMERGENCY_STOP" and targetState ~= "IDLE" then return false end

    local transKey = self.CurrentState .. "->" .. targetState
    local transRule = self._transitions[transKey]
    if not transRule then
        return false -- Whitelist guard
    end

    if transRule.Condition and not transRule.Condition(ctx) then
        return false
    end

    local currentDef = self._states[self.CurrentState]
    if currentDef and currentDef.CanExit and not currentDef:CanExit(ctx) then
        return false
    end

    local currentPri = self._priorities[self.CurrentState] or 0
    local targetPri = self._priorities[targetState] or 0

    if targetPri < currentPri and currentPri >= 70 then
        return false
    end

    local targetDef = self._states[targetState]
    if targetDef and targetDef.CanEnter and not targetDef:CanEnter(ctx) then
        return false
    end

    return true
end

function StateMachine:TransitionTo(newState: string, ctx: any, reason: string?, source: string?, force: boolean?): boolean
    if not force and not self:CanTransitionTo(newState, ctx) then
        return false
    end

    local now = os.clock()
    local oldState = self.CurrentState
    local durationInPrev = now - self.StateStartTime

    local oldDef = self._states[oldState]
    if oldDef and oldDef.OnExit then
        if self._logger then
            self._logger:SafeCall("FSM.OnExit", oldDef.OnExit, oldDef, newState, ctx)
        else
            pcall(oldDef.OnExit, oldDef, newState, ctx)
        end
    end

    table.insert(self.History, 1, oldState)
    if #self.History > 20 then table.remove(self.History) end

    -- Record Structured Telemetry Entry
    local telemetry: TransitionTelemetry = {
        From = oldState,
        To = newState,
        Reason = reason or "Standard Transition",
        Source = source or "Engine",
        Timestamp = now,
        DurationInPrev = durationInPrev,
    }
    table.insert(self.TelemetryLogs, 1, telemetry)
    if #self.TelemetryLogs > self.MaxTelemetryLogs then
        table.remove(self.TelemetryLogs)
    end

    self.PreviousState = oldState
    self.CurrentState = newState
    self.StateStartTime = now
    self.TransitionsCount += 1

    local newDef = self._states[newState]
    if newDef and newDef.OnEnter then
        if self._logger then
            self._logger:SafeCall("FSM.OnEnter", newDef.OnEnter, newDef, oldState, ctx, reason)
        else
            pcall(newDef.OnEnter, newDef, oldState, ctx, reason)
        end
    end

    self.StateChanged:Fire(newState, oldState, telemetry)
    return true
end

function StateMachine:Rollback(ctx: any): boolean
    if #self.History > 0 then
        local prev = table.remove(self.History, 1)
        return self:TransitionTo(prev, ctx, "FSM Rollback", "FSM", true)
    end
    return false
end

function StateMachine:Update(dt: number, ctx: any)
    local def = self._states[self.CurrentState]
    if def then
        -- Timeout Auto-Recovery Guard (Prevents getting permanently stuck in transient special states)
        if def.Timeout and (os.clock() - self.StateStartTime) > def.Timeout then
            local fallback = def.FallbackState or "IDLE"
            if self._logger then
                self._logger:Warn("FSM", string.format("State '%s' timed out (> %.1fs), auto-recovering to '%s'", self.CurrentState, def.Timeout, fallback))
            end
            self:TransitionTo(fallback, ctx, "State Timeout Recovery", "FSM", true)
            return
        end

        if def.OnUpdate then
            if self._logger then
                self._logger:SafeCall("FSM.OnUpdate", def.OnUpdate, def, dt, ctx)
            else
                pcall(def.OnUpdate, def, dt, ctx)
            end
        end
    end
end

return StateMachine

end
__modules["Architecture/StateMachine"] = __modules["Architecture.StateMachine"]

-- ============================================================================
-- Module: Bootstrap
-- ============================================================================
__modules["Bootstrap"] = function()
--!strict
local ServiceContainer = require("Core.ServiceContainer")
local Signal = require("Core.Signal")
local EventBus = require("Core.EventBus")
local Logger = require("Core.Logger")
local Maid = require("Core.Maid")
local Scheduler = require("Core.Scheduler")
local StateMachine = require("Architecture.StateMachine")
local FeatureManager = require("Architecture.FeatureManager")
local Profiler = require("Performance.Profiler")
local CacheEngine = require("Performance.Cache")
local ObjectPool = require("Performance.ObjectPool")
local ConfigManager = require("Config.ConfigManager")
local NetworkEngine = require("Network.NetworkEngine")
local RemoteResolver = require("Network.RemoteResolver")
local Combat = require("Systems.Combat")
local Movement = require("Systems.Movement")
local Survival = require("Systems.Survival")
local Skills = require("Systems.Skills")
local World = require("Systems.World")
local Visuals = require("Systems.Visuals")
local EnemyState = require("Systems.EnemyState")
local UnitTests = require("Diagnostics.UnitTests")
local SelfDiagnostics = require("Diagnostics.SelfDiagnostics")

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Bootstrap = {
    _maid = nil :: any,
    _isInitialized = false,
    Container = nil :: any,
}

function Bootstrap:Init()
    if self._isInitialized then
        -- Prevent Duplicate Loops: Destroy previous instance symmetrically
        self:Destroy()
    end

    self._maid = Maid.new()
    self._isInitialized = true

    local logger = Logger.new(3)
    logger:Info("Bootstrap", "=== 4080 HUB v9.0 PRODUCTION SPECIALIST FRAMEWORK BOOTING ===")

    -- 1. Create Core Instances (Instance-based OOP Architecture)
    local container = ServiceContainer.new()
    self.Container = container
    local eventBus = EventBus.new()
    local scheduler = Scheduler.new()
    local profiler = Profiler.new()
    local cache = CacheEngine.new(0.08)
    local fsm = StateMachine.new("IDLE", logger)
    local featureManager = FeatureManager.new(logger, profiler)
    local configManager = ConfigManager.new(logger)
    local diagnostics = SelfDiagnostics.new(logger)

    -- 2. Register Core Singletons into IoC Container
    container:Register("Logger", logger, {})
    container:Register("EventBus", eventBus, { "Logger" })
    container:Register("Scheduler", scheduler, { "Logger" })
    container:Register("Profiler", profiler, {})
    container:Register("Cache", cache, {})
    container:Register("StateMachine", fsm, { "Logger" })
    container:Register("FeatureManager", featureManager, { "Logger", "Profiler" })
    container:Register("ConfigManager", configManager, { "Logger" })
    container:Register("Diagnostics", diagnostics, { "Logger" })
    container:Register("ObjectPool", ObjectPool, {})

    -- 3. Register Systems via True Constructor Dependency Injection with Explicit DAG Dependencies
    container:Register("RemoteResolver", function(c)
        return RemoteResolver.new(c:Get("Logger"))
    end, { "Logger" })

    container:Register("NetworkEngine", function(c)
        return NetworkEngine.new({
            Logger = c:Get("Logger"),
            EventBus = c:Get("EventBus"),
            RemoteResolver = c:Get("RemoteResolver"),
        })
    end, { "Logger", "EventBus", "RemoteResolver" })

    container:Register("EnemyState", function(c)
        return EnemyState.new({
            Cache = c:Get("Cache"),
            EventBus = c:Get("EventBus"),
            Logger = c:Get("Logger"),
        })
    end, { "Cache", "EventBus", "Logger" })

    container:Register("Combat", function(c)
        return Combat.new({
            Cache = c:Get("Cache"),
            EventBus = c:Get("EventBus"),
            Network = c:Get("NetworkEngine"),
            EnemyState = c:Get("EnemyState"),
            Logger = c:Get("Logger"),
            StateMachine = c:Get("StateMachine"),
        })
    end, { "Cache", "EventBus", "NetworkEngine", "EnemyState", "Logger", "StateMachine" })

    container:Register("Movement", function(c)
        return Movement.new({
            Cache = c:Get("Cache"),
            Logger = c:Get("Logger"),
        })
    end, { "Cache", "Logger" })

    container:Register("Survival", function(c)
        return Survival.new({
            Cache = c:Get("Cache"),
            StateMachine = c:Get("StateMachine"),
            EventBus = c:Get("EventBus"),
            Logger = c:Get("Logger"),
        })
    end, { "Cache", "StateMachine", "EventBus", "Logger" })

    container:Register("Skills", function(c)
        return Skills.new({
            Cache = c:Get("Cache"),
            Combat = c:Get("Combat"),
            Logger = c:Get("Logger"),
        })
    end, { "Cache", "Combat", "Logger" })

    container:Register("World", function(c)
        return World.new({
            ConfigManager = c:Get("ConfigManager"),
            Logger = c:Get("Logger"),
        })
    end, { "ConfigManager", "Logger" })

    container:Register("Visuals", function(c)
        return Visuals.new({
            Cache = c:Get("Cache"),
            ObjectPool = ObjectPool,
            Logger = c:Get("Logger"),
        })
    end, { "Cache", "ObjectPool", "Logger" })

    -- 4. Run Diagnostics & Automated Unit Tests on Isolated Instances
    diagnostics:RunHealthCheck()
    local testsPassed, testResults = UnitTests.RunAll()
    logger:Info("Bootstrap", string.format("Automated Isolated Test Suite: %s", testsPassed and "100% PASSED" or "TESTS FAILED"))

    -- 5. Topological DAG Resolution of All Systems
    local initOrder = container:ResolveAllInOrder()
    logger:Info("Bootstrap", string.format("DAG Resolution Complete. Initialized %d services in topological order.", #initOrder))

    local network = container:Get("NetworkEngine")
    network:Init()
    self._maid:GiveTask(function() network:Destroy() end)

    -- Event-Driven Cache Invalidation connected to Root Maid
    cache:HookWorkspaceEvents(self._maid)

    local combat = container:Get("Combat")
    local movement = container:Get("Movement")
    local survival = container:Get("Survival")
    local skills = container:Get("Skills")
    local world = container:Get("World")
    local visuals = container:Get("Visuals")
    local enemyState = container:Get("EnemyState")

    -- 6. Load Config
    configManager:Load()

    -- 7. Active Scheduler Tasks Registration (Tiered Frequencies)
    scheduler:Register("Aimlock_Fast", "Fast", function(dt)
        combat:UpdateAimlock(configManager.Config)
    end)

    scheduler:Register("EnemyState_Normal", "Normal", function(dt)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer then
                enemyState:Update(p)
            end
        end
    end)

    scheduler:Register("WorldHop_Slow", "Slow", function(dt)
        world:CheckAutoServerHop(configManager.Config)
    end)

    scheduler:Register("Telemetry_Slow", "Slow", function(dt)
        profiler:UpdateSystemMetrics()
    end)

    scheduler:Register("ConfigAutosave_Background", "Background", function(dt)
        configManager:Save()
    end)

    -- 8. Register and Validate Feature Pipelines
    featureManager:Register({
        Name = "FlyMovement",
        Phase = "RenderStepped",
        Priority = 90,
        Budget = 1.0,
        Dependencies = { "Movement", "Cache" },
        Enabled = true,
        Update = function(self, dt, ctx) movement:UpdateFly(dt, configManager.Config) end
    })

    featureManager:Register({
        Name = "CombatEngine",
        Phase = "Heartbeat",
        Priority = 100,
        Budget = 2.0,
        Dependencies = { "Combat", "Cache", "EnemyState" },
        Enabled = true,
        Update = function(self, dt, ctx)
            combat:UpdateAutoM1(configManager.Config)
            combat:UpdateAutoBlock(configManager.Config)
            combat:UpdateHitboxExpander(configManager.Config)
        end
    })

    featureManager:Register({
        Name = "MovementEngine",
        Phase = "Heartbeat",
        Priority = 90,
        Budget = 1.0,
        Dependencies = { "Movement" },
        Enabled = true,
        Update = function(self, dt, ctx)
            movement:UpdateSpeed(dt, configManager.Config)
            movement:UpdateAntiVoid(configManager.Config)
        end
    })

    featureManager:Register({
        Name = "SurvivalEngine",
        Phase = "Heartbeat",
        Priority = 85,
        Budget = 1.5,
        Dependencies = { "Survival", "StateMachine" },
        Enabled = true,
        Update = function(self, dt, ctx)
            survival:UpdateSkyDodge(dt, configManager.Config)
            survival:CheckSkyEscape(configManager.Config)
        end
    })

    featureManager:Register({
        Name = "VisualsEngine",
        Phase = "Heartbeat",
        Priority = 70,
        Budget = 2.0,
        Dependencies = { "Visuals", "Cache" },
        Enabled = true,
        Update = function(self, dt, ctx)
            visuals:Update(configManager.Config)
        end
    })

    -- Validate all feature dependencies in DI container
    local depsOk, depReport = featureManager:ValidateDependencies(container)
    logger:Info("Bootstrap", string.format("Feature Dependency Graph: %s", depsOk and "ALL SATISFIED" or "DEGRADED ISOLATION ACTIVE"))

    featureManager:InitAll(container)
    self._maid:GiveTask(function() featureManager:DestroyAll() end)

    -- 9. Connect Game Loop Pipelines & Store Connections in Root Maid
    local rsConn = RunService.RenderStepped:Connect(function(dt)
        featureManager:ExecutePipeline("RenderStepped", dt, container)
    end)
    self._maid:GiveTask(rsConn)

    local stConn = RunService.Stepped:Connect(function()
        movement:UpdateNoclip(configManager.Config)
        featureManager:ExecutePipeline("Stepped", 1/60, container)
    end)
    self._maid:GiveTask(stConn)

    local hbConn = RunService.Heartbeat:Connect(function(dt)
        fsm:Update(dt, container)
        scheduler:Step(dt)
        featureManager:ExecutePipeline("Heartbeat", dt, container)
    end)
    self._maid:GiveTask(hbConn)

    logger:Info("Bootstrap", "=== 4080 HUB FRAMEWORK FULLY OPERATIONAL (SPECIALIST PRODUCTION ARCHITECTURE) ===")
end

function Bootstrap:Destroy()
    if self._maid then
        self._maid:DoCleaning()
        self._maid = nil
    end
    self._isInitialized = false
end

function Bootstrap:GetDiagnostics(): { [string]: any }
    if not self._isInitialized or not self.Container then
        return { Status = "Uninitialized", Initialized = false }
    end

    local profiler = self.Container:Get("Profiler")
    local fsm = self.Container:Get("StateMachine")
    local featureManager = self.Container:Get("FeatureManager")
    local cache = self.Container:Get("Cache")
    local network = self.Container:Get("NetworkEngine")

    return {
        Status = "Operational",
        Initialized = true,
        CurrentState = fsm and fsm.CurrentState or "UNKNOWN",
        StateHistory = fsm and fsm.TelemetryLogs or {},
        FeatureStates = featureManager and featureManager.FeatureStates or {},
        Network = {
            IsHooked = network and network._isHooked or false,
            PacketCount = network and network.PacketCount or 0,
            LastGoal = network and network.LastGoal or nil,
        },
        CacheStats = {
            Player = cache and cache.PlayerStats or {},
            Raycast = cache and cache.RaycastStats or {},
        },
        ProfilerReport = profiler and profiler:GetReport() or {},
    }
end

return Bootstrap

end

-- ============================================================================
-- Module: Config.ConfigManager
-- ============================================================================
__modules["Config.ConfigManager"] = function()
--!strict
local ConfigSchema = require("Config.ConfigSchema")
local HttpService = game:GetService("HttpService")

local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager.new(logger: any)
    local self = setmetatable({
        FileName = "4080_Hub_TSB_Config.json",
        Config = {},
        RegisteredUI = {},
        _logger = logger,
        _degradedMode = false,
    }, ConfigManager)

    self:ResetToDefaults()

    if typeof(writefile) ~= "function" or typeof(readfile) ~= "function" then
        self._degradedMode = true
        if self._logger then
            self._logger:Warn("ConfigManager", "Running in In-Memory Degraded Mode (writefile API unsupported)")
        end
    end

    return self
end

function ConfigManager:ResetToDefaults()
    for catName, catSchema in pairs(ConfigSchema) do
        self.Config[catName] = {}
        for key, spec in pairs(catSchema) do
            self.Config[catName][key] = spec.Default
        end
    end
end

function ConfigManager:ValidateAndClamp(data: any): any
    -- Strict Runtime Schema Enforcement with EnumItem type validation
    for catName, catSchema in pairs(ConfigSchema) do
        if type(data[catName]) == "table" then
            for key, spec in pairs(catSchema) do
                local val = data[catName][key]
                if val ~= nil then
                    if spec.Type == "number" then
                        if type(val) == "number" then
                            if spec.Min and spec.Max then
                                data[catName][key] = math.clamp(val, spec.Min, spec.Max)
                            end
                        else
                            data[catName][key] = spec.Default
                        end
                    elseif spec.Type == "boolean" then
                        if type(val) ~= "boolean" then
                            data[catName][key] = spec.Default
                        end
                    elseif spec.Type == "string" then
                        if type(val) ~= "string" then
                            data[catName][key] = spec.Default
                        end
                    elseif spec.Type == "EnumItem" then
                        if typeof(val) == "EnumItem" then
                            if spec.EnumType and val.EnumType ~= spec.EnumType then
                                data[catName][key] = spec.Default
                            end
                        else
                            data[catName][key] = spec.Default
                        end
                    end
                else
                    data[catName][key] = spec.Default
                end
            end
        else
            data[catName] = {}
            for key, spec in pairs(catSchema) do
                data[catName][key] = spec.Default
            end
        end
    end
    return data
end

local function SerializeValue(val: any): any
    if typeof(val) == "Color3" then
        return { __type = "Color3", R = val.R, G = val.G, B = val.B }
    elseif typeof(val) == "EnumItem" then
        return { __type = "EnumItem", EnumType = tostring(val.EnumType), Name = val.Name }
    elseif type(val) == "table" then
        local t = {}
        for k, v in pairs(val) do t[tostring(k)] = SerializeValue(v) end
        return t
    else
        return val
    end
end

local function DeserializeValue(val: any): any
    if type(val) == "table" then
        if val.__type == "Color3" then
            return Color3.new(val.R or 0, val.G or 0, val.B or 0)
        elseif val.__type == "EnumItem" then
            local enumTypeStr = val.EnumType or ""
            local enumName = val.Name or ""
            if enumTypeStr:find("KeyCode") and Enum.KeyCode[enumName] then
                return Enum.KeyCode[enumName]
            elseif enumTypeStr:find("UserInputType") and Enum.UserInputType[enumName] then
                return Enum.UserInputType[enumName]
            end
            return val
        else
            local t = {}
            for k, v in pairs(val) do t[k] = DeserializeValue(v) end
            return t
        end
    else
        return val
    end
end

function ConfigManager:Save(): (boolean, string?)
    if self._degradedMode then
        return true, "In-Memory"
    end
    self:ValidateAndClamp(self.Config)

    local ok, err = pcall(function()
        local dataToSave = {}
        for cat, val in pairs(self.Config) do
            dataToSave[cat] = SerializeValue(val)
        end
        local json = HttpService:JSONEncode(dataToSave)
        writefile(self.FileName, json)
    end)
    if ok and self._logger then self._logger:Info("Config", "Saved validated config to disk.") end
    return ok, err
end

function ConfigManager:Load(): (boolean, string?)
    if self._degradedMode or not isfile(self.FileName) then
        return false, "Config file not found or degraded"
    end
    local ok, err = pcall(function()
        local raw = readfile(self.FileName)
        local rawData = HttpService:JSONDecode(raw)
        local decoded = DeserializeValue(rawData)
        self:ValidateAndClamp(decoded)
        self.Config = decoded
        self:RefreshUI()
    end)
    if ok and self._logger then self._logger:Info("Config", "Loaded and validated config from disk.") end
    return ok, err
end

function ConfigManager:RefreshUI()
    for _, item in ipairs(self.RegisteredUI) do
        if item.Getter and item.Setter then
            pcall(function()
                local val = item.Getter()
                if val ~= nil then item.Setter(val) end
            end)
        end
    end
end

function ConfigManager:Reset()
    if typeof(delfile) == "function" and isfile(self.FileName) then
        pcall(function() delfile(self.FileName) end)
    end
    self:ResetToDefaults()
    self:RefreshUI()
end

return ConfigManager

end
__modules["Config/ConfigManager"] = __modules["Config.ConfigManager"]

-- ============================================================================
-- Module: Config.ConfigSchema
-- ============================================================================
__modules["Config.ConfigSchema"] = function()
--!strict
local ConfigSchema = {
    Combat = {
        Aimlock            = { Type = "boolean", Default = false },
        AimlockMode        = { Type = "string",  Default = "Body Only (No Screen Spin)" },
        AimPart            = { Type = "string",  Default = "HumanoidRootPart" },
        AimMode            = { Type = "string",  Default = "Nearest" },
        AimMaxRange        = { Type = "number",  Default = 300, Min = 50, Max = 1000 },
        AutoM1             = { Type = "boolean", Default = false },
        AutoM1Delay        = { Type = "number",  Default = 0.12, Min = 0.05, Max = 0.5 },
        AutoParry          = { Type = "boolean", Default = false },
        PacketParry        = { Type = "boolean", Default = true },
        PredictiveAim      = { Type = "boolean", Default = true },
        AutoComboSequencer = { Type = "boolean", Default = false },
        ComboMode          = { Type = "string",  Default = "Saitama Max Damage" },
        FrameTrapWakeup    = { Type = "boolean", Default = true },
        HitboxExpander     = { Type = "boolean", Default = false },
        HitboxSize         = { Type = "number",  Default = 16, Min = 4, Max = 35 },
        AntiCounterBait    = { Type = "boolean", Default = true },
        AntiRagdoll        = { Type = "boolean", Default = false },
        AutoEvasive        = { Type = "boolean", Default = false },
        MassBringEnabled   = { Type = "boolean", Default = true },
        MassBringMode      = { Type = "string",  Default = "FE Real Damage (Blitz)" },
        MassBringDistance  = { Type = "number",  Default = 20, Min = 5, Max = 50 },
        MassBringDuration  = { Type = "number",  Default = 10, Min = 3, Max = 30 },
    },
    Target = {
        TargetMode         = { Type = "string",  Default = "Nearest" },
        BehindTP           = { Type = "boolean", Default = false },
        BehindDistance     = { Type = "number",  Default = 3.5, Min = 1.5, Max = 8 },
        AutoM1OnTP         = { Type = "boolean", Default = true },
    },
    Skills = {
        AutoAim            = { Type = "boolean", Default = true },
        AutoSkillSpam      = { Type = "boolean", Default = false },
        SkillSpamDelay     = { Type = "number",  Default = 0.25, Min = 0.1, Max = 1.0 },
        AutoUltSpam        = { Type = "boolean", Default = false },
        VoidKill           = { Type = "boolean", Default = false },
        VoidDepth          = { Type = "number",  Default = -350, Min = -500, Max = -100 },
        VoidReturnDelay    = { Type = "number",  Default = 0.5, Min = 0.2, Max = 2.0 },
    },
    Survival = {
        SkyTeleport        = { Type = "boolean", Default = false },
        SkyEscapeHP        = { Type = "number",  Default = 30, Min = 10, Max = 60 },
        SkyReturnHP        = { Type = "number",  Default = 80, Min = 50, Max = 100 },
        SkyEscapeHeight    = { Type = "number",  Default = 180, Min = 50, Max = 400 },
        SkyDodge           = { Type = "boolean", Default = false },
        SkyDodgeHeight     = { Type = "number",  Default = 65, Min = 20, Max = 150 },
        SkyDodgeRange      = { Type = "number",  Default = 18, Min = 5, Max = 30 },
        SkyDodgeLockCamera = { Type = "boolean", Default = true },
    },
    Movement = {
        Fly                = { Type = "boolean", Default = false },
        FlySpeed           = { Type = "number",  Default = 60, Min = 10, Max = 200 },
        FlyMode            = { Type = "string",  Default = "CFrame" },
        SpeedBoost         = { Type = "boolean", Default = false },
        SpeedVal           = { Type = "number",  Default = 42, Min = 16, Max = 150 },
        InfiniteJump       = { Type = "boolean", Default = false },
        DoubleJump         = { Type = "boolean", Default = false },
        Noclip             = { Type = "boolean", Default = false },
        AntiVoid           = { Type = "boolean", Default = true },
    },
    Visuals = {
        HighlightESP       = { Type = "boolean", Default = false },
        BillboardESP       = { Type = "boolean", Default = false },
        ShowCharacterESP   = { Type = "boolean", Default = true },
        ShowUltiESP        = { Type = "boolean", Default = true },
        DeathCounterRisk   = { Type = "boolean", Default = true },
        Tracers            = { Type = "boolean", Default = false },
        TracerOrigin       = { Type = "string",  Default = "Bottom" },
        FOVCircle          = { Type = "boolean", Default = false },
    },
    World = {
        FullBright         = { Type = "boolean", Default = false },
        RemoveFog          = { Type = "boolean", Default = false },
        CustomFOV          = { Type = "boolean", Default = false },
        FOVValue           = { Type = "number",  Default = 90, Min = 60, Max = 120 },
        AntiAFK            = { Type = "boolean", Default = true },
        AutoServerHop      = { Type = "boolean", Default = true },
        AutoHopMinPlayers  = { Type = "number",  Default = 4, Min = 2, Max = 8 },
    },
    UI = {
        IsOpen             = { Type = "boolean", Default = true },
        AccentName         = { Type = "string",  Default = "Cyan Neon" },
    },
    Keybinds = {
        ToggleGUI          = { Type = "EnumItem", EnumType = Enum.KeyCode, Default = Enum.KeyCode.RightControl },
        ToggleFly          = { Type = "EnumItem", EnumType = Enum.KeyCode, Default = Enum.KeyCode.F5 },
        ToggleNoclip       = { Type = "EnumItem", EnumType = Enum.KeyCode, Default = Enum.KeyCode.F6 },
        ToggleAimlock      = { Type = "EnumItem", EnumType = Enum.KeyCode, Default = Enum.KeyCode.F7 },
        ToggleBehindTP     = { Type = "EnumItem", EnumType = Enum.KeyCode, Default = Enum.KeyCode.F9 },
        ToggleSkyDodge     = { Type = "EnumItem", EnumType = Enum.KeyCode, Default = Enum.KeyCode.H },
        EmergencyStop      = { Type = "EnumItem", EnumType = Enum.KeyCode, Default = Enum.KeyCode.Delete },
        MassBringKey       = { Type = "EnumItem", EnumType = Enum.KeyCode, Default = Enum.KeyCode.G },
    }
}

return ConfigSchema

end
__modules["Config/ConfigSchema"] = __modules["Config.ConfigSchema"]

-- ============================================================================
-- Module: Core.EventBus
-- ============================================================================
__modules["Core.EventBus"] = function()
--!strict
local Signal = require("Core.Signal")

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
    local self = setmetatable({
        _events = {},
        _history = {},
        _maxHistory = 25,
    }, EventBus)
    return self
end

function EventBus:Subscribe(eventName: string, callback: (...any) -> ())
    if not self._events[eventName] then
        self._events[eventName] = Signal.new()
    end
    return self._events[eventName]:Connect(callback)
end

function EventBus:Publish(eventName: string, ...: any)
    if not self._history[eventName] then
        self._history[eventName] = {}
    end
    local entry = { Timestamp = os.clock(), Data = { ... } }
    table.insert(self._history[eventName], 1, entry)
    if #self._history[eventName] > self._maxHistory then
        table.remove(self._history[eventName])
    end

    if self._events[eventName] then
        self._events[eventName]:Fire(...)
    end
end

function EventBus:PublishSync(eventName: string, ...: any)
    if not self._history[eventName] then
        self._history[eventName] = {}
    end
    local entry = { Timestamp = os.clock(), Data = { ... } }
    table.insert(self._history[eventName], 1, entry)
    if #self._history[eventName] > self._maxHistory then
        table.remove(self._history[eventName])
    end

    if self._events[eventName] then
        self._events[eventName]:FireSync(...)
    end
end

function EventBus:GetHistory(eventName: string)
    return self._history[eventName] or {}
end

function EventBus:Clear()
    for _, sig in pairs(self._events) do
        sig:Destroy()
    end
    table.clear(self._events)
    table.clear(self._history)
end

return EventBus

end
__modules["Core/EventBus"] = __modules["Core.EventBus"]

-- ============================================================================
-- Module: Core.Logger
-- ============================================================================
__modules["Core.Logger"] = function()
--!strict
local Logger = {}
Logger.__index = Logger

local LevelNames = {
    [1] = "TRACE",
    [2] = "DEBUG",
    [3] = "INFO",
    [4] = "WARN",
    [5] = "ERROR",
    [6] = "FATAL"
}

function Logger.new(initialLevel: (number | string)?)
    local self = setmetatable({
        Level = 3,
        History = {},
        MaxHistory = 100,
        OnLog = nil,
    }, Logger)
    if initialLevel then
        self:SetLevel(initialLevel)
    end
    return self
end

function Logger:SetLevel(level: number | string)
    if type(level) == "string" then
        for k, v in pairs(LevelNames) do
            if v == level:upper() then
                self.Level = k
                return
            end
        end
    elseif type(level) == "number" then
        self.Level = math.clamp(level, 1, 6)
    end
end

function Logger:_Log(level: number, tag: string, message: any)
    if level < self.Level then return end
    local levelStr = LevelNames[level] or "INFO"
    local timestamp = os.date("%X")
    local formatted = string.format("[%s] [%s] [%s] %s", timestamp, levelStr, tag, tostring(message))

    table.insert(self.History, 1, formatted)
    if #self.History > self.MaxHistory then
        table.remove(self.History)
    end

    if level >= 5 then
        warn(formatted)
    else
        print(formatted)
    end

    if self.OnLog then
        pcall(self.OnLog, formatted, level, tag)
    end
end

function Logger:Trace(tag: string, message: any) self:_Log(1, tag, message) end
function Logger:Debug(tag: string, message: any) self:_Log(2, tag, message) end
function Logger:Info(tag: string, message: any)  self:_Log(3, tag, message) end
function Logger:Warn(tag: string, message: any)  self:_Log(4, tag, message) end
function Logger:Error(tag: string, message: any) self:_Log(5, tag, message) end
function Logger:Fatal(tag: string, message: any) self:_Log(6, tag, message) end

function Logger:SafeCall(tag: string, fn: (...any) -> ...any, ...: any): (boolean, ...any)
    local results = { pcall(fn, ...) }
    local success = results[1]
    if not success then
        local err = tostring(results[2])
        local trace = debug.traceback()
        self:Error(tag, string.format("SafeCall Failed: %s\nTrace: %s", err, trace))
    end
    return table.unpack(results)
end

return Logger

end
__modules["Core/Logger"] = __modules["Core.Logger"]

-- ============================================================================
-- Module: Core.Maid
-- ============================================================================
__modules["Core.Maid"] = function()
--!strict
local Maid = {}
Maid.__index = Maid

export type Task = (() -> ()) | RBXScriptConnection | { Disconnect: (any) -> () } | { Destroy: (any) -> () } | Instance

function Maid.new()
    local self = setmetatable({
        _tasks = {},
    }, Maid)
    return self
end

function Maid:GiveTask(taskItem: Task): any
    assert(taskItem ~= nil, "Task cannot be nil")
    local taskId = #self._tasks + 1
    self._tasks[taskId] = taskItem
    return taskId
end

function Maid:DoCleaning()
    local tasks = self._tasks
    for index, taskItem in pairs(tasks) do
        if typeof(taskItem) == "RBXScriptConnection" then
            taskItem:Disconnect()
        elseif type(taskItem) == "function" then
            pcall(taskItem)
        elseif typeof(taskItem) == "Instance" then
            pcall(function() taskItem:Destroy() end)
        elseif type(taskItem) == "table" then
            if type(taskItem.Destroy) == "function" then
                pcall(function() taskItem:Destroy() end)
            elseif type(taskItem.Disconnect) == "function" then
                pcall(function() taskItem:Disconnect() end)
            elseif type(taskItem.DoCleaning) == "function" then
                pcall(function() taskItem:DoCleaning() end)
            end
        end
        tasks[index] = nil
    end
end

function Maid:Destroy()
    self:DoCleaning()
end

return Maid

end
__modules["Core/Maid"] = __modules["Core.Maid"]

-- ============================================================================
-- Module: Core.Scheduler
-- ============================================================================
__modules["Core.Scheduler"] = function()
--!strict
local Scheduler = {}
Scheduler.__index = Scheduler

export type TaskDefinition = {
    Category: string,
    Callback: (dt: number) -> (),
    LastRun: number,
    Enabled: boolean,
    ExecutionCount: number,
}

function Scheduler.new()
    local self = setmetatable({
        _intervals = {
            Fast       = 1 / 60, -- Exact 60 Hz interval (~0.0166s)
            Normal     = 0.05,   -- 20 Hz
            Slow       = 0.5,    -- 2 Hz
            Background = 2.0,    -- 0.5 Hz
        },
        _tasks = {},
    }, Scheduler)
    return self
end

function Scheduler:Register(name: string, category: string, callback: (dt: number) -> (), enabled: boolean?)
    self._tasks[name] = {
        Category = category or "Normal",
        Callback = callback,
        LastRun = 0,
        Enabled = enabled ~= false,
        ExecutionCount = 0,
    }
end

function Scheduler:SetEnabled(name: string, enabled: boolean)
    if self._tasks[name] then
        self._tasks[name].Enabled = enabled
    end
end

function Scheduler:Step(dt: number)
    local now = os.clock()
    for _, taskItem in pairs(self._tasks) do
        if taskItem.Enabled then
            local interval = self._intervals[taskItem.Category] or 0.05
            if (now - taskItem.LastRun) >= interval then
                local taskDt = taskItem.LastRun == 0 and dt or (now - taskItem.LastRun)
                taskItem.LastRun = now
                taskItem.ExecutionCount += 1
                pcall(taskItem.Callback, taskDt)
            end
        end
    end
end

function Scheduler:GetTaskStats(): { [string]: { Category: string, Executions: number, Enabled: boolean } }
    local stats = {}
    for name, item in pairs(self._tasks) do
        stats[name] = {
            Category = item.Category,
            Executions = item.ExecutionCount,
            Enabled = item.Enabled,
        }
    end
    return stats
end

return Scheduler

end
__modules["Core/Scheduler"] = __modules["Core.Scheduler"]

-- ============================================================================
-- Module: Core.ServiceContainer
-- ============================================================================
__modules["Core.ServiceContainer"] = function()
--!strict
local ServiceContainer = {}
ServiceContainer.__index = ServiceContainer

export type ServiceEntry = {
    Name: string,
    Instance: any?,
    Factory: ((container: any) -> any)?,
    Dependencies: { string },
    Resolved: boolean,
}

function ServiceContainer.new()
    local self = setmetatable({
        _services = {},
        _factories = {},
        _dependencies = {}, -- Adjacency list for real DAG
        _resolving = {},
    }, ServiceContainer)
    return self
end

function ServiceContainer:Register(name: string, instanceOrFactory: any, dependencies: { string }?)
    assert(name and instanceOrFactory, "ServiceContainer:Register requires name and instance/factory")
    local deps = dependencies or {}
    self._dependencies[name] = deps

    if type(instanceOrFactory) == "function" then
        self._factories[name] = instanceOrFactory
    else
        self._services[name] = instanceOrFactory
    end
    return instanceOrFactory
end

function ServiceContainer:Get(name: string): any
    if self._services[name] then
        return self._services[name]
    end

    if self._factories[name] then
        if self._resolving[name] then
            error(string.format("[ServiceContainer] Circular dependency detected while resolving service '%s'!", name))
        end

        self._resolving[name] = true
        local factory = self._factories[name]
        local instance = factory(self)
        self._resolving[name] = nil

        self._services[name] = instance
        self._factories[name] = nil
        return instance
    end

    error(string.format("[ServiceContainer] Service '%s' is not registered!", tostring(name)))
end

function ServiceContainer:Has(name: string): boolean
    return self._services[name] ~= nil or self._factories[name] ~= nil
end

function ServiceContainer:BuildGraph(): { [string]: { string } }
    local graph = {}
    for name, deps in pairs(self._dependencies) do
        graph[name] = deps
    end
    return graph
end

-- Kahn's Algorithm / Topological Sort for Dependency Graph
-- Resolves services in dependency-first order and detects any cyclic dependencies
function ServiceContainer:TopologicalSort(): ({ string }, boolean, string?)
    local inDegree = {}
    local adjList = {}
    local allNodes = {}

    -- Collect all registered nodes
    for name, _ in pairs(self._dependencies) do
        allNodes[name] = true
        inDegree[name] = 0
        adjList[name] = {}
    end
    for name, _ in pairs(self._services) do
        if not allNodes[name] then
            allNodes[name] = true
            inDegree[name] = 0
            adjList[name] = {}
        end
    end
    for name, _ in pairs(self._factories) do
        if not allNodes[name] then
            allNodes[name] = true
            inDegree[name] = 0
            adjList[name] = {}
        end
    end

    -- Build adjacency list: if A depends on B, edge is B -> A (B must resolve before A)
    for node, deps in pairs(self._dependencies) do
        for _, dep in ipairs(deps) do
            if allNodes[dep] then
                table.insert(adjList[dep], node)
                inDegree[node] = (inDegree[node] or 0) + 1
            end
        end
    end

    -- Queue for nodes with in-degree 0 (no unresolved dependencies)
    local queue = {}
    for node, deg in pairs(inDegree) do
        if deg == 0 then
            table.insert(queue, node)
        end
    end

    local order = {}
    while #queue > 0 do
        local curr = table.remove(queue, 1)
        table.insert(order, curr)

        for _, neighbor in ipairs(adjList[curr] or {}) do
            inDegree[neighbor] -= 1
            if inDegree[neighbor] == 0 then
                table.insert(queue, neighbor)
            end
        end
    end

    -- If order contains all nodes, no cycles exist; otherwise a cycle was detected
    local totalCount = 0
    for _ in pairs(allNodes) do totalCount += 1 end

    local hasCycle = (#order < totalCount)
    local cycleNode = nil
    if hasCycle then
        for node, deg in pairs(inDegree) do
            if deg > 0 then
                cycleNode = node
                break
            end
        end
    end

    return order, not hasCycle, cycleNode
end

function ServiceContainer:ResolveAllInOrder(): { string }
    local order, noCycles, cycleNode = self:TopologicalSort()
    if not noCycles then
        error(string.format("[ServiceContainer] Cannot initialize services due to circular dependency involving '%s'!", tostring(cycleNode)))
    end

    for _, sName in ipairs(order) do
        self:Get(sName)
    end
    return order
end

return ServiceContainer

end
__modules["Core/ServiceContainer"] = __modules["Core.ServiceContainer"]

-- ============================================================================
-- Module: Core.Signal
-- ============================================================================
__modules["Core.Signal"] = function()
--!strict
local Signal = {}
Signal.__index = Signal

export type Connection = {
    Disconnect: (self: Connection) -> (),
    Connected: boolean,
}

export type Signal = {
    Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
    Fire: (self: Signal, ...any) -> (),
    Wait: (self: Signal) -> ...any,
    Destroy: (self: Signal) -> (),
    GetListenerCount: (self: Signal) -> number,
}

function Signal.new(): Signal
    local self = setmetatable({
        _listeners = {},
        _listenerCount = 0,
    }, Signal)
    return (self :: any) :: Signal
end

function Signal:Connect(callback: (...any) -> ()): Connection
    assert(type(callback) == "function", "Signal:Connect requires a function")
    local connection = {
        _callback = callback,
        _signal = self,
        Connected = true,
    }
    function connection:Disconnect()
        if not self.Connected then return end
        self.Connected = false
        if self._signal then
            self._signal._listeners[self] = nil
            self._signal._listenerCount = math.max(0, self._signal._listenerCount - 1)
        end
    end
    self._listeners[connection] = true
    self._listenerCount += 1
    return connection
end

function Signal:Fire(...: any)
    for connection in pairs(self._listeners) do
        if connection.Connected and connection._callback then
            task.spawn(connection._callback, ...)
        end
    end
end

-- Synchronous Fire: executes callbacks immediately in the calling thread
function Signal:FireSync(...: any)
    for connection in pairs(self._listeners) do
        if connection.Connected and connection._callback then
            local ok, err = pcall(connection._callback, ...)
            if not ok then
                warn(string.format("[Signal] Error in synchronous listener: %s", tostring(err)))
            end
        end
    end
end

function Signal:Wait(): ...any
    local thread = coroutine.running()
    local conn
    conn = self:Connect(function(...)
        conn:Disconnect()
        task.spawn(thread, ...)
    end)
    return coroutine.yield()
end

function Signal:GetListenerCount(): number
    return self._listenerCount
end

function Signal:Destroy()
    for connection in pairs(self._listeners) do
        connection.Connected = false
    end
    table.clear(self._listeners)
    self._listenerCount = 0
end

return Signal

end
__modules["Core/Signal"] = __modules["Core.Signal"]

-- ============================================================================
-- Module: Diagnostics.SelfDiagnostics
-- ============================================================================
__modules["Diagnostics.SelfDiagnostics"] = function()
--!strict
local SelfDiagnostics = {}
SelfDiagnostics.__index = SelfDiagnostics

function SelfDiagnostics.new(logger: any)
    local self = setmetatable({
        _logger = logger,
        DegradedModes = {
            Network = false,
            Config = false,
            Visuals = false,
        }
    }, SelfDiagnostics)
    return self
end

function SelfDiagnostics:RunHealthCheck(): (boolean, { [string]: string })
    local report = {}
    local isHealthy = true

    local requiredServices = { "Players", "RunService", "UserInputService", "Workspace", "HttpService" }
    for _, sName in ipairs(requiredServices) do
        local ok, s = pcall(function() return game:GetService(sName) end)
        if ok and s then
            report["Service_" .. sName] = "OK"
        else
            report["Service_" .. sName] = "MISSING"
            isHealthy = false
        end
    end

    -- Real Degraded Fallback Assessment
    if typeof(hookmetamethod) ~= "function" then
        self.DegradedModes.Network = true
        report["API_hookmetamethod"] = "UNSUPPORTED (Degraded Network Mode)"
    else
        report["API_hookmetamethod"] = "AVAILABLE"
    end

    if typeof(writefile) ~= "function" then
        self.DegradedModes.Config = true
        report["API_writefile"] = "UNSUPPORTED (Degraded In-Memory Config)"
    else
        report["API_writefile"] = "AVAILABLE"
    end

    if typeof(Drawing) ~= "table" or Drawing.new == nil then
        self.DegradedModes.Visuals = true
        report["API_Drawing"] = "UNSUPPORTED (Degraded Visuals Mode)"
    else
        report["API_Drawing"] = "AVAILABLE"
    end

    self._logger:Info("SelfDiagnostics", string.format("Health Check Complete. Status: %s", isHealthy and "HEALTHY" or "DEGRADED"))
    return isHealthy, report
end

return SelfDiagnostics

end
__modules["Diagnostics/SelfDiagnostics"] = __modules["Diagnostics.SelfDiagnostics"]

-- ============================================================================
-- Module: Diagnostics.UnitTests
-- ============================================================================
__modules["Diagnostics.UnitTests"] = function()
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

    -- 1. Deterministic Signal Test (Synchronous & Async)
    local sig = Signal.new()
    local sigVal = nil
    local conn = sig:Connect(function(v) sigVal = v end)
    sig:FireSync(42) -- Deterministic immediate dispatch
    conn:Disconnect()
    sig:FireSync(99)
    sig:Destroy()
    results["Signal_DeterministicSyncTest"] = (sigVal == 42)

    -- 2. Deterministic EventBus Test
    local eb = EventBus.new()
    local ebReceived = false
    local ebConn = eb:Subscribe("Test.Event", function(d) if d == "OK" then ebReceived = true end end)
    eb:PublishSync("Test.Event", "OK")
    ebConn:Disconnect()
    eb:Clear()
    results["EventBus_DeterministicSyncTest"] = ebReceived

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

    -- 6. ServiceContainer True Factory DI & Kahn's DAG Topological Sort Test
    local container = ServiceContainer.new()
    container:Register("ServiceA", function(c) return { Name = "A" } end, {})
    container:Register("ServiceB", function(c) return { Dep = c:Get("ServiceA") } end, { "ServiceA" })
    local order, noCycles = container:TopologicalSort()
    local resolvedB = container:Get("ServiceB")
    results["DependencyGraph_KahnTopologicalSortTest"] = (noCycles and resolvedB.Dep.Name == "A")

    -- 7. ObjectPool Double-Release Guard & Telemetry Test
    local pool = ObjectPool.new(function() return { active = true } end, function(o) o.active = false end, 2, 10)
    local item = pool:Acquire()
    pool:Release(item)
    pool:Release(item) -- Double-release attempt
    local telem = pool:GetTelemetry()
    results["ObjectPool_DoubleReleaseGuardTest"] = (item.active == false and telem.InvalidReleases == 1 and telem.AcquireCount == 1)
    pool:Destroy()

    -- 8. Cache Weak-Key Instance ID Map & Invalidation Test
    local cache = CacheEngine.new(0.08)
    cache:Clear()
    local partA = Instance.new("Part")
    local partB = Instance.new("Part")
    local los1 = cache:CachedRaycast(Vector3.new(0,0,0), Vector3.new(0,10,0), { partA })
    local los2 = cache:CachedRaycast(Vector3.new(0,0,0), Vector3.new(0,10,0), { partB })
    cache:InvalidateRaycasts()
    results["Cache_WeakKeyAndInvalidationTest"] = (cache.RaycastStats.Misses == 2 and cache.RaycastStats.Invalidations == 1)
    partA:Destroy()
    partB:Destroy()

    -- 9. Profiler Hysteresis Test
    local profiler = Profiler.new()
    local pStart = profiler:Begin("BudgetTask", 0.001)
    task.wait(0.004)
    profiler:End("BudgetTask", pStart)
    local metric = profiler.Metrics["BudgetTask"]
    results["Profiler_HysteresisTest"] = (metric and metric.Status == "OVER_BUDGET")

    -- 10. Config Strict EnumFamily & Clamping Runtime Validation Test
    local cfg = ConfigManager.new(logger)
    local dirtyData = {
        World = { FOVValue = 99999 },
        Keybinds = {
            ToggleFly = "CorruptedString",         -- String -> Default Enum.KeyCode.F5
            ToggleAimlock = Enum.Material.Plastic, -- Wrong Enum Family -> Default Enum.KeyCode.F7
        }
    }
    cfg:ValidateAndClamp(dirtyData)
    local isEnumCorrect = (dirtyData.Keybinds.ToggleFly == Enum.KeyCode.F5 and dirtyData.Keybinds.ToggleAimlock == Enum.KeyCode.F7)
    results["Config_StrictEnumFamilyValidationTest"] = (dirtyData.World.FOVValue == 120 and isEnumCorrect)

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

end
__modules["Diagnostics/UnitTests"] = __modules["Diagnostics.UnitTests"]

-- ============================================================================
-- Module: Network.NetworkEngine
-- ============================================================================
__modules["Network.NetworkEngine"] = function()
--!strict
local NetworkEngine = {}
NetworkEngine.__index = NetworkEngine

function NetworkEngine.new(deps: { Logger: any, EventBus: any, RemoteResolver: any })
    local self = setmetatable({
        _logger = deps.Logger,
        _eventBus = deps.EventBus,
        _remoteResolver = deps.RemoteResolver,
        _isHooked = false,
        _oldNamecall = nil,
        OutgoingHooked = false,
        PacketCount = 0,
        LastPacketTick = 0,
        LastGoal = nil,
        _degradedMode = false,
    }, NetworkEngine)
    return self
end

function NetworkEngine:Init()
    if self._isHooked then return end -- Idempotency Guard

    pcall(function()
        if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
            local oldNamecall
            local this = self
            oldNamecall = hookmetamethod(game, "__namecall", function(selfRemote, ...)
                if not this._isHooked then
                    return oldNamecall(selfRemote, ...)
                end

                local method = getnamecallmethod()
                local args = {...}

                if method == "FireServer" and selfRemote:IsA("RemoteEvent") then
                    local name = selfRemote.Name:lower()
                    if name:find("comm") or name:find("combat") or name:find("action") then
                        this.PacketCount += 1
                        this.LastPacketTick = os.clock()

                        if type(args[1]) == "table" and args[1].Goal then
                            this.LastGoal = tostring(args[1].Goal)
                            this._eventBus:Publish("Network.OutgoingGoal", args[1].Goal, args[1])
                        end
                    end
                end
                return oldNamecall(selfRemote, ...)
            end)
            self._oldNamecall = oldNamecall
            self._isHooked = true
            self.OutgoingHooked = true
            self._logger:Info("NetworkEngine", "Metamethod Hook initialized successfully.")
        else
            self._degradedMode = true
            self._logger:Warn("NetworkEngine", "Running in Degraded Mode (hookmetamethod API unsupported)")
        end
    end)
end

function NetworkEngine:Unhook()
    if not self._isHooked then return end
    self._isHooked = false
    self.OutgoingHooked = false

    -- Attempt genuine metamethod restoration if environment supports it
    pcall(function()
        if self._oldNamecall then
            if typeof(hookmetamethod) == "function" then
                hookmetamethod(game, "__namecall", self._oldNamecall)
                self._logger:Info("NetworkEngine", "Metamethod Hook restored to original state.")
            elseif typeof(restorefunction) == "function" then
                restorefunction(self._oldNamecall)
            end
        end
    end)
end

function NetworkEngine:Destroy()
    self:Unhook()
    self._oldNamecall = nil
    self._isHooked = false
    self.OutgoingHooked = false
end

function NetworkEngine:SendAction(goalName: string, payload: any?): boolean
    local remote = self._remoteResolver:Resolve("Communicate")
    if remote then
        local data = payload or {}
        data.Goal = goalName
        local ok = pcall(function() remote:FireServer(data) end)
        return ok
    end
    return false
end

return NetworkEngine

end
__modules["Network/NetworkEngine"] = __modules["Network.NetworkEngine"]

-- ============================================================================
-- Module: Network.RemoteResolver
-- ============================================================================
__modules["Network.RemoteResolver"] = function()
--!strict
local RemoteResolver = {}
RemoteResolver.__index = RemoteResolver

function RemoteResolver.new(logger: any)
    local self = setmetatable({
        _logger = logger,
        _cache = {},
    }, RemoteResolver)
    return self
end

function RemoteResolver:Resolve(namePattern: string): RemoteEvent?
    if self._cache[namePattern] and (self._cache[namePattern] :: Instance).Parent then
        return self._cache[namePattern] :: RemoteEvent
    end

    local char = game:GetService("Players").LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("RemoteEvent") and child.Name:lower():find(namePattern:lower()) then
                self._cache[namePattern] = child
                return child
            end
        end
    end

    local rep = game:GetService("ReplicatedStorage")
    for _, desc in ipairs(rep:GetDescendants()) do
        if desc:IsA("RemoteEvent") and desc.Name:lower():find(namePattern:lower()) then
            self._cache[namePattern] = desc
            return desc
        end
    end

    return nil
end

return RemoteResolver

end
__modules["Network/RemoteResolver"] = __modules["Network.RemoteResolver"]

-- ============================================================================
-- Module: Performance.Cache
-- ============================================================================
__modules["Performance.Cache"] = function()
--!strict
local CacheEngine = {}
CacheEngine.__index = CacheEngine

function CacheEngine.new(baseTTL: number?)
    local self = setmetatable({
        PlayerCache = {},
        RaycastCache = {},
        _instanceIdMap = setmetatable({}, { __mode = "k" }), -- Ephemeron Weak-Key ID Map (100% collision-free in standard scripts)
        _nextInstanceId = 1,
        BaseTTL = baseTTL or 0.08,
        PlayerStats = { Hits = 0, Misses = 0, Invalidations = 0 },
        RaycastStats = { Hits = 0, Misses = 0, Invalidations = 0 },
        _maxRaycastEntries = 200,
    }, CacheEngine)
    return self
end

function CacheEngine:_GetInstanceId(inst: Instance): number
    local id = self._instanceIdMap[inst]
    if not id then
        id = self._nextInstanceId
        self._nextInstanceId += 1
        self._instanceIdMap[inst] = id
    end
    return id
end

function CacheEngine:GetPlayerEntry(player: Player): any
    if not player or not player.Parent then return nil end
    local entry = self.PlayerCache[player]
    local now = os.clock()

    local ttl = self.BaseTTL
    local totalReq = self.PlayerStats.Hits + self.PlayerStats.Misses
    if totalReq > 50 then
        local hitRate = self.PlayerStats.Hits / totalReq
        if hitRate > 0.85 then ttl *= 1.25
        elseif hitRate < 0.40 then ttl *= 0.75 end
    end

    if entry and (now - entry.LastCheck) < ttl and entry.Character and entry.Character.Parent then
        self.PlayerStats.Hits += 1
        return entry
    end

    self.PlayerStats.Misses += 1
    local char = player.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    local anim = hum and hum:FindFirstChildWhichIsA("Animator")
    local isAlive = (char ~= nil and hum ~= nil and root ~= nil and hum.Health > 0 and char.Parent ~= nil)

    entry = {
        Player = player,
        Character = char,
        RootPart = root,
        Humanoid = hum,
        Animator = anim,
        IsAlive = isAlive,
        Team = player.Team,
        LastCheck = now,
    }
    self.PlayerCache[player] = entry
    return entry
end

function CacheEngine:CachedRaycast(origin: Vector3, targetPos: Vector3, filterList: { Instance }?): boolean
    -- Collision-free deterministic hash using weak-key instance map
    local filterStr = ""
    if filterList and #filterList > 0 then
        local ids = {}
        for _, inst in ipairs(filterList) do
            table.insert(ids, tostring(self:_GetInstanceId(inst)))
        end
        filterStr = table.concat(ids, ",")
    end

    local hash = string.format("%.1f_%.1f_%.1f_%.1f_%.1f_%.1f_[%s]", origin.X, origin.Y, origin.Z, targetPos.X, targetPos.Y, targetPos.Z, filterStr)
    local cached = self.RaycastCache[hash]
    local now = os.clock()

    if cached and (now - cached.Time) < 0.04 then
        self.RaycastStats.Hits += 1
        return cached.Result
    end

    self.RaycastStats.Misses += 1
    local direction = targetPos - origin
    if direction.Magnitude < 0.1 then return true end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = filterList or {game:GetService("Players").LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(origin, direction, params)
    local hasLOS = true
    if result and result.Instance then
        local hitChar = result.Instance:FindFirstAncestorWhichIsA("Model")
        local isPlayerModel = false
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p.Character == hitChar then
                isPlayerModel = true
                break
            end
        end
        if not isPlayerModel then
            hasLOS = false
        end
    end

    self.RaycastCache[hash] = { Result = hasLOS, Time = now }
    return hasLOS
end

function CacheEngine:InvalidatePlayer(player: Player)
    self.PlayerCache[player] = nil
    self.PlayerStats.Invalidations += 1
    self:InvalidateRaycasts()
end

function CacheEngine:InvalidateRaycasts()
    table.clear(self.RaycastCache)
    self.RaycastStats.Invalidations += 1
end

-- Event-driven cache invalidation for workspace topology changes & player lifecycle
function CacheEngine:HookWorkspaceEvents(maid: any)
    if not maid then return end

    local lastGeomInvalidate = 0
    local function onTopologyChange()
        local now = os.clock()
        if (now - lastGeomInvalidate) > 0.1 then -- Debounced invalidation (max 10 Hz)
            lastGeomInvalidate = now
            table.clear(self.RaycastCache)
            self.RaycastStats.Invalidations += 1
        end
    end

    local Players = game:GetService("Players")

    pcall(function()
        maid:GiveTask(workspace.DescendantAdded:Connect(onTopologyChange))
        maid:GiveTask(workspace.DescendantRemoving:Connect(onTopologyChange))

        maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
            self:InvalidatePlayer(player)
        end))

        for _, player in ipairs(Players:GetPlayers()) do
            maid:GiveTask(player.CharacterRemoving:Connect(function()
                self:InvalidatePlayer(player)
            end))
        end

        maid:GiveTask(Players.PlayerAdded:Connect(function(player)
            maid:GiveTask(player.CharacterRemoving:Connect(function()
                self:InvalidatePlayer(player)
            end))
        end))
    end)
end

function CacheEngine:Clear()
    table.clear(self.PlayerCache)
    table.clear(self.RaycastCache)
    self.PlayerStats.Hits = 0
    self.PlayerStats.Misses = 0
    self.RaycastStats.Hits = 0
    self.RaycastStats.Misses = 0
end

return CacheEngine

end
__modules["Performance/Cache"] = __modules["Performance.Cache"]

-- ============================================================================
-- Module: Performance.ObjectPool
-- ============================================================================
__modules["Performance.ObjectPool"] = function()
--!strict
local ObjectPool = {}
ObjectPool.__index = ObjectPool

export type PoolTelemetry = {
    Available: number,
    Active: number,
    PeakUsage: number,
    MaxCapacity: number,
    AcquireCount: number,
    ReleaseCount: number,
    InvalidReleases: number,
}

function ObjectPool.new(factory: () -> any, resetFn: ((any) -> ())?, initialSize: number?, maxCapacity: number?)
    local self = setmetatable({
        _factory = factory,
        _reset = resetFn,
        _pool = {},
        _activeSet = setmetatable({}, { __mode = "k" }), -- Ownership & double-release protection
        MaxCapacity = maxCapacity or 32,
        Acquisitions = 0,
        Releases = 0,
        InvalidReleases = 0,
        PeakUsage = 0,
    }, ObjectPool)

    for i = 1, math.min(initialSize or 8, self.MaxCapacity) do
        table.insert(self._pool, factory())
    end
    return self
end

function ObjectPool:Acquire(): any
    self.Acquisitions += 1
    local obj = nil

    if #self._pool > 0 then
        obj = table.remove(self._pool)
    else
        obj = self._factory()
    end

    self._activeSet[obj] = true
    local activeCount = self:GetActiveCount()
    if activeCount > self.PeakUsage then
        self.PeakUsage = activeCount
    end

    return obj
end

function ObjectPool:Release(obj: any)
    -- Guard: Prevent double release of the exact same object
    if not self._activeSet[obj] then
        self.InvalidReleases += 1
        return
    end

    self._activeSet[obj] = nil
    self.Releases += 1

    if self._reset then
        pcall(self._reset, obj)
    end

    -- Respect maximum capacity bound to prevent unbounded pool growth
    if #self._pool < self.MaxCapacity then
        table.insert(self._pool, obj)
    elseif typeof(obj) == "Instance" then
        pcall(function() obj:Destroy() end)
    end
end

function ObjectPool:GetActiveCount(): number
    local count = 0
    for _ in pairs(self._activeSet) do count += 1 end
    return count
end

function ObjectPool:GetSize(): number
    return #self._pool
end

function ObjectPool:GetTelemetry(): PoolTelemetry
    return {
        Available = #self._pool,
        Active = self:GetActiveCount(),
        PeakUsage = self.PeakUsage,
        MaxCapacity = self.MaxCapacity,
        AcquireCount = self.Acquisitions,
        ReleaseCount = self.Releases,
        InvalidReleases = self.InvalidReleases,
    }
end

function ObjectPool:Destroy()
    for _, obj in ipairs(self._pool) do
        if typeof(obj) == "Instance" then
            pcall(function() obj:Destroy() end)
        end
    end
    table.clear(self._pool)
    table.clear(self._activeSet)
end

return ObjectPool

end
__modules["Performance/ObjectPool"] = __modules["Performance.ObjectPool"]

-- ============================================================================
-- Module: Performance.Profiler
-- ============================================================================
__modules["Performance.Profiler"] = function()
--!strict
local Profiler = {}
Profiler.__index = Profiler

export type ProfilerMetric = {
    TotalTime: number,
    Calls: number,
    MinTime: number,
    MaxTime: number,
    PeakMicroseconds: number,
    LastTime: number,
    AvgMicroseconds: number,
    EmaMicroseconds: number,
    Budget: number,
    Status: string,
}

function Profiler.new()
    local self = setmetatable({
        Enabled = true,
        Metrics = {},
        FrameSamples = 0,
        LastFpsCalc = os.clock(),
        CurrentFPS = 60,
        MemoryKB = 0,
        PingMS = 0,
    }, Profiler)
    return self
end

function Profiler:Begin(tag: string, budgetMs: number?): number?
    if not self.Enabled then return nil end
    if not self.Metrics[tag] then
        self.Metrics[tag] = {
            TotalTime = 0,
            Calls = 0,
            MinTime = math.huge,
            MaxTime = 0,
            PeakMicroseconds = 0,
            LastTime = 0,
            AvgMicroseconds = 0,
            EmaMicroseconds = 0,
            Budget = (budgetMs or 2.0) * 1000, -- microseconds
            Status = "OK",
        }
    end
    return os.clock()
end

function Profiler:End(tag: string, startTime: number?)
    if not self.Enabled or not startTime then return end
    local duration = (os.clock() - startTime) * 1000000 -- microseconds
    local metric: ProfilerMetric = self.Metrics[tag]
    if metric then
        metric.Calls += 1
        metric.TotalTime += duration
        metric.LastTime = duration
        if duration < metric.MinTime then metric.MinTime = duration end
        if duration > metric.MaxTime then metric.MaxTime = duration end
        if duration > metric.PeakMicroseconds then metric.PeakMicroseconds = duration end
        metric.AvgMicroseconds = metric.TotalTime / metric.Calls

        -- Real-Time Rolling EMA Calculation (Alpha = 0.20)
        metric.EmaMicroseconds = (metric.EmaMicroseconds == 0) and duration or (metric.EmaMicroseconds * 0.80 + duration * 0.20)

        -- Real-Time Budget Assessment with Hysteresis (Enter > 100%, Exit < 80%)
        if metric.Status == "OK" then
            if metric.EmaMicroseconds > metric.Budget then
                metric.Status = "OVER_BUDGET"
            end
        elseif metric.Status == "OVER_BUDGET" then
            if metric.EmaMicroseconds < (metric.Budget * 0.80) then
                metric.Status = "OK"
            end
        end
    end
end

function Profiler:UpdateSystemMetrics()
    self.FrameSamples += 1
    local now = os.clock()
    if (now - self.LastFpsCalc) >= 0.5 then
        self.CurrentFPS = math.floor(self.FrameSamples / (now - self.LastFpsCalc))
        self.FrameSamples = 0
        self.LastFpsCalc = now

        pcall(function()
            local stats = game:GetService("Stats")
            self.MemoryKB = math.floor(stats:GetTotalMemoryUsageMb() * 1024)
            local net = stats:FindFirstChild("PerformanceStats") and stats.PerformanceStats:FindFirstChild("Ping")
            if net then
                self.PingMS = math.floor(net:GetValue())
            end
        end)
    end
end

return Profiler

end
__modules["Performance/Profiler"] = __modules["Performance.Profiler"]

-- ============================================================================
-- Module: Systems.Combat
-- ============================================================================
__modules["Systems.Combat"] = function()
--!strict
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Combat = {}
Combat.__index = Combat

function Combat.new(deps: { Cache: any, EventBus: any, Network: any, EnemyState: any, Logger: any, StateMachine: any })
    local self = setmetatable({
        _cache = deps.Cache,
        _eventBus = deps.EventBus,
        _network = deps.Network,
        _enemyState = deps.EnemyState,
        _logger = deps.Logger,
        _fsm = deps.StateMachine,
        CurrentTarget = nil,
        LastAttackTick = 0,
        LastParryTick = 0,
        M1ComboCount = 0,
        MassBringActive = false,
    }, Combat)
    return self
end

local function SafeMouseClick()
    local char = LocalPlayer.Character
    local comm = char and char:FindFirstChild("Communicate")
    if comm and comm:IsA("RemoteEvent") then
        pcall(function() comm:FireServer({ Goal = "m1" }) end)
        return
    end

    local vim = nil
    pcall(function() vim = game:GetService("VirtualInputManager") end)
    if vim then
        pcall(function()
            vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.02)
            vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
    elseif typeof(mouse1click) == "function" then
        pcall(function() mouse1click() end)
    end
end

local function SafeKeyClick(keyCode: Enum.KeyCode)
    local vim = nil
    pcall(function() vim = game:GetService("VirtualInputManager") end)
    if vim then
        pcall(function()
            vim:SendKeyEvent(true, keyCode, false, game)
            task.wait(0.03)
            vim:SendKeyEvent(false, keyCode, false, game)
        end)
    elseif typeof(keypress) == "function" and typeof(keyrelease) == "function" then
        pcall(function()
            keypress(keyCode.Value)
            task.wait(0.03)
            keyrelease(keyCode.Value)
        end)
    end
end

function Combat:GetTarget(config: any): Player?
    local myEntry = self._cache:GetPlayerEntry(LocalPlayer)
    if not myEntry or not myEntry.RootPart then return nil end
    local myPos = myEntry.RootPart.Position

    local bestPlayer = nil
    local bestScore = config.Combat.AimMaxRange or 300

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local entry = self._cache:GetPlayerEntry(player)
        if not entry or not entry.IsAlive or not entry.RootPart then continue end

        local targetPart = entry.Character:FindFirstChild(config.Combat.AimPart or "HumanoidRootPart") or entry.RootPart
        local dist = (targetPart.Position - myPos).Magnitude

        if dist < bestScore then
            if config.Combat.AimWallCheck and not self._cache:CachedRaycast(myPos, targetPart.Position) then
                continue
            end
            bestScore = dist
            bestPlayer = player
        end
    end

    self.CurrentTarget = bestPlayer
    return bestPlayer
end

function Combat:UpdateAimlock(config: any)
    if not config.Combat.Aimlock then return end
    local target = self:GetTarget(config)
    if not target then return end

    local myEntry = self._cache:GetPlayerEntry(LocalPlayer)
    local tEntry = self._cache:GetPlayerEntry(target)
    if not myEntry or not myEntry.RootPart or not tEntry or not tEntry.RootPart then return end

    local targetPos = tEntry.RootPart.Position
    if config.Combat.PredictiveAim then
        local vel = tEntry.RootPart.AssemblyLinearVelocity or Vector3.zero
        targetPos = targetPos + (vel * 0.05)
    end

    local myRoot = myEntry.RootPart
    pcall(function()
        myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z))
    end)
end

function Combat:UpdateAutoM1(config: any)
    if not config.Combat.AutoM1 then return end
    local target = self.CurrentTarget or self:GetTarget(config)
    if not target then return end

    local myEntry = self._cache:GetPlayerEntry(LocalPlayer)
    local tEntry = self._cache:GetPlayerEntry(target)
    if not myEntry or not myEntry.RootPart or not tEntry or not tEntry.RootPart then return end

    local dist = (myEntry.RootPart.Position - tEntry.RootPart.Position).Magnitude
    if dist <= 14 then
        -- Natural FSM State Management
        if self._fsm.CurrentState == "IDLE" then
            self._fsm:TransitionTo("COMBAT")
        end

        local now = os.clock()
        if (now - self.LastAttackTick) >= (config.Combat.AutoM1Delay or 0.12) then
            self.LastAttackTick = now
            self.M1ComboCount = (self.M1ComboCount % 4) + 1
            SafeMouseClick()
        end
    end
end

function Combat:UpdateAutoBlock(config: any)
    if not config.Combat.AutoParry and not config.Combat.AutoBlock then return end
    local myEntry = self._cache:GetPlayerEntry(LocalPlayer)
    if not myEntry or not myEntry.RootPart then return end
    local myPos = myEntry.RootPart.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local tEntry = self._cache:GetPlayerEntry(player)
        if not tEntry or not tEntry.IsAlive or not tEntry.RootPart or not tEntry.Animator then continue end

        local dist = (tEntry.RootPart.Position - myPos).Magnitude
        if dist <= 18 then
            local isAttacking = false
            for _, track in ipairs(tEntry.Animator:GetPlayingAnimationTracks()) do
                local name = (track.Name or ""):lower()
                if name:find("attack") or name:find("punch") or name:find("slash") or name:find("strike") then
                    isAttacking = true
                    break
                end
            end

            if isAttacking then
                local now = os.clock()
                if (now - self.LastParryTick) >= 0.08 then
                    self.LastParryTick = now
                    SafeKeyClick(Enum.KeyCode.F)
                    self._eventBus:Publish("Combat.ParryExecuted", player)
                    break
                end
            end
        end
    end
end

function Combat:UpdateHitboxExpander(config: any)
    if not config.Combat.HitboxExpander then return end
    local sz = config.Combat.HitboxSize or 16
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local entry = self._cache:GetPlayerEntry(p)
            if entry and entry.IsAlive and entry.RootPart then
                pcall(function()
                    entry.RootPart.Size = Vector3.new(sz, sz, sz)
                    entry.RootPart.Transparency = 0.85
                    entry.RootPart.CanCollide = false
                end)
            end
        end
    end
end

function Combat:ResetHitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local entry = self._cache:GetPlayerEntry(p)
            if entry and entry.RootPart then
                pcall(function()
                    entry.RootPart.Size = Vector3.new(2, 2, 1)
                    entry.RootPart.Transparency = 1
                end)
            end
        end
    end
end

return Combat

end
__modules["Systems/Combat"] = __modules["Systems.Combat"]

-- ============================================================================
-- Module: Systems.EnemyState
-- ============================================================================
__modules["Systems.EnemyState"] = function()
--!strict
export type EnemyData = {
    Cooldowns: { [string]: number },
    IsRagdoll: boolean,
    RagdollStart: number,
    WakeupTime: number,
    IsBlocking: boolean,
    LastSkill: string,
    LastSkillTick: number,
}

local EnemyState = {}
EnemyState.__index = EnemyState

function EnemyState.new(deps: { Cache: any, EventBus: any, Logger: any })
    local self = setmetatable({
        _cache = deps.Cache,
        _eventBus = deps.EventBus,
        _logger = deps.Logger,
        _states = {},
        Profiles = {
            Saitama = { NormalPunch = 12, Consecutive = 15, Shove = 14, Uppercut = 16 },
            Garou = { FlowingWater = 14, LethalWhirlwind = 15, HuntersGrasp = 18, PreysPeril = 16 },
            Sonic = { FlashStrike = 12, WhirlwindKick = 14, Scatter = 16, Shuriken = 15 },
            Suiryu = { VanishingKick = 14, HeadFirst = 15, SweepingKick = 16, FistBarrage = 18 },
            Universal = { Skill1 = 14, Skill2 = 15, Skill3 = 16, Skill4 = 16 },
        }
    }, EnemyState)
    return self
end

function EnemyState:Get(player: Player): EnemyData
    local data = self._states[player]
    if not data then
        data = {
            Cooldowns = {},
            IsRagdoll = false,
            RagdollStart = 0,
            WakeupTime = 0,
            IsBlocking = false,
            LastSkill = "None",
            LastSkillTick = 0,
        }
        self._states[player] = data
    end
    return data
end

function EnemyState:Update(player: Player)
    local entry = self._cache:GetPlayerEntry(player)
    if not entry or not entry.IsAlive then return end

    local data = self:Get(player)
    local hum = entry.Humanoid
    local hState = hum:GetState()
    local isRag = (hState == Enum.HumanoidStateType.Physics or hState == Enum.HumanoidStateType.Ragdoll)

    if isRag and not data.IsRagdoll then
        data.IsRagdoll = true
        data.RagdollStart = os.clock()
        data.WakeupTime = data.RagdollStart + 2.25
        self._eventBus:Publish("Combat.EnemyRagdolled", player, data.WakeupTime)
    elseif not isRag and data.IsRagdoll then
        data.IsRagdoll = false
        self._eventBus:Publish("Combat.EnemyWakeup", player)
    end

    local isBlock = false
    local anim = entry.Animator
    if anim then
        for _, t in ipairs(anim:GetPlayingAnimationTracks()) do
            local n = (t.Name or ""):lower()
            if n:find("block") or n:find("guard") then
                isBlock = true
                break
            end
        end
    end
    data.IsBlocking = isBlock
end

return EnemyState

end
__modules["Systems/EnemyState"] = __modules["Systems.EnemyState"]

-- ============================================================================
-- Module: Systems.Movement
-- ============================================================================
__modules["Systems.Movement"] = function()
--!strict
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Movement = {}
Movement.__index = Movement

function Movement.new(deps: { Cache: any, Logger: any })
    local self = setmetatable({
        _cache = deps.Cache,
        _logger = deps.Logger,
        LastSafePos = nil,
    }, Movement)
    return self
end

function Movement:ToggleFly(enable: boolean, config: any)
    config.Movement.Fly = enable
    local entry = self._cache:GetPlayerEntry(LocalPlayer)
    if not entry or not entry.RootPart or not entry.Humanoid then return end
    if enable then
        pcall(function() entry.Humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
    end
end

function Movement:UpdateFly(dt: number, config: any)
    if not config.Movement.Fly then return end
    local entry = self._cache:GetPlayerEntry(LocalPlayer)
    local cam = Workspace.CurrentCamera
    if not entry or not entry.RootPart or not cam then return end

    local speed = config.Movement.FlySpeed or 60
    local moveDir = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end

    local root = entry.RootPart
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    if moveDir.Magnitude > 0 then
        root.CFrame = root.CFrame + (moveDir.Unit * speed * (dt or 0.016))
    end
end

function Movement:UpdateSpeed(dt: number, config: any)
    local entry = self._cache:GetPlayerEntry(LocalPlayer)
    if not entry or not entry.Humanoid or not entry.RootPart then return end

    if config.Movement.SpeedBoost then
        local moveDir = entry.Humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            local extra = (config.Movement.SpeedVal - 16) * (dt or 0.016)
            entry.RootPart.CFrame += (moveDir.Unit * extra)
        end
    end
end

function Movement:UpdateNoclip(config: any)
    if not config.Movement.Noclip then return end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end

function Movement:UpdateAntiVoid(config: any)
    if not config.Movement.AntiVoid then return end
    local entry = self._cache:GetPlayerEntry(LocalPlayer)
    if not entry or not entry.RootPart or not entry.Humanoid or entry.Humanoid.Health <= 0 then return end

    local root = entry.RootPart
    if root.Position.Y >= 0 and root.AssemblyLinearVelocity.Magnitude < 220 then
        self.LastSafePos = root.CFrame
    end

    if root.Position.Y < -60 or root.AssemblyLinearVelocity.Magnitude > 600 then
        if self.LastSafePos then
            root.CFrame = self.LastSafePos + Vector3.new(0, 6, 0)
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

return Movement

end
__modules["Systems/Movement"] = __modules["Systems.Movement"]

-- ============================================================================
-- Module: Systems.Skills
-- ============================================================================
__modules["Systems.Skills"] = function()
--!strict
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Skills = {}
Skills.__index = Skills

function Skills.new(deps: { Cache: any, Combat: any, Logger: any })
    local self = setmetatable({
        _cache = deps.Cache,
        _combat = deps.Combat,
        _logger = deps.Logger,
        LastSpamTick = 0,
        SpamIdx = 1,
        Keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four },
    }, Skills)
    return self
end

local function SafeKeyClick(keyCode: Enum.KeyCode)
    local vim = nil
    pcall(function() vim = game:GetService("VirtualInputManager") end)
    if vim then
        pcall(function()
            vim:SendKeyEvent(true, keyCode, false, game)
            task.wait(0.03)
            vim:SendKeyEvent(false, keyCode, false, game)
        end)
    end
end

function Skills:OrientToTarget(config: any)
    local target = self._combat.CurrentTarget or self._combat:GetTarget(config)
    if not target then return end
    local myEntry = self._cache:GetPlayerEntry(LocalPlayer)
    local tEntry = self._cache:GetPlayerEntry(target)
    if not myEntry or not myEntry.RootPart or not tEntry or not tEntry.RootPart then return end

    local myRoot = myEntry.RootPart
    local tPos = tEntry.RootPart.Position
    pcall(function()
        myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(tPos.X, myRoot.Position.Y, tPos.Z))
    end)
end

function Skills:UpdateAutoSkillSpam(config: any)
    if not config.Skills.AutoSkillSpam and not config.Skills.AutoUltSpam then return end
    local target = self._combat.CurrentTarget or self._combat:GetTarget(config)
    if not target then return end

    if config.Skills.AutoUltSpam then
        SafeKeyClick(Enum.KeyCode.G)
    end

    if config.Skills.AutoSkillSpam then
        local now = os.clock()
        if (now - self.LastSpamTick) >= (config.Skills.SkillSpamDelay or 0.25) then
            self.LastSpamTick = now
            self:OrientToTarget(config)
            SafeKeyClick(self.Keys[self.SpamIdx])
            self.SpamIdx = (self.SpamIdx % #self.Keys) + 1
        end
    end
end

return Skills

end
__modules["Systems/Skills"] = __modules["Systems.Skills"]

-- ============================================================================
-- Module: Systems.Survival
-- ============================================================================
__modules["Systems.Survival"] = function()
--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Survival = {}
Survival.__index = Survival

function Survival.new(deps: { Cache: any, StateMachine: any, EventBus: any, Logger: any })
    local self = setmetatable({
        _cache = deps.Cache,
        _fsm = deps.StateMachine,
        _eventBus = deps.EventBus,
        _logger = deps.Logger,
        IsDodging = false,
        SavedGroundPos = nil,
        LockedCameraPos = nil,
        LastDodgeTick = 0,
        HasSkyEscaped = false,
        SavedEscapeGround = nil,
    }, Survival)
    return self
end

function Survival:CheckSkyEscape(config: any)
    if not config.Survival.SkyTeleport then return end
    local entry = self._cache:GetPlayerEntry(LocalPlayer)
    if not entry or not entry.Humanoid or not entry.RootPart or entry.Humanoid.Health <= 0 then return end

    local hpPct = (entry.Humanoid.Health / entry.Humanoid.MaxHealth) * 100

    if hpPct <= config.Survival.SkyEscapeHP then
        if not self.HasSkyEscaped then
            -- Clean FSM Priority Transition
            if self._fsm:TransitionTo("SKY_ESCAPE") then
                self.HasSkyEscaped = true
                self.SavedEscapeGround = entry.RootPart.CFrame

                local skyY = entry.RootPart.Position.Y + config.Survival.SkyEscapeHeight
                pcall(function()
                    entry.RootPart.CFrame = CFrame.new(entry.RootPart.Position.X, skyY, entry.RootPart.Position.Z)
                    entry.RootPart.AssemblyLinearVelocity = Vector3.zero
                end)
            end
        end
    elseif self.HasSkyEscaped and hpPct >= (config.Survival.SkyReturnHP or 80) then
        self.HasSkyEscaped = false
        if self.SavedEscapeGround and entry.RootPart then
            entry.RootPart.CFrame = self.SavedEscapeGround + Vector3.new(0, 3, 0)
        end
        self._fsm:TransitionTo("IDLE")
    end
end

function Survival:UpdateSkyDodge(dt: number, config: any)
    if not config.Survival.SkyDodge or self.HasSkyEscaped then return end
    local myEntry = self._cache:GetPlayerEntry(LocalPlayer)
    if not myEntry or not myEntry.RootPart or not myEntry.Humanoid or myEntry.Humanoid.Health <= 0 then return end

    local now = os.clock()
    if not self.IsDodging then
        if (now - self.LastDodgeTick) < 0.2 then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local tEntry = self._cache:GetPlayerEntry(p)
            if not tEntry or not tEntry.IsAlive or not tEntry.RootPart or not tEntry.Animator then continue end

            local dist = (tEntry.RootPart.Position - myEntry.RootPart.Position).Magnitude
            if dist <= config.Survival.SkyDodgeRange then
                local attacking = false
                for _, track in ipairs(tEntry.Animator:GetPlayingAnimationTracks()) do
                    local n = (track.Name or ""):lower()
                    if n:find("attack") or n:find("punch") or n:find("strike") or n:find("slash") then
                        attacking = true
                        break
                    end
                end

                if attacking then
                    if self._fsm:TransitionTo("SKY_DODGE") then
                        self.IsDodging = true
                        self.LastDodgeTick = now
                        self.SavedGroundPos = myEntry.RootPart.CFrame
                        self.LockedCameraPos = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or nil

                        local skyY = myEntry.RootPart.Position.Y + config.Survival.SkyDodgeHeight
                        myEntry.RootPart.CFrame = CFrame.new(myEntry.RootPart.Position.X, skyY, myEntry.RootPart.Position.Z)
                        break
                    end
                end
            end
        end
    else
        local anyAttacking = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local tEntry = self._cache:GetPlayerEntry(p)
            if tEntry and tEntry.IsAlive and tEntry.RootPart and self.SavedGroundPos then
                local d = (tEntry.RootPart.Position - self.SavedGroundPos.Position).Magnitude
                if d <= config.Survival.SkyDodgeRange and tEntry.Animator then
                    for _, track in ipairs(tEntry.Animator:GetPlayingAnimationTracks()) do
                        local n = (track.Name or ""):lower()
                        if n:find("attack") or n:find("punch") or n:find("strike") then
                            anyAttacking = true
                            break
                        end
                    end
                end
            end
        end

        if not anyAttacking then
            self.IsDodging = false
            if self.SavedGroundPos and myEntry.RootPart then
                myEntry.RootPart.CFrame = self.SavedGroundPos
            end
            self.SavedGroundPos = nil
            self.LockedCameraPos = nil
            self._fsm:TransitionTo("IDLE")
        end
    end
end

return Survival

end
__modules["Systems/Survival"] = __modules["Systems.Survival"]

-- ============================================================================
-- Module: Systems.Visuals
-- ============================================================================
__modules["Systems.Visuals"] = function()
--!strict
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local Visuals = {}
Visuals.__index = Visuals

function Visuals.new(deps: { Cache: any, ObjectPool: any, Logger: any })
    -- Active Object Pooling for Highlights to eliminate runtime GC overhead
    local hlPool = deps.ObjectPool.new(
        function()
            local hl = Instance.new("Highlight")
            hl.FillColor = Color3.fromRGB(0, 220, 255)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.45
            return hl
        end,
        function(hl)
            hl.Adornee = nil
            hl.Parent = nil
        end,
        12
    )

    local self = setmetatable({
        _cache = deps.Cache,
        _hlPool = hlPool,
        _logger = deps.Logger,
        ActiveHighlights = {},
    }, Visuals)
    return self
end

function Visuals:Update(config: any)
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local entry = self._cache:GetPlayerEntry(player)

        if entry and entry.IsAlive and entry.Character and entry.RootPart then
            if config.Visuals.HighlightESP then
                local hl = self.ActiveHighlights[player]
                if not hl then
                    hl = self._hlPool:Acquire()
                    hl.Name = "HL_" .. player.UserId
                    hl.Adornee = entry.Character
                    hl.Parent = entry.Character
                    self.ActiveHighlights[player] = hl
                end
            else
                if self.ActiveHighlights[player] then
                    self._hlPool:Release(self.ActiveHighlights[player])
                    self.ActiveHighlights[player] = nil
                end
            end
        else
            if self.ActiveHighlights[player] then
                self._hlPool:Release(self.ActiveHighlights[player])
                self.ActiveHighlights[player] = nil
            end
        end
    end
end

return Visuals

end
__modules["Systems/Visuals"] = __modules["Systems.Visuals"]

-- ============================================================================
-- Module: Systems.World
-- ============================================================================
__modules["Systems.World"] = function()
--!strict
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local World = {}
World.__index = World

function World.new(deps: { ConfigManager: any, Logger: any })
    local self = setmetatable({
        _configManager = deps.ConfigManager,
        _logger = deps.Logger,
        OriginalLighting = {
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            Brightness = Lighting.Brightness,
            FogEnd = Lighting.FogEnd,
        },
        LastHopCheck = 0,
        HopActive = false,
    }, World)
    return self
end

function World:ToggleFullBright(enable: boolean)
    if enable then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
    else
        Lighting.Ambient = self.OriginalLighting.Ambient
        Lighting.OutdoorAmbient = self.OriginalLighting.OutdoorAmbient
        Lighting.Brightness = self.OriginalLighting.Brightness
    end
end

function World:ToggleRemoveFog(enable: boolean)
    if enable then
        Lighting.FogEnd = 9e9
    else
        Lighting.FogEnd = self.OriginalLighting.FogEnd
    end
end

function World:ServerHop()
    if self.HopActive then return end
    self.HopActive = true

    task.spawn(function()
        local placeId = game.PlaceId
        local jobId = game.JobId
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Desc&limit=100"

        local req = (typeof(syn) == "table" and syn.request) or (typeof(http_request) == "function" and http_request) or request
        local body = nil
        if req then
            local res = req({ Url = url, Method = "GET" })
            if res and res.Body then body = res.Body end
        elseif typeof(game.HttpGet) == "function" then
            pcall(function() body = game:HttpGet(url) end)
        end

        if body then
            local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
            if ok and data and data.data then
                for _, s in ipairs(data.data) do
                    if s.id ~= jobId and s.playing and s.maxPlayers and s.playing < (s.maxPlayers - 1) and s.playing >= 4 then
                        TeleportService:TeleportToPlaceInstance(placeId, s.id, Players.LocalPlayer)
                        return
                    end
                end
            end
        end

        TeleportService:Teleport(placeId, Players.LocalPlayer)
    end)
end

function World:CheckAutoServerHop(config: any)
    if not config.World.AutoServerHop or self.HopActive then return end
    local now = os.clock()
    if (now - self.LastHopCheck) < 10 then return end
    self.LastHopCheck = now

    local count = #Players:GetPlayers()
    if count <= (config.World.AutoHopMinPlayers or 4) then
        self:ServerHop()
    end
end

return World

end
__modules["Systems/World"] = __modules["Systems.World"]

-- ============================================================================
-- Module: UI.Components
-- ============================================================================
__modules["UI.Components"] = function()
--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Components = {}

local function Tween(inst: Instance, duration: number, props: { [string]: any })
    local ti = TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local tw = TweenService:Create(inst, ti, props)
    tw:Play()
    return tw
end

function Components.Section(parent: Instance, title: string)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 26)
    f.BackgroundTransparency = 1
    f.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "◆  " .. string.upper(title)
    lbl.TextColor3 = Color3.fromRGB(0, 220, 255)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    return f
end

function Components.Toggle(parent: Instance, title: string, subtitle: string?, defaultVal: boolean, callback: (boolean) -> ())
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, subtitle and 44 or 36)
    frame.BackgroundColor3 = Color3.fromRGB(22, 25, 38)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -66, 0, 18)
    titleL.Position = UDim2.new(0, 10, 0, subtitle and 5 or 9)
    titleL.BackgroundTransparency = 1
    titleL.Text = title
    titleL.TextColor3 = Color3.fromRGB(245, 247, 255)
    titleL.TextSize = 12
    titleL.Font = Enum.Font.GothamMedium
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = frame

    if subtitle then
        local subL = Instance.new("TextLabel")
        subL.Size = UDim2.new(1, -66, 0, 14)
        subL.Position = UDim2.new(0, 10, 0, 24)
        subL.BackgroundTransparency = 1
        subL.Text = subtitle
        subL.TextColor3 = Color3.fromRGB(140, 146, 175)
        subL.TextSize = 9
        subL.Font = Enum.Font.Gotham
        subL.TextXAlignment = Enum.TextXAlignment.Left
        subL.Parent = frame
    end

    local switchBg = Instance.new("Frame")
    switchBg.Size = UDim2.new(0, 42, 0, 22)
    switchBg.Position = UDim2.new(1, -52, 0.5, -11)
    switchBg.BackgroundColor3 = defaultVal and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(45, 50, 68)
    switchBg.BorderSizePixel = 0
    switchBg.Parent = frame
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local switchCirc = Instance.new("Frame")
    switchCirc.Size = UDim2.new(0, 16, 0, 16)
    switchCirc.Position = defaultVal and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    switchCirc.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchCirc.BorderSizePixel = 0
    switchCirc.Parent = switchBg
    Instance.new("UICorner", switchCirc).CornerRadius = UDim.new(1, 0)

    local state = defaultVal
    local function SetOn(val: boolean)
        state = val
        Tween(switchBg, 0.15, { BackgroundColor3 = state and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(45, 50, 68) })
        Tween(switchCirc, 0.15, { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) })
        if callback then callback(state) end
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = frame
    btn.MouseButton1Click:Connect(function() SetOn(not state) end)

    return { SetOn = SetOn, Frame = frame }
end

function Components.Slider(parent: Instance, title: string, minV: number, maxV: number, defaultV: number, suffix: string?, callback: (number) -> ())
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 48)
    frame.BackgroundColor3 = Color3.fromRGB(22, 25, 38)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -70, 0, 18)
    titleL.Position = UDim2.new(0, 10, 0, 8)
    titleL.BackgroundTransparency = 1
    titleL.Text = title
    titleL.TextColor3 = Color3.fromRGB(245, 247, 255)
    titleL.TextSize = 12
    titleL.Font = Enum.Font.GothamMedium
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = frame

    local valL = Instance.new("TextLabel")
    valL.Size = UDim2.new(0, 60, 0, 18)
    valL.Position = UDim2.new(1, -68, 0, 8)
    valL.BackgroundTransparency = 1
    valL.Text = tostring(defaultV) .. (suffix or "")
    valL.TextColor3 = Color3.fromRGB(0, 220, 255)
    valL.TextSize = 12
    valL.Font = Enum.Font.GothamBold
    valL.TextXAlignment = Enum.TextXAlignment.Right
    valL.Parent = frame

    local trackBg = Instance.new("Frame")
    trackBg.Size = UDim2.new(1, -20, 0, 6)
    trackBg.Position = UDim2.new(0, 10, 0, 32)
    trackBg.BackgroundColor3 = Color3.fromRGB(38, 42, 60)
    trackBg.BorderSizePixel = 0
    trackBg.Parent = frame
    Instance.new("UICorner", trackBg).CornerRadius = UDim.new(1, 0)

    local pct = (defaultV - minV) / (maxV - minV)
    local trackFill = Instance.new("Frame")
    trackFill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
    trackFill.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
    trackFill.BorderSizePixel = 0
    trackFill.Parent = trackBg
    Instance.new("UICorner", trackFill).CornerRadius = UDim.new(1, 0)

    local sliding = false
    local function Update(inp: any)
        local rel = math.clamp((inp.Position.X - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
        local val = math.floor(minV + (maxV - minV) * rel)
        trackFill.Size = UDim2.new(rel, 0, 1, 0)
        valL.Text = tostring(val) .. (suffix or "")
        if callback then callback(val) end
    end

    trackBg.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            Update(inp)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            Update(inp)
        end
    end)

    return { Frame = frame }
end

function Components.Button(parent: Instance, title: string, btnText: string, kind: string, callback: () -> ())
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(22, 25, 38)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -110, 1, 0)
    titleL.Position = UDim2.new(0, 10, 0, 0)
    titleL.BackgroundTransparency = 1
    titleL.Text = title
    titleL.TextColor3 = Color3.fromRGB(245, 247, 255)
    titleL.TextSize = 12
    titleL.Font = Enum.Font.GothamMedium
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 95, 0, 24)
    btn.Position = UDim2.new(1, -102, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
    btn.BorderSizePixel = 0
    btn.Text = btnText
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return { Frame = frame }
end

return Components

end
__modules["UI/Components"] = __modules["UI.Components"]

-- ============================================================================
-- FRAMEWORK PUBLIC RUNTIME SURFACE & ENTRYPOINT
-- ============================================================================
local Bootstrap = require("Bootstrap")
local UnitTests = require("Diagnostics.UnitTests")

local Framework = {
    Version = "9.0-SPECIALIST-PRODUCTION",
    Bootstrap = Bootstrap,
    
    Start = function(self)
        return Bootstrap:Init()
    end,
    
    Stop = function(self)
        return Bootstrap:Destroy()
    end,
    
    Destroy = function(self)
        return Bootstrap:Destroy()
    end,
    
    GetService = function(self, serviceName: string)
        if Bootstrap.Container and Bootstrap.Container:Has(serviceName) then
            return Bootstrap.Container:Get(serviceName)
        end
        return nil
    end,
    
    GetDiagnostics = function(self)
        return Bootstrap:GetDiagnostics()
    end,
    
    RunTests = function(self)
        return UnitTests.RunAll()
    end,
}

-- Expose Public Framework Handle to Global Environment for External Lifecycle Control
if typeof(_G) == "table" then
    _G.TSBFramework = Framework
end
if typeof(getgenv) == "function" then
    pcall(function()
        getgenv().TSBFramework = Framework
    end)
end

-- Automatic Framework Boot
Bootstrap:Init()

print("[4080 HUB v9.0] Specialist Production Framework Booted Successfully.")
return Framework

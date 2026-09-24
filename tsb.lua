-- // ========================================================================================
-- // ⚡ 4080 CUSTOM HUB v8.0 - PRODUCTION EXPERT / SPECIALIST FRAMEWORK
-- // Architecture: Modular Luau Service Architecture + IoC Container + FSM & Telemetry
-- // Built by Universal Bundler Pipeline
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

-- Module: Bootstrap
__modules["Bootstrap"] = function()
--!strict
local ServiceContainer = require("Core.ServiceContainer")
local Signal = require("Core.Signal")
local EventBus = require("Core.EventBus")
local Logger = require("Core.Logger")
local Scheduler = require("Core.Scheduler")
local StateMachine = require("Architecture.StateMachine")
local FeatureManager = require("Architecture.FeatureManager")
local Profiler = require("Performance.Profiler")
local Cache = require("Performance.Cache")
local ConfigManager = require("Config.ConfigManager")
local NetworkEngine = require("Network.NetworkEngine")
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

local Bootstrap = {}

function Bootstrap:Init()
    Logger:Info("Bootstrap", "=== 4080 HUB v8.0 EXPERT/SPECIALIST FRAMEWORK BOOTING ===")

    -- 1. Register Services into IoC Container
    ServiceContainer:Register("Signal", Signal)
    ServiceContainer:Register("EventBus", EventBus)
    ServiceContainer:Register("Logger", Logger)
    ServiceContainer:Register("Scheduler", Scheduler)
    ServiceContainer:Register("StateMachine", StateMachine)
    ServiceContainer:Register("FeatureManager", FeatureManager)
    ServiceContainer:Register("Profiler", Profiler)
    ServiceContainer:Register("Cache", Cache)
    ServiceContainer:Register("ConfigManager", ConfigManager)
    ServiceContainer:Register("NetworkEngine", NetworkEngine)
    ServiceContainer:Register("Combat", Combat)
    ServiceContainer:Register("Movement", Movement)
    ServiceContainer:Register("Survival", Survival)
    ServiceContainer:Register("Skills", Skills)
    ServiceContainer:Register("World", World)
    ServiceContainer:Register("Visuals", Visuals)

    -- 2. Run Diagnostics & Unit Tests
    SelfDiagnostics:RunHealthCheck()
    local testsPassed, testResults = UnitTests:RunAll()
    Logger:Info("Bootstrap", string.format("Automated Diagnostics Complete. Tests Passed: %s", tostring(testsPassed)))

    -- 3. Initialize Network Metamethod Hooking
    NetworkEngine:Init()

    -- 4. Load Saved Configurations
    ConfigManager:Load()

    -- 5. Register Feature Pipelines
    FeatureManager:Register({
        Name = "Aimlock",
        Phase = "RenderStepped",
        Priority = 100,
        Budget = 1.5,
        Enabled = true,
        Update = function(self, dt, ctx) Combat:UpdateAimlock(ConfigManager.Config) end
    })

    FeatureManager:Register({
        Name = "FlyMovement",
        Phase = "RenderStepped",
        Priority = 90,
        Budget = 1.0,
        Enabled = true,
        Update = function(self, dt, ctx) Movement:UpdateFly(dt, ConfigManager.Config) end
    })

    FeatureManager:Register({
        Name = "CombatEngine",
        Phase = "Heartbeat",
        Priority = 100,
        Budget = 2.0,
        Enabled = true,
        Update = function(self, dt, ctx)
            Combat:UpdateAutoM1(ConfigManager.Config)
            Combat:UpdateAutoBlock(ConfigManager.Config)
            Combat:UpdateHitboxExpander(ConfigManager.Config)
        end
    })

    FeatureManager:Register({
        Name = "MovementEngine",
        Phase = "Heartbeat",
        Priority = 90,
        Budget = 1.0,
        Enabled = true,
        Update = function(self, dt, ctx)
            Movement:UpdateSpeed(dt, ConfigManager.Config)
            Movement:UpdateAntiVoid(ConfigManager.Config)
        end
    })

    FeatureManager:Register({
        Name = "SurvivalEngine",
        Phase = "Heartbeat",
        Priority = 85,
        Budget = 1.5,
        Enabled = true,
        Update = function(self, dt, ctx)
            Survival:UpdateSkyDodge(dt, ConfigManager.Config)
            Survival:CheckSkyEscape(ConfigManager.Config)
        end
    })

    FeatureManager:Register({
        Name = "VisualsEngine",
        Phase = "Heartbeat",
        Priority = 70,
        Budget = 2.0,
        Enabled = true,
        Update = function(self, dt, ctx)
            Visuals:Update(ConfigManager.Config)
        end
    })

    -- 6. Connect Game Loop Pipelines
    RunService.RenderStepped:Connect(function(dt)
        Profiler:UpdateSystemMetrics()
        FeatureManager:ExecutePipeline("RenderStepped", dt, ServiceContainer)
    end)

    RunService.Stepped:Connect(function()
        Movement:UpdateNoclip(ConfigManager.Config)
        FeatureManager:ExecutePipeline("Stepped", 1/60, ServiceContainer)
    end)

    RunService.Heartbeat:Connect(function(dt)
        StateMachine:Update(dt, ServiceContainer)
        Scheduler:Step(dt)
        FeatureManager:ExecutePipeline("Heartbeat", dt, ServiceContainer)

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer then
                EnemyState:Update(player)
            end
        end
    end)

    Logger:Info("Bootstrap", "=== FRAMEWORK INITIALIZED & OPERATIONAL ===")
end

return Bootstrap

end

-- Module: Architecture.FeatureManager
__modules["Architecture.FeatureManager"] = function()
--!strict
local Maid = require("Core.Maid")
local Logger = require("Core.Logger")
local Profiler = require("Performance.Profiler")

export type Feature = {
    Name: string,
    Phase: string, -- "RenderStepped", "Stepped", "Heartbeat"
    Priority: number,
    Budget: number?, -- in ms
    Dependencies: { string }?,
    Enabled: boolean,
    Maid: any,
    Init: ((self: Feature, ctx: any) -> ())?,
    Start: ((self: Feature, ctx: any) -> ())?,
    Update: ((self: Feature, dt: number, ctx: any) -> ())?,
    Stop: ((self: Feature, ctx: any) -> ())?,
    Destroy: ((self: Feature) -> ())?,
}

local FeatureManager = {
    _features = {} :: { [string]: Feature },
    _renderPipeline = {} :: { Feature },
    _steppedPipeline = {} :: { Feature },
    _heartbeatPipeline = {} :: { Feature },
}

function FeatureManager:Register(def: any): Feature
    assert(type(def.Name) == "string", "Feature must have a unique Name")
    local feat: Feature = {
        Name = def.Name,
        Phase = def.Phase or "Heartbeat",
        Priority = def.Priority or 50,
        Budget = def.Budget or 2.0,
        Dependencies = def.Dependencies or {},
        Enabled = def.Enabled or false,
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

function FeatureManager:Get(name: string): Feature?
    return self._features[name]
end

function FeatureManager:SetEnabled(name: string, enabled: boolean, ctx: any)
    local feat = self._features[name]
    if not feat or feat.Enabled == enabled then return end

    feat.Enabled = enabled
    if enabled then
        if feat.Start then
            Logger:SafeCall(feat.Name .. ".Start", feat.Start, feat, ctx)
        end
    else
        feat.Maid:DoCleaning()
        if feat.Stop then
            Logger:SafeCall(feat.Name .. ".Stop", feat.Stop, feat, ctx)
        end
    end
end

function FeatureManager:ExecutePipeline(phase: string, dt: number, ctx: any)
    local list = self._heartbeatPipeline
    if phase == "RenderStepped" then list = self._renderPipeline
    elseif phase == "Stepped" then list = self._steppedPipeline end

    for _, feat in ipairs(list) do
        if feat.Enabled and feat.Update then
            local start = Profiler:Begin(feat.Name, feat.Budget)
            Logger:SafeCall(feat.Name .. ".Update", feat.Update, feat, dt, ctx)
            Profiler:End(feat.Name, start)
        end
    end
end

return FeatureManager

end
__modules["Architecture/FeatureManager"] = __modules["Architecture.FeatureManager"]

-- Module: Architecture.StateMachine
__modules["Architecture.StateMachine"] = function()
--!strict
local Signal = require("Core.Signal")
local Logger = require("Core.Logger")

export type StateDefinition = {
    OnEnter: ((self: any, prevState: string, ctx: any) -> ())?,
    OnUpdate: ((self: any, dt: number, ctx: any) -> ())?,
    OnExit: ((self: any, nextState: string, ctx: any) -> ())?,
    CanEnter: ((self: any, ctx: any) -> boolean)?,
    CanExit: ((self: any, ctx: any) -> boolean)?,
    Priority: number?,
}

local StateMachine = {
    CurrentState = "IDLE",
    PreviousState = "NONE",
    StateStartTime = os.clock(),
    TransitionsCount = 0,
    History = {} :: { string },
    StateChanged = Signal.new(),
    _states = {} :: { [string]: StateDefinition },
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
}

function StateMachine:RegisterState(name: string, def: StateDefinition)
    self._states[name] = def
    if def.Priority then
        self._priorities[name] = def.Priority
    end
end

function StateMachine:CanTransitionTo(targetState: string, ctx: any): boolean
    if self.CurrentState == targetState then return false end

    local currentDef = self._states[self.CurrentState]
    if currentDef and currentDef.CanExit and not currentDef:CanExit(ctx) then
        return false
    end

    local currentPri = self._priorities[self.CurrentState] or 0
    local targetPri = self._priorities[targetState] or 0

    if targetState == "EMERGENCY_STOP" then return true end
    if self.CurrentState == "EMERGENCY_STOP" and targetState ~= "IDLE" then
        return false
    end

    -- Strict Priority Enforcement: lower priority cannot preempt higher priority unless force transition!
    if targetPri < currentPri and currentPri >= 70 then
        return false
    end

    local targetDef = self._states[targetState]
    if targetDef and targetDef.CanEnter and not targetDef:CanEnter(ctx) then
        return false
    end

    return true
end

function StateMachine:TransitionTo(newState: string, ctx: any, force: boolean?): boolean
    if not force and not self:CanTransitionTo(newState, ctx) then
        return false
    end

    local oldState = self.CurrentState
    local oldDef = self._states[oldState]
    if oldDef and oldDef.OnExit then
        Logger:SafeCall("FSM.OnExit", oldDef.OnExit, oldDef, newState, ctx)
    end

    table.insert(self.History, 1, oldState)
    if #self.History > 20 then table.remove(self.History) end

    self.PreviousState = oldState
    self.CurrentState = newState
    self.StateStartTime = os.clock()
    self.TransitionsCount += 1

    local newDef = self._states[newState]
    if newDef and newDef.OnEnter then
        Logger:SafeCall("FSM.OnEnter", newDef.OnEnter, newDef, oldState, ctx)
    end

    self.StateChanged:Fire(newState, oldState)
    return true
end

function StateMachine:Rollback(ctx: any): boolean
    if #self.History > 0 then
        local prev = table.remove(self.History, 1)
        return self:TransitionTo(prev, ctx, true)
    end
    return false
end

function StateMachine:Update(dt: number, ctx: any)
    local def = self._states[self.CurrentState]
    if def and def.OnUpdate then
        Logger:SafeCall("FSM.OnUpdate", def.OnUpdate, def, dt, ctx)
    end
end

return StateMachine

end
__modules["Architecture/StateMachine"] = __modules["Architecture.StateMachine"]

-- Module: Config.ConfigManager
__modules["Config.ConfigManager"] = function()
--!strict
local ConfigSchema = require("Config.ConfigSchema")
local HttpService = game:GetService("HttpService")
local Logger = require("Core.Logger")

local ConfigManager = {
    FileName = "4080_Hub_TSB_Config.json",
    Config = {},
    RegisteredUI = {},
}

-- Generate Default Config from Schema
for catName, catSchema in pairs(ConfigSchema) do
    ConfigManager.Config[catName] = {}
    for key, spec in pairs(catSchema) do
        ConfigManager.Config[catName][key] = spec.Default
    end
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

local function DeepMerge(target: any, source: any)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" and not v.__type then
            DeepMerge(target[k], v)
        else
            target[k] = v
        end
    end
end

function ConfigManager:Save(): (boolean, string?)
    if typeof(writefile) ~= "function" then
        return false, "Executor writefile API not supported"
    end
    local ok, err = pcall(function()
        local dataToSave = {}
        for cat, val in pairs(self.Config) do
            dataToSave[cat] = SerializeValue(val)
        end
        local json = HttpService:JSONEncode(dataToSave)
        writefile(self.FileName, json)
    end)
    if ok then Logger:Info("Config", "Saved config successfully.") end
    return ok, err
end

function ConfigManager:Load(): (boolean, string?)
    if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
        return false, "Executor readfile/isfile API not supported"
    end
    if not isfile(self.FileName) then
        return false, "Config file not found"
    end
    local ok, err = pcall(function()
        local raw = readfile(self.FileName)
        local rawData = HttpService:JSONDecode(raw)
        local decoded = DeserializeValue(rawData)
        DeepMerge(self.Config, decoded)
        self:RefreshUI()
    end)
    if ok then Logger:Info("Config", "Loaded config successfully.") end
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
    if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(self.FileName) then
        pcall(function() delfile(self.FileName) end)
    end
    self:RefreshUI()
end

return ConfigManager

end
__modules["Config/ConfigManager"] = __modules["Config.ConfigManager"]

-- Module: Config.ConfigSchema
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
        ToggleGUI          = { Type = "EnumItem", Default = Enum.KeyCode.RightControl },
        ToggleFly          = { Type = "EnumItem", Default = Enum.KeyCode.F5 },
        ToggleNoclip       = { Type = "EnumItem", Default = Enum.KeyCode.F6 },
        ToggleAimlock      = { Type = "EnumItem", Default = Enum.KeyCode.F7 },
        ToggleBehindTP     = { Type = "EnumItem", Default = Enum.KeyCode.F9 },
        ToggleSkyDodge     = { Type = "EnumItem", Default = Enum.KeyCode.H },
        EmergencyStop      = { Type = "EnumItem", Default = Enum.KeyCode.Delete },
        MassBringKey       = { Type = "EnumItem", Default = Enum.KeyCode.G },
    }
}

return ConfigSchema

end
__modules["Config/ConfigSchema"] = __modules["Config.ConfigSchema"]

-- Module: Core.EventBus
__modules["Core.EventBus"] = function()
--!strict
local Signal = require("Core.Signal")

local EventBus = {
    _events = {} :: { [string]: any },
    _history = {} :: { [string]: { any } },
    _maxHistory = 20,
}

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

-- Module: Core.Logger
__modules["Core.Logger"] = function()
--!strict
local Logger = {
    Level = 3, -- 1=TRACE, 2=DEBUG, 3=INFO, 4=WARN, 5=ERROR, 6=FATAL
    History = {} :: { string },
    MaxHistory = 100,
    OnLog = nil :: any,
}

local LevelNames = {
    [1] = "TRACE",
    [2] = "DEBUG",
    [3] = "INFO",
    [4] = "WARN",
    [5] = "ERROR",
    [6] = "FATAL"
}

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
        self:Error(tag, string.format("Execution Failed: %s\nTrace: %s", err, trace))
    end
    return table.unpack(results)
end

return Logger

end
__modules["Core/Logger"] = __modules["Core.Logger"]

-- Module: Core.Maid
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

-- Module: Core.Scheduler
__modules["Core.Scheduler"] = function()
--!strict
local Scheduler = {
    _intervals = {
        Fast = 0,           -- Frame-rate bound (0s)
        Normal = 0.05,      -- 20 Hz
        Slow = 0.5,         -- 2 Hz
        Background = 2.0,   -- 0.5 Hz
    },
    _tasks = {} :: { [string]: { Category: string, Callback: (dt: number) -> (), LastRun: number, Enabled: boolean } },
}

function Scheduler:Register(name: string, category: string, callback: (dt: number) -> (), enabled: boolean?)
    self._tasks[name] = {
        Category = category or "Normal",
        Callback = callback,
        LastRun = 0,
        Enabled = enabled ~= false,
    }
end

function Scheduler:SetEnabled(name: string, enabled: boolean)
    if self._tasks[name] then
        self._tasks[name].Enabled = enabled
    end
end

function Scheduler:Step(dt: number)
    local now = os.clock()
    for name, taskItem in pairs(self._tasks) do
        if taskItem.Enabled then
            local interval = self._intervals[taskItem.Category] or 0.05
            if (now - taskItem.LastRun) >= interval then
                local taskDt = taskItem.LastRun == 0 and dt or (now - taskItem.LastRun)
                taskItem.LastRun = now
                pcall(taskItem.Callback, taskDt)
            end
        end
    end
end

return Scheduler

end
__modules["Core/Scheduler"] = __modules["Core.Scheduler"]

-- Module: Core.ServiceContainer
__modules["Core.ServiceContainer"] = function()
--!strict
local ServiceContainer = {
    _services = {} :: { [string]: any },
}

function ServiceContainer:Register(name: string, serviceInstance: any)
    assert(name and serviceInstance, "ServiceContainer:Register requires name and instance")
    self._services[name] = serviceInstance
    return serviceInstance
end

function ServiceContainer:Get(name: string): any
    local service = self._services[name]
    if not service then
        error(string.format("Service '%s' is not registered in ServiceContainer!", tostring(name)))
    end
    return service
end

function ServiceContainer:Has(name: string): boolean
    return self._services[name] ~= nil
end

function ServiceContainer:BuildGraph(): { string }
    local graph = {}
    for name, _ in pairs(self._services) do
        table.insert(graph, name)
    end
    table.sort(graph)
    return graph
end

return ServiceContainer

end
__modules["Core/ServiceContainer"] = __modules["Core.ServiceContainer"]

-- Module: Core.Signal
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

-- Module: Diagnostics.SelfDiagnostics
__modules["Diagnostics.SelfDiagnostics"] = function()
--!strict
local Logger = require("Core.Logger")
local ServiceContainer = require("Core.ServiceContainer")

local SelfDiagnostics = {}

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

    -- Check executor capabilities
    report["API_writefile"] = (typeof(writefile) == "function") and "AVAILABLE" or "UNSUPPORTED"
    report["API_hookmetamethod"] = (typeof(hookmetamethod) == "function") and "AVAILABLE" or "UNSUPPORTED"
    report["API_Drawing"] = (typeof(Drawing) == "table" and Drawing.new ~= nil) and "AVAILABLE" or "UNSUPPORTED"

    Logger:Info("SelfDiagnostics", string.format("Health Check Complete. Status: %s", isHealthy and "HEALTHY" or "DEGRADED"))
    return isHealthy, report
end

return SelfDiagnostics

end
__modules["Diagnostics/SelfDiagnostics"] = __modules["Diagnostics.SelfDiagnostics"]

-- Module: Diagnostics.UnitTests
__modules["Diagnostics.UnitTests"] = function()
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

end
__modules["Diagnostics/UnitTests"] = __modules["Diagnostics.UnitTests"]

-- Module: Network.NetworkEngine
__modules["Network.NetworkEngine"] = function()
--!strict
local EventBus = require("Core.EventBus")
local Logger = require("Core.Logger")
local RemoteResolver = require("Network.RemoteResolver")

local NetworkEngine = {
    OutgoingHooked = false,
    PacketCount = 0,
    LastPacketTick = 0,
    LastGoal = nil :: string?,
}

function NetworkEngine:Init()
    pcall(function()
        if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                local args = {...}

                if method == "FireServer" and self:IsA("RemoteEvent") then
                    local name = self.Name:lower()
                    if name:find("comm") or name:find("combat") or name:find("action") then
                        NetworkEngine.PacketCount += 1
                        NetworkEngine.LastPacketTick = os.clock()

                        if type(args[1]) == "table" and args[1].Goal then
                            NetworkEngine.LastGoal = tostring(args[1].Goal)
                            EventBus:Publish("Network.OutgoingGoal", args[1].Goal, args[1])
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
            self.OutgoingHooked = true
            Logger:Info("NetworkEngine", "Metamethod hook initialized successfully.")
        end
    end)
end

function NetworkEngine:SendAction(goalName: string, payload: any?): boolean
    local remote = RemoteResolver:Resolve("Communicate")
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

-- Module: Network.RemoteResolver
__modules["Network.RemoteResolver"] = function()
--!strict
local Logger = require("Core.Logger")

local RemoteResolver = {
    _cache = {} :: { [string]: RemoteEvent | RemoteFunction },
}

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

-- Module: Performance.Cache
__modules["Performance.Cache"] = function()
--!strict
local Cache = {
    PlayerCache = {},
    RaycastCache = {},
    AnimationCache = {},
    BaseTTL = 0.08,
    Stats = {
        Hits = 0,
        Misses = 0,
        Invalidations = 0,
    },
}

function Cache:GetPlayerEntry(player: Player): any
    if not player or not player.Parent then return nil end
    local entry = self.PlayerCache[player]
    local now = os.clock()

    -- Adaptive TTL Check
    local ttl = self.BaseTTL
    local totalReq = self.Stats.Hits + self.Stats.Misses
    if totalReq > 50 then
        local hitRate = self.Stats.Hits / totalReq
        if hitRate > 0.85 then ttl *= 1.25
        elseif hitRate < 0.40 then ttl *= 0.75 end
    end

    if entry and (now - entry.LastCheck) < ttl and entry.Character and entry.Character.Parent then
        self.Stats.Hits += 1
        return entry
    end

    self.Stats.Misses += 1
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

function Cache:CachedRaycast(origin: Vector3, targetPos: Vector3, filterList: { Instance }?): boolean
    local hash = string.format("%.1f_%.1f_%.1f_%.1f_%.1f_%.1f", origin.X, origin.Y, origin.Z, targetPos.X, targetPos.Y, targetPos.Z)
    local cached = self.RaycastCache[hash]
    local now = os.clock()

    if cached and (now - cached.Time) < 0.04 then
        self.Stats.Hits += 1
        return cached.Result
    end

    self.Stats.Misses += 1
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

function Cache:InvalidatePlayer(player: Player)
    self.PlayerCache[player] = nil
    self.Stats.Invalidations += 1
end

function Cache:Clear()
    table.clear(self.PlayerCache)
    table.clear(self.RaycastCache)
    table.clear(self.AnimationCache)
    self.Stats.Hits = 0
    self.Stats.Misses = 0
end

return Cache

end
__modules["Performance/Cache"] = __modules["Performance.Cache"]

-- Module: Performance.ObjectPool
__modules["Performance.ObjectPool"] = function()
--!strict
local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.new(factory: () -> any, resetFn: (any) -> (), initialSize: number?)
    local self = setmetatable({
        _factory = factory,
        _reset = resetFn,
        _pool = {},
    }, ObjectPool)

    for i = 1, (initialSize or 10) do
        table.insert(self._pool, factory())
    end
    return self
end

function ObjectPool:Acquire(): any
    if #self._pool > 0 then
        return table.remove(self._pool)
    else
        return self._factory()
    end
end

function ObjectPool:Release(obj: any)
    if self._reset then
        pcall(self._reset, obj)
    end
    table.insert(self._pool, obj)
end

return ObjectPool

end
__modules["Performance/ObjectPool"] = __modules["Performance.ObjectPool"]

-- Module: Performance.Profiler
__modules["Performance.Profiler"] = function()
--!strict
local Profiler = {
    Enabled = true,
    Metrics = {} :: { [string]: { TotalTime: number, Calls: number, MinTime: number, MaxTime: number, LastTime: number, AvgMicroseconds: number, Budget: number, Status: string } },
    FrameSamples = 0,
    LastFpsCalc = os.clock(),
    CurrentFPS = 60,
    MemoryKB = 0,
    PingMS = 0,
}

function Profiler:Begin(tag: string, budgetMs: number?): number?
    if not self.Enabled then return nil end
    if not self.Metrics[tag] then
        self.Metrics[tag] = {
            TotalTime = 0,
            Calls = 0,
            MinTime = math.huge,
            MaxTime = 0,
            LastTime = 0,
            AvgMicroseconds = 0,
            Budget = (budgetMs or 2.0) * 1000, -- convert to microseconds
            Status = "OK",
        }
    end
    return os.clock()
end

function Profiler:End(tag: string, startTime: number?)
    if not self.Enabled or not startTime then return end
    local duration = (os.clock() - startTime) * 1000000 -- microseconds
    local metric = self.Metrics[tag]
    if metric then
        metric.Calls += 1
        metric.TotalTime += duration
        metric.LastTime = duration
        if duration < metric.MinTime then metric.MinTime = duration end
        if duration > metric.MaxTime then metric.MaxTime = duration end
        metric.AvgMicroseconds = metric.TotalTime / metric.Calls

        if metric.AvgMicroseconds > metric.Budget then
            metric.Status = "OVER_BUDGET"
        else
            metric.Status = "OK"
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

-- Module: Systems.Combat
__modules["Systems.Combat"] = function()
--!strict
local Cache = require("Performance.Cache")
local Logger = require("Core.Logger")
local EventBus = require("Core.EventBus")
local NetworkEngine = require("Network.NetworkEngine")
local EnemyState = require("Systems.EnemyState")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Combat = {
    CurrentTarget = nil :: Player?,
    LastAttackTick = 0,
    LastParryTick = 0,
    LastBlockTick = 0,
    M1ComboCount = 0,
    MassBringActive = false,
    MassBringEndTime = 0,
}

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
    local myEntry = Cache:GetPlayerEntry(LocalPlayer)
    if not myEntry or not myEntry.RootPart then return nil end
    local myPos = myEntry.RootPart.Position

    local bestPlayer = nil
    local bestScore = config.Combat.AimMaxRange or 300

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local entry = Cache:GetPlayerEntry(player)
        if not entry or not entry.IsAlive or not entry.RootPart then continue end

        local targetPart = entry.Character:FindFirstChild(config.Combat.AimPart or "HumanoidRootPart") or entry.RootPart
        local dist = (targetPart.Position - myPos).Magnitude

        if dist < bestScore then
            if config.Combat.AimWallCheck and not Cache:CachedRaycast(myPos, targetPart.Position) then
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

    local myEntry = Cache:GetPlayerEntry(LocalPlayer)
    local tEntry = Cache:GetPlayerEntry(target)
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

    local myEntry = Cache:GetPlayerEntry(LocalPlayer)
    local tEntry = Cache:GetPlayerEntry(target)
    if not myEntry or not myEntry.RootPart or not tEntry or not tEntry.RootPart then return end

    local dist = (myEntry.RootPart.Position - tEntry.RootPart.Position).Magnitude
    if dist <= 14 then
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
    local myEntry = Cache:GetPlayerEntry(LocalPlayer)
    if not myEntry or not myEntry.RootPart then return end
    local myPos = myEntry.RootPart.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local tEntry = Cache:GetPlayerEntry(player)
        if not tEntry or not tEntry.IsAlive or not tEntry.RootPart or not tEntry.Animator then continue end

        local dist = (tEntry.RootPart.Position - myPos).Magnitude
        if dist <= 18 then
            local isAttacking = false
            for _, track in ipairs(tEntry.Animator:GetPlayingAnimationTracks()) do
                local name = (track.Name or ""):lower()
                if name:find("attack") or name:find("punch") or name:find("slash") or name:find("strike") or name:find("swing") then
                    isAttacking = true
                    break
                end
            end

            if isAttacking then
                local now = os.clock()
                if (now - self.LastParryTick) >= 0.08 then
                    self.LastParryTick = now
                    SafeKeyClick(Enum.KeyCode.F)
                    EventBus:Publish("Combat.ParryExecuted", player)
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
            local entry = Cache:GetPlayerEntry(p)
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
            local entry = Cache:GetPlayerEntry(p)
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

-- Module: Systems.EnemyState
__modules["Systems.EnemyState"] = function()
--!strict
local EventBus = require("Core.EventBus")
local Cache = require("Performance.Cache")

export type EnemyData = {
    Cooldowns: { [string]: number },
    IsRagdoll: boolean,
    RagdollStart: number,
    WakeupTime: number,
    IsBlocking: boolean,
    LastSkill: string,
    LastSkillTick: number,
}

local EnemyState = {
    _states = {} :: { [Player]: EnemyData },
    Profiles = {
        Saitama = { NormalPunch = 12, Consecutive = 15, Shove = 14, Uppercut = 16 },
        Garou = { FlowingWater = 14, LethalWhirlwind = 15, HuntersGrasp = 18, PreysPeril = 16 },
        Sonic = { FlashStrike = 12, WhirlwindKick = 14, Scatter = 16, Shuriken = 15 },
        Suiryu = { VanishingKick = 14, HeadFirst = 15, SweepingKick = 16, FistBarrage = 18 },
        Universal = { Skill1 = 14, Skill2 = 15, Skill3 = 16, Skill4 = 16 },
    }
}

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
    local entry = Cache:GetPlayerEntry(player)
    if not entry or not entry.IsAlive then return end

    local data = self:Get(player)
    local hum = entry.Humanoid
    local hState = hum:GetState()
    local isRag = (hState == Enum.HumanoidStateType.Physics or hState == Enum.HumanoidStateType.Ragdoll)

    if isRag and not data.IsRagdoll then
        data.IsRagdoll = true
        data.RagdollStart = os.clock()
        data.WakeupTime = data.RagdollStart + 2.25
        EventBus:Publish("Combat.EnemyRagdolled", player, data.WakeupTime)
    elseif not isRag and data.IsRagdoll then
        data.IsRagdoll = false
        EventBus:Publish("Combat.EnemyWakeup", player)
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

-- Module: Systems.Movement
__modules["Systems.Movement"] = function()
--!strict
local Cache = require("Performance.Cache")
local Logger = require("Core.Logger")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Movement = {
    LastSafePos = nil :: CFrame?,
    DoubleJumpReady = true,
}

function Movement:ToggleFly(enable: boolean, config: any)
    config.Movement.Fly = enable
    local entry = Cache:GetPlayerEntry(LocalPlayer)
    if not entry or not entry.RootPart or not entry.Humanoid then return end

    if enable then
        pcall(function() entry.Humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
    end
end

function Movement:UpdateFly(dt: number, config: any)
    if not config.Movement.Fly then return end
    local entry = Cache:GetPlayerEntry(LocalPlayer)
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
    local entry = Cache:GetPlayerEntry(LocalPlayer)
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
    local entry = Cache:GetPlayerEntry(LocalPlayer)
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

-- Module: Systems.Skills
__modules["Systems.Skills"] = function()
--!strict
local Cache = require("Performance.Cache")
local Combat = require("Systems.Combat")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Skills = {
    LastSpamTick = 0,
    SpamIdx = 1,
    Keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four },
}

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
    local target = Combat.CurrentTarget or Combat:GetTarget(config)
    if not target then return end
    local myEntry = Cache:GetPlayerEntry(LocalPlayer)
    local tEntry = Cache:GetPlayerEntry(target)
    if not myEntry or not myEntry.RootPart or not tEntry or not tEntry.RootPart then return end

    local myRoot = myEntry.RootPart
    local tPos = tEntry.RootPart.Position
    pcall(function()
        myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(tPos.X, myRoot.Position.Y, tPos.Z))
    end)
end

function Skills:UpdateAutoSkillSpam(config: any)
    if not config.Skills.AutoSkillSpam and not config.Skills.AutoUltSpam then return end
    local target = Combat.CurrentTarget or Combat:GetTarget(config)
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

-- Module: Systems.Survival
__modules["Systems.Survival"] = function()
--!strict
local Cache = require("Performance.Cache")
local StateMachine = require("Architecture.StateMachine")
local EventBus = require("Core.EventBus")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Survival = {
    IsDodging = false,
    SavedGroundPos = nil :: CFrame?,
    LockedCameraPos = nil :: CFrame?,
    LastDodgeTick = 0,
    HasSkyEscaped = false,
    SavedEscapeGround = nil :: CFrame?,
}

function Survival:CheckSkyEscape(config: any)
    if not config.Survival.SkyTeleport then return end
    local entry = Cache:GetPlayerEntry(LocalPlayer)
    if not entry or not entry.Humanoid or not entry.RootPart or entry.Humanoid.Health <= 0 then return end

    local hpPct = (entry.Humanoid.Health / entry.Humanoid.MaxHealth) * 100

    if hpPct <= config.Survival.SkyEscapeHP then
        if not self.HasSkyEscaped then
            self.HasSkyEscaped = true
            self.SavedEscapeGround = entry.RootPart.CFrame
            StateMachine:TransitionTo("SKY_ESCAPE", nil, true)

            local skyY = entry.RootPart.Position.Y + config.Survival.SkyEscapeHeight
            pcall(function()
                entry.RootPart.CFrame = CFrame.new(entry.RootPart.Position.X, skyY, entry.RootPart.Position.Z)
                entry.RootPart.AssemblyLinearVelocity = Vector3.zero
            end)
        end
    elseif self.HasSkyEscaped and hpPct >= (config.Survival.SkyReturnHP or 80) then
        self.HasSkyEscaped = false
        if self.SavedEscapeGround and entry.RootPart then
            entry.RootPart.CFrame = self.SavedEscapeGround + Vector3.new(0, 3, 0)
        end
        StateMachine:TransitionTo("IDLE", nil, true)
    end
end

function Survival:UpdateSkyDodge(dt: number, config: any)
    if not config.Survival.SkyDodge or self.HasSkyEscaped then return end
    local myEntry = Cache:GetPlayerEntry(LocalPlayer)
    if not myEntry or not myEntry.RootPart or not myEntry.Humanoid or myEntry.Humanoid.Health <= 0 then return end

    local now = os.clock()
    if not self.IsDodging then
        if (now - self.LastDodgeTick) < 0.2 then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local tEntry = Cache:GetPlayerEntry(p)
            if not tEntry or not tEntry.IsAlive or not tEntry.RootPart or not tEntry.Animator then continue end

            local dist = (tEntry.RootPart.Position - myEntry.RootPart.Position).Magnitude
            if dist <= config.Survival.SkyDodgeRange then
                local attacking = false
                for _, track in ipairs(tEntry.Animator:GetPlayingAnimationTracks()) do
                    local n = (track.Name or ""):lower()
                    if n:find("attack") or n:find("punch") or n:find("strike") or n:find("slash") or n:find("skill") then
                        attacking = true
                        break
                    end
                end

                if attacking then
                    self.IsDodging = true
                    self.LastDodgeTick = now
                    self.SavedGroundPos = myEntry.RootPart.CFrame
                    self.LockedCameraPos = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or nil
                    StateMachine:TransitionTo("SKY_DODGE", nil, true)

                    local skyY = myEntry.RootPart.Position.Y + config.Survival.SkyDodgeHeight
                    myEntry.RootPart.CFrame = CFrame.new(myEntry.RootPart.Position.X, skyY, myEntry.RootPart.Position.Z)
                    break
                end
            end
        end
    else
        -- Active dodge check
        local anyAttacking = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local tEntry = Cache:GetPlayerEntry(p)
            if tEntry and tEntry.IsAlive and tEntry.RootPart and self.SavedGroundPos then
                local d = (tEntry.RootPart.Position - self.SavedGroundPos.Position).Magnitude
                if d <= config.Survival.SkyDodgeRange and tEntry.Animator then
                    for _, track in ipairs(tEntry.Animator:GetPlayingAnimationTracks()) do
                        local n = (track.Name or ""):lower()
                        if n:find("attack") or n:find("punch") or n:find("strike") or n:find("slash") then
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
            StateMachine:TransitionTo("IDLE", nil, true)
        end
    end
end

return Survival

end
__modules["Systems/Survival"] = __modules["Systems.Survival"]

-- Module: Systems.Visuals
__modules["Systems.Visuals"] = function()
--!strict
local Cache = require("Performance.Cache")
local Combat = require("Systems.Combat")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local Visuals = {
    Highlights = {} :: { [Player]: Highlight },
    Billboards = {} :: { [Player]: BillboardGui },
    Tracers = {} :: { [Player]: any },
}

local ESPFolder = nil
pcall(function()
    ESPFolder = CoreGui:FindFirstChild("TSB_ESP_Folder") or Instance.new("Folder")
    ESPFolder.Name = "TSB_ESP_Folder"
    ESPFolder.Parent = CoreGui
end)

function Visuals:Update(config: any)
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local entry = Cache:GetPlayerEntry(player)

        if entry and entry.IsAlive and entry.Character and entry.RootPart then
            -- Highlight ESP
            if config.Visuals.HighlightESP then
                local hl = self.Highlights[player]
                if not hl or not hl.Parent then
                    hl = Instance.new("Highlight")
                    hl.Name = "HL_" .. player.UserId
                    hl.FillColor = Color3.fromRGB(0, 220, 255)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.45
                    hl.Adornee = entry.Character
                    hl.Parent = entry.Character
                    self.Highlights[player] = hl
                end
            else
                if self.Highlights[player] then
                    pcall(function() self.Highlights[player]:Destroy() end)
                    self.Highlights[player] = nil
                end
            end
        else
            if self.Highlights[player] then
                pcall(function() self.Highlights[player]:Destroy() end)
                self.Highlights[player] = nil
            end
        end
    end
end

return Visuals

end
__modules["Systems/Visuals"] = __modules["Systems.Visuals"]

-- Module: Systems.World
__modules["Systems.World"] = function()
--!strict
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local World = {
    OriginalLighting = {
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        FogEnd = Lighting.FogEnd,
    },
    LastHopCheck = 0,
    HopActive = false,
}

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

-- Module: UI.Components
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
-- FRAMEWORK ENTRYPOINT
-- ============================================================================
local Bootstrap = require("Bootstrap")
Bootstrap:Init()

print("[4080 HUB v8.0] Production Framework Booted Successfully.")

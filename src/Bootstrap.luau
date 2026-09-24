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

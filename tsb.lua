-- // ========================================================================================
-- // ⚡ 4080 CUSTOM HUB v7.0 SPECIALIST SUITE - THE STRONGEST BATTLEGROUNDS & UNIVERSAL FRAMEWORK
-- // Optimized for: Solara, Delta, Wave, Codex, Arceus X, Fluxus, Hydroxide, Electron, Celery
-- // Architecture: Level 6 (FSM Engine, EventBus, Signal Pattern, Cache Layer & Live Telemetry)
-- // ========================================================================================

-- [[ SECTION 1: SERVICES & COMPATIBILITY LAYER ]]
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")
local CoreGui          = game:GetService("CoreGui")
local SoundService     = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera or Workspace:FindFirstChildWhichIsA("Camera")
local Mouse       = LocalPlayer:GetMouse()

-- Safe Executor API Wrappers
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

local function SafeKeyClick(keyCode)
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
            task.wait(0.03)
            VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        end)
    elseif typeof(keypress) == "function" and typeof(keyrelease) == "function" then
        pcall(function()
            keypress(keyCode.Value)
            task.wait(0.03)
            keyrelease(keyCode.Value)
        end)
    elseif typeof(key_press) == "function" and typeof(key_release) == "function" then
        pcall(function()
            key_press(keyCode.Value)
            task.wait(0.03)
            key_release(keyCode.Value)
        end)
    end
end

local function SafeMouseClick()
    -- Check for TSB Communicate Remote first for zero-latency network attack
    local char = LocalPlayer.Character
    local comm = char and char:FindFirstChild("Communicate")
    if comm and comm:IsA("RemoteEvent") then
        local success = pcall(function()
            comm:FireServer({Goal = "m1"})
        end)
        if success then return end
    end

    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.02)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
    elseif typeof(mouse1click) == "function" then
        pcall(function() mouse1click() end)
    elseif VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(0, 0))
        end)
    end
end

-- Color Preset Map Utility
local ColorPresets = {
    ["Cyan Neon"]       = Color3.fromRGB(0, 220, 255),
    ["Yeşil"]           = Color3.fromRGB(0, 230, 120),
    ["Mor"]             = Color3.fromRGB(170, 0, 255),
    ["Sarı"]            = Color3.fromRGB(255, 220, 0),
    ["Kırmızı"]         = Color3.fromRGB(255, 45, 60),
    ["Kırmızı Neon"]    = Color3.fromRGB(255, 65, 80),
    ["Alev Turuncusu"]  = Color3.fromRGB(255, 120, 0),
    ["Magenta"]         = Color3.fromRGB(255, 0, 180),
    ["Pembe"]           = Color3.fromRGB(255, 150, 200),
    ["Altın Sarısı"]   = Color3.fromRGB(255, 185, 0),
    ["Koyu Turuncu"]   = Color3.fromRGB(230, 90, 0),
    ["Parlak Mor"]     = Color3.fromRGB(200, 50, 255),
    ["Beyaz"]           = Color3.fromRGB(255, 255, 255)
}

-- [[ SECTION 1.5: LEVEL 5 CORE FRAMEWORK, FSM, EVENT BUS & PERFORMANCE CACHE ]]

-- 1. FAST SIGNAL OBSERVER PATTERN
local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({
        _listeners = {},
        _listenerCount = 0
    }, Signal)
    return self
end

function Signal:Connect(callback)
    assert(type(callback) == "function", "Signal:Connect expects a function")
    local connection = {
        _callback = callback,
        _signal = self,
        Connected = true
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
    self._listenerCount = self._listenerCount + 1
    return connection
end

function Signal:Fire(...)
    for connection in pairs(self._listeners) do
        if connection.Connected and connection._callback then
            task.spawn(connection._callback, ...)
        end
    end
end

function Signal:Wait()
    local thread = coroutine.running()
    local conn
    conn = self:Connect(function(...)
        conn:Disconnect()
        task.spawn(thread, ...)
    end)
    return coroutine.yield()
end

function Signal:Destroy()
    for connection in pairs(self._listeners) do
        connection.Connected = false
    end
    table.clear(self._listeners)
    self._listenerCount = 0
end

-- 2. CENTRALIZED EVENT BUS
local EventBus = {
    _events = {}
}

function EventBus.Subscribe(eventName, callback)
    if not EventBus._events[eventName] then
        EventBus._events[eventName] = Signal.new()
    end
    return EventBus._events[eventName]:Connect(callback)
end

function EventBus.Publish(eventName, ...)
    if EventBus._events[eventName] then
        EventBus._events[eventName]:Fire(...)
    end
end

-- 3. PROFILER & TELEMETRY ENGINE
local Profiler = {
    Enabled = true,
    Metrics = {},
    FrameSamples = 0,
    LastFpsCalc = os.clock(),
    CurrentFPS = 60,
    MemoryKB = 0,
    PingMS = 0,
}

function Profiler.Begin(tag)
    if not Profiler.Enabled then return end
    if not Profiler.Metrics[tag] then
        Profiler.Metrics[tag] = {
            TotalTime = 0,
            Calls = 0,
            MinTime = math.huge,
            MaxTime = 0,
            LastTime = 0,
            AvgMicroseconds = 0
        }
    end
    return os.clock()
end

function Profiler.End(tag, startTime)
    if not Profiler.Enabled or not startTime then return end
    local duration = (os.clock() - startTime) * 1000000 -- microseconds
    local metric = Profiler.Metrics[tag]
    if metric then
        metric.Calls = metric.Calls + 1
        metric.TotalTime = metric.TotalTime + duration
        metric.LastTime = duration
        if duration < metric.MinTime then metric.MinTime = duration end
        if duration > metric.MaxTime then metric.MaxTime = duration end
        metric.AvgMicroseconds = metric.TotalTime / metric.Calls
    end
end

function Profiler.Benchmark(tag, fn, ...)
    local start = os.clock()
    local ok, res = pcall(fn, ...)
    Profiler.End(tag, start)
    return ok, res
end

function Profiler.UpdateSystemMetrics()
    Profiler.FrameSamples = Profiler.FrameSamples + 1
    local now = os.clock()
    if (now - Profiler.LastFpsCalc) >= 0.5 then
        Profiler.CurrentFPS = math.floor(Profiler.FrameSamples / (now - Profiler.LastFpsCalc))
        Profiler.FrameSamples = 0
        Profiler.LastFpsCalc = now

        pcall(function()
            local stats = game:GetService("Stats")
            Profiler.MemoryKB = math.floor(stats:GetTotalMemoryUsageMb() * 1024)
            local net = stats:FindFirstChild("PerformanceStats") and stats.PerformanceStats:FindFirstChild("Ping")
            if net then
                Profiler.PingMS = math.floor(net:GetValue())
            end
        end)
    end
end

-- 4. MULTI-TIER CACHE ENGINE (SPATIAL & OBJECT POOL)
local CacheEngine = {
    PlayerCache = {},
    RaycastCache = {},
    AnimationCache = {},
    Stats = {
        Hits = 0,
        Misses = 0,
        Invalidations = 0
    }
}

function CacheEngine.GetPlayerEntry(player)
    if not player or not player.Parent then return nil end
    local entry = CacheEngine.PlayerCache[player]
    local now = os.clock()

    if entry and (now - entry.LastCheck) < 0.08 and entry.Character and entry.Character.Parent then
        CacheEngine.Stats.Hits = CacheEngine.Stats.Hits + 1
        return entry
    end

    CacheEngine.Stats.Misses = CacheEngine.Stats.Misses + 1
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
        LastCheck = now
    }
    CacheEngine.PlayerCache[player] = entry
    return entry
end

function CacheEngine.InvalidatePlayer(player)
    CacheEngine.PlayerCache[player] = nil
    CacheEngine.Stats.Invalidations = CacheEngine.Stats.Invalidations + 1
end

function CacheEngine.CachedRaycast(origin, targetPos, filterList, ttl)
    ttl = ttl or 0.04
    local hash = string.format("%.1f_%.1f_%.1f_%.1f_%.1f_%.1f", origin.X, origin.Y, origin.Z, targetPos.X, targetPos.Y, targetPos.Z)
    local cached = CacheEngine.RaycastCache[hash]
    local now = os.clock()

    if cached and (now - cached.Time) < ttl then
        CacheEngine.Stats.Hits = CacheEngine.Stats.Hits + 1
        return cached.Result
    end

    CacheEngine.Stats.Misses = CacheEngine.Stats.Misses + 1
    local direction = targetPos - origin
    if direction.Magnitude < 0.1 then return true end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = filterList or {LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = Workspace:Raycast(origin, direction, params)
    local hasLOS = true
    if result and result.Instance then
        local hitChar = result.Instance:FindFirstAncestorWhichIsA("Model")
        local isPlayerModel = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character == hitChar then
                isPlayerModel = true
                break
            end
        end
        if not isPlayerModel then
            hasLOS = false
        end
    end

    CacheEngine.RaycastCache[hash] = { Result = hasLOS, Time = now }
    return hasLOS
end

-- 5. ROBUST FINITE STATE MACHINE (FSM ENGINE)
local FSMStates = {
    IDLE           = "IDLE",
    COMBAT         = "COMBAT",
    BEHIND_TP      = "BEHIND_TP",
    MASS_BRING     = "MASS_BRING",
    VOID_KILL      = "VOID_KILL",
    SKY_DODGE      = "SKY_DODGE",
    SKY_ESCAPE     = "SKY_ESCAPE",
    EMERGENCY_STOP = "EMERGENCY_STOP"
}

local FSMPriorities = {
    EMERGENCY_STOP = 100,
    SKY_ESCAPE     = 90,
    SKY_DODGE      = 80,
    VOID_KILL      = 70,
    MASS_BRING     = 60,
    BEHIND_TP      = 50,
    COMBAT         = 30,
    IDLE           = 0
}

local StateMachine = {
    CurrentState = FSMStates.IDLE,
    PreviousState = nil,
    StateStartTime = os.clock(),
    TransitionsCount = 0,
    StateChanged = Signal.new(),
    _handlers = {}
}

function StateMachine.RegisterState(stateName, definition)
    StateMachine._handlers[stateName] = {
        OnEnter = definition.OnEnter or function() end,
        OnUpdate = definition.OnUpdate or function(dt) end,
        OnExit = definition.OnExit or function() end,
        CanEnter = definition.CanEnter or function() return true end,
    }
end

function StateMachine.CanTransitionTo(targetState)
    if StateMachine.CurrentState == targetState then return false end
    local currentPri = FSMPriorities[StateMachine.CurrentState] or 0
    local targetPri = FSMPriorities[targetState] or 0

    if targetState == FSMStates.EMERGENCY_STOP then return true end
    if StateMachine.CurrentState == FSMStates.EMERGENCY_STOP and targetState ~= FSMStates.IDLE then
        return false
    end

    local handler = StateMachine._handlers[targetState]
    if handler and not handler.CanEnter() then
        return false
    end

    return true
end

function StateMachine.TransitionTo(newState, force)
    if not force and not StateMachine.CanTransitionTo(newState) then
        return false
    end

    local oldState = StateMachine.CurrentState
    local oldHandler = StateMachine._handlers[oldState]
    if oldHandler and oldHandler.OnExit then
        pcall(oldHandler.OnExit, newState)
    end

    StateMachine.PreviousState = oldState
    StateMachine.CurrentState = newState
    StateMachine.StateStartTime = os.clock()
    StateMachine.TransitionsCount = StateMachine.TransitionsCount + 1

    local newHandler = StateMachine._handlers[newState]
    if newHandler and newHandler.OnEnter then
        pcall(newHandler.OnEnter, oldState)
    end

    StateMachine.StateChanged:Fire(newState, oldState)
    EventBus.Publish("FSM_StateChanged", newState, oldState)
    return true
end

function StateMachine.Update(dt)
    local handler = StateMachine._handlers[StateMachine.CurrentState]
    if handler and handler.OnUpdate then
        pcall(handler.OnUpdate, dt)
    end
end

-- 6. EXTENSIBLE FEATURE & PLUGIN MANAGER
local FeatureManager = {
    _features = {},
    _renderPipeline = {},
    _steppedPipeline = {},
    _heartbeatPipeline = {}
}

function FeatureManager.Register(featureDef)
    assert(type(featureDef.Name) == "string", "Feature must have a unique Name")
    local feature = {
        Name = featureDef.Name,
        Phase = featureDef.Phase or "Heartbeat", -- "RenderStepped", "Stepped", "Heartbeat"
        Priority = featureDef.Priority or 50,
        IsEnabled = featureDef.IsEnabled or function() return true end,
        Execute = featureDef.Execute or function(dt) end,
        Init = featureDef.Init or function() end,
    }

    pcall(feature.Init)
    FeatureManager._features[feature.Name] = feature

    local list = FeatureManager._heartbeatPipeline
    if feature.Phase == "RenderStepped" then list = FeatureManager._renderPipeline
    elseif feature.Phase == "Stepped" then list = FeatureManager._steppedPipeline end

    table.insert(list, feature)
    table.sort(list, function(a, b) return a.Priority > b.Priority end)
    return feature
end

function FeatureManager.ExecutePipeline(phase, dt)
    local list = FeatureManager._heartbeatPipeline
    if phase == "RenderStepped" then list = FeatureManager._renderPipeline
    elseif phase == "Stepped" then list = FeatureManager._steppedPipeline end

    for _, feat in ipairs(list) do
        local ok, enabled = pcall(feat.IsEnabled)
        if ok and enabled then
            local start = Profiler.Begin(feat.Name)
            pcall(feat.Execute, dt)
            Profiler.End(feat.Name, start)
        end
    end
end

-- [[ SECTION 1.8: LEVEL 6 SPECIALIST LAYER (NETWORK HOOKING, HEURISTICS & PREDICTIVE AIM) ]]

-- 1. DYNAMIC REMOTE RESOLVER & PACKET INTERCEPTION ENGINE
local NetworkEngine = {
    CommunicateRemote = nil,
    OutgoingPacketHooked = false,
    IncomingPacketHooked = false,
    PacketParryEnabled = true,
    LastOutgoingGoal = nil,
    LastPacketTick = 0,
    PacketCount = 0
}

function NetworkEngine.ResolveCommunicateRemote()
    if NetworkEngine.CommunicateRemote and NetworkEngine.CommunicateRemote.Parent then
        return NetworkEngine.CommunicateRemote
    end

    local char = LocalPlayer.Character
    if char then
        local comm = char:FindFirstChild("Communicate") or char:FindFirstChildWhichIsA("RemoteEvent")
        if comm and comm:IsA("RemoteEvent") then
            NetworkEngine.CommunicateRemote = comm
            return comm
        end
    end

    local rep = game:GetService("ReplicatedStorage")
    for _, desc in ipairs(rep:GetDescendants()) do
        if desc:IsA("RemoteEvent") and (desc.Name:lower():find("comm") or desc.Name:lower():find("combat") or desc.Name:lower():find("action")) then
            NetworkEngine.CommunicateRemote = desc
            return desc
        end
    end

    return nil
end

-- Hook Metamethod for Network Interception
pcall(function()
    if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if method == "FireServer" and self:IsA("RemoteEvent") then
                local remoteName = self.Name:lower()
                if remoteName:find("comm") or remoteName:find("action") or remoteName:find("combat") then
                    NetworkEngine.PacketCount = NetworkEngine.PacketCount + 1
                    NetworkEngine.LastPacketTick = os.clock()

                    if type(args[1]) == "table" and args[1].Goal then
                        NetworkEngine.LastOutgoingGoal = tostring(args[1].Goal)
                        EventBus.Publish("Network_OutgoingGoal", args[1].Goal, args[1])
                    end
                end
            end

            return oldNamecall(self, ...)
        end)
        NetworkEngine.OutgoingPacketHooked = true
    end
end)

-- 2. DYNAMIC ASSET & HEURISTIC DISCOVERY ENGINE
local HeuristicDiscoveryEngine = {
    DiscoveredAttackAnims = {},
    DiscoveredCounterAnims = {},
    ScannedTracksCount = 0,
    Cache = {}
}

function HeuristicDiscoveryEngine.AnalyzeAnimationTrack(track)
    if not track or not track.Animation then return "Unknown", 0 end
    local animId = track.Animation.AnimationId or ""
    local rawId = animId:match("%d+")

    if rawId and HeuristicDiscoveryEngine.Cache[rawId] then
        return HeuristicDiscoveryEngine.Cache[rawId].Type, HeuristicDiscoveryEngine.Cache[rawId].Confidence
    end

    HeuristicDiscoveryEngine.ScannedTracksCount = HeuristicDiscoveryEngine.ScannedTracksCount + 1
    local name = (track.Name or ""):lower()
    local length = track.Length or 0
    local speed = track.Speed or 1
    local confidence = 0
    local animType = "Unknown"

    -- Heuristic Criterion 1: Known keyword match
    for _, kw in ipairs(TSBDatabase.AttackKeywords) do
        if name:find(kw) then
            confidence = confidence + 50
            animType = "Attack"
            break
        end
    end

    for _, ckw in ipairs(TSBDatabase.CounterKeywords) do
        if name:find(ckw) then
            confidence = confidence + 70
            animType = "Counter"
            break
        end
    end

    -- Heuristic Criterion 2: Short rapid duration (0.2s - 1.1s) and high speed characteristic of combat swings
    if length > 0.15 and length <= 1.15 and animType == "Unknown" then
        confidence = confidence + 30
        animType = "Attack"
    end

    -- Heuristic Criterion 3: Keyframe markers check
    pcall(function()
        if track.GetTimeOfKeyframe then
            local hitTime = track:GetTimeOfKeyframe("hit") or track:GetTimeOfKeyframe("strike") or track:GetTimeOfKeyframe("damage")
            if hitTime and hitTime > 0 then
                confidence = confidence + 40
                animType = "Attack"
            end
        end
    end)

    if rawId then
        HeuristicDiscoveryEngine.Cache[rawId] = { Type = animType, Confidence = confidence }
        if animType == "Attack" and confidence >= 40 then
            TSBDatabase.AttackAnimationIDs[rawId] = true
        elseif animType == "Counter" and confidence >= 50 then
            TSBDatabase.CounterAnimationIDs[rawId] = true
        end
    end

    return animType, confidence
end

-- 3. LIVE ENEMY STATE & COOLDOWN MIRRORING ENGINE
local EnemyStateEngine = {
    Profiles = {
        ["Saitama"] = {
            Skills = { ["Skill 1"] = 12, ["Skill 2"] = 15, ["Skill 3"] = 14, ["Skill 4"] = 16 },
            EvasiveCD = 15
        },
        ["Garou"] = {
            Skills = { ["Skill 1"] = 14, ["Skill 2"] = 15, ["Skill 3"] = 18, ["Skill 4"] = 16 },
            EvasiveCD = 15
        },
        ["Genos"] = {
            Skills = { ["Skill 1"] = 13, ["Skill 2"] = 16, ["Skill 3"] = 14, ["Skill 4"] = 17 },
            EvasiveCD = 15
        },
        ["Sonic"] = {
            Skills = { ["Skill 1"] = 12, ["Skill 2"] = 14, ["Skill 3"] = 16, ["Skill 4"] = 15 },
            EvasiveCD = 15
        },
        ["MetalBat"] = {
            Skills = { ["Skill 1"] = 14, ["Skill 2"] = 15, ["Skill 3"] = 17, ["Skill 4"] = 18 },
            EvasiveCD = 15
        },
        ["AtomicSamurai"] = {
            Skills = { ["Skill 1"] = 12, ["Skill 2"] = 15, ["Skill 3"] = 16, ["Skill 4"] = 18 },
            EvasiveCD = 15
        },
        ["Suiryu"] = {
            Skills = { ["Skill 1"] = 14, ["Skill 2"] = 15, ["Skill 3"] = 16, ["Skill 4"] = 18 },
            EvasiveCD = 15
        },
        ["KJ"] = {
            Skills = { ["Skill 1"] = 13, ["Skill 2"] = 15, ["Skill 3"] = 16, ["Skill 4"] = 18 },
            EvasiveCD = 15
        },
        ["Universal"] = {
            Skills = { ["Skill 1"] = 14, ["Skill 2"] = 15, ["Skill 3"] = 16, ["Skill 4"] = 16 },
            EvasiveCD = 15
        }
    },
    EnemyStates = {}, -- player -> { Cooldowns = {}, IsRagdoll = bool, RagdollStart = tick, WakeupTime = tick, IsBlocking = bool, EvasiveReadyTick = tick }
}

function EnemyStateEngine.GetState(player)
    if not player then return nil end
    local state = EnemyStateEngine.EnemyStates[player]
    if not state then
        state = {
            Cooldowns = {},
            IsRagdoll = false,
            RagdollStart = 0,
            WakeupTime = 0,
            IsBlocking = false,
            EvasiveReadyTick = 0,
            LastSkillUsed = "None",
            LastSkillTick = 0
        }
        EnemyStateEngine.EnemyStates[player] = state
    end
    return state
end

function EnemyStateEngine.Update(player)
    if not player or not Utils.IsAlive(player) then return end
    local state = EnemyStateEngine.GetState(player)
    local char = player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return end

    local hState = hum:GetState()
    local isCurrentlyRagdoll = (hState == Enum.HumanoidStateType.Physics or hState == Enum.HumanoidStateType.Ragdoll)

    if isCurrentlyRagdoll and not state.IsRagdoll then
        state.IsRagdoll = true
        state.RagdollStart = os.clock()
        state.WakeupTime = state.RagdollStart + 2.25 -- Average TSB get-up frame timing
        EventBus.Publish("Enemy_RagdollEntered", player, state.WakeupTime)
    elseif not isCurrentlyRagdoll and state.IsRagdoll then
        state.IsRagdoll = false
        EventBus.Publish("Enemy_Wakeup", player)
    end

    -- Check for block stance
    local isHoldingBlock = false
    local anim = hum:FindFirstChildWhichIsA("Animator")
    if anim then
        for _, t in ipairs(anim:GetPlayingAnimationTracks()) do
            local name = (t.Name or ""):lower()
            if name:find("block") or name:find("guard") or name:find("defend") then
                isHoldingBlock = true
                break
            end
        end
    end
    state.IsBlocking = isHoldingBlock
end

function EnemyStateEngine.RegisterSkillUsed(player, skillSlot)
    local state = EnemyStateEngine.GetState(player)
    local charBadge, _, _ = TSBDatabase.GetPlayerCharacterInfo(player)
    local charKey = charBadge:gsub("[^%a]", "")
    local profile = EnemyStateEngine.Profiles[charKey] or EnemyStateEngine.Profiles.Universal

    local cd = profile.Skills[skillSlot] or 15
    state.Cooldowns[skillSlot] = os.clock() + cd
    state.LastSkillUsed = skillSlot
    state.LastSkillTick = os.clock()
    EventBus.Publish("Enemy_SkillTriggered", player, skillSlot, cd)
end

-- 4. PREDICTIVE AIM & LAG COMPENSATION ENGINE
local PredictiveLagCompEngine = {
    Enabled = true,
    InterpDelta = 0.035,
    History = {}
}

function PredictiveLagCompEngine.GetPredictedPosition(targetPart, extraTime)
    if not targetPart then return Vector3.zero end
    local currentPos = targetPart.Position
    local velocity = targetPart.AssemblyLinearVelocity or Vector3.zero

    local ping = (Profiler.PingMS or 50) / 1000
    local dt = ping + (extraTime or PredictiveLagCompEngine.InterpDelta)

    -- Vector Trajectory Extrapolation: P_pred = P + V*dt
    local predicted = currentPos + (velocity * dt)

    -- Gravity compensation if target is airborne
    if math.abs(velocity.Y) > 2 then
        predicted = predicted + Vector3.new(0, -0.5 * Workspace.Gravity * (dt * dt), 0)
    end

    return predicted
end

-- 5. FRAME-DATA SUPPORTED COMBO SEQUENCER
local ComboSequencerEngine = {
    Enabled = false,
    CurrentComboMode = "Saitama Max Damage", -- "Default (4-M1)", "Saitama Max Damage", "Garou Extended", "Sonic Speed Chain"
    CurrentStep = 1,
    LastStepTick = 0,
    IsActive = false,
    Target = nil,

    Chains = {
        ["Default (4-M1)"] = {
            { Action = "M1", Delay = 0.12 },
            { Action = "M1", Delay = 0.12 },
            { Action = "M1", Delay = 0.12 },
            { Action = "M1", Delay = 0.14 }
        },
        ["Saitama Max Damage"] = {
            { Action = "M1", Delay = 0.12 },
            { Action = "M1", Delay = 0.12 },
            { Action = "M1", Delay = 0.12 },
            { Action = "Downslam", Delay = 0.35 },
            { Action = "Dash", Delay = 0.20 },
            { Action = "Skill1", Delay = 0.30 },
            { Action = "Skill2", Delay = 0.40 }
        },
        ["Garou Extended"] = {
            { Action = "M1", Delay = 0.12 },
            { Action = "M1", Delay = 0.12 },
            { Action = "M1", Delay = 0.12 },
            { Action = "Skill1", Delay = 0.35 },
            { Action = "Skill2", Delay = 0.40 },
            { Action = "Skill3", Delay = 0.45 }
        },
        ["Sonic Speed Chain"] = {
            { Action = "M1", Delay = 0.10 },
            { Action = "M1", Delay = 0.10 },
            { Action = "M1", Delay = 0.10 },
            { Action = "Skill1", Delay = 0.25 },
            { Action = "Skill3", Delay = 0.30 },
            { Action = "M1", Delay = 0.10 }
        }
    }
}

function ComboSequencerEngine.ExecuteStep(target)
    if not target or not Utils.IsAlive(target) then
        ComboSequencerEngine.Reset()
        return
    end

    local chain = ComboSequencerEngine.Chains[ComboSequencerEngine.CurrentComboMode] or ComboSequencerEngine.Chains["Default (4-M1)"]
    if ComboSequencerEngine.CurrentStep > #chain then
        ComboSequencerEngine.CurrentStep = 1
    end

    local step = chain[ComboSequencerEngine.CurrentStep]
    local now = os.clock()
    if (now - ComboSequencerEngine.LastStepTick) < step.Delay then return end

    ComboSequencerEngine.LastStepTick = now

    -- Check if enemy is blocking -> trigger Guard Break
    local enemyState = EnemyStateEngine.GetState(target)
    if enemyState and enemyState.IsBlocking then
        -- Execute Guard Break Punch (Holding or Skill)
        SafeKeyClick(Enum.KeyCode.One)
        ComboSequencerEngine.CurrentStep = ComboSequencerEngine.CurrentStep + 1
        return
    end

    if step.Action == "M1" then
        SafeMouseClick()
    elseif step.Action == "Downslam" then
        SafeKeyClick(Enum.KeyCode.Space)
        task.wait(0.04)
        SafeMouseClick()
    elseif step.Action == "Dash" then
        SafeKeyClick(Enum.KeyCode.Q)
    elseif step.Action == "Skill1" then
        SafeKeyClick(Enum.KeyCode.One)
    elseif step.Action == "Skill2" then
        SafeKeyClick(Enum.KeyCode.Two)
    elseif step.Action == "Skill3" then
        SafeKeyClick(Enum.KeyCode.Three)
    elseif step.Action == "Skill4" then
        SafeKeyClick(Enum.KeyCode.Four)
    end

    ComboSequencerEngine.CurrentStep = ComboSequencerEngine.CurrentStep + 1
    if ComboSequencerEngine.CurrentStep > #chain then
        ComboSequencerEngine.CurrentStep = 1
    end
end

function ComboSequencerEngine.Reset()
    ComboSequencerEngine.CurrentStep = 1
    ComboSequencerEngine.LastStepTick = 0
    ComboSequencerEngine.IsActive = false
    ComboSequencerEngine.Target = nil
end

-- 6. COMBAT TELEMETRY LOG BUFFER
local CombatLogEngine = {
    Logs = {},
    MaxLogs = 10
}

function CombatLogEngine.AddLog(message, category)
    local timestamp = os.date("%X")
    local entry = string.format("[%s] %s", timestamp, message)
    table.insert(CombatLogEngine.Logs, 1, entry)
    if #CombatLogEngine.Logs > CombatLogEngine.MaxLogs then
        table.remove(CombatLogEngine.Logs)
    end
    EventBus.Publish("CombatLog_Added", entry)
end

-- Hook EventBus to Combat Log
EventBus.Subscribe("Enemy_RagdollEntered", function(player, wakeupTime)
    CombatLogEngine.AddLog(string.format("Enemy %s ragdolled! Wakeup in 2.25s", player.DisplayName), "info")
end)
EventBus.Subscribe("Enemy_SkillTriggered", function(player, slot, cd)
    CombatLogEngine.AddLog(string.format("%s used %s (CD: %ds)", player.DisplayName, slot, cd), "warn")
end)
EventBus.Subscribe("FSM_StateChanged", function(newState, oldState)
    CombatLogEngine.AddLog(string.format("FSM: %s -> %s", tostring(oldState), tostring(newState)), "fsm")
end)


-- [[ SECTION 2: CONFIGURATION ]]
local Config = {
    Combat = {
        Aimlock            = false,
        AimlockMode        = "Body Only (No Screen Spin)", -- "Body Only (No Screen Spin)", "Camera & Body", "Camera Only"
        AimPart            = "HumanoidRootPart", -- "HumanoidRootPart", "Head", "UpperTorso"
        AimMode            = "Nearest",          -- "Nearest", "Cursor", "LowestHP"
        UseSmoothness      = false,              -- false = Instant Snap, true = Smooth lerp
        AimSmoothness      = 0.25,               -- 0.05 = snap, 0.5 = smooth
        AutoFaceTarget     = true,               -- Rotates local character toward target
        AimIndicator       = true,
        AimTeamCheck       = false,
        AimWallCheck       = false,
        AimMaxRange        = 300,
        AimFOVEnabled      = false,              -- false = Infinite FOV (lock anywhere)
        AimFOVRadius       = 180,

        HitboxExpander     = false,
        HitboxSize         = 16,
        HitboxTransp       = 0.85,

        AutoM1             = false,
        AutoM1Range        = 14,
        AutoM1Delay        = 0.12,
        AutoM1MaxCombo     = 4,
        ComboFinisher      = "None",             -- "None", "Uppercut", "Downslam"
        MeleeTP            = false,
        MeleeTpRange       = 15,
        KillAura           = false,
        KillAuraRange      = 14,
        KillAuraDelay      = 0.12,

        AutoBlock          = false,
        AutoBlockRange     = 18,
        AutoBlockDelay     = 0.06,
        PerfectBlockMode   = false,
        AutoParry          = false,
        AutoParryDelay     = 0.08,
        -- Level 6 Specialist Features
        PacketParry        = true,               -- 0-ping packet level parry
        PredictiveAim      = true,               -- Vector lag compensation for aimlock and skills
        AutoComboSequencer = false,              -- Frame-data action combo engine
        ComboMode          = "Saitama Max Damage",-- "Default (4-M1)", "Saitama Max Damage", "Garou Extended", "Sonic Speed Chain"
        FrameTrapWakeup    = true,               -- Frame-trap enemy upon wake-up from ragdoll
        EnemyCooldownESP   = true,               -- Display enemy skill cooldown counters in ESP

        AntiCounterBait    = true,               -- Pauses attack if enemy is in counter/parry stance

        AntiRagdoll        = false,
        AntiRagdollDelay   = 0.02,
        NoSlowdown         = false,
        AutoEvasive        = false,
        AutoEvasiveHP      = 35,
        AutoAwakening      = false,
        NoKnockback        = false,
        BodyReach          = false,
        ReachDistance      = 9,
        FakeLag            = false,
        FakeLagIntensity   = 3,
        MassBringEnabled   = true,
        MassBringMode      = "FE Real Damage (Blitz)", -- "FE Real Damage (Blitz)", "Local Visual Vacuum"
        MassBringDistance  = 20,                 -- Distance in studs in front of character (default 20)
        MassBringDuration  = 10,                 -- Duration in seconds (default 10)
    },

    Target = {
        TargetMode         = "Nearest",          -- "Nearest", "Lowest HP", "Random", "Selected Player"
        SelectedPlayerName = "",
        BehindTP           = false,
        BehindDistance     = 3.5,                -- Safe distance behind target
        AutoM1OnTP         = true,               -- Automatically punch while behind target
    },

    Skills = {
        AutoAim            = true,               -- Auto lock-on when pressing Skill 1, 2, 3, 4
        AutoSkillSpam      = false,              -- Auto spam skills (1, 2, 3, 4) sequentially when in range
        SkillSpamDelay     = 0.25,               -- Delay between skill uses
        AutoUltSpam        = false,              -- Auto use Awakening/Ult (G/T) as soon as ready
        FastM1Spam         = false,              -- Maximum speed M1 spam
        VoidKill           = false,              -- Teleport target to void when skill is used & return
        VoidDepth          = -350,               -- Y depth for void kill (-350 studs)
        VoidReturnDelay    = 0.5,                -- Delay before returning to original position (seconds)
        Keys               = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four},
    },

    Survival = {
        SkyTeleport        = false,
        SkyEscapeHP        = 30,                 -- Işınlanma tetiklenme canı (% HP)
        SkyReturnHP        = 80,                 -- Yere geri dönme canı (% HP)
        SkyEscapeHeight    = 180,
        HasSkyEscaped      = false,

        -- Auto Sky Dodge (Camera Freeze & Instant Sky Teleport until enemy attack animation ends)
        SkyDodge           = false,              -- Saldırı ve Skillerden havaya anlık kaçış
        SkyDodgeHeight     = 65,                 -- Kaçış irtifası (studs)
        SkyDodgeRange      = 18,                 -- Rakip saldırı algılama menzili
        SkyDodgeLockCamera = true,               -- Kaçış esnasında kamerayı yerde sabit tutar
        SkyDodgeCooldown   = 0.15,               -- Kaçışlar arası bekleme süresi
    },

    Movement = {
        Fly                = false,
        FlySpeed           = 60,
        FlyMode            = "CFrame",           -- "CFrame", "Velocity"
        FlyNoCollide       = true,
        SpeedBoost         = false,
        SpeedVal           = 42,
        SpeedMethod        = "CFrame",           -- "CFrame", "WalkSpeed"
        InfiniteJump       = false,
        HighJump           = false,
        JumpPowerVal       = 100,
        DoubleJump         = false,
        DoubleJumpCD       = 1.5,
        Noclip             = false,
        ClickTP            = false,
        ClickTPKey         = "LeftAlt",
        AntiVoid           = true,
        AntiVoidThreshold  = -60,
        GlideMode          = false,
        AirStall           = false,
        Gravity            = false,
        GravityValue       = 196.2,
        InfiniteStamina    = false,
    },

    Visuals = {
        HighlightESP       = false,
        HighlightFill      = Color3.fromRGB(0, 220, 255),
        HighlightOutline   = Color3.fromRGB(255, 255, 255),
        HighlightFillTrans = 0.45,
        HighlightOutTrans  = 0.0,
        HighlightTeam      = false,

        BillboardESP       = false,
        NameESP            = true,
        HealthESP          = true,
        DistanceESP        = true,
        DistanceColor      = true,
        ShowCharacterESP   = true,               -- Karakter ESP (Karakter & Aktif Skill Seti)
        ShowUltiESP        = true,               -- Ulti ESP (Ultide mi uyarısı)
        DeathCounterRisk   = true,               -- Saitama Ulti bittiğinde 10sn Tehlike uyarısı

        -- State Dynamic Colors
        StandardESPColor   = Color3.fromRGB(0, 220, 255),  -- Standard ESP Rengi
        UltiESPColor       = Color3.fromRGB(255, 65, 80),   -- Ulti Aktif ESP Rengi
        DeathCounterRiskColor = Color3.fromRGB(255, 185, 0), -- Death Counter Risk ESP Rengi

        Tracers            = false,
        TracerOrigin       = "Bottom",           -- "Bottom", "Center", "Mouse"
        TracerColor        = Color3.fromRGB(0, 220, 255),
        TracerThickness    = 1.5,

        FOVCircle          = false,
        FOVColor           = Color3.fromRGB(0, 220, 255),
        FOVFilled          = false,

        LocalHighlight     = false,
        LocalChamsColor    = Color3.fromRGB(0, 255, 120),
        SpectatorAlert     = false,
    },

    Telemetry = {
        Enabled            = true,
        AutoCleanMemory    = false,
        CacheTTL           = 0.05,
    },

    World = {
        FullBright         = false,
        RemoveFog          = false,
        CustomFOV          = false,
        FOVValue           = 90,
        CustomTime         = false,
        TimeValue          = 14,
        FPSBoost           = false,
        NoSounds           = false,
        AntiAFK            = true,
        AutoServerHop      = true,               -- Otomatik server hop
        AutoHopMinPlayers  = 4,                  -- Kişi sayısı bu sayının altına düşünce dolu servere geçer
        AutoHopMaxPlayers  = 13,                 -- Aşırı dolu/kilitli sunuculara girip başarısız olmamak için üst limit (Örn: 12-13/14)
        AutoHopMode        = "Optimal Active",   -- "Optimal Active (10-13 Players)", "Random Public", "Lowest Ping"
    },

    Player = {
        InfiniteHealth     = false,
        InfiniteHealthVal  = 100,
        HideCharacter      = false,
        FreezePosition     = false,
    },

    UI = {
        IsOpen             = true,
        TabActive          = "Combat",
        AccentColor        = Color3.fromRGB(0, 220, 255),
        AccentName         = "Cyan Neon",
        BgColor            = Color3.fromRGB(14, 16, 24),
        CardColor          = Color3.fromRGB(22, 25, 38),
        Card2Color         = Color3.fromRGB(30, 34, 52),
        HoverColor         = Color3.fromRGB(40, 46, 68),
        TextColor          = Color3.fromRGB(245, 247, 255),
        SubTextColor       = Color3.fromRGB(140, 146, 175),
        DimColor           = Color3.fromRGB(85, 92, 120),
        SuccessColor       = Color3.fromRGB(0, 230, 130),
        WarnColor          = Color3.fromRGB(255, 185, 0),
        DangerColor        = Color3.fromRGB(255, 65, 80),
        VersionStr         = "v5.0 ULTRA ELITE",
    },

    Keybinds = {
        ToggleGUI          = Enum.KeyCode.RightControl,
        ToggleFly          = Enum.KeyCode.F5,
        ToggleNoclip       = Enum.KeyCode.F6,
        ToggleAimlock      = Enum.KeyCode.F7,
        ToggleESP          = Enum.KeyCode.F8,
        ToggleBehindTP     = Enum.KeyCode.F9,
        ToggleSkyDodge     = Enum.KeyCode.H,
        EmergencyStop      = Enum.KeyCode.Delete,
        MassBringKey       = Enum.KeyCode.G,
    },
}

-- [[ SECTION 2.5: CONFIG SAVE & LOAD SYSTEM ]]
local ConfigSystem = {
    FileName = "4080_Hub_TSB_Config.json",
    AutoSave = true,
    RegisteredUI = {},
}

local function SerializeValue(val)
    if typeof(val) == "Color3" then
        return { __type = "Color3", R = val.R, G = val.G, B = val.B }
    elseif typeof(val) == "EnumItem" then
        return { __type = "EnumItem", EnumType = tostring(val.EnumType), Name = val.Name }
    elseif type(val) == "table" then
        local t = {}
        for k, v in pairs(val) do
            t[tostring(k)] = SerializeValue(v)
        end
        return t
    else
        return val
    end
end

local function DeserializeValue(val)
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
            for k, v in pairs(val) do
                t[k] = DeserializeValue(v)
            end
            return t
        end
    else
        return val
    end
end

local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" and not v.__type then
            DeepMerge(target[k], v)
        else
            target[k] = v
        end
    end
end

function ConfigSystem.RefreshUI()
    for _, item in ipairs(ConfigSystem.RegisteredUI) do
        if item.Getter and item.Setter then
            pcall(function()
                local val = item.Getter()
                if val ~= nil then
                    item.Setter(val)
                end
            end)
        end
    end
end

function ConfigSystem.Save()
    if typeof(writefile) ~= "function" then
        return false, "Executor writefile API desteklemiyor"
    end
    local success, err = pcall(function()
        local dataToSave = {}
        local categoriesToSave = {"Combat", "Target", "Skills", "Survival", "Movement", "Visuals", "World", "Player", "Keybinds", "Telemetry"}
        for _, cat in ipairs(categoriesToSave) do
            if Config[cat] then
                dataToSave[cat] = SerializeValue(Config[cat])
            end
        end
        local json = HttpService:JSONEncode(dataToSave)
        writefile(ConfigSystem.FileName, json)
    end)
    return success, err
end

function ConfigSystem.Load()
    if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
        return false, "Executor readfile/isfile API desteklemiyor"
    end
    if not isfile(ConfigSystem.FileName) then
        return false, "Kayıtlı ayar dosyası bulunamadı"
    end
    local success, err = pcall(function()
        local raw = readfile(ConfigSystem.FileName)
        local rawData = HttpService:JSONDecode(raw)
        local decodedData = DeserializeValue(rawData)
        DeepMerge(Config, decodedData)
        ConfigSystem.RefreshUI()
    end)
    return success, err
end

function ConfigSystem.Reset()
    if typeof(delfile) == "function" and typeof(isfile) == "function" then
        if isfile(ConfigSystem.FileName) then
            pcall(function() delfile(ConfigSystem.FileName) end)
        end
    end
    ConfigSystem.RefreshUI()
end

-- Immediately load saved settings BEFORE UI elements are rendered!
pcall(function()
    if typeof(isfile) == "function" and isfile(ConfigSystem.FileName) then
        ConfigSystem.Load()
    end
end)

-- [[ SECTION 3: RUNTIME STATE ]]
local State = {
    IsEmergencyStop    = false,
    CurrentTarget      = nil,
    AimTargetHL        = nil,
    MassBringActive    = false,
    MassBringEndTime   = 0,
    SavedBehindTPState = nil,
    IsVoidKilling      = false,
    SavedPreVoidPos    = nil,
    LastAttackTick     = 0,
    LastBlockTick      = 0,
    LastParryTick      = 0,
    LastEvasiveTick    = 0,
    M1ComboCount       = 0,
    M1LastTick         = 0,
    LastSafePos        = nil,
    AntiAFKTick        = 0,
    DoubleJumpReady    = true,
    SpectatorList      = {},
    ServerHopActive    = false,
    LastServerHopCheck = 0,
    OriginalLighting   = {
        Ambient        = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness     = Lighting.Brightness,
        FogEnd         = Lighting.FogEnd,
        FogStart       = Lighting.FogStart,
        GlobalShadows  = Lighting.GlobalShadows,
        ClockTime      = Lighting.ClockTime,
    },
    OriginalFOV        = Camera and Camera.FieldOfView or 70,
    OriginalGravity    = Workspace.Gravity,
    ESP = {
        Highlights     = {},
        Billboards     = {},
        Tracers        = {},
    },
    Fly = {
        LV             = nil,
        AG             = nil,
        Att            = nil,
    },
    Drawings = {},
    SaitamaUltiTrack = {}, -- Player -> { WasInUlt = bool, UltEndTick = number }
    CharacterCache   = {}, -- Cache player character recognition for maximum accuracy
    RandomTarget     = nil,
    RandomTargetTick = 0,
    SkyDodge = {
        IsDodging     = false,
        SavedGroundPos = nil,
        LockedCameraPos = nil,
        LastDodgeTick = 0,
        AttackingPlayer = nil,
    },
}

-- [[ SECTION 4: TSB ANIMATION & COMBAT DATABASE & CHARACTER RECOGNITION ]]
local TSBDatabase = {
    -- Detailed TSB Skill & Character Mapping with High-Visibility Badges
    CharacterProfiles = {
        ["Saitama"] = {
            Badge = "🥊 SAITAMA",
            NormalSkills = {"normal punch", "consecutive punches", "shove", "uppercut"},
            UltiSkills = {"death counter", "table flip", "serious punch", "omni directinoal punch"}
        },
        ["Garou"] = {
            Badge = "🐺 GAROU",
            NormalSkills = {"flowing water", "lethal whirlwind", "hunter's grasp", "prey's peril"},
            UltiSkills = {"water stream", "final hunt", "rock splitting", "crushed rock"}
        },
        ["MonsterGarou"] = {
            Badge = "👾 MONSTER GAROU",
            NormalSkills = {"doom dive", "crowd buster", "hammer heel", "binding cloth"},
            UltiSkills = {"hunter's mark", "great fajin", "god slayer", "sky ripping"}
        },
        ["CosmicGarou"] = {
            Badge = "🌌 COSMIC GAROU",
            NormalSkills = {"nuclear fission", "singularity", "great fajin", "sky ripping"},
            UltiSkills = {}
        },
        ["Genos"] = {
            Badge = "🤖 GENOS",
            NormalSkills = {"machine gun", "ignition burst", "blitz shot", "jet dive"},
            UltiSkills = {"maximum incineration", "thunder kick", "core burst", "rocket stomp"}
        },
        ["Sonic"] = {
            Badge = "🥷 SONIC",
            NormalSkills = {"flash strike", "whirlwind kick", "scatter", "explosive shuriken"},
            UltiSkills = {"ten shadow", "sonic slice", "hail of carnage", "blitzing slash"}
        },
        ["MetalBat"] = {
            Badge = "🏏 METAL BAT",
            NormalSkills = {"grand slam", "foul ball", "home run", "beatdown"},
            UltiSkills = {"death blow", "savage tornado", "furious smash", "brutal counter"}
        },
        ["AtomicSamurai"] = {
            Badge = "⚔️ ATOMIC SAMURAI",
            NormalSkills = {"quick slice", "atmos cleave", "pin cushion", "split second counter"},
            UltiSkills = {"atomic slash", "dual atmos", "focused slash", "blade dance"}
        },
        ["Tatsumaki"] = {
            Badge = "🌪️ TATSUMAKI",
            NormalSkills = {"crushing pull", "kinetic slam", "rubble toss", "expressive repulsion"},
            UltiSkills = {"twisted horizon", "meteor strike", "immobilizing grip", "cataclysmic burst"}
        },
        ["Suiryu"] = {
            Badge = "🥋 SUIRYU",
            NormalSkills = {"vanishing kick", "head first", "sweeping kick", "fist barrage"},
            UltiSkills = {"void tremor", "phoenix strike", "void flurry", "skyfall drop"}
        },
        ["ChildEmperor"] = {
            Badge = "🎒 CHILD EMPEROR",
            NormalSkills = {"twin burst", "trinity tear", "plasma cannon", "gadget stun"},
            UltiSkills = {"photon edge", "missile swarm", "mega shield", "hyper beam"}
        },
        ["Gojo"] = {
            Badge = "👁️ GOJO",
            NormalSkills = {"lapse blue", "reversal red", "rapid punches", "infinity counter"},
            UltiSkills = {"hollow purple", "infinite void", "unlimited fist", "maximum output"}
        },
        ["KJ"] = {
            Badge = "💥 KJ",
            NormalSkills = {"ravage", "swift sweep", "collateral ruin", "dropkick"},
            UltiSkills = {"20-20-20 dropkick", "stoic bomb", "unlimited flex", "five seasons"}
        }
    },

    AttackAnimationIDs = {
        ["10468665991"] = true, ["10466974800"] = true, ["10466975850"] = true, ["10466976930"] = true,
        ["10466977750"] = true, ["10471336737"] = true, ["12510170988"] = true, ["10469493270"] = true,
        ["10469630950"] = true, ["10469639222"] = true, ["10469643911"] = true, ["10469645293"] = true,
        ["12447707844"] = true, ["12273188754"] = true, ["12272894215"] = true, ["12296113986"] = true,
        ["12300483801"] = true, ["12300486071"] = true, ["13927612951"] = true, ["13927616353"] = true,
        ["13927618956"] = true, ["15955393872"] = true, ["15955396590"] = true, ["15955398246"] = true,
        ["15259164849"] = true, ["15259167232"] = true,
    },

    CounterAnimationIDs = {
        ["10468665991"] = true, ["15955398246"] = true, ["12510170988"] = true,
    },

    AttackKeywords = {
        "attack", "m1", "punch", "slash", "combo", "hit", "strike", "swing",
        "downslam", "uppercut", "dashattack", "crush", "lethal", "whirlwind",
        "fury", "smash", "blitz", "consecutive", "hunter", "pinpoint"
    },

    CounterKeywords = {
        "counter", "parry", "flowingwater", "deflect", "reflect"
    },

    Characters = {
        Saitama       = { Name = "Saitama", HoldTime = 0.65, MaxWindup = 0.4 },
        Garou         = { Name = "Garou", HoldTime = 0.75, MaxWindup = 0.45 },
        Genos         = { Name = "Genos", HoldTime = 0.60, MaxWindup = 0.35 },
        Sonic         = { Name = "Sonic", HoldTime = 0.55, MaxWindup = 0.30 },
        MetalBat      = { Name = "Metal Bat", HoldTime = 0.70, MaxWindup = 0.40 },
        AtomicSamurai = { Name = "Atomic Samurai", HoldTime = 0.60, MaxWindup = 0.35 },
        Suiryu        = { Name = "Suiryu", HoldTime = 0.65, MaxWindup = 0.40 },
        Universal     = { Name = "Universal TSB", HoldTime = 0.60, MaxWindup = 0.35 },
    },
}

-- Ultra Precision Character Recognition Engine (Scans Tools, Character Models, Animations & Attributes)
function TSBDatabase.GetPlayerCharacterInfo(player)
    if not player then return "❓ BILINMIYOR", false, false end

    local now = tick()
    local cached = State.CharacterCache[player]
    if cached and (now - (cached.LastScan or 0)) < 0.5 then
        return cached.Badge, cached.IsUltActive, cached.HasSaitamaUltEnded
    end

    local foundCharKey = cached and cached.CharKey or "Bilinmiyor"
    local isUltActive = false
    local hasSaitamaUltEnded = false

    pcall(function()
        local char = player.Character
        local scannedNames = {}

        if char then
            for _, child in ipairs(char:GetChildren()) do
                table.insert(scannedNames, child.Name:lower())
            end
        end

        if player:FindFirstChild("Backpack") then
            for _, tool in ipairs(player.Backpack:GetChildren()) do
                table.insert(scannedNames, tool.Name:lower())
            end
        end

        for key, prof in pairs(TSBDatabase.CharacterProfiles) do
            local normMatch = 0
            local ultMatch = 0

            for _, scanned in ipairs(scannedNames) do
                for _, sName in ipairs(prof.NormalSkills) do
                    if scanned:find(sName, 1, true) then
                        normMatch = normMatch + 1
                    end
                end
                for _, uName in ipairs(prof.UltiSkills) do
                    if scanned:find(uName, 1, true) then
                        ultMatch = ultMatch + 1
                    end
                end
            end

            if normMatch > 0 or ultMatch > 0 then
                foundCharKey = key
                if ultMatch > 0 then
                    isUltActive = true
                end
                break
            end
        end

        if foundCharKey == "Saitama" then
            local track = State.SaitamaUltiTrack[player] or { WasInUlt = false, UltEndTick = 0 }
            if track.WasInUlt and not isUltActive then
                track.UltEndTick = tick()
            end
            track.WasInUlt = isUltActive
            State.SaitamaUltiTrack[player] = track

            if (tick() - track.UltEndTick) <= 10 and track.UltEndTick > 0 then
                hasSaitamaUltEnded = true
            end
        end
    end)

    local badge = TSBDatabase.CharacterProfiles[foundCharKey] and TSBDatabase.CharacterProfiles[foundCharKey].Badge or ("❓ " .. string.upper(foundCharKey))
    State.CharacterCache[player] = {
        Badge = badge,
        IsUltActive = isUltActive,
        HasSaitamaUltEnded = hasSaitamaUltEnded,
        CharKey = foundCharKey,
        LastScan = now
    }

    return badge, isUltActive, hasSaitamaUltEnded
end

function TSBDatabase.DetectCurrentCharacter()
    local name, _, _ = TSBDatabase.GetPlayerCharacterInfo(LocalPlayer)
    return name
end


-- [[ SECTION 5: UTILITIES ]]
local Utils = {}

function Utils.SafeGetRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
end

function Utils.SafeGetHum(char)
    if not char then return nil end
    return char:FindFirstChildWhichIsA("Humanoid")
end

function Utils.SafeGetAnimator(char)
    local hum = Utils.SafeGetHum(char)
    return hum and hum:FindFirstChildWhichIsA("Animator") or nil
end

function Utils.IsAlive(player)
    if not player then return false end
    local entry = CacheEngine.GetPlayerEntry(player)
    if entry then return entry.IsAlive end
    if not player.Character then return false end
    local hum  = Utils.SafeGetHum(player.Character)
    local root = Utils.SafeGetRoot(player.Character)
    return (hum ~= nil and root ~= nil and hum.Health > 0)
end

function Utils.LocalChar() return LocalPlayer.Character end
function Utils.LocalRoot() return Utils.SafeGetRoot(Utils.LocalChar()) end
function Utils.LocalHum()  return Utils.SafeGetHum(Utils.LocalChar()) end

function Utils.DistanceTo(partA, partB)
    if not partA or not partB then return math.huge end
    return (partA.Position - partB.Position).Magnitude
end

function Utils.CenterOfScreen()
    local cam = Workspace.CurrentCamera or Workspace:FindFirstChildWhichIsA("Camera")
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

function Utils.DistFromCenter(worldPos)
    local cam = Workspace.CurrentCamera or Workspace:FindFirstChildWhichIsA("Camera")
    if not cam then return math.huge end
    local sp, onScreen = cam:WorldToViewportPoint(worldPos)
    if not onScreen then return math.huge end
    return (Vector2.new(sp.X, sp.Y) - Utils.CenterOfScreen()).Magnitude
end

function Utils.InFOVRadius(worldPos, radius)
    return Utils.DistFromCenter(worldPos) <= radius
end

function Utils.HasLineOfSight(origin, target)
    if not origin or not target then return false end
    return CacheEngine.CachedRaycast(origin, target, {Utils.LocalChar()}, 0.04)
end

function Utils.TweenPlay(inst, duration, style, dir, props)
    if not inst then return end
    local ti = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    local tw = TweenService:Create(inst, ti, props)
    tw:Play()
    return tw
end

function Utils.LerpColor(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

function Utils.HealthColor(pct)
    if pct > 0.6 then
        return Utils.LerpColor(Color3.fromRGB(255, 200, 0), Color3.fromRGB(0, 230, 120), (pct - 0.6) / 0.4)
    else
        return Utils.LerpColor(Color3.fromRGB(255, 45, 60), Color3.fromRGB(255, 200, 0), pct / 0.6)
    end
end

function Utils.IsPlayingAttackAnim(char)
    local animator = Utils.SafeGetAnimator(char)
    if not animator then return false, nil end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animId = track.Animation and track.Animation.AnimationId or ""
        local rawId = animId:match("%d+")

        if rawId and TSBDatabase.AttackAnimationIDs[rawId] then
            return true, "ID_Match"
        end

        local nameLower = (track.Name or ""):lower()
        for _, kw in ipairs(TSBDatabase.AttackKeywords) do
            if nameLower:find(kw) then
                return true, "Name_Match"
            end
        end
    end

    return false, nil
end

function Utils.IsEnemyInCounterStance(char)
    local animator = Utils.SafeGetAnimator(char)
    if not animator then return false end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animId = track.Animation and track.Animation.AnimationId or ""
        local rawId = animId:match("%d+")

        if rawId and TSBDatabase.CounterAnimationIDs[rawId] then
            return true
        end

        local nameLower = (track.Name or ""):lower()
        for _, ckw in ipairs(TSBDatabase.CounterKeywords) do
            if nameLower:find(ckw) then
                return true
            end
        end
    end

    return false
end

-- Screen Notifications Factory (Self-Cleaning & Order Independent)
local NotifyContainer = nil
local function GetNotifyContainer()
    if NotifyContainer and NotifyContainer.Parent then return NotifyContainer end
    local sg = CoreGui:FindFirstChild("HubNotifyGui")
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "HubNotifyGui"
        sg.ResetOnSpawn = false
        pcall(function() sg.Parent = CoreGui end)
        if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    end
    local container = sg:FindFirstChild("NotifyContainer")
    if not container then
        container = Instance.new("Frame")
        container.Name = "NotifyContainer"
        container.Size = UDim2.new(0, 280, 1, -40)
        container.Position = UDim2.new(1, -290, 0, 20)
        container.BackgroundTransparency = 1
        container.Parent = sg

        local layout = Instance.new("UIListLayout", container)
        layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        layout.Padding = UDim.new(0, 8)
    end
    NotifyContainer = container
    return NotifyContainer
end

local function Notify(title, message, arg3, arg4)
    local duration = 3.5
    local kind = "info"

    if type(arg3) == "number" then
        duration = arg3
        if type(arg4) == "string" then kind = arg4 end
    elseif type(arg3) == "string" then
        kind = arg3
        if type(arg4) == "number" then duration = arg4 end
    end

    local parent = GetNotifyContainer()

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 58)
    card.BackgroundColor3 = Config.UI.CardColor
    card.BorderSizePixel = 0
    card.BackgroundTransparency = 0.1
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", card)
    stroke.Thickness = 1
    stroke.Transparency = 0.4

    local colorMap = {
        info    = Config.UI.AccentColor,
        success = Config.UI.SuccessColor,
        warn    = Config.UI.WarnColor,
        error   = Config.UI.DangerColor,
    }
    local sideColor = colorMap[kind] or Config.UI.AccentColor
    stroke.Color = sideColor

    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 4, 1, -12)
    stripe.Position = UDim2.new(0, 6, 0, 6)
    stripe.BackgroundColor3 = sideColor
    stripe.BorderSizePixel = 0
    stripe.Parent = card
    Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 4)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -20, 0, 18)
    titleL.Position = UDim2.new(0, 16, 0, 6)
    titleL.BackgroundTransparency = 1
    titleL.Text = title
    titleL.TextColor3 = Config.UI.TextColor
    titleL.TextSize = 12
    titleL.Font = Enum.Font.GothamBold
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = card

    local msgL = Instance.new("TextLabel")
    msgL.Size = UDim2.new(1, -20, 0, 28)
    msgL.Position = UDim2.new(0, 16, 0, 24)
    msgL.BackgroundTransparency = 1
    msgL.Text = message
    msgL.TextColor3 = Config.UI.SubTextColor
    msgL.TextSize = 10
    msgL.Font = Enum.Font.Gotham
    msgL.TextWrapped = true
    msgL.TextXAlignment = Enum.TextXAlignment.Left
    msgL.Parent = card

    card.Position = UDim2.new(1, 400, 0, 0)
    Utils.TweenPlay(card, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {Position = UDim2.new(0, 0, 0, 0)})

    task.delay(duration, function()
        if card and card.Parent then
            pcall(function()
                local tw = Utils.TweenPlay(card, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In, {Position = UDim2.new(1, 400, 0, 0)})
                if tw then
                    tw.Completed:Connect(function() pcall(function() card:Destroy() end) end)
                    task.delay(0.3, function() pcall(function() card:Destroy() end) end)
                else
                    card:Destroy()
                end
            end)
        end
    end)
end

-- [[ SECTION 6: COMBAT ENGINE ]]
local Combat = {}

function Combat.GetTarget()
    local myRoot = Utils.LocalRoot()
    if not myRoot then return nil end

    local bestPlayer = nil
    local bestDist   = Config.Combat.AimFOVEnabled and Config.Combat.AimFOVRadius or Config.Combat.AimMaxRange

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.Combat.AimTeamCheck and player.Team == LocalPlayer.Team then continue end

        local char = player.Character
        if not Utils.IsAlive(player) then continue end

        local targetPart = char:FindFirstChild(Config.Combat.AimPart) or Utils.SafeGetRoot(char)
        if not targetPart then continue end

        if Config.Combat.AimWallCheck and not Utils.HasLineOfSight(myRoot.Position, targetPart.Position) then
            continue
        end

        local score = math.huge
        if Config.Combat.AimMode == "Nearest" then
            score = Utils.DistanceTo(myRoot, targetPart)
            if score > Config.Combat.AimMaxRange then continue end
        elseif Config.Combat.AimMode == "Cursor" then
            score = Utils.DistFromCenter(targetPart.Position)
            if Config.Combat.AimFOVEnabled and score > Config.Combat.AimFOVRadius then continue end
        elseif Config.Combat.AimMode == "LowestHP" then
            local hum = Utils.SafeGetHum(char)
            score = hum and hum.Health or math.huge
            if Utils.DistanceTo(myRoot, targetPart) > Config.Combat.AimMaxRange then continue end
        end

        if score < bestDist then
            bestDist = score
            bestPlayer = player
        end
    end

    return bestPlayer
end

function Combat.UpdateAimlock()
    if not Config.Combat.Aimlock then
        State.CurrentTarget = nil
        return
    end

    local targetPlayer = Combat.GetTarget()
    State.CurrentTarget = targetPlayer
    if not targetPlayer then return end

    local char = targetPlayer.Character
    local targetPart = char and (char:FindFirstChild(Config.Combat.AimPart) or Utils.SafeGetRoot(char))
    local myRoot     = Utils.LocalRoot()
    if not targetPart or not myRoot then return end

    local targetPos = targetPart.Position
    if Config.Combat.PredictiveAim then
        targetPos = PredictiveLagCompEngine.GetPredictedPosition(targetPart)
    end
    local mode      = Config.Combat.AimlockMode

    if mode == "Body Only (No Screen Spin)" or Config.Combat.AutoFaceTarget then
        pcall(function()
            local rootPos = myRoot.Position
            myRoot.CFrame = CFrame.lookAt(rootPos, Vector3.new(targetPos.X, rootPos.Y, targetPos.Z))
        end)
    end

    if mode == "Camera & Body" or mode == "Camera Only" then
        local cam = Workspace.CurrentCamera
        if cam then
            local curCF = cam.CFrame
            local targetCF = CFrame.lookAt(curCF.Position, targetPos)
            if Config.Combat.UseSmoothness then
                cam.CFrame = curCF:Lerp(targetCF, math.clamp(Config.Combat.AimSmoothness, 0.01, 1))
            else
                cam.CFrame = targetCF
            end
        end
    end
end

function Combat.UpdateAutoM1()
    if not Config.Combat.AutoM1 then return end
    local target = State.CurrentTarget or Combat.GetTarget()
    if not target then return end

    local myRoot = Utils.LocalRoot()
    local tRoot  = Utils.SafeGetRoot(target.Character)
    if not myRoot or not tRoot then return end

    local dist = Utils.DistanceTo(myRoot, tRoot)
    if dist <= Config.Combat.AutoM1Range then
        if Config.Combat.AntiCounterBait and Utils.IsEnemyInCounterStance(target.Character) then
            return
        end

        local now = tick()
        if Config.Combat.AutoComboSequencer then
            ComboSequencerEngine.CurrentComboMode = Config.Combat.ComboMode or "Saitama Max Damage"
            ComboSequencerEngine.ExecuteStep(target)
        else
            local now = tick()
            if (now - State.LastAttackTick) >= Config.Combat.AutoM1Delay then
                State.LastAttackTick = now
                State.M1ComboCount = (State.M1ComboCount % Config.Combat.AutoM1MaxCombo) + 1

                if Config.Combat.AutoFaceTarget then
                    pcall(function()
                        myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(tRoot.Position.X, myRoot.Position.Y, tRoot.Position.Z))
                    end)
                end

                SafeMouseClick()
            end
        end
    end
end

function Combat.UpdateAutoBlock()
    if not Config.Combat.AutoBlock and not Config.Combat.AutoParry then return end

    local myChar = Utils.LocalChar()
    local myRoot = Utils.LocalRoot()
    if not myChar or not myRoot then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not Utils.IsAlive(player) then continue end

        local tChar = player.Character
        local tRoot = Utils.SafeGetRoot(tChar)
        if not tRoot then continue end

        local dist = Utils.DistanceTo(myRoot, tRoot)
        if dist <= Config.Combat.AutoBlockRange then
            local isAttacking, _ = Utils.IsPlayingAttackAnim(tChar)
            if not isAttacking and Config.Combat.PacketParry then
                local anim = tChar:FindFirstChildWhichIsA("Humanoid") and tChar.Humanoid:FindFirstChildWhichIsA("Animator")
                if anim then
                    for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
                        local hType, conf = HeuristicDiscoveryEngine.AnalyzeAnimationTrack(track)
                        if hType == "Attack" and conf >= 40 then
                            isAttacking = true
                            break
                        end
                    end
                end
            end
            if isAttacking then
                local now = tick()
                if Config.Combat.AutoParry and (now - State.LastParryTick) >= Config.Combat.AutoParryDelay then
                    State.LastParryTick = now
                    pcall(function()
                        SafeKeyClick(Enum.KeyCode.F)
                    end)
                    Notify("⚡ AUTO PARRY ⚡", player.DisplayName .. " saldırıyor! Blok/Parry yapıldı.", "warn", 1.5)
                elseif Config.Combat.AutoBlock and (now - State.LastBlockTick) >= Config.Combat.AutoBlockDelay then
                    State.LastBlockTick = now
                    pcall(function()
                        SafeKeyClick(Enum.KeyCode.F)
                    end)
                end
                break
            end
        end
    end
end

function Combat.UpdateHitboxExpander()
    if not Config.Combat.HitboxExpander then return end
    local sz = Config.Combat.HitboxSize
    local tp = Config.Combat.HitboxTransp

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Utils.IsAlive(player) then
            local root = Utils.SafeGetRoot(player.Character)
            if root then
                pcall(function()
                    root.Size = Vector3.new(sz, sz, sz)
                    root.Transparency = tp
                    root.CanCollide = false
                end)
            end
        end
    end
end

function Combat.ResetHitboxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if player.Character then
            local root = Utils.SafeGetRoot(player.Character)
            if root then
                pcall(function()
                    root.Size = Vector3.new(2, 2, 1)
                    root.Transparency = 1
                end)
            end
        end
    end
end

function Combat.UpdateBodyReach()
    if not Config.Combat.BodyReach then return end
    local char = Utils.LocalChar()
    if not char then return end
    local dist = Config.Combat.ReachDistance

    pcall(function()
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and (part.Name:find("Arm") or part.Name:find("Hand") or part.Name:find("Leg")) then
                part.Size = Vector3.new(dist, dist, dist)
                part.Massless = true
            end
        end
    end)
end

function Combat.UpdateFakeLag(dt)
    if not Config.Combat.FakeLag then return end
    local root = Utils.LocalRoot()
    if not root then return end

    pcall(function()
        if math.random(1, 10) <= Config.Combat.FakeLagIntensity then
            root.Anchored = true
            task.wait(0.04)
            root.Anchored = false
        end
    end)
end

function Combat.HookAntiRagdoll(char)
    if not char then return end
    local hum = Utils.SafeGetHum(char)
    if not hum then return end

    hum.StateChanged:Connect(function(_, newState)
        if Config.Combat.AntiRagdoll then
            if newState == Enum.HumanoidStateType.Ragdoll or newState == Enum.HumanoidStateType.FallingDown or newState == Enum.HumanoidStateType.Physics then
                task.wait(Config.Combat.AntiRagdollDelay)
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    local root = Utils.SafeGetRoot(char)
                    if root then root.AssemblyLinearVelocity = Vector3.zero end
                end)
            end
        end
    end)
end

function Combat.HookAutoEvasive(char)
    if not char then return end
    local hum = Utils.SafeGetHum(char)
    if not hum then return end

    hum.HealthChanged:Connect(function(hp)
        if Config.Combat.AutoEvasive then
            local pct = (hp / hum.MaxHealth) * 100
            if pct <= Config.Combat.AutoEvasiveHP and (tick() - State.LastEvasiveTick) >= 15 then
                State.LastEvasiveTick = tick()
                pcall(function()
                    SafeKeyClick(Enum.KeyCode.Q)
                end)
                Notify("AUTO EVASIVE", "Critical HP! Dash/Evasive triggered.", "error", 2.5)
            end
        end
    end)
end

function Combat.CheckAutoAwakening()
    if not Config.Combat.AutoAwakening then return end
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui then
            local screen = pGui:FindFirstChild("ScreenGui") or pGui:FindFirstChild("Hotbar")
            if screen then
                for _, desc in ipairs(screen:GetDescendants()) do
                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                        local txt = (desc.Text or ""):lower()
                        if txt:find("awakening") or txt:find("ultimate") or txt:find("100%") then
                            SafeKeyClick(Enum.KeyCode.G)
                        end
                    end
                end
            end
        end
    end)
end

function Combat.UpdateNoKnockback()
    if not Config.Combat.NoKnockback then return end
    local root = Utils.LocalRoot()
    if root then
        pcall(function()
            local vel = root.AssemblyLinearVelocity
            if vel.Magnitude > 80 then
                root.AssemblyLinearVelocity = Vector3.new(vel.X * 0.1, vel.Y * 0.1, vel.Z * 0.1)
            end
        end)
    end
end

function Combat.UpdateNoSlowdown()
    if not Config.Combat.NoSlowdown then return end
    local hum = Utils.LocalHum()
    if hum and hum.WalkSpeed < 16 then
        hum.WalkSpeed = 16
    end
end

function Combat.ToggleMassBring()
    if State.MassBringActive then
        State.MassBringActive = false
        StateMachine.TransitionTo(FSMStates.IDLE)
        Combat.ResetHitboxes()
        if State.SavedBehindTPState ~= nil then
            Config.Target.BehindTP = State.SavedBehindTPState
            State.SavedBehindTPState = nil
            ConfigSystem.RefreshUI()
        end
        Notify("MASS VACUUM", "Mass Vacuum manuel kapatıldı!", "info", 2)
        return
    end

    local myChar = Utils.LocalChar()
    local myRoot = Utils.LocalRoot()
    local myHum  = Utils.LocalHum()
    if not myChar or not myRoot or not myHum or myHum.Health <= 0 then
        Notify("Mass Vacuum", "Karakterinizin parçası bulunamadı!", "error", 2)
        return
    end

    if Config.Target.BehindTP then
        State.SavedBehindTPState = true
        Config.Target.BehindTP = false
        ConfigSystem.RefreshUI()
    end

    State.MassBringActive = true
    StateMachine.TransitionTo(FSMStates.MASS_BRING)
    State.MassBringEndTime = tick() + (Config.Combat.MassBringDuration or 10)
    Notify("⚡ MASS VACUUM TP ⚡", string.format("%d saniye boyunca HERKES %d stud önüne ışınlanıyor! (Behind-TP geçici kapalı)", Config.Combat.MassBringDuration or 10, Config.Combat.MassBringDistance or 20), "warn", 4)
end

function Combat.UpdateMassBring(dt)
    if not State.MassBringActive then return end

    if tick() >= State.MassBringEndTime then
        State.MassBringActive = false
        if not Config.Combat.HitboxExpander then
            Combat.ResetHitboxes()
        end
        if State.SavedBehindTPState ~= nil then
            Config.Target.BehindTP = State.SavedBehindTPState
            State.SavedBehindTPState = nil
            ConfigSystem.RefreshUI()
        end
        Notify("MASS VACUUM", "Mass Vacuum süresi doldu! (Normale dönüldü)", "info", 3)
        return
    end

    local myChar = Utils.LocalChar()
    local myRoot = Utils.LocalRoot()
    local myHum  = Utils.LocalHum()
    if not myChar or not myRoot or not myHum or myHum.Health <= 0 then return end

    local mode = Config.Combat.MassBringMode or "FE Real Damage (Blitz)"

    if mode == "FE Real Damage (Blitz)" then
        local aliveEnemies = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and Utils.IsAlive(p) then
                local tRoot = Utils.SafeGetRoot(p.Character)
                if tRoot then
                    table.insert(aliveEnemies, {Player = p, Root = tRoot})
                end
            end
        end

        if #aliveEnemies == 0 then return end

        State.MassBringIndex = ((State.MassBringIndex or 0) % #aliveEnemies) + 1
        local targetData = aliveEnemies[State.MassBringIndex]
        if targetData and targetData.Root then
            local tRoot = targetData.Root
            local tCF = tRoot.CFrame
            local dist = Config.Target.BehindDistance or 3.2
            local targetPos = tCF.Position - (tCF.LookVector * dist) + Vector3.new(0, 0.2, 0)

            pcall(function()
                tRoot.Size = Vector3.new(16, 16, 16)
                tRoot.CanTouch = true
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
                myRoot.CFrame = CFrame.lookAt(targetPos, tRoot.Position)
            end)

            if (tick() - State.LastAttackTick) >= (Config.Combat.AutoM1Delay or 0.12) then
                State.LastAttackTick = tick()
                SafeMouseClick()
            end
        end
    else
        local dist = Config.Combat.MassBringDistance or 20
        local targetPos = myRoot.Position + (myRoot.CFrame.LookVector * dist)
        local expandSize = Vector3.new(dist * 2.2, dist * 2.2, dist * 2.2)

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and Utils.IsAlive(p) then
                local tChar = p.Character
                local tRoot = Utils.SafeGetRoot(tChar)
                if tRoot then
                    pcall(function()
                        tRoot.Size = expandSize
                        tRoot.Transparency = 0.75
                        tRoot.CanCollide = false
                        tRoot.CanTouch = true
                        tRoot.Massless = true
                        tRoot.AssemblyLinearVelocity = Vector3.zero
                        tRoot.AssemblyAngularVelocity = Vector3.zero
                        tRoot.CFrame = CFrame.new(targetPos)
                    end)
                end
            end
        end
    end
end

-- [[ SECTION 7.5: TARGET & BEHIND-TP ENGINE WITH ADVANCED MODES ]]
local TargetSystem = {}

function TargetSystem.GetTargetPlayer()
    local mode = Config.Target.TargetMode or "Nearest"

    if mode == "Selected Player" then
        local name = Config.Target.SelectedPlayerName
        if name and name ~= "" and name ~= "Oyuncu Yok" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and (p.Name == name or p.DisplayName == name) then
                    if Utils.IsAlive(p) then return p end
                end
            end
        end
    elseif mode == "Lowest HP" then
        local myRoot = Utils.LocalRoot()
        local bestPlayer = nil
        local lowestHP = math.huge

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and Utils.IsAlive(p) then
                local hum = Utils.SafeGetHum(p.Character)
                if hum and hum.Health < lowestHP then
                    lowestHP = hum.Health
                    bestPlayer = p
                end
            end
        end
        if bestPlayer then return bestPlayer end
    elseif mode == "Random" then
        if State.RandomTarget and Utils.IsAlive(State.RandomTarget) and (tick() - (State.RandomTargetTick or 0)) < 3.5 then
            return State.RandomTarget
        end

        local alivePlayers = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and Utils.IsAlive(p) then
                table.insert(alivePlayers, p)
            end
        end
        if #alivePlayers > 0 then
            local picked = alivePlayers[math.random(1, #alivePlayers)]
            State.RandomTarget = picked
            State.RandomTargetTick = tick()
            return picked
        end
    end

    -- Default / Nearest Mode
    if State.CurrentTarget and Utils.IsAlive(State.CurrentTarget) then
        return State.CurrentTarget
    end
    return Combat.GetTarget()
end

function TargetSystem.UpdateBehindTP(dt)
    if not Config.Target.BehindTP then return end
    if StateMachine.CurrentState == FSMStates.IDLE or StateMachine.CurrentState == FSMStates.COMBAT then StateMachine.TransitionTo(FSMStates.BEHIND_TP) end
    local target = TargetSystem.GetTargetPlayer()
    if not target then return end

    local myChar = Utils.LocalChar()
    local myRoot = Utils.LocalRoot()
    local myHum  = Utils.SafeGetHum(myChar)
    local tChar  = target.Character
    local tRoot  = Utils.SafeGetRoot(tChar)
    local tHum   = Utils.SafeGetHum(tChar)
    if not myChar or not myRoot or not myHum or not tChar or not tRoot or not tHum then return end

    if myHum.Health <= 0 or tHum.Health <= 0 then return end

    local state = myHum:GetState()
    if state == Enum.HumanoidStateType.Dead or state == Enum.HumanoidStateType.Physics then
        return
    end

    for _, part in ipairs(myChar:GetChildren()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    local targetCF = tRoot.CFrame
    local lookDir  = targetCF.LookVector
    local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)
    if flatLook.Magnitude > 0.001 then
        flatLook = flatLook.Unit
    else
        flatLook = Vector3.new(0, 0, -1)
    end

    local predictedPos = tRoot.Position
    if Config.Combat.PredictiveAim then
        predictedPos = PredictiveLagCompEngine.GetPredictedPosition(tRoot, dt)
    else
        local dtStep = (type(dt) == "number" and dt > 0) and dt or 0.016
        predictedPos = tRoot.Position + (tRoot.AssemblyLinearVelocity * dtStep)
    end

    local dist = Config.Target.BehindDistance or 3.5
    local behindPos = predictedPos - (flatLook * dist) + Vector3.new(0, 0.1, 0)
    local targetFacePos = predictedPos + Vector3.new(0, 0.1, 0)

    pcall(function()
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.AssemblyAngularVelocity = Vector3.zero
        myRoot.CFrame = CFrame.lookAt(behindPos, targetFacePos)
    end)

    local m1Delay = Config.Combat.AutoM1Delay or 0.12
    if Config.Target.AutoM1OnTP and (tick() - State.LastAttackTick) >= m1Delay then
        State.LastAttackTick = tick()
        SafeMouseClick()
    end
end

-- [[ SECTION 7.6: SKILL AUTO-AIM & GUARANTEED HIT ENGINE ]]
local SkillSystem = {}

function SkillSystem.OrientToTarget()
    local target = State.CurrentTarget or Combat.GetTarget() or TargetSystem.GetTargetPlayer()
    if not target or not Utils.IsAlive(target) then return end

    local myRoot = Utils.LocalRoot()
    local tRoot  = Utils.SafeGetRoot(target.Character)
    if not myRoot or not tRoot then return end

    pcall(function()
        local rootPos = myRoot.Position
        local tPos = tRoot.Position
        myRoot.CFrame = CFrame.lookAt(rootPos, Vector3.new(tPos.X, rootPos.Y, tPos.Z))
    end)
end

function SkillSystem.ExecuteVoidKill(target)
    if not Config.Skills.VoidKill or State.IsVoidKilling then return end

    target = target or State.CurrentTarget or Combat.GetTarget() or TargetSystem.GetTargetPlayer()
    if not target or not Utils.IsAlive(target) then return end

    local myChar = Utils.LocalChar()
    local myRoot = Utils.LocalRoot()
    local tChar  = target.Character
    local tRoot  = Utils.SafeGetRoot(tChar)
    local tHum   = Utils.SafeGetHum(tChar)
    if not myChar or not myRoot or not tChar or not tRoot or not tHum then return end

    local charKey = TSBDatabase.DetectCurrentCharacter()
    local profile = TSBDatabase.Characters[charKey] or TSBDatabase.Characters.Universal

    local savedGroundPos = myRoot.CFrame
    State.IsVoidKilling = true
    StateMachine.TransitionTo(FSMStates.VOID_KILL)
    State.SavedPreVoidPos = savedGroundPos

    task.spawn(function()
        local startTime = tick()
        local maxWait = profile.MaxWindup or 0.4
        local hasHitConnected = false

        while (tick() - startTime) < maxWait do
            task.wait(0.02)
            if not Utils.IsAlive(target) or not myRoot or not tRoot then break end

            local currentDist = Utils.DistanceTo(myRoot, tRoot)
            local isTargetStunned = (tHum:GetState() == Enum.HumanoidStateType.Physics or tHum:GetState() == Enum.HumanoidStateType.Ragdoll)
            local isPlayingAttack, _ = Utils.IsPlayingAttackAnim(myChar)

            if currentDist <= 10 or isTargetStunned or isPlayingAttack then
                hasHitConnected = true
                break
            end
        end

        if hasHitConnected or Utils.DistanceTo(myRoot, tRoot) <= 14 then
            Notify("⚡ VOID SACRIFICE (" .. profile.Name .. ") ⚡", "Skill tutundu! Rakip voide çekiliyor...", "warn", 2.5)

            local voidY = Config.Skills.VoidDepth or -350
            local voidPos = Vector3.new(myRoot.Position.X, voidY, myRoot.Position.Z)
            local voidCF = CFrame.new(voidPos)

            pcall(function()
                tRoot.AssemblyLinearVelocity = Vector3.zero
                tRoot.AssemblyAngularVelocity = Vector3.zero
                tRoot.CFrame = voidCF

                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
                myRoot.CFrame = voidCF + Vector3.new(0, 3, -2)
            end)

            local holdTime = profile.HoldTime or (Config.Skills.VoidReturnDelay or 0.5)
            task.delay(holdTime, function()
                if savedGroundPos and myRoot then
                    pcall(function()
                        myRoot.AssemblyLinearVelocity = Vector3.zero
                        myRoot.AssemblyAngularVelocity = Vector3.zero
                        myRoot.CFrame = savedGroundPos
                    end)
                    Notify("VOID RETURN", "Eski konumunuza güvenle dönüldü! Rakip voide düştü.", "success", 2)
                end
                State.IsVoidKilling = false
                State.SavedPreVoidPos = nil
                if StateMachine.CurrentState == FSMStates.VOID_KILL then StateMachine.TransitionTo(FSMStates.IDLE) end
            end)
        else
            State.IsVoidKilling = false
            State.SavedPreVoidPos = nil
            if StateMachine.CurrentState == FSMStates.VOID_KILL then StateMachine.TransitionTo(FSMStates.IDLE) end
        end
    end)
end

function SkillSystem.HookSkillKeys()
    UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            if inp.KeyCode == Enum.KeyCode.One or inp.KeyCode == Enum.KeyCode.Two 
               or inp.KeyCode == Enum.KeyCode.Three or inp.KeyCode == Enum.KeyCode.Four
               or inp.KeyCode == Enum.KeyCode.G or inp.KeyCode == Enum.KeyCode.T then
                if Config.Skills.AutoAim then
                    SkillSystem.OrientToTarget()
                end
                if Config.Skills.VoidKill then
                    SkillSystem.ExecuteVoidKill()
                end
            end
        end
    end)
end
SkillSystem.HookSkillKeys()

local lastSkillSpamTick = 0
local currentSkillIdx = 1
local skillKeysList = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}

function SkillSystem.UpdateAutoSkillSpam()
    if not Config.Skills.AutoSkillSpam and not Config.Skills.AutoUltSpam then return end
    local now = tick()
    local target = State.CurrentTarget or Combat.GetTarget() or TargetSystem.GetTargetPlayer()
    if not target or not Utils.IsAlive(target) then return end

    if Config.Skills.AutoUltSpam then
        pcall(function()
            SafeKeyClick(Enum.KeyCode.G)
            SafeKeyClick(Enum.KeyCode.T)
        end)
    end

    if Config.Skills.AutoSkillSpam and (now - lastSkillSpamTick) >= Config.Skills.SkillSpamDelay then
        lastSkillSpamTick = now
        SkillSystem.OrientToTarget()
        local keyToPress = skillKeysList[currentSkillIdx]
        if keyToPress then
            SafeKeyClick(keyToPress)
        end
        currentSkillIdx = (currentSkillIdx % #skillKeysList) + 1
    end
end

-- [[ SECTION 7.7: SURVIVAL & SKY ESCAPE ENGINE ]]
local SurvivalSystem = {}

function SurvivalSystem.CheckSkyEscape()
    if not Config.Survival.SkyTeleport then
        if Config.Survival.HasSkyEscaped then
            SurvivalSystem.RestoreFeaturesAndReturn()
        end
        return
    end

    local hum  = Utils.LocalHum()
    local root = Utils.LocalRoot()
    if not hum or not root or hum.Health <= 0 then return end

    local hpPct = (hum.Health / hum.MaxHealth) * 100

    -- Phase 1: Trigger Sky Escape when HP drops below threshold
    if hpPct <= Config.Survival.SkyEscapeHP then
        if not Config.Survival.HasSkyEscaped then
            Config.Survival.HasSkyEscaped = true
            StateMachine.TransitionTo(FSMStates.SKY_ESCAPE)
            State.SavedSkyEscapeGroundPos = root.CFrame

            -- Save & Disable features that interfere with Sky Teleport (Behind-TP, Aimlock Melee TP, Mass Bring)
            State.SavedSkyEscapeFeatures = {
                BehindTP = Config.Target.BehindTP,
                Aimlock = Config.Combat.Aimlock,
                AutoM1 = Config.Combat.AutoM1,
                MassBring = State.MassBringActive,
            }

            Config.Target.BehindTP = false
            Config.Combat.Aimlock = false
            Config.Combat.AutoM1 = false
            State.MassBringActive = false
            ConfigSystem.RefreshUI()

            -- Initial Teleport into Sky
            local skyY = root.Position.Y + Config.Survival.SkyEscapeHeight
            State.SkyTargetY = skyY
            pcall(function()
                root.CFrame = CFrame.new(root.Position.X, skyY, root.Position.Z)
                root.AssemblyLinearVelocity = Vector3.zero
            end)

            Notify("⚡ SAFE SKY ESCAPE ⚡", string.format("Canınız %% %d altına düştü! Güvenli irtifaya ışınlanıldı. (TP & Saldırılar askıya alındı)", Config.Survival.SkyEscapeHP), "warn", 3.5)
        else
            -- Continuous Sky Lock: Hold player strictly at sky height so gravity or flinging never pulls down!
            pcall(function()
                local curPos = root.Position
                local targetY = State.SkyTargetY or (curPos.Y + Config.Survival.SkyEscapeHeight)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.CFrame = CFrame.new(curPos.X, targetY, curPos.Z)
            end)
        end
    else
        -- Phase 2: User specified SkyReturnHP threshold reached -> return to ground & restore features!
        local returnThreshold = Config.Survival.SkyReturnHP or 80
        if Config.Survival.HasSkyEscaped and hpPct >= returnThreshold then
            SurvivalSystem.RestoreFeaturesAndReturn()
        end
    end
end

function SurvivalSystem.RestoreFeaturesAndReturn()
    Config.Survival.HasSkyEscaped = false
    if StateMachine.CurrentState == FSMStates.SKY_ESCAPE then StateMachine.TransitionTo(FSMStates.IDLE) end
    local root = Utils.LocalRoot()

    -- Return to saved ground position
    if State.SavedSkyEscapeGroundPos and root then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = State.SavedSkyEscapeGroundPos + Vector3.new(0, 3, 0)
        end)
    end

    -- Restore previous states in Config & GUI
    if State.SavedSkyEscapeFeatures then
        Config.Target.BehindTP = State.SavedSkyEscapeFeatures.BehindTP or false
        Config.Combat.Aimlock = State.SavedSkyEscapeFeatures.Aimlock or false
        Config.Combat.AutoM1 = State.SavedSkyEscapeFeatures.AutoM1 or false
        State.SavedSkyEscapeFeatures = nil
        ConfigSystem.RefreshUI()
    end

    Notify("SKY RETURN", "Canınız normale döndü! Eski konumunuza ışınlanıldı ve özellikler tekrar açıldı.", "success", 3)
end

function SurvivalSystem.UpdateSkyDodge(dt)
    if not Config.Survival.SkyDodge or State.IsEmergencyStop or Config.Survival.HasSkyEscaped then
        if State.SkyDodge.IsDodging then
            SurvivalSystem.EndSkyDodge()
        end
        return
    end

    local myChar = Utils.LocalChar()
    local myRoot = Utils.LocalRoot()
    local myHum  = Utils.LocalHum()
    if not myChar or not myRoot or not myHum or myHum.Health <= 0 then
        if State.SkyDodge.IsDodging then SurvivalSystem.EndSkyDodge() end
        return
    end

    local now = tick()

    -- Check if we are currently in an active sky dodge
    if State.SkyDodge.IsDodging then
        local attacker = State.SkyDodge.AttackingPlayer
        local attackerStillAttacking = false

        if attacker and Utils.IsAlive(attacker) and attacker.Character then
            local isAttacking, _ = Utils.IsPlayingAttackAnim(attacker.Character)
            if isAttacking then
                attackerStillAttacking = true
            end
        end

        -- Check any other nearby enemy if attacker finished or left
        if not attackerStillAttacking then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and Utils.IsAlive(player) then
                    local tRoot = Utils.SafeGetRoot(player.Character)
                    if tRoot and State.SkyDodge.SavedGroundPos then
                        local dist = (State.SkyDodge.SavedGroundPos.Position - tRoot.Position).Magnitude
                        if dist <= Config.Survival.SkyDodgeRange then
                            local isAttacking, _ = Utils.IsPlayingAttackAnim(player.Character)
                            if isAttacking then
                                attackerStillAttacking = true
                                State.SkyDodge.AttackingPlayer = player
                                break
                            end
                        end
                    end
                end
            end
        end

        if attackerStillAttacking then
            -- Maintain Sky Position & Lock Camera to ground position
            pcall(function()
                local groundPos = State.SkyDodge.SavedGroundPos.Position
                local targetY = groundPos.Y + Config.Survival.SkyDodgeHeight
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
                myRoot.CFrame = CFrame.new(groundPos.X, targetY, groundPos.Z)
            end)
        else
            -- Attack animation ended -> Return instantly to ground!
            SurvivalSystem.EndSkyDodge()
        end

    else
        -- We are on ground -> scan nearby players for attack animations or skills
        if (now - State.SkyDodge.LastDodgeTick) < Config.Survival.SkyDodgeCooldown then return end

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer or not Utils.IsAlive(player) then continue end

            local tChar = player.Character
            local tRoot = Utils.SafeGetRoot(tChar)
            if not tRoot then continue end

            local dist = Utils.DistanceTo(myRoot, tRoot)
            if dist <= Config.Survival.SkyDodgeRange then
                local isAttacking, attackType = Utils.IsPlayingAttackAnim(tChar)
                if isAttacking then
                    -- Trigger Sky Dodge!
                    State.SkyDodge.IsDodging = true
                    StateMachine.TransitionTo(FSMStates.SKY_DODGE)
                    State.SkyDodge.LastDodgeTick = now
                    State.SkyDodge.AttackingPlayer = player
                    State.SkyDodge.SavedGroundPos = myRoot.CFrame
                    State.SkyDodge.LockedCameraPos = Camera and Camera.CFrame or nil

                    local skyY = myRoot.Position.Y + Config.Survival.SkyDodgeHeight
                    pcall(function()
                        myRoot.AssemblyLinearVelocity = Vector3.zero
                        myRoot.AssemblyAngularVelocity = Vector3.zero
                        myRoot.CFrame = CFrame.new(myRoot.Position.X, skyY, myRoot.Position.Z)
                    end)

                    Notify("⚡ SKY DODGE ⚡", string.format("%s saldırısından havaya kaçıldı! (Kamera kilitli)", player.DisplayName), "info", 1.2)
                    break
                end
            end
        end
    end
end

function SurvivalSystem.EndSkyDodge()
    State.SkyDodge.IsDodging = false
    if StateMachine.CurrentState == FSMStates.SKY_DODGE then StateMachine.TransitionTo(FSMStates.IDLE) end
    local myRoot = Utils.LocalRoot()
    if myRoot and State.SkyDodge.SavedGroundPos then
        pcall(function()
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
            myRoot.CFrame = State.SkyDodge.SavedGroundPos
        end)
    end
    State.SkyDodge.AttackingPlayer = nil
    State.SkyDodge.SavedGroundPos = nil
    State.SkyDodge.LockedCameraPos = nil
end

-- [[ SECTION 8: MOVEMENT ENGINE ]]
local Movement = {}

function Movement.ToggleFly(enable)
    Config.Movement.Fly = enable
    local root = Utils.LocalRoot()
    local hum  = Utils.LocalHum()
    if not root or not hum then return end

    if enable then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)

        if Config.Movement.FlyMode == "Velocity" then
            pcall(function()
                local oldAtt = root:FindFirstChild("HubFlyAtt")
                if oldAtt then oldAtt:Destroy() end
                local oldLV = root:FindFirstChild("HubLinearVel")
                if oldLV then oldLV:Destroy() end
                local oldAG = root:FindFirstChild("HubAlignOri")
                if oldAG then oldAG:Destroy() end
            end)

            local att = Instance.new("Attachment")
            att.Name = "HubFlyAtt"
            att.Parent = root
            State.Fly.Att = att

            local lv = Instance.new("LinearVelocity")
            lv.Name = "HubLinearVel"
            lv.Attachment0 = att
            lv.MaxForce = math.huge
            lv.VectorVelocity = Vector3.zero
            lv.RelativeTo = Enum.ActuatorRelativeTo.World
            lv.Parent = root
            State.Fly.LV = lv

            local ag = Instance.new("AlignOrientation")
            ag.Name = "HubAlignOri"
            ag.Attachment0 = att
            ag.MaxTorque = math.huge
            ag.Responsiveness = 200
            ag.Mode = Enum.OrientationAlignmentMode.OneAttachment
            ag.CFrame = root.CFrame
            ag.Parent = root
            State.Fly.AG = ag
        end
        Notify("Movement", "Fly (Uçma) AKTİF!", "success", 2)
    else
        pcall(function()
            if State.Fly.LV then State.Fly.LV:Destroy() end
            if State.Fly.AG then State.Fly.AG:Destroy() end
            if State.Fly.Att then State.Fly.Att:Destroy() end
        end)
        State.Fly.LV = nil
        State.Fly.AG = nil
        State.Fly.Att = nil
        Notify("Movement", "Fly (Uçma) KAPALI!", "warn", 2)
    end
end

function Movement.UpdateFly(dt)
    if not Config.Movement.Fly then return end
    local root = Utils.LocalRoot()
    local cam  = Workspace.CurrentCamera
    if not root or not cam then return end

    local speed = Config.Movement.FlySpeed or 60
    local moveDir = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

    if Config.Movement.FlyMode == "Velocity" and State.Fly.LV then
        State.Fly.LV.VectorVelocity = moveDir.Magnitude > 0 and (moveDir.Unit * speed) or Vector3.zero
        if State.Fly.AG then State.Fly.AG.CFrame = cam.CFrame end
    else
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if moveDir.Magnitude > 0 then
            root.CFrame = root.CFrame + (moveDir.Unit * speed * (dt or 0.016))
        end
    end
end

function Movement.UpdateSpeed(dt)
    local hum  = Utils.LocalHum()
    local root = Utils.LocalRoot()
    local char = Utils.LocalChar()
    if not hum or not root or not char then return end

    if Config.Movement.SpeedBoost then
        if Config.Movement.SpeedMethod == "WalkSpeed" then
            hum.WalkSpeed = Config.Movement.SpeedVal
        elseif Config.Movement.SpeedMethod == "CFrame" then
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                local extraSpeed = (Config.Movement.SpeedVal - 16) * (dt or 0.016)
                root.CFrame = root.CFrame + (moveDir.Unit * extraSpeed)
            end
        end
    end

    if Config.Movement.HighJump then
        hum.UseJumpPower = true
        hum.JumpPower = Config.Movement.JumpPowerVal
    end

    if Config.Movement.InfiniteStamina then
        pcall(function()
            local stam = char:FindFirstChild("Stamina") or char:FindFirstChild("Energy")
            if stam and stam:IsA("NumberValue") then stam.Value = 100 end
        end)
    end
end

function Movement.UpdateNoclip()
    if not Config.Movement.Noclip then return end
    local char = Utils.LocalChar()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

function Movement.UpdateAntiVoid()
    if not Config.Movement.AntiVoid or State.IsVoidKilling then return end
    local root = Utils.LocalRoot()
    local hum  = Utils.LocalHum()
    if not root or not hum or hum.Health <= 0 then return end

    if root.Position.Y >= 0 and root.AssemblyLinearVelocity.Magnitude < 220 then
        State.LastSafePos = root.CFrame
    end

    if root.Position.Y < Config.Movement.AntiVoidThreshold or root.AssemblyLinearVelocity.Magnitude > 600 then
        if State.LastSafePos then
            root.CFrame = State.LastSafePos + Vector3.new(0, 6, 0)
            root.AssemblyLinearVelocity = Vector3.zero
            Notify("Anti-Void", "Recovered from void fling!", "warn", 2)
        end
    end
end

function Movement.UpdateGlide()
    if not Config.Movement.GlideMode then return end
    local root = Utils.LocalRoot()
    local hum  = Utils.SafeGetHum(root and root.Parent)
    if not root or not hum then return end
    if hum:GetState() == Enum.HumanoidStateType.Freefall and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        local vel = root.AssemblyLinearVelocity
        if vel.Y < -6 then
            root.AssemblyLinearVelocity = Vector3.new(vel.X, -3, vel.Z)
        end
    end
end

function Movement.UpdateAirStall()
    if not Config.Movement.AirStall then return end
    local root = Utils.LocalRoot()
    local hum  = Utils.SafeGetHum(root and root.Parent)
    if not root or not hum then return end
    if hum:GetState() == Enum.HumanoidStateType.Freefall and UserInputService:IsKeyDown(Enum.KeyCode.E) then
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

function Movement.TeleportToPlayer(target)
    if not target or not Utils.IsAlive(target) then
        Notify("Teleport", "Player is unavailable!", "error", 2)
        return
    end
    local myRoot = Utils.LocalRoot()
    local tRoot  = Utils.SafeGetRoot(target.Character)
    if not myRoot or not tRoot then return end
    myRoot.CFrame = tRoot.CFrame + Vector3.new(3, 0, 3)
    Notify("Teleport", "Teleported to " .. target.DisplayName, "success", 2)
end

-- [[ SECTION 9: ESP & STATE DYNAMIC VISUALS ENGINE ]]
local ESP = {}

-- Dedicated GUI container for 100% stable Billboards across respawns
local ESPGuiContainer = nil
pcall(function()
    ESPGuiContainer = CoreGui:FindFirstChild("Hub_ESP_Billboards")
    if not ESPGuiContainer then
        ESPGuiContainer = Instance.new("Folder")
        ESPGuiContainer.Name = "Hub_ESP_Billboards"
        pcall(function() ESPGuiContainer.Parent = CoreGui end)
        if not ESPGuiContainer.Parent then ESPGuiContainer.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    end
end)

function ESP.GetPlayerStateColor(player)
    local ok, charBadge, isUltActive, hasSaitamaUltEnded = pcall(function()
        return TSBDatabase.GetPlayerCharacterInfo(player)
    end)
    if not ok then return Config.Visuals.StandardESPColor or Color3.fromRGB(0, 220, 255), "Standard" end

    if hasSaitamaUltEnded and Config.Visuals.DeathCounterRisk then
        return Config.Visuals.DeathCounterRiskColor or Color3.fromRGB(255, 185, 0), "DeathRisk"
    elseif isUltActive and Config.Visuals.ShowUltiESP then
        return Config.Visuals.UltiESPColor or Color3.fromRGB(255, 65, 80), "Ulti"
    else
        return Config.Visuals.StandardESPColor or Color3.fromRGB(0, 220, 255), "Standard"
    end
end

function ESP.CreateHighlight(player)
    local char = player and player.Character
    if not char then return end

    local existingHl = State.ESP.Highlights[player]
    if existingHl and existingHl.Parent and existingHl.Adornee == char then
        return
    end

    if existingHl then
        pcall(function() existingHl:Destroy() end)
        State.ESP.Highlights[player] = nil
    end

    pcall(function()
        local stateColor, _ = ESP.GetPlayerStateColor(player)
        local hl = Instance.new("Highlight")
        hl.Name = "Hub_HL_" .. player.UserId
        hl.FillColor = stateColor
        hl.OutlineColor = Config.Visuals.HighlightOutline or Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = Config.Visuals.HighlightFillTrans or 0.45
        hl.OutlineTransparency = Config.Visuals.HighlightOutTrans or 0.0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = char
        hl.Parent = char
        State.ESP.Highlights[player] = hl
    end)
end

function ESP.RemoveHighlight(player)
    local hl = State.ESP.Highlights[player]
    if hl then
        pcall(function() hl:Destroy() end)
        State.ESP.Highlights[player] = nil
    end
end

function ESP.CreateBillboard(player)
    local char = player and player.Character
    local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
    if not head then return end

    local existingBb = State.ESP.Billboards[player]
    if existingBb and existingBb.Parent and existingBb.Adornee == head then
        return
    end

    if existingBb then
        pcall(function() existingBb:Destroy() end)
        State.ESP.Billboards[player] = nil
    end

    pcall(function()
        local bb = Instance.new("BillboardGui")
        bb.Name = "Hub_BB_" .. player.UserId
        bb.Adornee = head
        bb.Size = UDim2.new(0, 220, 0, 84)
        bb.StudsOffset = Vector3.new(0, 3.8, 0)
        bb.AlwaysOnTop = true
        bb.LightInfluence = 0
        bb.ResetOnSpawn = false
        bb.Parent = ESPGuiContainer or head

        local layout = Instance.new("UIListLayout", bb)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 2)

        local nameL = Instance.new("TextLabel")
        nameL.Name = "NameLabel"
        nameL.LayoutOrder = 1
        nameL.Size = UDim2.new(1, 0, 0, 16)
        nameL.BackgroundTransparency = 1
        nameL.Text = player.DisplayName
        nameL.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameL.TextSize = 12
        nameL.Font = Enum.Font.GothamBold
        nameL.TextStrokeTransparency = 0.3
        nameL.TextXAlignment = Enum.TextXAlignment.Center
        nameL.Parent = bb

        local charL = Instance.new("TextLabel")
        charL.Name = "CharLabel"
        charL.LayoutOrder = 2
        charL.Size = UDim2.new(1, 0, 0, 16)
        charL.BackgroundTransparency = 1
        charL.Text = "❓ BILINMIYOR"
        charL.TextColor3 = Color3.fromRGB(0, 220, 255)
        charL.TextSize = 12
        charL.Font = Enum.Font.GothamBold
        charL.TextStrokeTransparency = 0.2
        charL.TextXAlignment = Enum.TextXAlignment.Center
        charL.Parent = bb

        local ultL = Instance.new("TextLabel")
        ultL.Name = "UltLabel"
        ultL.LayoutOrder = 3
        ultL.Size = UDim2.new(1, 0, 0, 14)
        ultL.BackgroundTransparency = 1
        ultL.Text = ""
        ultL.TextColor3 = Color3.fromRGB(255, 65, 80)
        ultL.TextSize = 11
        ultL.Font = Enum.Font.GothamBold
        ultL.TextStrokeTransparency = 0.2
        ultL.TextXAlignment = Enum.TextXAlignment.Center
        ultL.Visible = false
        ultL.Parent = bb

        local distL = Instance.new("TextLabel")
        distL.Name = "DistLabel"
        distL.LayoutOrder = 4
        distL.Size = UDim2.new(1, 0, 0, 12)
        distL.BackgroundTransparency = 1
        distL.Text = "0 studs"
        distL.TextColor3 = Config.UI.AccentColor
        distL.TextSize = 9
        distL.Font = Enum.Font.GothamMedium
        distL.TextStrokeTransparency = 0.5
        distL.TextXAlignment = Enum.TextXAlignment.Center
        distL.Parent = bb

        local hpBg = Instance.new("Frame")
        hpBg.Name = "HpBg"
        hpBg.LayoutOrder = 5
        hpBg.Size = UDim2.new(0.8, 0, 0, 4)
        hpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        hpBg.BorderSizePixel = 0
        hpBg.Parent = bb
        Instance.new("UICorner", hpBg).CornerRadius = UDim.new(1, 0)

        local hpBar = Instance.new("Frame")
        hpBar.Name = "HpBar"
        hpBar.Size = UDim2.new(1, 0, 1, 0)
        hpBar.BackgroundColor3 = Color3.fromRGB(0, 230, 120)
        hpBar.BorderSizePixel = 0
        hpBar.Parent = hpBg
        Instance.new("UICorner", hpBar).CornerRadius = UDim.new(1, 0)

        State.ESP.Billboards[player] = bb
    end)
end

function ESP.RemoveBillboard(player)
    local bb = State.ESP.Billboards[player]
    if bb then
        pcall(function() bb:Destroy() end)
        State.ESP.Billboards[player] = nil
    end
end

function ESP.UpdateBillboard(player)
    local char = player.Character
    if not char then
        ESP.RemoveBillboard(player)
        return
    end

    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    local hum  = Utils.SafeGetHum(char)
    local root = Utils.SafeGetRoot(char)
    if not head or not hum or not root then return end

    local bb = State.ESP.Billboards[player]
    if not bb or not bb.Parent or bb.Adornee ~= head then
        ESP.RemoveBillboard(player)
        ESP.CreateBillboard(player)
        bb = State.ESP.Billboards[player]
        if not bb then return end
    end

    local myRoot = Utils.LocalRoot()
    local nameL  = bb:FindFirstChild("NameLabel")
    if nameL then nameL.Visible = Config.Visuals.NameESP end

    -- Character Badge & State-Based Color ESP Update
    local charL = bb:FindFirstChild("CharLabel")
    local ultL  = bb:FindFirstChild("UltLabel")
    
    local ok, charBadge, isUltActive, hasSaitamaUltEnded = pcall(function()
        return TSBDatabase.GetPlayerCharacterInfo(player)
    end)
    if not ok then charBadge = "❓ BILINMIYOR" end

    local stateColor, _ = ESP.GetPlayerStateColor(player)

    if charL then
        if Config.Visuals.ShowCharacterESP then
            charL.Text = charBadge or "❓ BILINMIYOR"
            charL.TextColor3 = stateColor
            charL.Visible = true
        else
            charL.Visible = false
        end
    end

    if ultL then
        local showUlt = false
        if Config.Visuals.ShowUltiESP and isUltActive then
            ultL.Text = "🔥 ULTİDE! 🔥"
            ultL.TextColor3 = Config.Visuals.UltiESPColor or Color3.fromRGB(255, 65, 80)
            showUlt = true
        elseif Config.Visuals.DeathCounterRisk and hasSaitamaUltEnded then
            ultL.Text = "⚠️ DEATH COUNTER RISK! ⚠️"
            ultL.TextColor3 = Config.Visuals.DeathCounterRiskColor or Color3.fromRGB(255, 185, 0)
            showUlt = true
        end
        ultL.Visible = showUlt
    end

    local distLabel = bb:FindFirstChild("DistLabel")
    if distLabel then
        distLabel.Visible = Config.Visuals.DistanceESP
        if myRoot then
            local dist = math.floor(Utils.DistanceTo(myRoot, root))
            distLabel.Text = dist .. " studs"
            if Config.Visuals.DistanceColor then
                distLabel.TextColor3 = dist < 25 and Config.UI.DangerColor or (dist < 60 and Config.UI.WarnColor or Config.UI.AccentColor)
            end
        end
    end

    local hpBg  = bb:FindFirstChild("HpBg")
    local hpBar = hpBg and hpBg:FindFirstChild("HpBar")
    if hpBg then hpBg.Visible = Config.Visuals.HealthESP end
    if hpBar and hum.MaxHealth and hum.MaxHealth > 0 then
        local curHp = math.max(0, hum.Health)
        local maxHp = math.max(1, hum.MaxHealth)
        local pct = math.clamp(curHp / maxHp, 0, 1)
        hpBar.Size = UDim2.new(pct, 0, 1, 0)
        hpBar.BackgroundColor3 = Utils.HealthColor(pct)
    end
end

-- Drawing API Tracers
function ESP.UpdateTracers()
    if not (typeof(Drawing) == "table" and Drawing.new) then return end

    local cam = Workspace.CurrentCamera or Workspace:FindFirstChildWhichIsA("Camera")
    if not cam then return end

    local vp = cam.ViewportSize
    local origin = Vector2.new(vp.X / 2, vp.Y)
    if Config.Visuals.TracerOrigin == "Center" then
        origin = Vector2.new(vp.X / 2, vp.Y / 2)
    elseif Config.Visuals.TracerOrigin == "Mouse" then
        origin = UserInputService:GetMouseLocation()
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local tracer = State.ESP.Tracers[player]
        if not tracer then
            pcall(function()
                tracer = Drawing.new("Line")
                tracer.Thickness = Config.Visuals.TracerThickness or 1.5
                tracer.Transparency = 1
                tracer.Visible = false
                State.ESP.Tracers[player] = tracer
            end)
        end

        if not tracer then continue end

        if Config.Visuals.Tracers and Utils.IsAlive(player) then
            local root = Utils.SafeGetRoot(player.Character)
            if root then
                local screenPos, onScreen = cam:WorldToViewportPoint(root.Position)
                if onScreen then
                    local stateColor, _ = ESP.GetPlayerStateColor(player)
                    tracer.From = origin
                    tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                    tracer.Color = (State.CurrentTarget == player) and Config.UI.DangerColor or stateColor
                    tracer.Thickness = Config.Visuals.TracerThickness or 1.5
                    tracer.Visible = true
                else
                    tracer.Visible = false
                end
            else
                tracer.Visible = false
            end
        else
            tracer.Visible = false
        end
    end
end

function ESP.Update()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        pcall(function()
            local char = player.Character
            local hum = Utils.SafeGetHum(char)
            local isAlive = (char ~= nil and hum ~= nil and hum.Health > 0 and char.Parent ~= nil)

            if isAlive then
                if Config.Visuals.HighlightESP then
                    ESP.CreateHighlight(player)
                    local hl = State.ESP.Highlights[player]
                    if hl and hl.Parent then
                        local stateColor, _ = ESP.GetPlayerStateColor(player)
                        hl.FillColor = stateColor
                    end
                else
                    ESP.RemoveHighlight(player)
                end

                if Config.Visuals.BillboardESP then
                    ESP.CreateBillboard(player)
                    ESP.UpdateBillboard(player)
                else
                    ESP.RemoveBillboard(player)
                end
            else
                ESP.RemoveHighlight(player)
                ESP.RemoveBillboard(player)
            end
        end)
    end

    pcall(ESP.UpdateTracers)

    if Config.Visuals.SpectatorAlert then
        pcall(function()
            local cam = Workspace.CurrentCamera
            if cam and cam.CameraSubject then
                local subjectChar = cam.CameraSubject:FindFirstAncestorWhichIsA("Model")
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        if subjectChar == LocalPlayer.Character and not State.SpectatorList[player.UserId] then
                            State.SpectatorList[player.UserId] = true
                            Notify("Spectator Alert", player.DisplayName .. " is watching you!", "warn", 3)
                        end
                    end
                end
            end
        end)
    end
end

function ESP.ClearAll()
    for p, _ in pairs(State.ESP.Highlights) do ESP.RemoveHighlight(p) end
    for p, _ in pairs(State.ESP.Billboards) do ESP.RemoveBillboard(p) end
    for p, tracer in pairs(State.ESP.Tracers) do
        if tracer and tracer.Remove then pcall(function() tracer:Remove() end) end
    end
    State.ESP.Tracers = {}
end

-- FOV Circle Visualizer
local FOVDrawing = nil
local function SetupFOVCircle()
    pcall(function()
        if typeof(Drawing) == "table" and Drawing.new then
            FOVDrawing = Drawing.new("Circle")
            FOVDrawing.Visible = false
            FOVDrawing.Thickness = 1.5
            FOVDrawing.NumSides = 64
        end
    end)
end

local function UpdateFOVCircle()
    if not FOVDrawing then return end
    if not Config.Visuals.FOVCircle then
        FOVDrawing.Visible = false
        return
    end
    local center = Utils.CenterOfScreen()
    FOVDrawing.Position = center
    FOVDrawing.Radius   = Config.Combat.AimFOVRadius
    FOVDrawing.Color    = Config.Visuals.FOVColor
    FOVDrawing.Filled   = Config.Visuals.FOVFilled
    FOVDrawing.Visible  = true
end

-- [[ SECTION 10: WORLD MODIFICATIONS ]]
local World = {}

function World.ToggleFullBright(enable)
    Config.World.FullBright = enable
    if enable then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
    else
        Lighting.Ambient = State.OriginalLighting.Ambient
        Lighting.OutdoorAmbient = State.OriginalLighting.OutdoorAmbient
        Lighting.Brightness = State.OriginalLighting.Brightness
    end
end

function World.ToggleRemoveFog(enable)
    Config.World.RemoveFog = enable
    if enable then
        Lighting.FogEnd = 9e9
        Lighting.FogStart = 9e9
    else
        Lighting.FogEnd = State.OriginalLighting.FogEnd
        Lighting.FogStart = State.OriginalLighting.FogStart
    end
end

-- Robust Universal Server Hop & Auto Reconnect Queue
local function QueueScriptOnTeleport()
    pcall(function()
        local queueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or (identifyexecutor and (queue_on_teleport or syn_queue_on_teleport))
        if queueTeleport and typeof(queueTeleport) == "function" then
            -- 1. Try to read from local file if supported
            if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("tsb.lua") then
                queueTeleport(readfile("tsb.lua"))
            else
                -- Fallback to universal script trigger or raw string execution
                queueTeleport([[
                    repeat task.wait() until game:IsLoaded()
                    pcall(function()
                        if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("tsb.lua") then
                            loadstring(readfile("tsb.lua"))()
                        end
                    end)
                ]])
            end
        end
    end)
end

function World.ServerHop()
    if State.ServerHopActive then return end
    State.ServerHopActive = true

    Notify("Server Hop", "Uygun ve boş slotu olan sunucu aranıyor...", "info", 3)

    -- Auto-execute script in new server
    QueueScriptOnTeleport()

    task.spawn(function()
        local placeId = game.PlaceId
        local jobId = game.JobId
        local serversUrl = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Desc&limit=100"
        
        local validServers = {}
        local cursor = ""
        
        local httpRequest = (typeof(syn) == "table" and syn.request) or (typeof(http) == "table" and http.request) or (typeof(http_request) == "function" and http_request) or request
        
        local function FetchServers()
            local url = serversUrl .. (cursor ~= "" and ("&cursor=" .. cursor) or "")
            local body = nil
            
            if httpRequest then
                local res = httpRequest({Url = url, Method = "GET"})
                if res and res.Body then body = res.Body end
            elseif typeof(game.HttpGet) == "function" then
                pcall(function() body = game:HttpGet(url) end)
            end
            
            if body then
                local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
                if ok and data and data.data then
                    local minP = tonumber(Config.World.AutoHopMinPlayers) or 4
                    local maxP = tonumber(Config.World.AutoHopMaxPlayers) or 13

                    for _, s in ipairs(data.data) do
                        -- CRITICAL FIX: Make sure the server has at least 1-2 free slots so teleport NEVER fails (playing < maxPlayers - 1)
                        if s.id ~= jobId and s.playing and s.maxPlayers and s.playing >= minP and s.playing <= math.min(maxP, s.maxPlayers - 1) then
                            table.insert(validServers, s)
                        end
                    end
                    cursor = data.nextPageCursor or ""
                end
            end
        end

        pcall(FetchServers)
        if #validServers == 0 and cursor ~= "" then
            pcall(FetchServers)
        end

        if #validServers > 0 then
            -- Sort by highest player count (that still has guaranteed free spots)
            table.sort(validServers, function(a, b)
                return a.playing > b.playing
            end)

            local targetServer = validServers[1]
            Notify("Server Hop", string.format("Sunucu bulundu (%d/%d kişi - Boş slot var). Işınlanılıyor...", targetServer.playing, targetServer.maxPlayers), "success", 4)
            task.wait(0.8)

            -- Hook teleport failure handler to retry if game fills up during loading
            local tpConn
            tpConn = TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
                if player == LocalPlayer then
                    if tpConn then tpConn:Disconnect() end
                    State.ServerHopActive = false
                    Notify("Server Hop", "Işınlanma dolu sunucu nedeniyle reddedildi, başka sunucu deneniyor...", "warn", 3)
                    task.wait(1)
                    World.ServerHop()
                end
            end)

            TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
        else
            Notify("Server Hop", "Filtreye uygun sunucu bulunamadı, rastgele sunucu deneniyor...", "warn", 3)
            task.wait(0.8)
            TeleportService:Teleport(placeId, LocalPlayer)
        end

        task.delay(12, function()
            State.ServerHopActive = false
        end)
    end)
end

function World.CheckAutoServerHop()
    if not Config.World.AutoServerHop or State.ServerHopActive then return end
    local now = tick()
    if (now - (State.LastServerHopCheck or 0)) < 10 then return end
    State.LastServerHopCheck = now

    local currentPlayers = #Players:GetPlayers()
    local minLimit = Config.World.AutoHopMinPlayers or 4

    if currentPlayers <= minLimit then
        Notify("Auto Server Hop", "Sunucuda sadece " .. currentPlayers .. " kişi kaldı! Dolu sunucuya geçiliyor...", "warn", 5)
        World.ServerHop()
    end
end


-- [[ SECTION 11: USER INTERFACE CONSTRUCTION ]]
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "4080_Hub_TSB_Gui"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Glow Background Shadow
local GlowShadow = Instance.new("Frame")
GlowShadow.Name = "GlowShadow"
GlowShadow.Size = UDim2.new(0, 620, 0, 440)
GlowShadow.Position = UDim2.new(0.5, -310, 0.5, -220)
GlowShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
GlowShadow.BackgroundTransparency = 0.55
GlowShadow.BorderSizePixel = 0
GlowShadow.Parent = ScreenGui
Instance.new("UICorner", GlowShadow).CornerRadius = UDim.new(0, 14)

-- Main Hub Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 610, 0, 430)
MainFrame.Position = UDim2.new(0.5, -305, 0.5, -215)
MainFrame.BackgroundColor3 = Config.UI.BgColor
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Color = Config.UI.AccentColor
mainStroke.Thickness = 1.4
mainStroke.Transparency = 0.25

-- [[ HEADER BAR ]]
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = Config.UI.CardColor
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local headerStripe = Instance.new("Frame")
headerStripe.Size = UDim2.new(0, 4, 1, -14)
headerStripe.Position = UDim2.new(0, 6, 0, 7)
headerStripe.BackgroundColor3 = Config.UI.AccentColor
headerStripe.BorderSizePixel = 0
headerStripe.Parent = Header
Instance.new("UICorner", headerStripe).CornerRadius = UDim.new(0, 4)

-- Live FSM State Indicator Badge
local FSMIndicator = Instance.new("Frame")
FSMIndicator.Name = "FSMIndicator"
FSMIndicator.Size = UDim2.new(0, 110, 0, 22)
FSMIndicator.Position = UDim2.new(0.5, 48, 0.5, -11)
FSMIndicator.BackgroundColor3 = Config.UI.Card2Color
FSMIndicator.BorderSizePixel = 0
FSMIndicator.Parent = Header
Instance.new("UICorner", FSMIndicator).CornerRadius = UDim.new(1, 0)

local fsmStroke = Instance.new("UIStroke", FSMIndicator)
fsmStroke.Color = Config.UI.AccentColor
fsmStroke.Thickness = 1

local FSMText = Instance.new("TextLabel")
FSMText.Size = UDim2.new(1, 0, 1, 0)
FSMText.BackgroundTransparency = 1
FSMText.Text = "FSM: IDLE"
FSMText.TextColor3 = Config.UI.AccentColor
FSMText.TextSize = 9
FSMText.Font = Enum.Font.GothamBold
FSMText.Parent = FSMIndicator

StateMachine.StateChanged:Connect(function(newState)
    pcall(function()
        FSMText.Text = "FSM: " .. tostring(newState)
        if newState == FSMStates.EMERGENCY_STOP then
            fsmStroke.Color = Config.UI.DangerColor
            FSMText.TextColor3 = Config.UI.DangerColor
        elseif newState == FSMStates.COMBAT or newState == FSMStates.BEHIND_TP or newState == FSMStates.MASS_BRING then
            fsmStroke.Color = Config.UI.WarnColor
            FSMText.TextColor3 = Config.UI.WarnColor
        elseif newState == FSMStates.SKY_ESCAPE or newState == FSMStates.SKY_DODGE then
            fsmStroke.Color = Color3.fromRGB(170, 0, 255)
            FSMText.TextColor3 = Color3.fromRGB(170, 0, 255)
        else
            fsmStroke.Color = Config.UI.AccentColor
            FSMText.TextColor3 = Config.UI.AccentColor
        end
    end)
end)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 240, 1, 0)
Title.Position = UDim2.new(0, 18, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ <b>4080 HUB</b> <font color=\"rgb(0,220,255)\">" .. Config.UI.VersionStr .. "</font>"
Title.RichText = true
Title.TextColor3 = Config.UI.TextColor
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(0, 200, 0, 12)
SubTitle.Position = UDim2.new(0, 18, 1, -16)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "The Strongest Battlegrounds • NextGen Suite"
SubTitle.TextColor3 = Config.UI.SubTextColor
SubTitle.TextSize = 9
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Parent = Header

-- Status Badge
local StatusBadge = Instance.new("Frame")
StatusBadge.Size = UDim2.new(0, 84, 0, 22)
StatusBadge.Position = UDim2.new(0.5, -42, 0.5, -11)
StatusBadge.BackgroundColor3 = Config.UI.SuccessColor
StatusBadge.BorderSizePixel = 0
StatusBadge.Parent = Header
Instance.new("UICorner", StatusBadge).CornerRadius = UDim.new(1, 0)

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, 0, 1, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "● ONLINE"
StatusText.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusText.TextSize = 10
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = StatusBadge

-- Header Buttons Factory
local function CreateHeaderBtn(text, xOffset, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 30, 0, 30)
    btn.Position = UDim2.new(1, xOffset, 0.5, -15)
    btn.BackgroundColor3 = Config.UI.Card2Color
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = color or Config.UI.SubTextColor
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Parent = Header
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseEnter:Connect(function()
        Utils.TweenPlay(btn, 0.15, nil, nil, {BackgroundColor3 = Config.UI.HoverColor})
    end)
    btn.MouseLeave:Connect(function()
        Utils.TweenPlay(btn, 0.15, nil, nil, {BackgroundColor3 = Config.UI.Card2Color})
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local CloseBtn  = CreateHeaderBtn("✕", -38, Config.UI.DangerColor, function()
    Config.UI.IsOpen = false
    MainFrame.Visible = false
    GlowShadow.Visible = false
    Notify("4080 HUB", "GUI hidden. Press RightCtrl or Mobile Button to show.", "info", 2.5)
end)

local isMinimized = false
local MinBtn    = CreateHeaderBtn("—", -74, Config.UI.SubTextColor, function()
    isMinimized = not isMinimized
    if isMinimized then
        Utils.TweenPlay(MainFrame, 0.25, Enum.EasingStyle.Quart, nil, {Size = UDim2.new(0, 610, 0, 48)})
        Utils.TweenPlay(GlowShadow, 0.25, Enum.EasingStyle.Quart, nil, {Size = UDim2.new(0, 620, 0, 58)})
    else
        Utils.TweenPlay(MainFrame, 0.25, Enum.EasingStyle.Quart, nil, {Size = UDim2.new(0, 610, 0, 430)})
        Utils.TweenPlay(GlowShadow, 0.25, Enum.EasingStyle.Quart, nil, {Size = UDim2.new(0, 620, 0, 440)})
    end
end)

local EmergBtn  = CreateHeaderBtn("⚠", -110, Config.UI.WarnColor, function()
    State.IsEmergencyStop = not State.IsEmergencyStop
    if State.IsEmergencyStop then
        StateMachine.TransitionTo(FSMStates.EMERGENCY_STOP, true)
        State.MassBringActive = false
        if State.SavedBehindTPState ~= nil then
            Config.Target.BehindTP = State.SavedBehindTPState
            State.SavedBehindTPState = nil
        end
        Config.Combat.Aimlock = false
        Config.Combat.AutoM1 = false
        Config.Combat.AutoBlock = false
        Config.Combat.HitboxExpander = false
        Config.Combat.KillAura = false
        Config.Movement.Fly = false
        Config.Movement.SpeedBoost = false
        Config.Movement.Noclip = false
        Config.Visuals.HighlightESP = false
        Config.Visuals.BillboardESP = false
        Config.Visuals.Tracers = false
        ConfigSystem.RefreshUI()
        Movement.ToggleFly(false)
        Combat.ResetHitboxes()
        ESP.ClearAll()
        StatusBadge.BackgroundColor3 = Config.UI.DangerColor
        StatusText.Text = "⚠ STOPPED"
        mainStroke.Color = Config.UI.DangerColor
        Notify("EMERGENCY STOP", "All active features have been stopped!", "error", 3)
    else
        StatusBadge.BackgroundColor3 = Config.UI.SuccessColor
        StatusText.Text = "● ONLINE"
        mainStroke.Color = Config.UI.AccentColor
        StateMachine.TransitionTo(FSMStates.IDLE, true)
        Notify("4080 HUB", "Hub resumed normal operation.", "success", 2)
    end
end)

-- Dragging Logic
do
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inp.Position
            startPos = MainFrame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            MainFrame.Position = newPos
            GlowShadow.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset - 5, newPos.Y.Scale, newPos.Y.Offset - 5)
        end
    end)
end

-- [[ SIDEBAR & CONTENT LAYOUT ]]
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 155, 1, -58)
Sidebar.Position = UDim2.new(0, 8, 0, 52)
Sidebar.BackgroundColor3 = Config.UI.CardColor
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)

local sLayout = Instance.new("UIListLayout", Sidebar)
sLayout.Padding = UDim.new(0, 4)
sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local sPad = Instance.new("UIPadding", Sidebar)
sPad.PaddingTop = UDim.new(0, 6)
sPad.PaddingLeft = UDim.new(0, 5)
sPad.PaddingRight = UDim.new(0, 5)

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -175, 1, -58)
ContentArea.Position = UDim2.new(0, 168, 0, 52)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Tabs = {}
local TabButtons = {}
local ActiveTab = nil

local function SwitchTab(tabName)
    if tabName == ActiveTab then return end
    ActiveTab = tabName
    Config.UI.TabActive = tabName

    for name, frame in pairs(Tabs) do
        frame.Visible = (name == tabName)
    end
    for name, btn in pairs(TabButtons) do
        local isActive = (name == tabName)
        Utils.TweenPlay(btn, 0.18, nil, nil, {
            BackgroundColor3 = isActive and Config.UI.AccentColor or Config.UI.Card2Color,
            TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Config.UI.SubTextColor,
        })
        local dot = btn:FindFirstChild("ActiveDot")
        if dot then dot.Visible = isActive end
    end
end

local function CreateTab(name, icon, order)
    local sf = Instance.new("ScrollingFrame")
    sf.Name = "Tab_" .. name
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = Config.UI.AccentColor
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.Visible = false
    sf.Parent = ContentArea

    local sfLayout = Instance.new("UIListLayout", sf)
    sfLayout.Padding = UDim.new(0, 6)
    sfLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local sfPad = Instance.new("UIPadding", sf)
    sfPad.PaddingTop = UDim.new(0, 4)
    sfPad.PaddingBottom = UDim.new(0, 10)
    sfPad.PaddingLeft = UDim.new(0, 2)
    sfPad.PaddingRight = UDim.new(0, 8)

    local btn = Instance.new("TextButton")
    btn.Name = "TabBtn_" .. name
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Config.UI.Card2Color
    btn.BorderSizePixel = 0
    btn.Text = "  " .. icon .. "  " .. name
    btn.TextColor3 = Config.UI.SubTextColor
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.LayoutOrder = order or 0
    btn.Parent = Sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local dot = Instance.new("Frame")
    dot.Name = "ActiveDot"
    dot.Size = UDim2.new(0, 4, 0, 4)
    dot.Position = UDim2.new(0, 4, 0.5, -2)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel = 0
    dot.Visible = false
    dot.Parent = btn
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
    btn.MouseEnter:Connect(function()
        if ActiveTab ~= name then
            Utils.TweenPlay(btn, 0.15, nil, nil, {BackgroundColor3 = Config.UI.HoverColor})
        end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= name then
            Utils.TweenPlay(btn, 0.15, nil, nil, {BackgroundColor3 = Config.UI.Card2Color})
        end
    end)

    Tabs[name] = sf
    TabButtons[name] = btn

    if not ActiveTab then SwitchTab(name) end
    return sf
end

-- [[ SECTION 12: UI COMPONENT FACTORIES ]]
local UI = {}

function UI.Section(parent, title)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 26)
    f.BackgroundTransparency = 1
    f.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "◆  " .. string.upper(title)
    lbl.TextColor3 = Config.UI.AccentColor
    lbl.TextSize = 10
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    return f
end

function UI.Toggle(parent, title, subtitle, defaultState, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, subtitle and 44 or 36)
    frame.BackgroundColor3 = Config.UI.CardColor
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -66, 0, 18)
    titleL.Position = UDim2.new(0, 10, 0, subtitle and 5 or 9)
    titleL.BackgroundTransparency = 1
    titleL.Text = title
    titleL.TextColor3 = Config.UI.TextColor
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
        subL.TextColor3 = Config.UI.SubTextColor
        subL.TextSize = 9
        subL.Font = Enum.Font.Gotham
        subL.TextXAlignment = Enum.TextXAlignment.Left
        subL.Parent = frame
    end

    local switchBg = Instance.new("Frame")
    switchBg.Size = UDim2.new(0, 42, 0, 22)
    switchBg.Position = UDim2.new(1, -52, 0.5, -11)
    switchBg.BackgroundColor3 = defaultState and Config.UI.AccentColor or Color3.fromRGB(45, 50, 68)
    switchBg.BorderSizePixel = 0
    switchBg.Parent = frame
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local switchCirc = Instance.new("Frame")
    switchCirc.Size = UDim2.new(0, 16, 0, 16)
    switchCirc.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    switchCirc.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchCirc.BorderSizePixel = 0
    switchCirc.Parent = switchBg
    Instance.new("UICorner", switchCirc).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = frame

    local isOn = defaultState or false
    local function SetState(v)
        isOn = v
        Utils.TweenPlay(switchBg, 0.18, nil, nil, {BackgroundColor3 = v and Config.UI.AccentColor or Color3.fromRGB(45, 50, 68)})
        Utils.TweenPlay(switchCirc, 0.18, nil, nil, {Position = v and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)})
        if callback then callback(v) end
    end

    btn.MouseButton1Click:Connect(function() SetState(not isOn) end)
    frame.MouseEnter:Connect(function()
        Utils.TweenPlay(frame, 0.15, nil, nil, {BackgroundColor3 = Config.UI.HoverColor})
    end)
    frame.MouseLeave:Connect(function()
        Utils.TweenPlay(frame, 0.15, nil, nil, {BackgroundColor3 = Config.UI.CardColor})
    end)

    return {SetOn = SetState, Frame = frame}
end

function UI.Slider(parent, title, minV, maxV, defaultV, suffix, callback, step)
    step = step or 1
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 50)
    frame.BackgroundColor3 = Config.UI.CardColor
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -80, 0, 20)
    titleL.Position = UDim2.new(0, 10, 0, 4)
    titleL.BackgroundTransparency = 1
    titleL.Text = title
    titleL.TextColor3 = Config.UI.TextColor
    titleL.TextSize = 12
    titleL.Font = Enum.Font.GothamMedium
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = frame

    local valL = Instance.new("TextLabel")
    valL.Size = UDim2.new(0, 70, 0, 20)
    valL.Position = UDim2.new(1, -80, 0, 4)
    valL.BackgroundTransparency = 1
    valL.Text = tostring(defaultV) .. (suffix or "")
    valL.TextColor3 = Config.UI.AccentColor
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
    trackFill.BackgroundColor3 = Config.UI.AccentColor
    trackFill.BorderSizePixel = 0
    trackFill.Parent = trackBg
    Instance.new("UICorner", trackFill).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.Position = UDim2.new(math.clamp(pct, 0, 1), -6, 0.5, -6)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.Parent = trackBg
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local sliding = false
    local currentVal = defaultV

    local function UpdateValue(inp)
        local relX = math.clamp((inp.Position.X - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
        local raw = minV + (maxV - minV) * relX
        currentVal = math.floor(raw / step + 0.5) * step
        currentVal = math.clamp(currentVal, minV, maxV)

        local newPct = (currentVal - minV) / (maxV - minV)
        trackFill.Size = UDim2.new(newPct, 0, 1, 0)
        thumb.Position = UDim2.new(newPct, -6, 0.5, -6)
        valL.Text = tostring(currentVal) .. (suffix or "")
        if callback then callback(currentVal) end
    end

    trackBg.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            UpdateValue(inp)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            UpdateValue(inp)
        end
    end)

    frame.MouseEnter:Connect(function()
        Utils.TweenPlay(frame, 0.15, nil, nil, {BackgroundColor3 = Config.UI.HoverColor})
    end)
    frame.MouseLeave:Connect(function()
        Utils.TweenPlay(frame, 0.15, nil, nil, {BackgroundColor3 = Config.UI.CardColor})
    end)

    return {Frame = frame}
end

function UI.Button(parent, title, btnText, kind, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Config.UI.CardColor
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -110, 1, 0)
    titleL.Position = UDim2.new(0, 10, 0, 0)
    titleL.BackgroundTransparency = 1
    titleL.Text = title
    titleL.TextColor3 = Config.UI.TextColor
    titleL.TextSize = 12
    titleL.Font = Enum.Font.GothamMedium
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = frame

    local colorMap = {
        primary = Config.UI.AccentColor,
        danger  = Config.UI.DangerColor,
        warn    = Config.UI.WarnColor,
        success = Config.UI.SuccessColor,
    }
    local bgCol = colorMap[kind] or Config.UI.AccentColor

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 95, 0, 24)
    btn.Position = UDim2.new(1, -102, 0.5, -12)
    btn.BackgroundColor3 = bgCol
    btn.BorderSizePixel = 0
    btn.Text = btnText
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    btn.MouseEnter:Connect(function()
        Utils.TweenPlay(btn, 0.12, nil, nil, {BackgroundColor3 = Utils.LerpColor(bgCol, Color3.fromRGB(255, 255, 255), 0.15)})
    end)
    btn.MouseLeave:Connect(function()
        Utils.TweenPlay(btn, 0.12, nil, nil, {BackgroundColor3 = bgCol})
    end)

    return {Frame = frame}
end

function UI.Dropdown(parent, title, options, defaultOpt, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Config.UI.CardColor
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -140, 1, 0)
    titleL.Position = UDim2.new(0, 10, 0, 0)
    titleL.BackgroundTransparency = 1
    titleL.Text = title
    titleL.TextColor3 = Config.UI.TextColor
    titleL.TextSize = 12
    titleL.Font = Enum.Font.GothamMedium
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = frame

    local cycleBtn = Instance.new("TextButton")
    cycleBtn.Size = UDim2.new(0, 125, 0, 24)
    cycleBtn.Position = UDim2.new(1, -132, 0.5, -12)
    cycleBtn.BackgroundColor3 = Config.UI.Card2Color
    cycleBtn.BorderSizePixel = 0
    cycleBtn.Text = defaultOpt .. " ▾"
    cycleBtn.TextColor3 = Config.UI.AccentColor
    cycleBtn.TextSize = 11
    cycleBtn.Font = Enum.Font.GothamBold
    cycleBtn.AutoButtonColor = false
    cycleBtn.Parent = frame
    Instance.new("UICorner", cycleBtn).CornerRadius = UDim.new(0, 5)

    local idx = 1
    for i, o in ipairs(options) do
        if o == defaultOpt then idx = i break end
    end

    cycleBtn.MouseButton1Click:Connect(function()
        idx = (idx % #options) + 1
        local sel = options[idx]
        cycleBtn.Text = sel .. " ▾"
        if callback then callback(sel) end
    end)

    return {Frame = frame}
end

function UI.Keybind(parent, title, defaultKey, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Config.UI.CardColor
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -120, 1, 0)
    titleL.Position = UDim2.new(0, 10, 0, 0)
    titleL.BackgroundTransparency = 1
    titleL.Text = title
    titleL.TextColor3 = Config.UI.TextColor
    titleL.TextSize = 12
    titleL.Font = Enum.Font.GothamMedium
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = frame

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(0, 105, 0, 24)
    keyBtn.Position = UDim2.new(1, -112, 0.5, -12)
    keyBtn.BackgroundColor3 = Config.UI.Card2Color
    keyBtn.BorderSizePixel = 0
    keyBtn.Text = defaultKey and defaultKey.Name or "None"
    keyBtn.TextColor3 = Config.UI.AccentColor
    keyBtn.TextSize = 11
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.AutoButtonColor = false
    keyBtn.Parent = frame
    Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 5)

    local listening = false
    local currentKey = defaultKey

    local function SetKey(k)
        currentKey = k
        keyBtn.Text = k and k.Name or "None"
        keyBtn.TextColor3 = Config.UI.AccentColor
        listening = false
        if callback then callback(k) end
    end

    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        keyBtn.Text = "... Tuşa Bas ..."
        keyBtn.TextColor3 = Config.UI.WarnColor
    end)

    UserInputService.InputBegan:Connect(function(inp, gpe)
        if listening and inp.UserInputType == Enum.UserInputType.Keyboard then
            SetKey(inp.KeyCode)
        end
    end)

    return {SetKey = SetKey, Frame = frame}
end

-- [[ SECTION 13: POPULATE TABS ]]

-- ============================================================================
-- TAB 1: ⚔️ COMBAT & LEVEL 6 SPECIALIST
-- ============================================================================
local tCombat = CreateTab("Combat", "⚔️", 1)

UI.Section(tCombat, "⚡ Level 6 Specialist Combat Engine")

local tPacketParry = UI.Toggle(tCombat, "0-Ping Packet Auto-Parry", "Network seviyesinde paket dinleyerek 0ms gecikmeli Parry yapar", Config.Combat.PacketParry, function(v)
    Config.Combat.PacketParry = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Combat.PacketParry end, Setter = tPacketParry.SetOn })

local tPredAim = UI.Toggle(tCombat, "Predictive Aim (Lag Comp)", "Hedefin hız ve ping vektörünü hesaplayarak gelecekteki pozisyona kilitlenir", Config.Combat.PredictiveAim, function(v)
    Config.Combat.PredictiveAim = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Combat.PredictiveAim end, Setter = tPredAim.SetOn })

local tCombo = UI.Toggle(tCombat, "Frame-Data Combo Sequencer", "M1 yerine seçilen karakterin profesyonel kombo zincirini çalıştırır", Config.Combat.AutoComboSequencer, function(v)
    Config.Combat.AutoComboSequencer = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Combat.AutoComboSequencer end, Setter = tCombo.SetOn })

UI.Dropdown(tCombat, "Combo Dizilimi", {"Saitama Max Damage", "Garou Extended", "Sonic Speed Chain", "Default (4-M1)"}, Config.Combat.ComboMode or "Saitama Max Damage", function(sel)
    Config.Combat.ComboMode = sel
    ComboSequencerEngine.CurrentComboMode = sel
    Notify("Combo Engine", "Aktif kombo: " .. sel, "info", 2)
end)

local tFrameTrap = UI.Toggle(tCombat, "Frame-Trap (Wake-Up Punish)", "Rakip ragdoll'dan kalktığı tam milisaniyede kombo başlatır", Config.Combat.FrameTrapWakeup, function(v)
    Config.Combat.FrameTrapWakeup = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Combat.FrameTrapWakeup end, Setter = tFrameTrap.SetOn })

UI.Section(tCombat, "TSB Aimlock Engine")

local tAim = UI.Toggle(tCombat, "Lock-On Aimlock", "En yakın / en düşük HP rakibe otomatik kilitlenir", Config.Combat.Aimlock, function(v)
    Config.Combat.Aimlock = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Combat.Aimlock end, Setter = tAim.SetOn })

UI.Dropdown(tCombat, "Aimlock Mode", {"Body Only (No Screen Spin)", "Camera & Body", "Camera Only"}, Config.Combat.AimlockMode, function(sel)
    Config.Combat.AimlockMode = sel
end)

UI.Dropdown(tCombat, "Target Priority", {"Nearest", "Cursor", "LowestHP"}, Config.Combat.AimMode, function(sel)
    Config.Combat.AimMode = sel
end)

UI.Slider(tCombat, "Lock Range", 50, 1000, Config.Combat.AimMaxRange, " studs", function(val)
    Config.Combat.AimMaxRange = val
end)

UI.Section(tCombat, "Auto Parry & Anti-Counter")

local tParry = UI.Toggle(tCombat, "Auto Parry / Auto Block", "Saldırı animasyonlarında kusursuz blok ve savuşturma", Config.Combat.AutoParry, function(v)
    Config.Combat.AutoParry = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Combat.AutoParry end, Setter = tParry.SetOn })

UI.Toggle(tCombat, "Anti-Counter Bait Protection", "Rakip Counter/Parry duruşundaysa saldırmayı durdurur", Config.Combat.AntiCounterBait, function(v)
    Config.Combat.AntiCounterBait = v
end)

UI.Section(tCombat, "Auto M1 & Reach Engine")

local tAutoM1 = UI.Toggle(tCombat, "Auto M1 Attack", "Menzildeki rakibe otomatik kesintisiz M1 vuruşu yapar", Config.Combat.AutoM1, function(v)
    Config.Combat.AutoM1 = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Combat.AutoM1 end, Setter = tAutoM1.SetOn })

local tHitbox = UI.Toggle(tCombat, "Hitbox Expander", "Rakiplerin vuruş alanını (Hitbox) devasa yapar", Config.Combat.HitboxExpander, function(v)
    Config.Combat.HitboxExpander = v
    if not v then Combat.ResetHitboxes() end
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Combat.HitboxExpander end, Setter = tHitbox.SetOn })

UI.Slider(tCombat, "Hitbox Size", 4, 30, Config.Combat.HitboxSize, " studs", function(val)
    Config.Combat.HitboxSize = val
end)

UI.Toggle(tCombat, "Body Reach (Extended Limbs)", "Kolların ve bacakların vuruş menzilini uzatır", Config.Combat.BodyReach, function(v)
    Config.Combat.BodyReach = v
end)

UI.Section(tCombat, "Vacuum Mass Bring Engine")

UI.Dropdown(tCombat, "Mass Vacuum Mode", {"FE Real Damage (Blitz)", "Local Visual Vacuum"}, Config.Combat.MassBringMode, function(sel)
    Config.Combat.MassBringMode = sel
end)

UI.Slider(tCombat, "Vacuum Range", 5, 50, Config.Combat.MassBringDistance, " studs", function(v)
    Config.Combat.MassBringDistance = v
end)

UI.Slider(tCombat, "Vacuum Duration", 3, 30, Config.Combat.MassBringDuration, " saniye", function(v)
    Config.Combat.MassBringDuration = v
end)

UI.Button(tCombat, "Mass Vacuum TP Trigger", "AKTİF ET", "primary", function()
    Combat.ToggleMassBring()
end)

UI.Section(tCombat, "Combat Defenses & Utilities")

UI.Toggle(tCombat, "Anti-Ragdoll (Instant Standup)", "Yere düşüldüğünde beklemeden anında ayağa kalkar", Config.Combat.AntiRagdoll, function(v)
    Config.Combat.AntiRagdoll = v
end)

UI.Toggle(tCombat, "Auto Evasive (Dash on Low HP)", "Can kritik seviyeye indiğinde otomatik Q dash atar", Config.Combat.AutoEvasive, function(v)
    Config.Combat.AutoEvasive = v
end)

UI.Toggle(tCombat, "Auto Awakening (Instant Ult)", "Awakening dolduğu anda otomatik G/T basar", Config.Combat.AutoAwakening, function(v)
    Config.Combat.AutoAwakening = v
end)

UI.Toggle(tCombat, "No Knockback", "Düşman saldırılarından kaynaklanan geri savrulmayı engeller", Config.Combat.NoKnockback, function(v)
    Config.Combat.NoKnockback = v
end)

UI.Toggle(tCombat, "No Slowdown", "Saldırı veya yetenek sonrası oluşan yavaşlamayı sıfırlar", Config.Combat.NoSlowdown, function(v)
    Config.Combat.NoSlowdown = v
end)

-- ============================================================================
-- TAB 2: 🎯 TARGET & BEHIND-TP
-- ============================================================================
local tTarget = CreateTab("Target", "🎯", 2)
UI.Section(tTarget, "Target Lock & Behind-TP Engine")

local tBehind = UI.Toggle(tTarget, "Safe Behind-TP", "Hedef rakibin tam arkasına güvenli ışınlanma", Config.Target.BehindTP, function(v)
    Config.Target.BehindTP = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Target.BehindTP end, Setter = tBehind.SetOn })

UI.Dropdown(tTarget, "Behind-TP Hedef Modu", {"Nearest", "Lowest HP", "Random", "Selected Player"}, Config.Target.TargetMode, function(sel)
    Config.Target.TargetMode = sel
    Notify("Behind-TP", "Hedef modu değiştirildi: " .. sel, "info", 2)
end)

UI.Slider(tTarget, "Behind Distance", 1.5, 8, Config.Target.BehindDistance, " studs", function(v)
    Config.Target.BehindDistance = v
end, 0.1)

UI.Toggle(tTarget, "Auto Punch on TP", "Arkasına ışınlanırken otomatik M1 kombosu atar", Config.Target.AutoM1OnTP, function(v)
    Config.Target.AutoM1OnTP = v
end)

-- ============================================================================
-- TAB 3: ⚡ SKILLS & VOID
-- ============================================================================
local tSkills = CreateTab("Skills", "⚡", 3)
UI.Section(tSkills, "Skill Aimlock & Void Sacrifice")

UI.Toggle(tSkills, "Auto Skill Aimlock", "1, 2, 3, 4 veya G tuşlarına basıldığında hedefe anında döner", Config.Skills.AutoAim, function(v)
    Config.Skills.AutoAim = v
end)

UI.Toggle(tSkills, "Void Sacrifice (Void Kill)", "Yetenek tuttuğunda rakibi Void'e (-350 stud) çeker ve geri döner", Config.Skills.VoidKill, function(v)
    Config.Skills.VoidKill = v
end)

UI.Slider(tSkills, "Void Y Depth", -500, -100, Config.Skills.VoidDepth, " Y", function(v)
    Config.Skills.VoidDepth = v
end, 10)

UI.Slider(tSkills, "Void Return Delay", 0.2, 2.0, Config.Skills.VoidReturnDelay, " saniye", function(v)
    Config.Skills.VoidReturnDelay = v
end, 0.1)

UI.Section(tSkills, "Auto Skill & Ult Spam")

UI.Toggle(tSkills, "Auto Skill Spam (1-2-3-4)", "Menzildeki hedefe yetenekleri sırayla otomatik atar", Config.Skills.AutoSkillSpam, function(v)
    Config.Skills.AutoSkillSpam = v
end)

UI.Slider(tSkills, "Skill Spam Delay", 0.1, 1.0, Config.Skills.SkillSpamDelay, " saniye", function(v)
    Config.Skills.SkillSpamDelay = v
end, 0.05)

UI.Toggle(tSkills, "Auto Ult Spam (G/T)", "Awakening veya Ulti hazır olduğunda otomatik kullanır", Config.Skills.AutoUltSpam, function(v)
    Config.Skills.AutoUltSpam = v
end)

-- ============================================================================
-- TAB 4: 🛡️ SURVIVAL & SKY DODGE
-- ============================================================================
local tSurvival = CreateTab("Survival", "🛡️", 4)
UI.Section(tSurvival, "Auto Sky Escape (Low HP)")

local tSkyEsc = UI.Toggle(tSurvival, "Safe Sky Escape", "Can kritik seviyeye indiğinde güvenli irtifaya ışınlanır", Config.Survival.SkyTeleport, function(v)
    Config.Survival.SkyTeleport = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Survival.SkyTeleport end, Setter = tSkyEsc.SetOn })

UI.Slider(tSurvival, "Escape Trigger HP", 10, 60, Config.Survival.SkyEscapeHP, " % HP", function(v)
    Config.Survival.SkyEscapeHP = v
end)

UI.Slider(tSurvival, "Return Ground HP", 50, 100, Config.Survival.SkyReturnHP, " % HP", function(v)
    Config.Survival.SkyReturnHP = v
end)

UI.Slider(tSurvival, "Sky Escape Height", 50, 400, Config.Survival.SkyEscapeHeight, " studs", function(v)
    Config.Survival.SkyEscapeHeight = v
end)

UI.Section(tSurvival, "Auto Sky Dodge (Combat Evasion)")

local tSkyDodge = UI.Toggle(tSurvival, "Auto Sky Dodge", "Düşman saldırı/skill animasyonu başlattığında anlık havaya kaçar", Config.Survival.SkyDodge, function(v)
    Config.Survival.SkyDodge = v
    if not v and State.SkyDodge.IsDodging then
        SurvivalSystem.EndSkyDodge()
    end
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Survival.SkyDodge end, Setter = tSkyDodge.SetOn })

UI.Slider(tSurvival, "Dodge Altitude", 20, 150, Config.Survival.SkyDodgeHeight, " studs", function(v)
    Config.Survival.SkyDodgeHeight = v
end)

UI.Slider(tSurvival, "Dodge Trigger Range", 5, 30, Config.Survival.SkyDodgeRange, " studs", function(v)
    Config.Survival.SkyDodgeRange = v
end)

UI.Toggle(tSurvival, "Lock Camera on Ground", "Kaçış anında kamerayı yerde sabit tutar (ekran titremez)", Config.Survival.SkyDodgeLockCamera, function(v)
    Config.Survival.SkyDodgeLockCamera = v
end)

-- ============================================================================
-- TAB 5: 🏃 MOVEMENT
-- ============================================================================
local tMovement = CreateTab("Movement", "🏃", 5)
UI.Section(tMovement, "Fly Engine")

local tFly = UI.Toggle(tMovement, "Fly (Uçma)", "Karakteri serbestçe uçurur (WASD + Space/Shift)", Config.Movement.Fly, function(v)
    Movement.ToggleFly(v)
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Movement.Fly end, Setter = tFly.SetOn })

UI.Dropdown(tMovement, "Fly Modu", {"CFrame", "Velocity"}, Config.Movement.FlyMode, function(sel)
    Config.Movement.FlyMode = sel
    if Config.Movement.Fly then Movement.ToggleFly(true) end
end)

UI.Slider(tMovement, "Fly Speed", 10, 200, Config.Movement.FlySpeed, " studs/s", function(val)
    Config.Movement.FlySpeed = val
end)

UI.Section(tMovement, "Speed & Jump Modifications")

local tSpeed = UI.Toggle(tMovement, "Speed Boost", "Yürüme ve koşma hızını artırır", Config.Movement.SpeedBoost, function(v)
    Config.Movement.SpeedBoost = v
    if not v then
        local hum = Utils.LocalHum()
        if hum then hum.WalkSpeed = 16 end
    end
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Movement.SpeedBoost end, Setter = tSpeed.SetOn })

UI.Slider(tMovement, "Speed Value", 16, 150, Config.Movement.SpeedVal, "", function(val)
    Config.Movement.SpeedVal = val
end)

UI.Toggle(tMovement, "Infinite Jump", "Havadayken sınırsız zıplama hakkı", Config.Movement.InfiniteJump, function(v)
    Config.Movement.InfiniteJump = v
end)

UI.Toggle(tMovement, "Double Jump", "Çift zıplama özelliği", Config.Movement.DoubleJump, function(v)
    Config.Movement.DoubleJump = v
end)

UI.Section(tMovement, "Physics & Noclip")

local tNoclip = UI.Toggle(tMovement, "Noclip (Duvarlardan Geçme)", "Tüm duvar ve engellerin içinden geçmeyi sağlar", Config.Movement.Noclip, function(v)
    Config.Movement.Noclip = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Movement.Noclip end, Setter = tNoclip.SetOn })

UI.Toggle(tMovement, "Anti-Void Safe Recovery", "Haritadan aşağı düşüldüğünde güvenli zemine geri ışınlar", Config.Movement.AntiVoid, function(v)
    Config.Movement.AntiVoid = v
end)

UI.Toggle(tMovement, "Glide Mode (Space Glide)", "Havadayken Space'e basılı tutulduğunda yavaşça süzülür", Config.Movement.GlideMode, function(v)
    Config.Movement.GlideMode = v
end)

-- ============================================================================
-- TAB 6: 👁️ VISUALS & ESP
-- ============================================================================
local tVisuals = CreateTab("Visuals", "👁️", 6)
UI.Section(tVisuals, "Player ESP & Indicators")

local tEspHL = UI.Toggle(tVisuals, "Highlight Cham ESP", "Rakipleri duvar arkasından renkli gösterir", Config.Visuals.HighlightESP, function(v)
    Config.Visuals.HighlightESP = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Visuals.HighlightESP end, Setter = tEspHL.SetOn })

local tEspBB = UI.Toggle(tVisuals, "Billboard Text ESP", "İsim, can barı ve mesafe göstergeleri", Config.Visuals.BillboardESP, function(v)
    Config.Visuals.BillboardESP = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Visuals.BillboardESP end, Setter = tEspBB.SetOn })

local tEspChar = UI.Toggle(tVisuals, "Karakter & Skill Set ESP", "Hangi karakteri ve skill setini oynadığını gösterir", Config.Visuals.ShowCharacterESP, function(v)
    Config.Visuals.ShowCharacterESP = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Visuals.ShowCharacterESP end, Setter = tEspChar.SetOn })

local tEspUlt = UI.Toggle(tVisuals, "Ulti & Awakening ESP", "Rakip ulti açtığında kırmızı renkli alevli uyarı verir", Config.Visuals.ShowUltiESP, function(v)
    Config.Visuals.ShowUltiESP = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Visuals.ShowUltiESP end, Setter = tEspUlt.SetOn })

local tDeathRisk = UI.Toggle(tVisuals, "Saitama Death Counter Risk", "Saitama ultisi bittiğinde 10sn boyunca tehlike uyarısı verir", Config.Visuals.DeathCounterRisk, function(v)
    Config.Visuals.DeathCounterRisk = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Visuals.DeathCounterRisk end, Setter = tDeathRisk.SetOn })

UI.Section(tVisuals, "Drawing API Tracers & FOV")

local tTracers = UI.Toggle(tVisuals, "Tracers (Çizgi İzleri)", "Rakiplere doğru ekran üzerinden çizgi çeker", Config.Visuals.Tracers, function(v)
    Config.Visuals.Tracers = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Visuals.Tracers end, Setter = tTracers.SetOn })

UI.Dropdown(tVisuals, "Tracer Origin", {"Bottom", "Center", "Mouse"}, Config.Visuals.TracerOrigin, function(sel)
    Config.Visuals.TracerOrigin = sel
end)

local tFOVCirc = UI.Toggle(tVisuals, "FOV Çemberi", "Aimlock kilitlenme alanını ekranda çember olarak gösterir", Config.Visuals.FOVCircle, function(v)
    Config.Visuals.FOVCircle = v
end)
table.insert(ConfigSystem.RegisteredUI, { Getter = function() return Config.Visuals.FOVCircle end, Setter = tFOVCirc.SetOn })

-- ============================================================================
-- TAB 7: 🌐 WORLD & SERVER HOP
-- ============================================================================
local tWorld = CreateTab("World", "🌐", 7)
UI.Section(tWorld, "World & Rendering Settings")

UI.Toggle(tWorld, "FullBright (Gece Görüşü)", "Tüm karanlık gölgeleri kaldırarak aydınlatır", Config.World.FullBright, function(v)
    World.ToggleFullBright(v)
end)

UI.Toggle(tWorld, "Remove Fog (Sisi Kaldır)", "Haritadaki görüş engelleyen sisleri temizler", Config.World.RemoveFog, function(v)
    World.ToggleRemoveFog(v)
end)

UI.Toggle(tWorld, "Custom Camera FOV", "Kamera görüş açısını genişletir", Config.World.CustomFOV, function(v)
    Config.World.CustomFOV = v
    if not v and Camera then Camera.FieldOfView = State.OriginalFOV end
end)

UI.Slider(tWorld, "Camera FOV", 60, 120, Config.World.FOVValue, "°", function(val)
    Config.World.FOVValue = val
end)

UI.Section(tWorld, "Smart Server Hop Engine")

UI.Toggle(tWorld, "Auto Server Hop (Low Population)", "Sunucuda kişi sayısı azaldığında otomatik dolu sunucuya geçer", Config.World.AutoServerHop, function(v)
    Config.World.AutoServerHop = v
end)

UI.Slider(tWorld, "Min Server Oyuncu Limiti", 2, 8, Config.World.AutoHopMinPlayers, " kişi", function(val)
    Config.World.AutoHopMinPlayers = val
end)

UI.Button(tWorld, "Manuel Server Hop Başlat", "SUNUCU DEĞİŞTİR", "warn", function()
    World.ServerHop()
end)

UI.Toggle(tWorld, "Anti-AFK (Oyun Atmasını Engeller)", "20 dakika hareketsiz kalınca Roblox'un atmasını engeller", Config.World.AntiAFK, function(v)
    Config.World.AntiAFK = v
end)

-- ============================================================================
-- TAB 8: 📊 TELEMETRY & SPECIALIST ENGINE
-- ============================================================================
local tTelemetry = CreateTab("Telemetry", "📊", 8)

UI.Section(tTelemetry, "⚡ Level 6 Specialist Engine Telemetry")

local teleGrid = Instance.new("Frame")
teleGrid.Size = UDim2.new(1, 0, 0, 68)
teleGrid.BackgroundTransparency = 1
teleGrid.Parent = tTelemetry

local tLayout = Instance.new("UIListLayout", teleGrid)
tLayout.FillDirection = Enum.FillDirection.Horizontal
tLayout.Padding = UDim.new(0, 6)
tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function CreateMetricCard(title, initialVal, color)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0.31, 0, 1, 0)
    card.BackgroundColor3 = Config.UI.Card2Color
    card.BorderSizePixel = 0
    card.Parent = teleGrid
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", card)
    stroke.Color = color or Config.UI.AccentColor
    stroke.Thickness = 1
    stroke.Transparency = 0.5

    local tit = Instance.new("TextLabel")
    tit.Size = UDim2.new(1, -10, 0, 16)
    tit.Position = UDim2.new(0, 8, 0, 6)
    tit.BackgroundTransparency = 1
    tit.Text = title
    tit.TextColor3 = Config.UI.SubTextColor
    tit.TextSize = 10
    tit.Font = Enum.Font.GothamMedium
    tit.TextXAlignment = Enum.TextXAlignment.Left
    tit.Parent = card

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1, -10, 0, 32)
    val.Position = UDim2.new(0, 8, 0, 24)
    val.BackgroundTransparency = 1
    val.Text = tostring(initialVal)
    val.TextColor3 = color or Config.UI.TextColor
    val.TextSize = 18
    val.Font = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Left
    val.Parent = card

    return val
end

local fpsValLabel = CreateMetricCard("FPS", "60", Config.UI.SuccessColor)
local pingValLabel = CreateMetricCard("PING", "0 ms", Config.UI.AccentColor)
local memValLabel = CreateMetricCard("MEMORY", "0 MB", Config.UI.WarnColor)

UI.Section(tTelemetry, "🧠 Finite State Machine (FSM) Status")

local fsmCard = Instance.new("Frame")
fsmCard.Size = UDim2.new(1, 0, 0, 80)
fsmCard.BackgroundColor3 = Config.UI.Card2Color
fsmCard.BorderSizePixel = 0
fsmCard.Parent = tTelemetry
Instance.new("UICorner", fsmCard).CornerRadius = UDim.new(0, 8)

local fsmInfoLabel = Instance.new("TextLabel")
fsmInfoLabel.Size = UDim2.new(1, -20, 1, -16)
fsmInfoLabel.Position = UDim2.new(0, 10, 0, 8)
fsmInfoLabel.BackgroundTransparency = 1
fsmInfoLabel.Text = "Current State: IDLE\nPrevious State: NONE\nTransitions Count: 0\nActive State Uptime: 0.0s"
fsmInfoLabel.TextColor3 = Config.UI.TextColor
fsmInfoLabel.TextSize = 11
fsmInfoLabel.Font = Enum.Font.Gotham
fsmInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
fsmInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
fsmInfoLabel.Parent = fsmCard

UI.Section(tTelemetry, "📜 Live Combat & Network Telemetry Log")

local logCard = Instance.new("Frame")
logCard.Size = UDim2.new(1, 0, 0, 110)
logCard.BackgroundColor3 = Config.UI.Card2Color
logCard.BorderSizePixel = 0
logCard.Parent = tTelemetry
Instance.new("UICorner", logCard).CornerRadius = UDim.new(0, 8)

local logText = Instance.new("TextLabel")
logText.Size = UDim2.new(1, -20, 1, -12)
logText.Position = UDim2.new(0, 10, 0, 6)
logText.BackgroundTransparency = 1
logText.Text = "Waiting for combat events..."
logText.TextColor3 = Config.UI.SubTextColor
logText.TextSize = 10
logText.Font = Enum.Font.Code
logText.TextXAlignment = Enum.TextXAlignment.Left
logText.TextYAlignment = Enum.TextYAlignment.Top
logText.Parent = logCard

task.spawn(function()
    while true do
        task.wait(0.6)
        pcall(function()
            if tTelemetry.Visible and #CombatLogEngine.Logs > 0 then
                logText.Text = table.concat(CombatLogEngine.Logs, "\n")
            end
        end)
    end
end)

UI.Section(tTelemetry, "⏱️ Profiler Benchmarks (Microseconds)")

local profilerCard = Instance.new("Frame")
profilerCard.Size = UDim2.new(1, 0, 0, 130)
profilerCard.BackgroundColor3 = Config.UI.Card2Color
profilerCard.BorderSizePixel = 0
profilerCard.Parent = tTelemetry
Instance.new("UICorner", profilerCard).CornerRadius = UDim.new(0, 8)

local profilerLabel = Instance.new("TextLabel")
profilerLabel.Size = UDim2.new(1, -20, 1, -16)
profilerLabel.Position = UDim2.new(0, 10, 0, 8)
profilerLabel.BackgroundTransparency = 1
profilerLabel.Text = "Rendering Pipeline: 0 μs\nPhysics Stepped: 0 μs\nHeartbeat Pipeline: 0 μs\nCombat Engine: 0 μs\nESP Pipeline: 0 μs\nRaycast Cache Hits: 0 | Misses: 0"
profilerLabel.TextColor3 = Config.UI.SubTextColor
profilerLabel.TextSize = 11
profilerLabel.Font = Enum.Font.Code
profilerLabel.TextXAlignment = Enum.TextXAlignment.Left
profilerLabel.TextYAlignment = Enum.TextYAlignment.Top
profilerLabel.Parent = profilerCard

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            if tTelemetry.Visible then
                fpsValLabel.Text = tostring(Profiler.CurrentFPS)
                pingValLabel.Text = tostring(Profiler.PingMS) .. " ms"
                memValLabel.Text = string.format("%.1f MB", (Profiler.MemoryKB or 0) / 1024)

                local uptime = os.clock() - (StateMachine.StateStartTime or os.clock())
                fsmInfoLabel.Text = string.format("● Current State: %s\n● Previous State: %s\n● Total Transitions: %d\n● Active State Uptime: %.1fs",
                    tostring(StateMachine.CurrentState),
                    tostring(StateMachine.PreviousState or "NONE"),
                    StateMachine.TransitionsCount,
                    uptime
                )

                local renderAvg = Profiler.Metrics["RenderPipeline"] and Profiler.Metrics["RenderPipeline"].AvgMicroseconds or 0
                local steppedAvg = Profiler.Metrics["SteppedPipeline"] and Profiler.Metrics["SteppedPipeline"].AvgMicroseconds or 0
                local hbAvg = Profiler.Metrics["HeartbeatPipeline"] and Profiler.Metrics["HeartbeatPipeline"].AvgMicroseconds or 0
                local combatAvg = Profiler.Metrics["CombatEngine"] and Profiler.Metrics["CombatEngine"].AvgMicroseconds or 0
                local espAvg = Profiler.Metrics["ESPEngine"] and Profiler.Metrics["ESPEngine"].AvgMicroseconds or 0

                local hitRate = 0
                local totalCacheReq = CacheEngine.Stats.Hits + CacheEngine.Stats.Misses
                if totalCacheReq > 0 then
                    hitRate = math.floor((CacheEngine.Stats.Hits / totalCacheReq) * 100)
                end

                profilerLabel.Text = string.format("Render Pipeline:    %.1f μs\nPhysics Stepped:    %.1f μs\nHeartbeat Logic:    %.1f μs\nCombat Execution:   %.1f μs\nESP Processing:     %.1f μs\nCache Ratio:        %d%% (%d hits / %d req)",
                    renderAvg, steppedAvg, hbAvg, combatAvg, espAvg, hitRate, CacheEngine.Stats.Hits, totalCacheReq
                )
            end
        end)
    end
end)

UI.Button(tTelemetry, "Force Memory Garbage Collection", "TEMİZLE", "success", function()
    pcall(function()
        local before = collectgarbage("count")
        collectgarbage("collect")
        local after = collectgarbage("count")
        local freed = math.max(0, before - after)
        Notify("Memory Cleared", string.format("%.1f KB bellek başarıyla temizlendi!", freed), "success", 3)
    end)
end)

UI.Button(tTelemetry, "Reset Profiler & Invalidate Cache", "SIFIRLA", "warn", function()
    table.clear(Profiler.Metrics)
    table.clear(CacheEngine.PlayerCache)
    table.clear(CacheEngine.RaycastCache)
    CacheEngine.Stats.Hits = 0
    CacheEngine.Stats.Misses = 0
    Notify("Profiler & Cache", "Tüm metrikler ve önbellekler sıfırlandı!", "info", 2.5)
end)

UI.Button(tTelemetry, "Force FSM Reset to IDLE", "FSM SIFIRLA", "danger", function()
    StateMachine.TransitionTo(FSMStates.IDLE, true)
    Notify("FSM Engine", "Durum makinesi zorla IDLE durumuna alındı.", "warn", 2.5)
end)

-- ============================================================================
-- TAB 9: ⚙️ SETTINGS & CONFIG
-- ============================================================================
local tSettings = CreateTab("Settings", "⚙️", 9)
UI.Section(tSettings, "Theme & Accent Color Presets")

local themeNames = {}
for name, _ in pairs(ColorPresets) do table.insert(themeNames, name) end
table.sort(themeNames)

UI.Dropdown(tSettings, "UI Accent Renk Teması", themeNames, Config.UI.AccentName or "Cyan Neon", function(sel)
    Config.UI.AccentName = sel
    local col = ColorPresets[sel] or Color3.fromRGB(0, 220, 255)
    Config.UI.AccentColor = col
    mainStroke.Color = col
    headerStripe.BackgroundColor3 = col
    ConfigSystem.Save()
    Notify("Theme Changed", "Renk teması: " .. sel, "info", 2)
end)

UI.Section(tSettings, "Keybinds & Controls")

UI.Keybind(tSettings, "Menü Gizle / Göster", Config.Keybinds.ToggleGUI, function(k)
    Config.Keybinds.ToggleGUI = k
end)

UI.Keybind(tSettings, "Fly (Uçma) Kısayolu", Config.Keybinds.ToggleFly, function(k)
    Config.Keybinds.ToggleFly = k
end)

UI.Keybind(tSettings, "Noclip Kısayolu", Config.Keybinds.ToggleNoclip, function(k)
    Config.Keybinds.ToggleNoclip = k
end)

UI.Keybind(tSettings, "Aimlock Kısayolu", Config.Keybinds.ToggleAimlock, function(k)
    Config.Keybinds.ToggleAimlock = k
end)

UI.Keybind(tSettings, "Safe Behind-TP Kısayolu", Config.Keybinds.ToggleBehindTP, function(k)
    Config.Keybinds.ToggleBehindTP = k
end)

UI.Keybind(tSettings, "Auto Sky Dodge Kısayolu", Config.Keybinds.ToggleSkyDodge, function(k)
    Config.Keybinds.ToggleSkyDodge = k
end)

UI.Keybind(tSettings, "Mass Vacuum TP Kısayolu", Config.Keybinds.MassBringKey, function(k)
    Config.Keybinds.MassBringKey = k
end)

UI.Keybind(tSettings, "Emergency Stop Kısayolu", Config.Keybinds.EmergencyStop, function(k)
    Config.Keybinds.EmergencyStop = k
end)

UI.Section(tSettings, "Config Save & Load Engine")

UI.Button(tSettings, "Save Config File", "KAYDET", "success", function()
    local ok, err = ConfigSystem.Save()
    if ok then
        Notify("Config System", "Ayarlar başarıyla kaydedildi! (" .. ConfigSystem.FileName .. ")", "success", 3)
    else
        Notify("Config System", "Kayıt hatası: " .. tostring(err), "error", 3)
    end
end)

UI.Button(tSettings, "Load Saved Config", "YÜKLE", "primary", function()
    local ok, err = ConfigSystem.Load()
    if ok then
        Notify("Config System", "Ayarlar başarıyla yüklendi!", "success", 3)
    else
        Notify("Config System", "Yükleme hatası: " .. tostring(err), "error", 3)
    end
end)

UI.Button(tSettings, "Reset to Factory Defaults", "SIFIRLA", "danger", function()
    ConfigSystem.Reset()
    Notify("Config System", "Tüm ayarlar varsayılana döndürüldü!", "warn", 3)
end)

-- Default Tab Active
SwitchTab("Combat")


-- [[ SECTION 14: GLOBAL KEYBIND LISTENERS ]]
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.UserInputType == Enum.UserInputType.Keyboard then
        if Config.Keybinds.ToggleGUI and inp.KeyCode == Config.Keybinds.ToggleGUI then
            Config.UI.IsOpen = not Config.UI.IsOpen
            MainFrame.Visible = Config.UI.IsOpen
            GlowShadow.Visible = Config.UI.IsOpen
        elseif Config.Keybinds.ToggleBehindTP and inp.KeyCode == Config.Keybinds.ToggleBehindTP then
            Config.Target.BehindTP = not Config.Target.BehindTP
            ConfigSystem.RefreshUI()
            Notify("Target", "Safe Behind-TP: " .. (Config.Target.BehindTP and "AKTİF" or "KAPALI"), "info", 2)
        elseif Config.Keybinds.ToggleFly and inp.KeyCode == Config.Keybinds.ToggleFly then
            Movement.ToggleFly(not Config.Movement.Fly)
            ConfigSystem.RefreshUI()
        elseif Config.Keybinds.ToggleNoclip and inp.KeyCode == Config.Keybinds.ToggleNoclip then
            Config.Movement.Noclip = not Config.Movement.Noclip
            ConfigSystem.RefreshUI()
            Notify("Movement", "Noclip: " .. (Config.Movement.Noclip and "AKTİF" or "KAPALI"), "info", 2)
        elseif Config.Keybinds.ToggleSkyDodge and inp.KeyCode == Config.Keybinds.ToggleSkyDodge then
            Config.Survival.SkyDodge = not Config.Survival.SkyDodge
            if not Config.Survival.SkyDodge and State.SkyDodge.IsDodging then
                SurvivalSystem.EndSkyDodge()
            end
            ConfigSystem.RefreshUI()
            Notify("Survival", "Auto Sky Dodge: " .. (Config.Survival.SkyDodge and "AKTİF" or "KAPALI"), "info", 2)
        elseif Config.Keybinds.MassBringKey and inp.KeyCode == Config.Keybinds.MassBringKey then
            Combat.ToggleMassBring()
        end
    end
end)

-- [[ SECTION 15: MOBILE TOGGLE BUTTON ]]
pcall(function()
    local oldMobile = CoreGui:FindFirstChild("HubMobileBtnGui") or LocalPlayer.PlayerGui:FindFirstChild("HubMobileBtnGui")
    if oldMobile then oldMobile:Destroy() end
end)

local MobileGui = Instance.new("ScreenGui")
MobileGui.Name = "HubMobileBtnGui"
MobileGui.ResetOnSpawn = false
pcall(function() MobileGui.Parent = CoreGui end)
if not MobileGui.Parent then MobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MobileBtn = Instance.new("TextButton")
MobileBtn.Name = "MobileToggle"
MobileBtn.Size = UDim2.new(0, 48, 0, 48)
MobileBtn.Position = UDim2.new(0, 15, 0.5, -24)
MobileBtn.BackgroundColor3 = Config.UI.CardColor
MobileBtn.BorderSizePixel = 0
MobileBtn.Text = "⚡"
MobileBtn.TextSize = 22
MobileBtn.Parent = MobileGui
Instance.new("UICorner", MobileBtn).CornerRadius = UDim.new(1, 0)

local mStroke = Instance.new("UIStroke", MobileBtn)
mStroke.Color = Config.UI.AccentColor
mStroke.Thickness = 1.5

MobileBtn.MouseButton1Click:Connect(function()
    Config.UI.IsOpen = not Config.UI.IsOpen
    MainFrame.Visible = Config.UI.IsOpen
    GlowShadow.Visible = Config.UI.IsOpen
end)

-- [[ SECTION 16: MAIN LOOPS & FEATURE PIPELINE ]]

-- Register Features into Pipeline
FeatureManager.Register({
    Name = "Aimlock",
    Phase = "RenderStepped",
    Priority = 100,
    IsEnabled = function() return Config.Combat.Aimlock and not State.IsEmergencyStop end,
    Execute = function(dt) Combat.UpdateAimlock() end
})

FeatureManager.Register({
    Name = "FlyMovement",
    Phase = "RenderStepped",
    Priority = 90,
    IsEnabled = function() return Config.Movement.Fly and not State.IsEmergencyStop end,
    Execute = function(dt) Movement.UpdateFly(dt) end
})

FeatureManager.Register({
    Name = "BehindTP_Render",
    Phase = "RenderStepped",
    Priority = 80,
    IsEnabled = function() return Config.Target.BehindTP and not State.IsEmergencyStop end,
    Execute = function(dt) TargetSystem.UpdateBehindTP(dt) end
})

FeatureManager.Register({
    Name = "MassBring_Render",
    Phase = "RenderStepped",
    Priority = 70,
    IsEnabled = function() return State.MassBringActive and not State.IsEmergencyStop end,
    Execute = function(dt) Combat.UpdateMassBring(dt) end
})

FeatureManager.Register({
    Name = "FOVCircle",
    Phase = "RenderStepped",
    Priority = 50,
    IsEnabled = function() return Config.Visuals.FOVCircle and not State.IsEmergencyStop end,
    Execute = function(dt) UpdateFOVCircle() end
})

FeatureManager.Register({
    Name = "PhysicsNoclip",
    Phase = "Stepped",
    Priority = 100,
    IsEnabled = function() return Config.Movement.Noclip and not State.IsEmergencyStop end,
    Execute = function(dt) Movement.UpdateNoclip() end
})

FeatureManager.Register({
    Name = "HitboxExpander",
    Phase = "Stepped",
    Priority = 90,
    IsEnabled = function() return Config.Combat.HitboxExpander and not State.IsEmergencyStop end,
    Execute = function(dt) Combat.UpdateHitboxExpander() end
})

FeatureManager.Register({
    Name = "BodyReach",
    Phase = "Stepped",
    Priority = 80,
    IsEnabled = function() return Config.Combat.BodyReach and not State.IsEmergencyStop end,
    Execute = function(dt) Combat.UpdateBodyReach() end
})

FeatureManager.Register({
    Name = "EnemyStateEngine",
    Phase = "Heartbeat",
    Priority = 95,
    IsEnabled = function() return not State.IsEmergencyStop end,
    Execute = function(dt)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                EnemyStateEngine.Update(player)
            end
        end
    end
})

FeatureManager.Register({
    Name = "CombatEngine",
    Phase = "Heartbeat",
    Priority = 100,
    IsEnabled = function() return not State.IsEmergencyStop end,
    Execute = function(dt)
        Combat.UpdateAutoM1()
        Combat.UpdateAutoBlock()
        Combat.CheckAutoAwakening()
        Combat.UpdateNoKnockback()
        Combat.UpdateNoSlowdown()
    end
})

FeatureManager.Register({
    Name = "MovementEngine",
    Phase = "Heartbeat",
    Priority = 90,
    IsEnabled = function() return not State.IsEmergencyStop end,
    Execute = function(dt)
        Movement.UpdateSpeed(dt)
        Movement.UpdateAntiVoid()
        Movement.UpdateGlide()
        Movement.UpdateAirStall()
    end
})

FeatureManager.Register({
    Name = "SurvivalEngine",
    Phase = "Heartbeat",
    Priority = 85,
    IsEnabled = function() return not State.IsEmergencyStop end,
    Execute = function(dt)
        SurvivalSystem.UpdateSkyDodge(dt)
        SurvivalSystem.CheckSkyEscape()
    end
})

FeatureManager.Register({
    Name = "SkillEngine",
    Phase = "Heartbeat",
    Priority = 80,
    IsEnabled = function() return not State.IsEmergencyStop end,
    Execute = function(dt)
        SkillSystem.UpdateAutoSkillSpam()
    end
})

FeatureManager.Register({
    Name = "ESPEngine",
    Phase = "Heartbeat",
    Priority = 70,
    IsEnabled = function() return not State.IsEmergencyStop end,
    Execute = function(dt)
        ESP.Update()
    end
})

FeatureManager.Register({
    Name = "WorldEngine",
    Phase = "Heartbeat",
    Priority = 60,
    IsEnabled = function() return not State.IsEmergencyStop end,
    Execute = function(dt)
        World.CheckAutoServerHop()
    end
})

local function OnCharacterAdded(char)
    Combat.HookAntiRagdoll(char)
    Combat.HookAutoEvasive(char)
    State.LastSafePos = nil
    State.M1ComboCount = 0
    CacheEngine.InvalidatePlayer(LocalPlayer)
    task.wait(0.5)
    if Config.Movement.Fly then Movement.ToggleFly(true) end
end

if LocalPlayer.Character then task.spawn(OnCharacterAdded, LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

Players.PlayerRemoving:Connect(function(player)
    CacheEngine.InvalidatePlayer(player)
    ESP.RemoveHighlight(player)
    ESP.RemoveBillboard(player)
    local tr = State.ESP.Tracers[player]
    if tr and tr.Remove then pcall(function() tr:Remove() end) end
    State.ESP.Tracers[player] = nil
    State.SaitamaUltiTrack[player] = nil
    State.CharacterCache[player] = nil
end)

-- Main Render Loop
RunService.RenderStepped:Connect(function(dt)
    Profiler.UpdateSystemMetrics()
    if State.IsEmergencyStop then return end

    local pStart = Profiler.Begin("RenderPipeline")
    FeatureManager.ExecutePipeline("RenderStepped", dt)
    Profiler.End("RenderPipeline", pStart)

    -- Sky Dodge Camera Lock
    if Config.Survival.SkyDodge and State.SkyDodge.IsDodging and Config.Survival.SkyDodgeLockCamera and State.SkyDodge.LockedCameraPos and Camera then
        pcall(function()
            Camera.CFrame = State.SkyDodge.LockedCameraPos
        end)
    end

    if Config.World.CustomFOV and Camera then
        Camera.FieldOfView = Config.World.FOVValue
    end
end)

-- Main Physics Stepped Loop
RunService.Stepped:Connect(function()
    if State.IsEmergencyStop then return end
    local pStart = Profiler.Begin("SteppedPipeline")
    FeatureManager.ExecutePipeline("Stepped")
    Profiler.End("SteppedPipeline", pStart)
end)

-- Main Logic Heartbeat Loop
RunService.Heartbeat:Connect(function(dt)
    if State.IsEmergencyStop then return end

    local pStart = Profiler.Begin("HeartbeatPipeline")
    StateMachine.Update(dt)
    FeatureManager.ExecutePipeline("Heartbeat", dt)
    Profiler.End("HeartbeatPipeline", pStart)

    -- Anti AFK
    if Config.World.AntiAFK and (tick() - State.AntiAFKTick) > 60 then
        State.AntiAFKTick = tick()
        if VirtualUser then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end
end)

-- Infinite Jump Hook
UserInputService.JumpRequest:Connect(function()
    if Config.Movement.InfiniteJump then
        local hum = Utils.LocalHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
    if Config.Movement.DoubleJump and State.DoubleJumpReady then
        local hum = Utils.LocalHum()
        if hum and hum:GetState() == Enum.HumanoidStateType.Freefall then
            State.DoubleJumpReady = false
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            task.delay(Config.Movement.DoubleJumpCD, function() State.DoubleJumpReady = true end)
        end
    end
end)

-- [[ SECTION 17: STARTUP ]]
SetupFOVCircle()

pcall(function()
    if typeof(isfile) == "function" and isfile(ConfigSystem.FileName) then
        Notify("Config System", "Eski ayarlarınız (Behind-TP, Fly, Keybinds vb.) menüye otomatik yüklendi!", "success", 4)
    end
end)

Notify("4080 HUB PRO", "TSB Expert Suite v6.0 Loaded! Level 6 FSM & Cache Engine Active.", "success", 4.5)
print("[4080 HUB v7.0 SPECIALIST SUITE] Level 6 Architecture Initialized Successfully.")

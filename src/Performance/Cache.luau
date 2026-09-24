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

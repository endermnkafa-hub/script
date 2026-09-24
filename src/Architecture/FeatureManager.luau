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
                report[name] = string.format("Missing Dependency '%s'", dep)
                feat.Status = "DEGRADED"
                allValid = false
            end
        end
    end

    return allValid, report
end

function FeatureManager:InitAll(ctx: any)
    for name, feat in pairs(self._features) do
        if feat.Init then
            self._logger:SafeCall(name .. ".Init", feat.Init, feat, ctx)
        end
    end
end

function FeatureManager:SetEnabled(name: string, enabled: boolean, ctx: any)
    local feat = self._features[name]
    if not feat or feat.Enabled == enabled then return end

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
        if feat.Enabled and feat.Update then
            -- Active Budget Enforcement & Adaptive Throttling
            local metric = self._profiler and self._profiler.Metrics[feat.Name]
            if metric and metric.Status == "OVER_BUDGET" then
                feat.OverBudgetCount += 1
                if feat.OverBudgetCount > 5 then
                    feat.Status = "THROTTLED"
                    -- Skip 1 in 2 frames to enforce performance budget
                    if (feat.OverBudgetCount % 2) == 0 then
                        continue
                    end
                end
            else
                feat.OverBudgetCount = 0
                feat.Status = "RUNNING"
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

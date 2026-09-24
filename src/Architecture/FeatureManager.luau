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

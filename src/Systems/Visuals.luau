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

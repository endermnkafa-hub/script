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

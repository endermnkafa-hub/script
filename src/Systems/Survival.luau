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

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

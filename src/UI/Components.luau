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

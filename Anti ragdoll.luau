local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer

local parentGui
pcall(function() parentGui = game:GetService("CoreGui") end)
if not parentGui then parentGui = lp:WaitForChild("PlayerGui") end
if parentGui:FindFirstChild("ScreenGui") then parentGui.ScreenGui:Destroy() end

local on = false
local conns = {}
local motorGuards = {}
local ceiling = nil
local spawnY = nil
local groundY = nil
local currentY = 72

local CEILING_OFFSET = 72
local CEILING_SIZE = Vector3.new(30, 1, 30)
local BUFFER = 4

local function clearAll()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    for _, c in ipairs(motorGuards) do pcall(function() c:Disconnect() end) end
    motorGuards = {}
    if ceiling then ceiling:Destroy(); ceiling = nil end
end

local function detectGroundY(hrp)
    if not hrp then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {lp.Character}
    params.IgnoreWater = true
    local hit = workspace:Raycast(hrp.Position + Vector3.new(0, 5, 0), Vector3.new(0, -500, 0), params)
    if hit then return hit.Position.Y end
    return nil
end

local function makeCeiling()
    if ceiling then ceiling:Destroy() end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local base = groundY or spawnY or (hrp.Position.Y - 3)
    currentY = base + CEILING_OFFSET
    local p = Instance.new("Part")
    p.Name = "SharkCeiling"
    p.Size = CEILING_SIZE
    p.Anchored = true
    p.CanCollide = true
    p.CanTouch = false
    p.CanQuery = false
    p.Transparency = 1
    p.Massless = true
    p.Material = Enum.Material.SmoothPlastic
    p.CFrame = CFrame.new(hrp.Position.X, currentY, hrp.Position.Z)
    p.Parent = workspace
    ceiling = p
end

local function updateCeiling()
    if not ceiling then return end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local base = groundY or spawnY or (hrp.Position.Y - 3)
    currentY = base + CEILING_OFFSET
    ceiling.CFrame = CFrame.new(hrp.Position.X, currentY, hrp.Position.Z)
end

local function guardMotor(m)
    if not m:IsA("Motor6D") then return end
    pcall(function() if not m.Enabled then m.Enabled = true end end)
    table.insert(motorGuards, m:GetPropertyChangedSignal("Enabled"):Connect(function()
        if on and not m.Enabled then m.Enabled = true end
    end))
    table.insert(motorGuards, m.AncestryChanged:Connect(function(_, parent)
        if on and not parent then
            local char = lp.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function() m.Parent = hrp; m.Enabled = true end)
            end
        end
    end))
end

local function enable()
    local char = lp.Character or lp.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid", 5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hum or not hrp then return end

    task.wait(0.3)
    spawnY = hrp.Position.Y
    groundY = detectGroundY(hrp)

    makeCeiling()

    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Motor6D") then guardMotor(d) end
    end
    table.insert(conns, char.DescendantAdded:Connect(function(d)
        if d:IsA("Motor6D") then task.wait(); guardMotor(d) end
    end))

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    end)
    table.insert(conns, hum.StateChanged:Connect(function(_, new)
        if not on then return end
        if new == Enum.HumanoidStateType.Ragdoll
        or new == Enum.HumanoidStateType.FallingDown
        or new == Enum.HumanoidStateType.Physics then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end))

    local lastVel = Vector3.zero
    table.insert(conns, RunService.Heartbeat:Connect(function()
        if not on then return end
        local c = lp.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return end

        local v = r.AssemblyLinearVelocity
        local speed = v.Magnitude
        local spike = (v - lastVel).Magnitude

        if spike > 250 or speed > 400 then
            local flat = Vector3.new(v.X, 0, v.Z)
            if flat.Magnitude > 0.1 then
                local keep = lastVel.Magnitude
                if keep < 1 then keep = 16 end
                r.AssemblyLinearVelocity = flat.Unit * keep
            else
                r.AssemblyLinearVelocity = Vector3.zero
            end
            r.AssemblyAngularVelocity = Vector3.zero
        end

        if r.Position.Y > currentY - BUFFER then
            r.AssemblyLinearVelocity = Vector3.new(
                r.AssemblyLinearVelocity.X,
                math.min(r.AssemblyLinearVelocity.Y, 0),
                r.AssemblyLinearVelocity.Z
            )
            r.CFrame = CFrame.new(r.Position.X, currentY - BUFFER, r.Position.Z)
        end

        lastVel = r.AssemblyLinearVelocity
    end))

    local lastGroundCheck = 0
    table.insert(conns, RunService.RenderStepped:Connect(function()
        if not on then return end
        local c = lp.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return end

        local up = r.CFrame.UpVector
        if up.Y < 0.25 then
            local look = r.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.01 then
                r.CFrame = CFrame.new(r.Position, r.Position + flat.Unit)
            end
        end

        local now = os.clock()
        if now - lastGroundCheck > 1.0 then
            lastGroundCheck = now
            local g = detectGroundY(r)
            if g then groundY = g end
        end

        updateCeiling()
    end))

    table.insert(conns, lp.CharacterAdded:Connect(function()
        if not on then return end
        task.wait(0.3)
        local keep = on
        on = false
        clearAll()
        on = keep
        if on then enable() end
    end))
end

local COLORS = {
    bg = Color3.fromRGB(18,18,22),
    text = Color3.fromRGB(235,235,240),
    good = Color3.fromRGB(80,220,120),
    stroke = Color3.fromRGB(45,45,55),
}
local FONT_BOLD = Enum.Font.GothamBold

local screen = Instance.new("ScreenGui")
screen.Name = "ScreenGui"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.IgnoreGuiInset = true
screen.Parent = parentGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 180, 0, 80)
main.Position = UDim2.new(0.5, -90, 0.5, -40)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = screen
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local mst = Instance.new("UIStroke", main)
mst.Color = COLORS.stroke
mst.Thickness = 1

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.Position = UDim2.new(0, 0, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Anti-Ragdoll"
title.TextColor3 = COLORS.text
title.TextSize = 13
title.Font = FONT_BOLD
title.Parent = main

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -24, 0, 40)
btn.Position = UDim2.new(0, 12, 0, 34)
btn.BackgroundColor3 = COLORS.stroke
btn.Text = "OFF"
btn.TextColor3 = COLORS.text
btn.TextSize = 16
btn.Font = FONT_BOLD
btn.AutoButtonColor = false
btn.Parent = main
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

local function setVisual(s)
    TweenService:Create(btn, TweenInfo.new(0.15), {
        BackgroundColor3 = s and COLORS.good or COLORS.stroke
    }):Play()
    btn.Text = s and "ON" or "OFF"
end

btn.MouseButton1Click:Connect(function()
    on = not on
    if on then enable(); setVisual(true)
    else clearAll(); setVisual(false) end
end)

UIS.InputBegan:Connect(function(k, gp)
    if gp then return end
    if k.KeyCode == Enum.KeyCode.RightControl then
        main.Visible = not main.Visible
    end
end)

end

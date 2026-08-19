repeat task.wait() until game:IsLoaded()
task.wait(1)

local cloneref = cloneref or function(obj) return obj end
local players = cloneref(game:GetService("Players"))
local run = cloneref(game:GetService("RunService"))
local workspace = cloneref(game:GetService("Workspace"))
local lighting = cloneref(game:GetService("Lighting"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local RemoteEvent = ReplicatedStorage:FindFirstChild("RemoteEvent")
local fog = lighting:FindFirstChild("Atmosphere")

local Player = players.LocalPlayer

local DisableBeastRoping = false
local SkillcheckEnabled = false
local Hooked = false
local SavedAtmosphere = nil

local Values = {
    IsGameActive = ReplicatedStorage:FindFirstChild("IsGameActive"),
    GameStatus = ReplicatedStorage:FindFirstChild("GameStatus"),
    CurrentMap = ReplicatedStorage:FindFirstChild("CurrentMap"),
    ComputersLeft = ReplicatedStorage:FindFirstChild("ComputersLeft")
}

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
    Title = "yandere.sense",
    Footer = "version: 1.0.0 | Flee the Facility",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Survivor = Window:AddTab("Survivor", "user"),
    Rage = Window:AddTab("Rage", "zap"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Movement = Window:AddTab("Movement", "move"),
    Credits = Window:AddTab("Credits", "info"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local vec2 = Vector2.new
local vec3 = Vector3.new
local rgb = Color3.fromRGB

local r6_bones = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local flags = {
    ["Enabled"] = false,
    ["Names"] = true, 
    ["Name_Color"] = { Color = rgb(255, 255, 255) },
    ["Boxes"] = true,
    ["Box_Type"] = "Normal",
    ["Box_Color"] = { Color = rgb(255, 255, 255) },
    ["Distance"] = true,
    ["Weapon"] = true,
    ["Skeletons"] = true,
    ["Skeletons_Color"] = { Color = rgb(255, 255, 255) },
    ["Distance_Color"] = { Color = rgb(255, 255, 255) },
    ["Weapon_Color"] = { Color = rgb(255, 255, 255) }
}

local esp = {
    cache = {},
    connections = {}
}

function esp:create_drawing(type_name, properties)
    local obj = Drawing.new(type_name)
    obj.Transparency = 1
    obj.Visible = false
    for prop, val in properties do
        obj[prop] = val
    end
    return obj
end

function esp:get_box(character, camera)
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    if not root then return nil end

    local root_pos, on_screen = camera:WorldToViewportPoint(root.Position)
    if not on_screen or root_pos.Z <= 0 then
        return nil
    end

    local top_pos = camera:WorldToViewportPoint(root.Position + vec3(0, 3, 0))
    local bottom_pos = camera:WorldToViewportPoint(root.Position - vec3(0, 3.5, 0))

    if top_pos.Z <= 0 or bottom_pos.Z <= 0 then
        return nil
    end

    local height = math.abs(top_pos.Y - bottom_pos.Y)
    local width = height * 0.65
    local position = vec2(math.floor(root_pos.X - width / 2), math.floor(top_pos.Y))
    local size = vec2(math.floor(width), math.floor(height))

    return position, size, root_pos.Z
end

function esp:create_player(player)
    if esp.cache[player] then return end

    local data = {
        box = esp:create_drawing("Square", { Thickness = 1, Filled = false }),
        name = esp:create_drawing("Text", { Size = 13, Center = true, Outline = true }),
        distance = esp:create_drawing("Text", { Size = 13, Center = true, Outline = true }),
        weapon = esp:create_drawing("Text", { Size = 13, Center = true, Outline = true }),
        corners = {},
        skeletons = {}
    }

    for i = 1, 8 do
        data.corners[i] = esp:create_drawing("Line", { Thickness = 1 })
    end

    for i = 1, #r6_bones do
        data.skeletons[i] = esp:create_drawing("Line", { Thickness = 1 })
    end

    esp.cache[player] = data
end

function esp:hide_player(data)
    data.box.Visible = false
    data.name.Visible = false
    data.distance.Visible = false
    data.weapon.Visible = false
    for _, line in data.corners do line.Visible = false end
    for _, line in data.skeletons do line.Visible = false end
end

function esp:remove_player(player)
    local data = esp.cache[player]
    if not data then return end

    data.box:Remove()
    data.name:Remove()
    data.distance:Remove()
    data.weapon:Remove()
    for _, line in data.corners do line:Remove() end
    for _, line in data.skeletons do line:Remove() end

    esp.cache[player] = nil
end

function esp:draw_corners(data, pos, size, color, visible)
    local corners = data.corners
    if not visible then
        for _, line in corners do line.Visible = false end
        return
    end

    local len = math.clamp(math.min(size.X, size.Y) * 0.25, 3, 15)
    local x, y, w, h = pos.X, pos.Y, size.X, size.Y

    corners[1].From, corners[1].To = vec2(x, y), vec2(x + len, y)
    corners[2].From, corners[2].To = vec2(x, y), vec2(x, y + len)
    corners[3].From, corners[3].To = vec2(x + w, y), vec2(x + w - len, y)
    corners[4].From, corners[4].To = vec2(x + w, y), vec2(x + w, y + len)
    corners[5].From, corners[5].To = vec2(x, y + h), vec2(x + len, y + h)
    corners[6].From, corners[6].To = vec2(x, y + h), vec2(x, y + h - len)
    corners[7].From, corners[7].To = vec2(x + w, y + h), vec2(x + w - len, y + h)
    corners[8].From, corners[8].To = vec2(x + w, y + h), vec2(x + w, y + h - len)

    for _, line in corners do
        line.Color = color
        line.Visible = true
    end
end

esp.connection = run.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    if not camera then return end

    for _, player in players:GetPlayers() do
        if player == Player then continue end

        local data = esp.cache[player]
        if not data then continue end

        if not flags["Enabled"] then
            esp:hide_player(data)
            continue
        end

        local character = player.Character
        if not character or not character:FindFirstChild("Torso") then
            esp:hide_player(data)
            continue
        end

        local pos, size, distance = esp:get_box(character, camera)
        if not pos then
            esp:hide_player(data)
            continue
        end

        local color = flags["Box_Color"].Color
        local isBeast = false

        local tempStats = player:FindFirstChild("TempPlayerStatsModule")
        if tempStats then
            local beast = tempStats:FindFirstChild("IsBeast")
            if beast and beast.Value then
                isBeast = true
                color = Color3.fromRGB(255, 60, 60)
            end
        end

        if flags["Boxes"] then
            if flags["Box_Type"] == "Normal" then
                data.box.Position = pos
                data.box.Size = size
                data.box.Color = color
                data.box.Visible = true
                esp:draw_corners(data, pos, size, color, false)
            else
                data.box.Visible = false
                esp:draw_corners(data, pos, size, color, true)
            end
        else
            data.box.Visible = false
            esp:draw_corners(data, pos, size, color, false)
        end

        if flags["Names"] then
            data.name.Text = string.format(
                "%s (@%s)%s",
                player.DisplayName,
                player.Name,
                isBeast and " (Beast)" or ""
            )

            data.name.Position = vec2(pos.X + size.X / 2, pos.Y - 15)
            data.name.Color = isBeast and color or flags["Name_Color"].Color
            data.name.Visible = true
        else
            data.name.Visible = false
        end

        local bottom_offset = 3
        if flags["Distance"] then
            data.distance.Text = string.format("%dst", math.round(distance))
            data.distance.Position = vec2(pos.X + size.X / 2, pos.Y + size.Y + bottom_offset)
            data.distance.Color = isBeast and color or flags["Distance_Color"].Color
            data.distance.Visible = true
            bottom_offset += 13
        else
            data.distance.Visible = false
        end

        local tool = character:FindFirstChildOfClass("Tool")
        if flags["Weapon"] and tool then
            data.weapon.Text = string.format("[%s]", tool.Name)
            data.weapon.Position = vec2(pos.X + size.X / 2, pos.Y + size.Y + bottom_offset)
            data.weapon.Color = isBeast and color or flags["Weapon_Color"].Color
            data.weapon.Visible = true
        else
            data.weapon.Visible = false
        end

        if flags["Skeletons"] then
            for i, bone_pair in r6_bones do
                local p1 = character:FindFirstChild(bone_pair[1])
                local p2 = character:FindFirstChild(bone_pair[2])

                if p1 and p2 then
                    local v1, vis1 = camera:WorldToViewportPoint(p1.Position)
                    local v2, vis2 = camera:WorldToViewportPoint(p2.Position)

                    if vis1 and vis2 and v1.Z > 0 and v2.Z > 0 then
                        data.skeletons[i].From = vec2(v1.X, v1.Y)
                        data.skeletons[i].To = vec2(v2.X, v2.Y)
                        data.skeletons[i].Color = isBeast and color or flags["Skeletons_Color"].Color
                        data.skeletons[i].Visible = true
                    else
                        data.skeletons[i].Visible = false
                    end
                else
                    data.skeletons[i].Visible = false
                end
            end
        else
            for _, line in data.skeletons do
                line.Visible = false
            end
        end
    end
end)

for _, player in players:GetPlayers() do
    if player ~= Player then
        esp:create_player(player)
    end
end

players.PlayerAdded:Connect(function(player)
    esp:create_player(player)
end)

players.PlayerRemoving:Connect(function(player)
    esp:remove_player(player)
end)

local function EnablePcHighlights(State)
    if not Values.IsGameActive or not Values.IsGameActive.Value then return end

    local Map = Values.CurrentMap and Values.CurrentMap.Value
    if not Map or not Map.Parent then return end

    for _, Object in ipairs(Map:GetDescendants()) do
        if Object:IsA("Highlight") and Object.Name == "_ComputerHighlight" then
            Object:Destroy()
        end
    end

    if not State then return end

    for _, Object in ipairs(Map:GetDescendants()) do
        if Object.Name == "ComputerTable" then
            local Highlight = Instance.new("Highlight")
            Highlight.Name = "_ComputerHighlight"
            Highlight.FillColor = Color3.fromRGB(6, 118, 255)
            Highlight.FillTransparency = 0.5
            Highlight.OutlineTransparency = 1
            Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            Highlight.Adornee = Object
            Highlight.Parent = Object
        end
    end
end

local function EnableExitDoorHighlights(State)
    if not Values.IsGameActive or not Values.IsGameActive.Value then return end

    local Map = Values.CurrentMap and Values.CurrentMap.Value
    if not Map or not Map.Parent then return end

    for _, Object in ipairs(Map:GetDescendants()) do
        if Object:IsA("Highlight") and Object.Name == "_ExitHighlight" then
            Object:Destroy()
        end
    end

    if not State then return end

    for _, Object in ipairs(Map:GetDescendants()) do
        if Object.Name == "ExitDoor" then
            local Highlight = Instance.new("Highlight")
            Highlight.Name = "_ExitHighlight"
            Highlight.FillColor = Color3.fromRGB(255, 193, 6)
            Highlight.FillTransparency = 0.5
            Highlight.OutlineTransparency = 1
            Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            Highlight.Adornee = Object
            Highlight.Parent = Object
        end
    end
end

local function InitHooks()
    if Hooked then return end
    Hooked = true

    local OldNamecall
    OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if not checkcaller()
            and self == RemoteEvent
            and getnamecallmethod() == "FireServer" then

            local Args = {...}
            if SkillcheckEnabled and Args[1] == "SetPlayerMinigameResult" then
                Args[2] = true
                return OldNamecall(self, unpack(Args))
            end

            if DisableBeastRoping and (Args[1] == "Carrying" or Args[1] == "Rope") then
                return
            end
        end

        return OldNamecall(self, ...)
    end))
end

InitHooks()

local SurvivorGroup = Tabs.Survivor:AddLeftGroupbox("Automation")

SurvivorGroup:AddToggle("AutoSkillcheck", {
    Text = "Auto skill check - Computers",
    Default = false,
    Tooltip = "Automatically succeeds computer hacking minigames"
})

Toggles.AutoSkillcheck:OnChanged(function()
    SkillcheckEnabled = Toggles.AutoSkillcheck.Value
end)

local RageGroup = Tabs.Rage:AddLeftGroupbox("Beast")

RageGroup:AddToggle("DisableBeastRoping", {
    Text = "Disable beast roping",
    Default = false,
    Tooltip = "Prevents the Beast from roping survivors"
})

Toggles.DisableBeastRoping:OnChanged(function()
    DisableBeastRoping = Toggles.DisableBeastRoping.Value

    if DisableBeastRoping then
        task.spawn(function()
            while DisableBeastRoping and not Library.Unloaded do
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("RopeConstraint") or obj.Name == "Rope" then
                        obj:Destroy()
                    end
                end
                task.wait(0.1)
            end
        end)
    end
end)

local VisualsESPGroup = Tabs.Visuals:AddLeftGroupbox("ESP Settings")

VisualsESPGroup:AddToggle("BoxESP", {
    Text = "Box ESP",
    Default = false
})

Toggles.BoxESP:OnChanged(function()
    flags.Enabled = Toggles.BoxESP.Value
end)

VisualsESPGroup:AddToggle("ComputerChams", {
    Text = "Computer Chams",
    Default = false
})

Toggles.ComputerChams:OnChanged(function()
    EnablePcHighlights(Toggles.ComputerChams.Value)
end)

VisualsESPGroup:AddToggle("ExitChams", {
    Text = "Exit Chams",
    Default = false
})

Toggles.ExitChams:OnChanged(function()
    EnableExitDoorHighlights(Toggles.ExitChams.Value)
end)

local VisualsWorldGroup = Tabs.Visuals:AddRightGroupbox("World")

VisualsWorldGroup:AddToggle("NoFog", {
    Text = "No Fog",
    Default = false
})

Toggles.NoFog:OnChanged(function()
    if Toggles.NoFog.Value then
        local Atmosphere = lighting:FindFirstChild("Atmosphere") or fog
        if Atmosphere then
            SavedAtmosphere = Atmosphere
            Atmosphere.Parent = nil
        end
    else
        if SavedAtmosphere then
            SavedAtmosphere.Parent = lighting
        end
    end
end)

VisualsWorldGroup:AddToggle("FullBright", {
    Text = "Full Bright",
    Default = false
})

Toggles.FullBright:OnChanged(function()
    if Toggles.FullBright.Value then
        lighting.ClockTime = 15
    else
        lighting.ClockTime = 1
    end
end)

local MovementGroup = Tabs.Movement:AddLeftGroupbox("Character Movement")

MovementGroup:AddSlider("WalkSpeedSlider", {
    Text = "WalkSpeed",
    Default = 16,
    Min = 16,
    Max = 100,
    Rounding = 0,
})

Options.WalkSpeedSlider:OnChanged(function()
    if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
        Player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Options.WalkSpeedSlider.Value
    end
end)

MovementGroup:AddSlider("JumpPowerSlider", {
    Text = "Jump Power",
    Default = 35,
    Min = 35,
    Max = 150,
    Rounding = 0,
})

Options.JumpPowerSlider:OnChanged(function()
    if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
        Player.Character:FindFirstChildOfClass("Humanoid").JumpHeight = Options.JumpPowerSlider.Value
    end
end)

Player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hum = char:WaitForChild("Humanoid", 3)
    if hum then
        if Options.WalkSpeedSlider then hum.WalkSpeed = Options.WalkSpeedSlider.Value end
        if Options.JumpPowerSlider then hum.JumpHeight = Options.JumpPowerSlider.Value end
    end
end)

local CreditsGroup = Tabs.Credits:AddLeftGroupbox("yandere.sense")

CreditsGroup:AddLabel("Script: yandere.sense")
CreditsGroup:AddLabel("UI Library: Obsidian (LinoriaLib)")
CreditsGroup:AddLabel("Box ESP: i77lhm (rewritten by fwzn)")
CreditsGroup:AddLabel("Disable Beast Roping: fwzn")

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible,
    Text = "Open Keybind Menu",
    Callback = function(value)
        Library.KeybindFrame.Visible = value
    end,
})

MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = Library.ShowCustomCursor,
    Callback = function(Value)
        Library.ShowCustomCursor = Value
    end,
})

MenuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notification Side",
    Callback = function(Value)
        Library:SetNotifySide(Value)
    end,
})

MenuGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    Default = "100%",
    Text = "DPI Scale",
    Callback = function(Value)
        Value = Value:gsub("%%", "")
        Library:SetDPIScale(tonumber(Value))
    end,
})

MenuGroup:AddSlider("UICornerSlider", {
    Text = "Corner Radius",
    Default = Library.CornerRadius,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value)
        Window:SetCornerRadius(value)
    end
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("yandere.sense")
SaveManager:SetFolder("yandere.sense/flee-the-facility")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

SaveManager:LoadAutoloadConfig()

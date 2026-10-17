-- Example for the Feral UI Library. Loads Library + SaveManager from the UiMain repo.

local repo = "https://raw.githubusercontent.com/test123131235/UiMain/main/"

local Library     = loadstring(game:HttpGet(repo .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "Feral Hub",
    GameName = "Example",
    Logo = "rbxassetid://121449270899000",
})

Window:SetWatermark("Feral Hub — DEV", "rbxassetid://104479390541433")
Window:AddFPSPill()
Window:AddTimePill()
Window:AddCoordsPill()
Window:AddUsernamePill()

local MainTab     = Window:AddTab("Main", "rbxassetid://106606600179475")
local VisualsTab  = Window:AddTab("Visuals", "rbxassetid://106606600179475")
local SettingsTab = Window:AddTab("Settings", "rbxassetid://106606600179475")

----------------------------------------------------------------------
-- Main tab -> subtabs -> sections
----------------------------------------------------------------------
local Combat = MainTab:AddSubTab("Combat")
local Movement = MainTab:AddSubTab("Movement")

local Aim = Combat:AddSection("Aimbot", "Left")

Aim:AddToggle("AimbotEnabled", {
    Text = "Enabled",
    Default = false,
    Callback = function(v) print("Aimbot:", v) end,
})

-- toggle with colour picker (original look) + keybind
local Fov = Aim:AddToggle("FovCircle", { Text = "FOV circle", Default = false })
Fov:AddColorPicker("FovColor", { Default = Color3.fromRGB(255, 60, 60), Callback = function(c) print("FOV color", c) end })
Fov:AddKeyPicker("FovKey", { Default = "H", Mode = "Toggle", SyncToggleState = true })

Aim:AddSlider("AimFov", {
    Text = "FOV",
    Min = 0, Max = 360, Default = 90,
    Callback = function(v) end,
})
Aim:AddSlider("AimSmooth", {
    Text = "Smoothness",
    Min = 0, Max = 1, Default = 0.25, Decimals = 2,
    Callback = function(v) end,
})

local Target = Combat:AddSection("Targeting", "Right")

Target:AddDropdown("AimPart", {
    Title = "Target part",
    Options = { "Head", "Torso", "Random" },
    Default = "Head",
    Callback = function(v) end,
})
Target:AddDropdown("AimChecks", {
    Title = "Checks",
    Multi = true,
    Options = { "Team", "Visible", "Alive" },
    Default = { "Alive" },
    Callback = function(v) end,
})
Target:AddTextbox("AimWhitelist", {
    Placeholder = "Whitelist player...",
    Icon = "rbxassetid://107972121937062",
    Callback = function(v) print("Whitelist:", v) end,
})
Target:AddTextIndicator("AimStatus", { Default = "Idle", Icon = "rbxassetid://102638872351950" })
Target:AddLabel("Right click the keybind to change its mode")
Target:AddButton("Print config", function()
    print("Aimbot enabled:", Toggles.AimbotEnabled.Value, "| FOV:", Options.AimFov.Value)
end):AddButton("Notify", function()
    Library:Notify("Example", "Hello from Feral!", 3)
end)

local Move = Movement:AddSection("Speed", "Left")
Move:AddToggle("SpeedEnabled", { Text = "Speed", Default = false })
Move:AddSlider("SpeedValue", { Text = "Speed", Min = 16, Max = 200, Default = 16 })
Move:AddColorpicker("TrailColor", { Title = "Trail color", Default = Color3.fromRGB(0, 170, 255) })

----------------------------------------------------------------------
-- Visuals tab (one subtab)
----------------------------------------------------------------------
local Esp = VisualsTab:AddSubTab("ESP")
local EspSection = Esp:AddSection("Players", "Left")
EspSection:AddToggle("EspBox", {
    Text = "Boxes", Default = true,
    Color = Color3.fromRGB(255, 255, 255), ColorFlag = "EspBoxColor", -- original style color toggle still works
})
EspSection:AddToggle("EspName", { Text = "Names", Default = false })

----------------------------------------------------------------------
-- Settings tab -> Config subtab
----------------------------------------------------------------------
local Config = SettingsTab:AddSubTab("Config")
local MenuSection = Config:AddSection("Menu", "Left")
MenuSection:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", { Default = "X", Mode = "Toggle" })
Library.ToggleKeybind = Options.MenuKeybind
MenuSection:AddButton("Unload", function() Library:Exit() end)

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("FeralHub/Example")
SaveManager:BuildConfigSection(Config) -- adds the "Configuration" section on the right
SaveManager:LoadAutoloadConfig()

task.delay(1, function()
    Library:Notify("Example", "Loaded", 3)
end)

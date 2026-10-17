-- Example script for the Feral UI Library (Linoria-style API)
-- Host Library.lua and SaveManager.lua somewhere (GitHub raw, etc.) and change `repo`,
-- or swap the loadstring(game:HttpGet(...)) lines for loadstring(readfile("Library.lua"))().

local repo = "https://raw.githubusercontent.com/YOURNAME/YOURREPO/main/"

local Library     = loadstring(game:HttpGet(repo .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "Feral Hub",
    SubTitle = "Example",
    -- Logo = "rbxassetid://121449270899000",
    Center = true,
    AutoShow = true,
    TabPadding = 6,
})

local Tabs = {
    Main = Window:AddTab("Main"),
    ["UI Settings"] = Window:AddTab("UI Settings"),
}

----------------------------------------------------------------------
-- Left groupbox
----------------------------------------------------------------------
local LeftGroupBox = Tabs.Main:AddLeftGroupbox("Groupbox")

LeftGroupBox:AddToggle("MyToggle", {
    Text = "This is a toggle",
    Default = true,
    Tooltip = "This is a tooltip",
    Callback = function(Value)
        print("[cb] MyToggle changed to:", Value)
    end,
})

Toggles.MyToggle:OnChanged(function()
    print("MyToggle changed to:", Toggles.MyToggle.Value)
end)

-- Toggle with a color picker and a keybind attached
LeftGroupBox:AddToggle("ColorToggle", { Text = "Toggle with addons", Default = false })
    :AddColorPicker("ToggleColor", {
        Default = Color3.fromRGB(255, 60, 60),
        Title = "Some color",
        Callback = function(Value) print("[cb] Toggle color changed:", Value) end,
    })
Toggles.ColorToggle:AddKeyPicker("ToggleKey", {
    Default = "E",
    Mode = "Toggle",
    Text = "Toggle keybind",
    SyncToggleState = true,
})

LeftGroupBox:AddButton({
    Text = "Button",
    Func = function() print("You clicked a button!") end,
    DoubleClick = false,
    Tooltip = "This is the main button",
}):AddButton({
    Text = "Sub button",
    Func = function() print("You clicked a sub button!") end,
    Tooltip = "This is a sub button",
})

LeftGroupBox:AddButton({
    Text = "Double click button",
    DoubleClick = true,
    Func = function() print("You clicked a double click button!") end,
})

LeftGroupBox:AddDivider()

LeftGroupBox:AddLabel("This is a label")
LeftGroupBox:AddLabel("This is a label\n\nthat wraps its text!", true)

LeftGroupBox:AddLabel("Label with a color picker"):AddColorPicker("LabelColor", {
    Default = Color3.fromRGB(0, 170, 255),
    Title = "Label color",
})
LeftGroupBox:AddLabel("Label with a keybind"):AddKeyPicker("LabelKey", {
    Default = "RightControl",
    Mode = "Hold",
    Text = "Hold keybind",
})

LeftGroupBox:AddDivider()

LeftGroupBox:AddSlider("MySlider", {
    Text = "This is my slider",
    Default = 0,
    Min = 0,
    Max = 5,
    Rounding = 1,
    Compact = false,
    Suffix = "s",
    Callback = function(Value) print("[cb] MySlider was changed! New value:", Value) end,
})

LeftGroupBox:AddSlider("CompactSlider", { Text = "Compact slider", Default = 50, Min = 0, Max = 100, Rounding = 0, Compact = true })

Options.MySlider:OnChanged(function()
    print("MySlider was changed! New value:", Options.MySlider.Value)
end)
Options.MySlider:SetValue(3)

LeftGroupBox:AddInput("MyTextbox", {
    Default = "My textbox!",
    Numeric = false,
    Finished = false,
    Text = "This is a textbox",
    Tooltip = "This is a tooltip",
    Placeholder = "Placeholder text",
    Callback = function(Value) print("[cb] Text updated. New text:", Value) end,
})

LeftGroupBox:AddDropdown("MyDropdown", {
    Values = { "This", "is", "a", "dropdown" },
    Default = 1, -- index or value
    Multi = false,
    Text = "A dropdown",
    Tooltip = "This is a tooltip",
    Callback = function(Value) print("[cb] Dropdown got changed. New value:", Value) end,
})
Options.MyDropdown:OnChanged(function() print("Dropdown got changed. New value:", Options.MyDropdown.Value) end)
Options.MyDropdown:SetValue("This")

LeftGroupBox:AddDropdown("MyMultiDropdown", {
    Values = { "This", "is", "a", "dropdown" },
    Default = 1,
    Multi = true,
    Text = "A multi dropdown",
    Tooltip = "This is a tooltip",
    Callback = function(Value)
        local keys = {}
        for k in next, Value do table.insert(keys, k) end
        print("[cb] Multi dropdown got changed:", table.concat(keys, ", "))
    end,
})
Options.MyMultiDropdown:SetValue({ This = true, is = true })

LeftGroupBox:AddDropdown("NullableDropdown", {
    Values = { "One", "Two", "Three" },
    Default = 1,
    AllowNull = true,
    Text = "Nullable dropdown",
})

----------------------------------------------------------------------
-- Right side: tabbox
----------------------------------------------------------------------
local TabBox = Tabs.Main:AddRightTabbox()
local Tab1 = TabBox:AddTab("Tab 1")
Tab1:AddToggle("Tab1Toggle", { Text = "Tab1 toggle" })
local Tab2 = TabBox:AddTab("Tab 2")
Tab2:AddToggle("Tab2Toggle", { Text = "Tab2 toggle" })

local RightGroupBox = Tabs.Main:AddRightGroupbox("Notifications")
RightGroupBox:AddButton("Notify", function()
    Library:Notify("Hello from the Feral library!", 4)
end)
RightGroupBox:AddSlider("AccentHue", { Text = "Accent hue", Default = 58, Min = 0, Max = 100, Rounding = 0 })
Options.AccentHue:OnChanged(function()
    local c = Color3.fromHSV(Options.AccentHue.Value / 100, 0.9, 1)
    Library:SetAccent(c)
end)

----------------------------------------------------------------------
-- UI Settings
----------------------------------------------------------------------
Library:SetWatermark("Feral Hub | Example")

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
MenuGroup:AddButton("Unload", function() Library:Unload() end)
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", Mode = "Toggle", Text = "Menu keybind" })
Library.ToggleKeybind = Options.MenuKeybind -- allows the menu keybind to be rebound

Library:OnUnload(function()
    print("Unloaded!")
    Library.Unloaded = true
end)

----------------------------------------------------------------------
-- Save manager
----------------------------------------------------------------------
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("FeralHub/Example")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

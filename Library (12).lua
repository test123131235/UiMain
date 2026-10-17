--[[
    Feral UI Library (Linoria-style API)
    Visual style: Feral Hub. API: CreateWindow / AddTab / AddLeftGroupbox / Toggles / Options.

    Elements: Toggle, Slider, Dropdown (multi), Input, Button (+ sub-buttons), Label, Divider,
              ColorPicker + KeyPicker (attached to Toggles / Labels), Tabboxes, Notifications, Watermark.
]]

local cloneref = cloneref or function(o) return o end

local Players          = cloneref(game:GetService("Players"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService       = cloneref(game:GetService("RunService"))
local HttpService      = cloneref(game:GetService("HttpService"))
local TweenService     = cloneref(game:GetService("TweenService"))
local CoreGui          = cloneref(game:GetService("CoreGui"))

local env = (getgenv and getgenv()) or _G

if env.FeralLibrary and env.FeralLibrary.Unload then
    pcall(function() env.FeralLibrary:Unload() end)
end

local Toggles = {}
local Options = {}
env.Toggles = Toggles
env.Options = Options

local Library = {
    Directory   = "FeralHub",
    Toggles     = Toggles,
    Options     = Options,
    Registry    = {},
    Connections = {},
    KeyPickers  = {},
    UnloadCallbacks = {},
    Unloaded    = false,
    Toggled     = true,
    ToggleKeybind = nil, -- set to an Options key picker (e.g. Options.MenuKeybind). Default key: RightShift
    Popup       = nil,
    Window      = nil,

    Accent     = Color3.fromRGB(0, 131, 255),
    AccentDark = Color3.fromRGB(0, 63, 255),
    Theme = {
        Window        = Color3.fromRGB(21, 21, 22),
        Group         = Color3.fromRGB(24, 24, 26),
        Element       = Color3.fromRGB(28, 28, 30),
        Outline       = Color3.fromRGB(40, 40, 40),
        WindowOutline = Color3.fromRGB(61, 61, 61),
        Text          = Color3.fromRGB(255, 255, 255),
        Dim           = Color3.fromRGB(150, 150, 150),
    },
}
env.FeralLibrary = Library

local Theme = Library.Theme
local MB1, MB2, MB3 = Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3

----------------------------------------------------------------------
-- Filesystem / fonts
----------------------------------------------------------------------
local function SafeFolder(path)
    pcall(function()
        if makefolder and isfolder and not isfolder(path) then makefolder(path) end
    end)
end
SafeFolder(Library.Directory)
SafeFolder(Library.Directory .. "/Assets")

local function LoadFont(name, url, fallbackWeight)
    local ok, font = pcall(function()
        local dir = Library.Directory .. "/Assets"
        local ttf = dir .. "/" .. name .. ".ttf"
        if not isfile(ttf) then writefile(ttf, game:HttpGet(url)) end
        local json = dir .. "/" .. name .. ".font"
        writefile(json, HttpService:JSONEncode({
            name = name,
            faces = { { name = name, weight = 400, style = "Regular", assetId = getcustomasset(ttf) } },
        }))
        return Font.new(getcustomasset(json))
    end)
    if ok and font then return font end
    return Font.new("rbxasset://fonts/families/GothamSSm.json", fallbackWeight)
end

Library.Font     = LoadFont("InterMedium", "https://github.com/ilxypp/assets/raw/refs/heads/main/InterMedium.ttf", Enum.FontWeight.Medium)
Library.FontBold = LoadFont("InterBold",   "https://github.com/ilxypp/assets/raw/refs/heads/main/InterBold.ttf",   Enum.FontWeight.Bold)

----------------------------------------------------------------------
-- Core helpers
----------------------------------------------------------------------
local function New(class, props, parent)
    local inst = Instance.new(class)
    if inst:IsA("GuiObject") then inst.BorderSizePixel = 0 end
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function Corner(parent, r) return New("UICorner", { CornerRadius = UDim.new(0, r or 5) }, parent) end
local function Stroke(parent, color)
    return New("UIStroke", { Color = color or Theme.Outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end
local function Padding(parent, t, r, b, l)
    return New("UIPadding", {
        PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0), PaddingLeft = UDim.new(0, l or 0),
    }, parent)
end
local function List(parent, pad, extra)
    local l = New("UIListLayout", { Padding = UDim.new(0, pad or 0), SortOrder = Enum.SortOrder.LayoutOrder }, parent)
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
end
local function Label(parent, props)
    local p = {
        BackgroundTransparency = 1, FontFace = Library.Font, TextColor3 = Theme.Text,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    }
    for k, v in pairs(props or {}) do p[k] = v end
    return New("TextLabel", p, parent)
end

function Library:Bind(inst, prop, fn)
    inst[prop] = fn()
    table.insert(self.Registry, { inst, prop, fn })
end

function Library:Refresh()
    for _, r in ipairs(self.Registry) do
        if r[1].Parent then r[1][r[2]] = r[3]() end
    end
end

function Library:SetAccent(a, b)
    self.Accent = a
    self.AccentDark = b or Color3.new(math.max(a.R - 0.27, 0), math.max(a.G - 0.27, 0), math.max(a.B - 0.27, 0))
    self:Refresh()
end

local function AccentGradient(parent, rotation)
    local g = New("UIGradient", { Rotation = rotation or 0 }, parent)
    Library:Bind(g, "Color", function() return ColorSequence.new(Library.Accent, Library.AccentDark) end)
    return g
end

function Library:Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self.Connections, c)
    return c
end
Library.GiveSignal = Library.Connect

function Library:SafeCallback(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[FeralLib] callback error: " .. tostring(err)) end
end

local function Fire(obj)
    Library:SafeCallback(obj.Callback, obj.Value)
    for _, fn in ipairs(obj.Changed) do Library:SafeCallback(fn, obj.Value) end
end

local function Tween(inst, props, t)
    local tw = TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function MouseOver(gui)
    if not gui or not gui.Parent then return false end
    local m = UserInputService:GetMouseLocation()
    local p, s = gui.AbsolutePosition, gui.AbsoluteSize
    return m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
end

local function InputName(i)
    if i.UserInputType == Enum.UserInputType.Keyboard then return i.KeyCode.Name
    elseif i.UserInputType == MB1 then return "MB1"
    elseif i.UserInputType == MB2 then return "MB2"
    elseif i.UserInputType == MB3 then return "MB3" end
end

function Library:OnUnload(fn) table.insert(self.UnloadCallbacks, fn) end

----------------------------------------------------------------------
-- Root GUI
----------------------------------------------------------------------
local function RandomName()
    local s = ""
    for _ = 1, 12 do s = s .. string.char(math.random(97, 122)) end
    return s
end

local Holder = New("ScreenGui", {
    Name = RandomName(), ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999,
})
do
    local ok = pcall(function() Holder.Parent = (gethui and gethui()) or CoreGui end)
    if not ok or not Holder.Parent then Holder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
    if syn and syn.protect_gui then pcall(syn.protect_gui, Holder) end
end
Library.Holder = Holder

----------------------------------------------------------------------
-- Popups (dropdown lists, colour pickers)
----------------------------------------------------------------------
function Library:OpenPopup(p)
    self:ClosePopup()
    self.Popup = p
    if p.Reposition then p.Reposition() end
    p.Frame.Visible = true
    if p.Reposition then p.Conn = RunService.RenderStepped:Connect(p.Reposition) end
end

function Library:ClosePopup()
    local p = self.Popup
    if not p then return end
    self.Popup = nil
    if p.Conn then p.Conn:Disconnect() end
    p.Frame.Visible = false
    if p.OnClose then p.OnClose() end
end

Library:Connect(UserInputService.InputBegan, function(input)
    if input.UserInputType == MB1 and Library.Popup then
        local p = Library.Popup
        if not MouseOver(p.Frame) and not (p.Anchor and MouseOver(p.Anchor)) then Library:ClosePopup() end
    end
end)

----------------------------------------------------------------------
-- Tooltips
----------------------------------------------------------------------
local TipFrame = New("Frame", {
    BackgroundColor3 = Theme.Window, AutomaticSize = Enum.AutomaticSize.XY,
    Size = UDim2.fromOffset(0, 0), Visible = false, ZIndex = 300,
}, Holder)
Corner(TipFrame, 4); Stroke(TipFrame, Theme.WindowOutline); Padding(TipFrame, 4, 6, 4, 6)
local TipLabel = Label(TipFrame, { AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), TextSize = 12 })

Library:Connect(RunService.RenderStepped, function()
    if TipFrame.Visible then
        local m = UserInputService:GetMouseLocation()
        TipFrame.Position = UDim2.fromOffset(m.X + 14, m.Y + 14)
    end
end)

function Library:AddTooltip(inst, text)
    if not text then return end
    self:Connect(inst.MouseEnter, function() TipLabel.Text = text; TipFrame.Visible = true end)
    self:Connect(inst.MouseLeave, function() TipFrame.Visible = false end)
end

----------------------------------------------------------------------
-- Notifications & watermark
----------------------------------------------------------------------
local NotifBox = New("Frame", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 40), Size = UDim2.new(0, 320, 1, -60), ZIndex = 250,
}, Holder)
List(NotifBox, 6)

function Library:Notify(text, time)
    time = time or 4
    local wrap = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), ClipsDescendants = true }, NotifBox)
    local inner = New("Frame", {
        BackgroundColor3 = Theme.Window, AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(-1, -20, 0, 0),
    }, wrap)
    Corner(inner, 5); Stroke(inner, Theme.WindowOutline)
    local bar = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0, 3, 1, 0) }, inner)
    Corner(bar, 5); AccentGradient(bar, 90)
    Label(inner, {
        Text = tostring(text), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        Position = UDim2.fromOffset(12, 0),
    })
    Padding(inner, 0, 10, 0, 0)
    Tween(inner, { Position = UDim2.new(0, 0, 0, 0) }, 0.3)
    task.delay(time, function()
        if not inner.Parent then return end
        local tw = Tween(inner, { Position = UDim2.new(-1, -20, 0, 0) }, 0.3)
        tw.Completed:Wait()
        wrap:Destroy()
    end)
end

local Watermark
function Library:SetWatermark(text)
    if not Watermark then
        Watermark = New("Frame", {
            BackgroundColor3 = Theme.Window, AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 26), Position = UDim2.fromOffset(12, 10), ZIndex = 240,
        }, Holder)
        Corner(Watermark, 6); Stroke(Watermark, Theme.WindowOutline); Padding(Watermark, 0, 10, 0, 10)
        Watermark.Accent = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 2), Position = UDim2.fromOffset(0, 0) }, Watermark)
        AccentGradient(Watermark.Accent, 0)
        Watermark.Text = Label(Watermark, {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), FontFace = Library.FontBold,
        })
    end
    Watermark.Text.Text = tostring(text)
end
function Library:SetWatermarkVisibility(v)
    if Watermark then Watermark.Visible = v end
end

----------------------------------------------------------------------
-- Colour picker
----------------------------------------------------------------------
function Library:MakeColorPicker(Idx, Info, box)
    Info = Info or {}
    local CP = {
        Type = "ColorPicker", Value = Info.Default or Color3.new(1, 1, 1), Transparency = 0,
        Title = Info.Title, Callback = Info.Callback, Changed = {},
    }
    local h, s, v = CP.Value:ToHSV()

    local swatch = New("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundColor3 = CP.Value, Size = UDim2.fromOffset(20, 14), LayoutOrder = 2,
    }, box)
    Corner(swatch, 4); Stroke(swatch)

    local popup = New("Frame", {
        BackgroundColor3 = Theme.Window, Size = UDim2.fromOffset(168, 154), Visible = false, ZIndex = 100,
    }, Holder)
    Corner(popup, 8); Stroke(popup, Theme.WindowOutline)

    local sv = New("Frame", { BackgroundColor3 = Color3.fromHSV(h, 1, 1), Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(130, 110) }, popup)
    Corner(sv, 4)
    local white = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1) }, sv)
    Corner(white, 4)
    New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, white)
    local black = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1) }, sv)
    Corner(black, 4)
    New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, black)
    local svMarker = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5) }, sv)
    Corner(svMarker, 8); Stroke(svMarker, Color3.new(0, 0, 0))

    local hue = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(146, 8), Size = UDim2.fromOffset(14, 110) }, popup)
    Corner(hue, 4)
    local keys = {}
    for i = 0, 6 do table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))) end
    New("UIGradient", { Rotation = 90, Color = ColorSequence.new(keys) }, hue)
    local hueMarker = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 4, 0, 3), AnchorPoint = Vector2.new(0.5, 0.5) }, hue)
    Stroke(hueMarker, Color3.new(0, 0, 0))

    local hex = New("TextBox", {
        BackgroundColor3 = Theme.Element, FontFace = Library.Font, TextColor3 = Theme.Text, TextSize = 12,
        ClearTextOnFocus = false, Position = UDim2.fromOffset(8, 126), Size = UDim2.fromOffset(152, 20), Text = "",
    }, popup)
    Corner(hex, 4); Stroke(hex)

    local function Update(silent)
        local c = Color3.fromHSV(h, s, v)
        CP.Value = c
        swatch.BackgroundColor3 = c
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svMarker.Position = UDim2.fromScale(s, 1 - v)
        hueMarker.Position = UDim2.fromScale(0.5, h)
        hex.Text = "#" .. c:ToHex()
        if not silent then Fire(CP) end
    end

    local svDrag, hueDrag = false, false
    local function UpdateFromMouse()
        local m = UserInputService:GetMouseLocation()
        if svDrag then
            local p, sz = sv.AbsolutePosition, sv.AbsoluteSize
            s = math.clamp((m.X - p.X) / sz.X, 0, 1)
            v = 1 - math.clamp((m.Y - p.Y) / sz.Y, 0, 1)
            Update()
        elseif hueDrag then
            local p, sz = hue.AbsolutePosition, hue.AbsoluteSize
            h = math.clamp((m.Y - p.Y) / sz.Y, 0, 1)
            Update()
        end
    end
    Library:Connect(sv.InputBegan, function(i) if i.UserInputType == MB1 or i.UserInputType == Enum.UserInputType.Touch then svDrag = true; UpdateFromMouse() end end)
    Library:Connect(hue.InputBegan, function(i) if i.UserInputType == MB1 or i.UserInputType == Enum.UserInputType.Touch then hueDrag = true; UpdateFromMouse() end end)
    Library:Connect(UserInputService.InputChanged, function(i)
        if (svDrag or hueDrag) and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then UpdateFromMouse() end
    end)
    Library:Connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == MB1 or i.UserInputType == Enum.UserInputType.Touch then svDrag, hueDrag = false, false end
    end)
    Library:Connect(hex.FocusLost, function()
        local ok, c = pcall(Color3.fromHex, hex.Text)
        if ok and c then h, s, v = c:ToHSV() end
        Update()
    end)

    local popupObj = {
        Frame = popup, Anchor = swatch,
        Reposition = function()
            local p, sz = swatch.AbsolutePosition, swatch.AbsoluteSize
            local vp = workspace.CurrentCamera.ViewportSize
            local x = math.clamp(p.X + sz.X - 168, 0, math.max(vp.X - 168, 0))
            local y = p.Y + sz.Y + 4
            if y + 154 > vp.Y then y = p.Y - 158 end
            popup.Position = UDim2.fromOffset(x, y)
        end,
    }
    Library:Connect(swatch.MouseButton1Click, function()
        if Library.Popup == popupObj then Library:ClosePopup() else Library:OpenPopup(popupObj) end
    end)

    function CP:SetValueRGB(c) h, s, v = c:ToHSV(); Update() end
    function CP:SetValue(val)
        if typeof(val) == "Color3" then h, s, v = val:ToHSV()
        elseif type(val) == "table" then h, s, v = val[1], val[2], val[3] end
        Update()
    end
    function CP:OnChanged(fn) table.insert(self.Changed, fn); Library:SafeCallback(fn, self.Value) end

    Update(true)
    Options[Idx] = CP
    return CP
end

----------------------------------------------------------------------
-- Key picker
----------------------------------------------------------------------
local ModeCycle = { Always = "Toggle", Toggle = "Hold", Hold = "Always" }

function Library:MakeKeyPicker(Idx, Info, box, parentToggle)
    Info = Info or {}
    local KP = {
        Type = "KeyPicker", Value = Info.Default or "None", Mode = Info.Mode or "Toggle",
        Toggled = false, Holding = false, Picking = false,
        Callback = Info.Callback, ChangedCallback = Info.ChangedCallback, Changed = {}, Clicked = {},
        Sync = Info.SyncToggleState, ParentToggle = parentToggle,
    }

    local btn = New("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Element, AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 14), LayoutOrder = 1,
    }, box)
    Corner(btn, 4); Stroke(btn); Padding(btn, 0, 5, 0, 5)
    local txt = Label(btn, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center })
    Library:AddTooltip(btn, (Info.Text or "Keybind") .. " - right click to change mode")

    local function Display()
        txt.Text = KP.Picking and "..." or ("[" .. tostring(KP.Value) .. (KP.Mode ~= "Toggle" and (" · " .. KP.Mode) or "") .. "]")
    end

    function KP:GetState()
        if self.Mode == "Always" then return true
        elseif self.Mode == "Hold" then return self.Holding
        else return self.Toggled end
    end

    function KP:Press()
        if self.Mode == "Toggle" then self.Toggled = not self.Toggled
        elseif self.Mode == "Hold" then self.Holding = true end
        self:Notify()
    end
    function KP:Release()
        if self.Mode == "Hold" then self.Holding = false; self:Notify() end
    end
    function KP:Notify()
        local st = self:GetState()
        if self.Sync and self.ParentToggle then self.ParentToggle:SetValue(st) end
        Library:SafeCallback(self.Callback, st)
        for _, fn in ipairs(self.Clicked) do Library:SafeCallback(fn, st) end
    end
    function KP:SetValue(data)
        if type(data) == "table" then
            self.Value = data[1] or data.key or data.Key or self.Value
            self.Mode = data[2] or data.mode or data.Mode or self.Mode
        elseif type(data) == "string" then
            self.Value = data
        end
        Display()
        Library:SafeCallback(self.ChangedCallback, self.Value)
        for _, fn in ipairs(self.Changed) do Library:SafeCallback(fn, self.Value) end
    end
    function KP:OnClick(fn) table.insert(self.Clicked, fn) end
    function KP:OnChanged(fn) table.insert(self.Changed, fn); Library:SafeCallback(fn, self.Value) end

    Library:Connect(btn.MouseButton1Click, function() KP.Picking = true; Display() end)
    Library:Connect(btn.MouseButton2Click, function() KP.Mode = ModeCycle[KP.Mode] or "Toggle"; Display() end)

    Display()
    table.insert(Library.KeyPickers, KP)
    Options[Idx] = KP
    return KP
end

Library:Connect(UserInputService.InputBegan, function(input, gp)
    local name = InputName(input)
    if not name then return end

    for _, kp in ipairs(Library.KeyPickers) do
        if kp.Picking then
            kp.Picking = false
            kp:SetValue({ name == "Escape" and "None" or name, kp.Mode })
            return
        end
    end
    if gp then return end

    local tk = Library.ToggleKeybind
    local key = (tk and tk.Value) or "RightShift"
    if name == key and Library.Window then Library.Window:Toggle() end

    for _, kp in ipairs(Library.KeyPickers) do
        if kp.Value == name then kp:Press() end
    end
end)

Library:Connect(UserInputService.InputEnded, function(input)
    local name = InputName(input)
    if not name then return end
    for _, kp in ipairs(Library.KeyPickers) do
        if kp.Value == name then kp:Release() end
    end
end)

----------------------------------------------------------------------
-- Element builders (shared by groupboxes and tabbox tabs)
----------------------------------------------------------------------
local function AttachAddons(target, holder, rightPad, parentToggle)
    local box = New("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -rightPad, 0.5, 0),
        Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
    }, holder)
    List(box, 4, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center })
    function target:AddColorPicker(Idx, Info) return Library:MakeColorPicker(Idx, Info, box) end
    function target:AddKeyPicker(Idx, Info) return Library:MakeKeyPicker(Idx, Info, box, parentToggle) end
end

local function ApplyElements(obj, content)
    local order = 0
    local function Row(height, auto)
        order += 1
        return New("Frame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), LayoutOrder = order,
            AutomaticSize = auto and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        }, content)
    end

    -- Toggle -----------------------------------------------------------
    function obj:AddToggle(Idx, Info)
        Info = Info or {}
        local Toggle = { Type = "Toggle", Value = Info.Default or false, Callback = Info.Callback, Changed = {} }
        local row = Row(18)
        local hit = New("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, row)
        Label(row, { Text = Info.Text or Idx, Size = UDim2.new(1, -40, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })

        local sw = New("Frame", { BackgroundColor3 = Theme.Element, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(30, 14) }, row)
        Corner(sw, 7)
        local swStroke = Stroke(sw)
        local circle = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(10, 10) }, sw)
        Corner(circle, 5)
        Library:Bind(sw, "BackgroundColor3", function() return Toggle.Value and Library.Accent or Theme.Element end)
        Library:Bind(swStroke, "Color", function() return Toggle.Value and Library.AccentDark or Theme.Outline end)

        local function Display()
            Tween(circle, { Position = Toggle.Value and UDim2.new(1, -12, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
            Tween(sw, { BackgroundColor3 = Toggle.Value and Library.Accent or Theme.Element })
            Tween(swStroke, { Color = Toggle.Value and Library.AccentDark or Theme.Outline })
        end
        Display()

        function Toggle:SetValue(v)
            v = not not v
            if v == self.Value then return end
            self.Value = v
            Display()
            Fire(self)
        end
        function Toggle:OnChanged(fn) table.insert(self.Changed, fn); Library:SafeCallback(fn, self.Value) end

        Library:Connect(hit.MouseButton1Click, function() Toggle:SetValue(not Toggle.Value) end)
        Library:AddTooltip(hit, Info.Tooltip)
        AttachAddons(Toggle, row, 36, Toggle)

        Toggles[Idx] = Toggle
        return Toggle
    end

    -- Slider -----------------------------------------------------------
    function obj:AddSlider(Idx, Info)
        Info = Info or {}
        local Slider = {
            Type = "Slider", Min = Info.Min or 0, Max = Info.Max or 100, Rounding = Info.Rounding or 0,
            Value = Info.Default or Info.Min or 0, Callback = Info.Callback, Changed = {},
        }
        local compact = Info.Compact
        local row = Row(compact and 16 or 32)
        local text = Info.Text or Idx
        local suffix, prefix = Info.Suffix or "", Info.Prefix or ""

        if not compact then Label(row, { Text = text, Size = UDim2.new(1, 0, 0, 14) }) end
        local valueLabel
        local bar = New("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Element,
            Position = UDim2.fromOffset(0, compact and 0 or 18), Size = UDim2.new(1, 0, 0, 14),
        }, row)
        Corner(bar, 5); Stroke(bar)
        bar.ClipsDescendants = true
        local fill = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1) }, bar)
        Corner(fill, 5); AccentGradient(fill, 0)
        valueLabel = Label(compact and bar or row, {
            FontFace = Library.FontBold, TextSize = 12,
            Size = compact and UDim2.fromScale(1, 1) or UDim2.new(1, 0, 0, 14),
            TextXAlignment = compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Right,
        })

        local function Display()
            local a = (Slider.Max == Slider.Min) and 0 or (Slider.Value - Slider.Min) / (Slider.Max - Slider.Min)
            Tween(fill, { Size = UDim2.new(a, 0, 1, 0) }, 0.08)
            local str = string.format("%." .. Slider.Rounding .. "f", Slider.Value)
            valueLabel.Text = (compact and (text .. ": ") or "") .. prefix .. str .. suffix
        end
        Display()

        function Slider:SetValue(v)
            v = tonumber(v); if not v then return end
            v = math.clamp(v, self.Min, self.Max)
            local m = 10 ^ self.Rounding
            v = math.floor(v * m + 0.5) / m
            if v == self.Value then return end
            self.Value = v
            Display()
            Fire(self)
        end
        function Slider:SetMax(n) self.Max = n; self:SetValue(self.Value); Display() end
        function Slider:SetMin(n) self.Min = n; self:SetValue(self.Value); Display() end
        function Slider:OnChanged(fn) table.insert(self.Changed, fn); Library:SafeCallback(fn, self.Value) end

        local dragging = false
        local function FromMouse()
            local m = UserInputService:GetMouseLocation()
            local a = math.clamp((m.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            Slider:SetValue(Slider.Min + a * (Slider.Max - Slider.Min))
        end
        Library:Connect(bar.InputBegan, function(i)
            if i.UserInputType == MB1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; FromMouse() end
        end)
        Library:Connect(UserInputService.InputChanged, function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then FromMouse() end
        end)
        Library:Connect(UserInputService.InputEnded, function(i)
            if i.UserInputType == MB1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        Library:AddTooltip(bar, Info.Tooltip)

        Options[Idx] = Slider
        return Slider
    end

    -- Dropdown ---------------------------------------------------------
    function obj:AddDropdown(Idx, Info)
        Info = Info or {}
        local D = {
            Type = "Dropdown", Values = Info.Values or {}, Multi = Info.Multi, AllowNull = Info.AllowNull,
            Callback = Info.Callback, Changed = {}, Value = Info.Multi and {} or nil,
        }
        local row = Row(Info.Text and 40 or 24)
        if Info.Text then Label(row, { Text = Info.Text, Size = UDim2.new(1, 0, 0, 14) }) end
        local pill = New("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Element,
            Position = UDim2.fromOffset(0, Info.Text and 18 or 0), Size = UDim2.new(1, 0, 0, 22),
        }, row)
        Corner(pill, 5); Stroke(pill)
        local shown = Label(pill, { Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -30, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
        local arrow = New("ImageLabel", {
            BackgroundTransparency = 1, Image = "rbxassetid://116827751679514", AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(14, 14),
        }, pill)

        local popup = New("Frame", { BackgroundColor3 = Theme.Window, Visible = false, ZIndex = 100 }, Holder)
        Corner(popup, 6); Stroke(popup, Theme.WindowOutline)
        local scroll = New("ScrollingFrame", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScrollBarThickness = 2,
            ScrollBarImageColor3 = Library.Accent, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        }, popup)
        Padding(scroll, 4, 4, 4, 4); List(scroll, 2)

        local items = {}
        local function Selected(v)
            if D.Multi then return D.Value[v] == true end
            return D.Value == v
        end
        local function Display()
            if D.Multi then
                local t = {}
                for _, v in ipairs(D.Values) do if D.Value[v] then t[#t + 1] = v end end
                shown.Text = #t > 0 and table.concat(t, ", ") or "--"
            else
                shown.Text = D.Value and tostring(D.Value) or "--"
            end
            for v, it in pairs(items) do
                local sel = Selected(v)
                it.TextColor3 = sel and Library.Accent or Theme.Text
                it.FontFace = sel and Library.FontBold or Library.Font
            end
        end

        local popupObj = {
            Frame = popup, Anchor = pill,
            Reposition = function()
                local p, sz = pill.AbsolutePosition, pill.AbsoluteSize
                popup.Size = UDim2.fromOffset(sz.X, math.min(#D.Values, 7) * 24 + 8)
                popup.Position = UDim2.fromOffset(p.X, p.Y + sz.Y + 3)
            end,
            OnClose = function() Tween(arrow, { Rotation = 0 }) end,
        }

        local function Build()
            for _, c in pairs(scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            items = {}
            for i, v in ipairs(D.Values) do
                local it = New("TextButton", {
                    Text = tostring(v), AutoButtonColor = false, BackgroundTransparency = 1, FontFace = Library.Font,
                    TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i,
                }, scroll)
                Padding(it, 0, 0, 0, 4)
                Library:Connect(it.MouseEnter, function() it.BackgroundTransparency = 0.85 end)
                Library:Connect(it.MouseLeave, function() it.BackgroundTransparency = 1 end)
                Library:Connect(it.MouseButton1Click, function()
                    if D.Multi then
                        D.Value[v] = (not D.Value[v]) or nil
                    else
                        if D.Value == v and D.AllowNull then D.Value = nil else D.Value = v end
                        Library:ClosePopup()
                    end
                    Display(); Fire(D)
                end)
                items[v] = it
            end
            Display()
        end

        local function Resolve(def)
            if def == nil then return end
            if D.Multi then
                if type(def) == "table" then
                    for k, val in pairs(def) do
                        if type(k) == "number" then
                            local name = type(val) == "number" and D.Values[val] or val
                            if name then D.Value[name] = true end
                        elseif val then D.Value[k] = true end
                    end
                else
                    local name = type(def) == "number" and D.Values[def] or def
                    if name then D.Value[name] = true end
                end
            else
                D.Value = type(def) == "number" and D.Values[def] or def
            end
        end
        Resolve(Info.Default)
        Build()

        function D:SetValue(val)
            if self.Multi then
                self.Value = {}
                if type(val) == "table" then
                    for k, x in pairs(val) do
                        if type(k) == "number" then self.Value[x] = true elseif x then self.Value[k] = true end
                    end
                end
            else
                self.Value = val
            end
            Display(); Fire(self)
        end
        function D:SetValues(vals)
            self.Values = vals
            if self.Multi then
                local keep = {}
                for _, v in ipairs(vals) do if self.Value[v] then keep[v] = true end end
                self.Value = keep
            elseif self.Value ~= nil and not table.find(vals, self.Value) then
                self.Value = nil
            end
            Build()
        end
        function D:GetActiveValues()
            if not self.Multi then return self.Value and { self.Value } or {} end
            local t = {}
            for k in pairs(self.Value) do t[#t + 1] = k end
            return t
        end
        function D:OnChanged(fn) table.insert(self.Changed, fn); Library:SafeCallback(fn, self.Value) end

        Library:Connect(pill.MouseButton1Click, function()
            if Library.Popup == popupObj then Library:ClosePopup()
            else Library:OpenPopup(popupObj); Tween(arrow, { Rotation = 180 }) end
        end)
        Library:AddTooltip(pill, Info.Tooltip)

        Options[Idx] = D
        return D
    end

    -- Input ------------------------------------------------------------
    function obj:AddInput(Idx, Info)
        Info = Info or {}
        local I = { Type = "Input", Value = Info.Default or "", Callback = Info.Callback, Changed = {}, Numeric = Info.Numeric }
        local row = Row(Info.Text and 42 or 24)
        if Info.Text then Label(row, { Text = Info.Text, Size = UDim2.new(1, 0, 0, 14) }) end
        local box = New("TextBox", {
            BackgroundColor3 = Theme.Element, FontFace = Library.Font, TextSize = 13, TextColor3 = Theme.Text,
            PlaceholderText = Info.Placeholder or "", PlaceholderColor3 = Theme.Dim, ClearTextOnFocus = Info.ClearTextOnFocus or false,
            TextXAlignment = Enum.TextXAlignment.Left, Text = I.Value,
            Position = UDim2.fromOffset(0, Info.Text and 18 or 0), Size = UDim2.new(1, 0, 0, 22),
        }, row)
        Corner(box, 5); Stroke(box); Padding(box, 0, 6, 0, 6)
        box.ClipsDescendants = true

        function I:SetValue(v)
            v = tostring(v or "")
            if self.Numeric and tonumber(v) == nil and v ~= "" then v = self.Value end
            self.Value = v
            box.Text = v
            Fire(self)
        end
        function I:OnChanged(fn) table.insert(self.Changed, fn); Library:SafeCallback(fn, self.Value) end

        if Info.Finished then
            Library:Connect(box.FocusLost, function(enter) if enter then I:SetValue(box.Text) end end)
        else
            Library:Connect(box:GetPropertyChangedSignal("Text"), function()
                if I.Numeric and box.Text ~= "" and tonumber(box.Text) == nil and box.Text ~= "-" and box.Text ~= "." then
                    box.Text = I.Value; return
                end
                if box.Text ~= I.Value then I.Value = box.Text; Fire(I) end
            end)
        end
        Library:AddTooltip(box, Info.Tooltip)

        Options[Idx] = I
        return I
    end

    -- Button -----------------------------------------------------------
    function obj:AddButton(Info, Func)
        if type(Info) == "string" then Info = { Text = Info, Func = Func } end
        local row = Row(22)
        local list = {}
        local pad = 5

        local function Relayout()
            local n = #list
            for i, b in ipairs(list) do
                b.Instance.Size = UDim2.new(1 / n, -pad * (n - 1) / n, 1, 0)
                b.Instance.Position = UDim2.new((i - 1) / n, (i - 1) * pad / n, 0, 0)
            end
        end

        local function Make(inf)
            local B = { Text = inf.Text or "Button", Func = inf.Func or inf.Callback, DoubleClick = inf.DoubleClick }
            local btn = New("TextButton", {
                Text = B.Text, AutoButtonColor = false, BackgroundColor3 = Theme.Element, FontFace = Library.FontBold,
                TextSize = 13, TextColor3 = Theme.Text,
            }, row)
            Corner(btn, 5); Stroke(btn)
            B.Instance = btn
            Library:Connect(btn.MouseEnter, function() Tween(btn, { BackgroundColor3 = Color3.fromRGB(38, 38, 41) }) end)
            Library:Connect(btn.MouseLeave, function() Tween(btn, { BackgroundColor3 = Theme.Element }) end)
            local armed = false
            Library:Connect(btn.MouseButton1Click, function()
                if B.DoubleClick then
                    if not armed then
                        armed = true; btn.Text = "Click again to confirm"
                        task.delay(2, function() armed = false; if btn.Parent then btn.Text = B.Text end end)
                        return
                    end
                    armed = false; btn.Text = B.Text
                end
                Library:SafeCallback(B.Func)
            end)
            Library:AddTooltip(btn, inf.Tooltip)
            function B:SetText(t) self.Text = t; btn.Text = t end
            function B:AddButton(inf2, f2)
                if type(inf2) == "string" then inf2 = { Text = inf2, Func = f2 } end
                local nb = Make(inf2)
                return nb
            end
            table.insert(list, B)
            Relayout()
            return B
        end
        return Make(Info)
    end

    -- Label / Divider / Blank -----------------------------------------
    function obj:AddLabel(text, wrap)
        local L = {}
        local row = Row(16, wrap)
        local lbl = Label(row, {
            Text = tostring(text), Size = wrap and UDim2.new(1, 0, 0, 16) or UDim2.new(1, -50, 1, 0),
            TextWrapped = wrap or false, AutomaticSize = wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
            TextTruncate = wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
        })
        L.TextLabel = lbl
        function L:SetText(t) lbl.Text = tostring(t) end
        AttachAddons(L, row, 0, nil)
        return L
    end

    function obj:AddDivider()
        local row = Row(8)
        New("Frame", { BackgroundColor3 = Theme.Outline, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1) }, row)
    end

    function obj:AddBlank(size) Row(size or 6) end
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function Library:CreateWindow(Config)
    Config = Config or {}
    local Window = { Tabs = {}, Visible = false }
    Library.Window = Window

    local center = Config.Center ~= false
    local Main = New("Frame", {
        Name = "Window", BackgroundColor3 = Theme.Window, Size = Config.Size or UDim2.fromOffset(650, 450),
        AnchorPoint = center and Vector2.new(0.5, 0.5) or Vector2.new(0, 0),
        Position = center and UDim2.fromScale(0.5, 0.5) or UDim2.fromOffset(100, 100),
        Visible = false,
    }, Holder)
    Corner(Main, 10)
    Stroke(Main, Theme.WindowOutline)

    local Modal = New("TextButton", { Text = "", BackgroundTransparency = 1, Modal = false, Size = UDim2.new(), Visible = true }, Main)

    -- top bar
    local Top = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58) }, Main)
    Padding(Top, 6, 8, 6, 8)
    local pill = New("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
    }, Top)
    Corner(pill, 6); Stroke(pill, Color3.fromRGB(41, 41, 41)); AccentGradient(pill, 90)
    Padding(pill, 0, 14, 0, 10)
    List(pill, 8, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center })
    if Config.Logo then
        New("ImageLabel", { BackgroundTransparency = 1, Image = Config.Logo, Size = UDim2.fromOffset(32, 32), LayoutOrder = 1 }, pill)
    end
    local titles = New("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2 }, pill)
    List(titles, 0, { VerticalAlignment = Enum.VerticalAlignment.Center })
    Label(titles, { Text = Config.Title or "Feral Hub", FontFace = Library.FontBold, TextSize = 16, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 18), LayoutOrder = 1 })
    if Config.SubTitle then
        Label(titles, { Text = Config.SubTitle, FontFace = Library.FontBold, TextSize = 13, TextTransparency = 0.15, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 15), LayoutOrder = 2 })
    end
    local div = New("Frame", { BackgroundColor3 = Theme.Outline, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1) }, Main)
    div.Position = UDim2.new(0, 0, 0, 58)
    div.AnchorPoint = Vector2.new(0, 0)

    -- drag
    do
        local dragging, dragStart, startPos
        Library:Connect(Top.InputBegan, function(i)
            if i.UserInputType == MB1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, i.Position, Main.Position
            end
        end)
        Library:Connect(UserInputService.InputChanged, function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - dragStart
                Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        Library:Connect(UserInputService.InputEnded, function(i)
            if i.UserInputType == MB1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
    end

    -- body
    local Body = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 59), Size = UDim2.new(1, 0, 1, -59) }, Main)
    local Side = New("ScrollingFrame", {
        BackgroundTransparency = 1, Size = UDim2.new(0, 150, 1, 0), ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    }, Body)
    Padding(Side, 10, 10, 10, 10); List(Side, Config.TabPadding or 5)
    local sideLine = New("Frame", { BackgroundColor3 = Theme.Outline, Position = UDim2.new(0, 150, 0, 0), Size = UDim2.new(0, 1, 1, 0) }, Body)
    local Content = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(151, 0), Size = UDim2.new(1, -151, 1, 0) }, Body)
    Padding(Content, 8, 8, 8, 8)

    function Window:SetVisible(v)
        self.Visible = v
        Library.Toggled = v
        Main.Visible = v
        Modal.Modal = v
        if not v then Library:ClosePopup() end
    end
    function Window:Toggle() self:SetVisible(not self.Visible) end
    function Library:Toggle() Window:Toggle() end
    function Window:SetTitle() end

    function Window:AddTab(Name, Icon)
        local Tab = { Name = Name, Selected = false }

        local btn = New("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(25, 25, 27),
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = #Window.Tabs + 1,
        }, Side)
        Corner(btn, 5)
        local mark = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0, 3, 0.6, 0), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundTransparency = 1 }, btn)
        Corner(mark, 3); AccentGradient(mark, 90)
        local textOffset = 12
        if Icon then
            New("ImageLabel", { BackgroundTransparency = 1, Image = Icon, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0, 10, 0.5, -10) }, btn)
            textOffset = 38
        end
        local lbl = Label(btn, { Text = Name, FontFace = Library.FontBold, TextSize = 14, TextColor3 = Theme.Dim, Position = UDim2.fromOffset(textOffset, 0), Size = UDim2.new(1, -textOffset, 1, 0) })

        local page = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, Content)
        local function Column(left)
            local sc = New("ScrollingFrame", {
                BackgroundTransparency = 1, ScrollBarThickness = 2, ScrollBarImageColor3 = Library.Accent,
                AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
                Position = left and UDim2.new() or UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0),
            }, page)
            Padding(sc, 1, 4, 1, 1); List(sc, 8)
            return sc
        end
        local leftCol, rightCol = Column(true), Column(false)

        local function Groupbox(col, name)
            local G = {}
            local frame = New("Frame", { BackgroundColor3 = Theme.Group, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = #col:GetChildren() }, col)
            Corner(frame, 5); Stroke(frame)
            List(frame, 0)
            local head = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1 }, frame)
            Corner(head, 5); AccentGradient(head, 0)
            Label(head, { Text = name, FontFace = Library.FontBold, TextSize = 13, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
            local content = New("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 }, frame)
            Padding(content, 6, 6, 6, 6); List(content, 6)
            G.Container = content
            ApplyElements(G, content)
            return G
        end

        local function Tabbox(col)
            local T = { Tabs = {} }
            local frame = New("Frame", { BackgroundColor3 = Theme.Group, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = #col:GetChildren() }, col)
            Corner(frame, 5); Stroke(frame); List(frame, 0)
            local bar = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1 }, frame)
            local body = New("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 }, frame)
            List(body, 0)

            function T:AddTab(tname)
                local TT = {}
                local b = New("TextButton", { Text = tname, AutoButtonColor = false, BackgroundTransparency = 1, FontFace = Library.FontBold, TextSize = 13, TextColor3 = Theme.Dim }, bar)
                local ul = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), Visible = false }, b)
                AccentGradient(ul, 0)
                local c = New("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Visible = false }, body)
                Padding(c, 6, 6, 6, 6); List(c, 6)
                TT.Container = c
                ApplyElements(TT, c)

                function TT:Show()
                    for _, o in ipairs(T.Tabs) do o:Hide() end
                    c.Visible = true; ul.Visible = true; b.TextColor3 = Theme.Text
                end
                function TT:Hide() c.Visible = false; ul.Visible = false; b.TextColor3 = Theme.Dim end
                Library:Connect(b.MouseButton1Click, function() TT:Show() end)

                table.insert(T.Tabs, TT)
                for i, o in ipairs(T.Tabs) do
                    -- every button is resized evenly
                end
                local n = #T.Tabs
                for i, child in ipairs(bar:GetChildren()) do
                    if child:IsA("TextButton") then
                        child.Size = UDim2.new(1 / n, 0, 1, 0)
                        child.Position = UDim2.new((i - 1) / n, 0, 0, 0)
                    end
                end
                if n == 1 then TT:Show() end
                return TT
            end
            return T
        end

        function Tab:AddLeftGroupbox(n)  return Groupbox(leftCol, n) end
        function Tab:AddRightGroupbox(n) return Groupbox(rightCol, n) end
        function Tab:AddLeftTabbox()     return Tabbox(leftCol) end
        function Tab:AddRightTabbox()    return Tabbox(rightCol) end

        function Tab:Show()
            for _, t in ipairs(Window.Tabs) do if t ~= self then t:Hide() end end
            self.Selected = true
            page.Visible = true
            Tween(btn, { BackgroundTransparency = 0 })
            Tween(mark, { BackgroundTransparency = 0 })
            lbl.TextColor3 = Theme.Text
            Library:ClosePopup()
        end
        function Tab:Hide()
            self.Selected = false
            page.Visible = false
            Tween(btn, { BackgroundTransparency = 1 })
            Tween(mark, { BackgroundTransparency = 1 })
            lbl.TextColor3 = Theme.Dim
        end
        Library:Connect(btn.MouseButton1Click, function() Tab:Show() end)

        table.insert(Window.Tabs, Tab)
        if #Window.Tabs == 1 then Tab:Show() end
        return Tab
    end

    if Config.AutoShow ~= false then Window:SetVisible(true) end
    return Window
end

----------------------------------------------------------------------
-- Unload
----------------------------------------------------------------------
function Library:Unload()
    self.Unloaded = true
    for _, fn in ipairs(self.UnloadCallbacks) do pcall(fn) end
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    if self.Popup and self.Popup.Conn then self.Popup.Conn:Disconnect() end
    Holder:Destroy()
    env.FeralLibrary = nil
    env.Toggles = nil
    env.Options = nil
end

return Library

--[[
    CinderUI  -  sketch-style Roblox UI library (v4)

    local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/<user>/<repo>/main/UiLib.lua"))()
    local Window  = Library:CreateWindow({ Title = "My Hub", Size = UDim2.fromOffset(700, 500), AutoShow = true })

    ---- Groupbox layout (Linoria / Feral style) -----------------------------------------------------------
    local Tab   = Window:AddTab("Main")
    local Left  = Tab:AddLeftGroupbox("Farming")        -- left column
    local Right = Tab:AddRightGroupbox("Settings")      -- right column
    local Box   = Tab:AddLeftTabbox()                   -- one box, several tabs
    local T1    = Box:AddTab("One")
    local Sub   = Tab:AddSubTab("Extra")                -- row of sub tabs at the top of the tab
    Sub:AddLeftGroupbox("..."), Sub:AddRightGroupbox("...")

    ---- Controls: Idx + Info table (also available as Toggles.Idx / Options.Idx) ------------------------------
    local Farm = Left:AddToggle("Farm", { Text = "Auto Farm", Default = false, Tooltip = "...", Callback = function(v) end })
    Farm:AddColorPicker("FarmColor", { Default = Color3.new(1,1,1) })          -- swatch on the toggle row
    Farm:AddKeyPicker("FarmKey", { Default = "F", Mode = "Toggle", Text = "Farm", SyncToggleState = true })   -- right click = change mode
    Left:AddSlider("Speed", { Text = "Speed", Min = 0, Max = 100, Default = 50, Rounding = 0, Suffix = " st" })
    Left:AddDropdown("Mode", { Text = "Mode", Values = { "A", "B" }, Default = 1, Multi = false })   -- Multi = true -> value is { [name] = true }
    Left:AddInput("Name", { Text = "Name", Default = "", Placeholder = "...", Numeric = false })
    Left:AddButton("Go", function() end):AddButton("Second", function() end)   -- sub buttons share the row
    Left:AddLabel("text", true):AddColorPicker("LabelColor", { Default = Color3.new(1,1,1) })
    Left:AddDivider()
    Toggles.Farm.Value / :SetValue(v) / :OnChanged(fn)      Options.Speed.Value / :SetValue(v)
    Options.Mode:SetValues({ ... })      Options.FarmKey.Value / .Mode / :GetState() / :OnClick(fn)

    ---- Table API (also supported) ---------------------------------------------
    Tab:AddToggle{ key, label, default, callback }    Tab:AddSlider{ key, label, min, max, step, default, suffix, callback }
    Tab:AddDropdown{ key, label, options, default, callback }
    Tab:AddInput{ key, label, default, placeholder, numeric }   Tab:AddColorPicker{ key, label, default }
    Tab:AddKeybind{ key, label, default, onPress }   Tab:AddButton{ label, callback, colour }   Tab:AddSection / AddLabel / AddDivider
    Extra field on any control:  save = false -> not stored in configs    path = "A.B.C" -> where it is mirrored inside opts.Target

    Window:  Get, Set, SetMany, Values, ApplyTo, OnChange, SetOptions, GetOptions, RunCallbacks, Open, Close, Toggle, IsOpen,
             SetTitle, SetToggleIcon, SetVisible, Notify, SelectTab, GetTab, Destroy
    Open/close square:  CreateWindow{ ToggleIcon = "rbxassetid://123" } (or ToggleImage / just the number)  -> picture instead of the letter;
                        ToggleIconBackground = false removes the dark square behind it;  Window:SetToggleIcon(nil) goes back to text
    Library: Unload, OnUnload, Notify, ToggleKeybind, CreateStats

    ---- Stats panels (pop-out windows with  label ..... value  rows) -----------------------------------
    local Stats = Library:CreateStats({ Title = "Killer", Color = Color3.fromRGB(240, 190, 40), Width = 270,
        Rows = { { key = "uptime", label = "Uptime", clock = true }, { key = "kills", label = "Kills", color = Color3.fromRGB(255,132,226) } } })
    Stats:AddStat("deaths", "Deaths", { Color = Color3.fromRGB(255,90,90) })      -- add rows any time
    Stats:Set("kills", 5)  Stats:Increment("kills")  Stats:Get("kills")  Stats:Reset()  Stats:SetMany({ kills = 1 })
    Stats:SetTitle("x")  Stats:SetHeaderColor(c)  Stats:SetColor(key, c)  Stats:SetLabel(key, "x")  Stats:SetVisible(b)  Stats:Toggle()
    Stats:SetCollapsed(b)  Stats:SetPosition(UDim2, anchor)  Stats:Poll(key, seconds, function() return value end)  Stats:Destroy()
    Row format: "number" (default, 1,234) | "clock" (1:51) | "text" | function(value) -> string. Drag the header; click it to collapse. (= an Options key picker that opens/closes the menu)
]]

local cloneref = cloneref or function(i) return i end

local Players = cloneref(game:GetService("Players"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TextService = cloneref(game:GetService("TextService"))
local LocalPlayer = Players.LocalPlayer

local genv = (getgenv and getgenv()) or _G

--------------------------------------------------------------------------------------------------
-- Library table / theme (edit Library.Theme fields BEFORE CreateWindow to restyle everything)
--------------------------------------------------------------------------------------------------
local Library = {}

Library.FontFace = Font.new("rbxassetid://12187375716", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
Library.TextScale = 1 -- multiplies every text size in the UI (e.g. 1.15 = 15% bigger)
Library.Version = 4

Library.Theme = {
	Background = Color3.fromRGB(18, 14, 14),
	BackgroundTransparency = 0.04,
	Ink = Color3.fromRGB(240, 232, 222),
	Header = Color3.fromRGB(255, 170, 50),
	Label = Color3.fromRGB(245, 245, 240),
	Muted = Color3.fromRGB(175, 168, 160),
	Value = Color3.fromRGB(255, 255, 255),
	Accent = Color3.fromRGB(228, 122, 50),
	On = Color3.fromRGB(140, 230, 160),
	Off = Color3.fromRGB(50, 46, 44),
	Flash = Color3.fromRGB(255, 228, 190),
	Shadow = Color3.fromRGB(0, 0, 0),
	Danger = Color3.fromRGB(235, 51, 90),
	Well = Color3.fromRGB(24, 22, 22),
	List = Color3.fromRGB(22, 18, 18),
	Neutral = Color3.fromRGB(70, 62, 56),
}
local Theme = Library.Theme

Library.Defaults = {
	Title = "Menu",
	Folder = "UiLib",
	Width = 560,
	Height = 430,
	SidebarWidth = 148,
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	TogglePosition = UDim2.new(0, 24, 0.5, 0),
	ToggleSize = 60,
	AlwaysShowLauncher = true, -- launcher square stays visible while the window is open
	ToggleText = nil,
	ToggleIcon = nil, -- picture on the open/close square: "rbxassetid://123" or just 123 (alias: ToggleImage). nil = text
	ToggleIconBackground = true, -- false = no dark square behind the picture (for pictures with their own shape)
	ToggleKeyCode = nil, -- Enum.KeyCode.RightShift
	StartOpen = false,
	Draggable = true,
	Resizable = true,
	MinWidth = 340,
	MinHeight = 150,
	MaxWidth = 900,
	MaxHeight = 600,
	Target = nil, -- table that mirrors every control value (by path)
	DisplayOrder = 14,
	ForceEnglish = true, -- disables Roblox auto-translation (AutoLocalize) on every UI element
}

--------------------------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------------------------
local function create(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		obj[k] = v
	end
	if parent then
		obj.Parent = parent
	end
	return obj
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function randomName()
	local chars = table.create(10)
	for i = 1, 10 do
		chars[i] = string.char(math.random(97, 122))
	end
	return table.concat(chars)
end

local function decimalsOf(step)
	if not step or step <= 0 or step >= 1 then return 0 end
	local d = 0
	while d < 4 and math.abs(step - math.floor(step + 0.5)) > 1e-6 do
		step *= 10
		d += 1
	end
	return d
end

local function snap(value, min, step)
	if not step or step <= 0 then return value end
	local n = math.floor((value - min) / step + 0.5) * step + min
	local d = decimalsOf(step)
	if d == 0 then return n end
	local m = 10 ^ d
	return math.floor(n * m + 0.5) / m
end

local function formatNumber(value, step)
	local d = decimalsOf(step)
	if d == 0 then return tostring(math.floor(value + 0.5)) end
	return string.format("%." .. d .. "f", value)
end

local function splitPath(path)
	local parts = {}
	for p in string.gmatch(tostring(path), "[^%.]+") do
		parts[#parts + 1] = p
	end
	return parts
end

local function getPath(tbl, path)
	for _, p in ipairs(splitPath(path)) do
		if type(tbl) ~= "table" then return nil end
		tbl = tbl[p]
	end
	return tbl
end

local function setPath(tbl, path, value)
	local parts = splitPath(path)
	for i = 1, #parts - 1 do
		local nxt = tbl[parts[i]]
		if type(nxt) ~= "table" then
			nxt = {}
			tbl[parts[i]] = nxt
		end
		tbl = nxt
	end
	tbl[parts[#parts]] = value
end

local function getGuiParent()
	local ok, res = pcall(function() return gethui and gethui() or nil end)
	if ok and typeof(res) == "Instance" then return res, true end
	local ok2, core = pcall(function() return cloneref(game:GetService("CoreGui")) end)
	if ok2 and core then return core, true end
	return LocalPlayer:WaitForChild("PlayerGui"), false
end

local function protect(gui)
	pcall(function()
		if syn and syn.protect_gui then syn.protect_gui(gui)
		elseif protect_gui then protect_gui(gui) end
	end)
end

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- visuals --------------------------------------------------------------------------------------
local function textLabel(text, size, align)
	local l = create("TextLabel", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Text = tostring(text), AutoLocalize = false,
		FontFace = Library.FontFace, TextSize = math.floor((size or 15) * (Library.TextScale or 1) + 0.5), TextColor3 = Theme.Label,
		TextXAlignment = align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
	})
	create("UIStroke", { Color = Theme.Shadow, Thickness = 1.5, Transparency = 0.35, LineJoinMode = Enum.LineJoinMode.Round }, l)
	return l
end

local function sketchEdge(parent, color, thickness, transparency, rotation, pad, z)
	local f = create("Frame", {
		Name = "SketchEdge", BackgroundTransparency = 1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, pad, 1, pad), Rotation = rotation, ZIndex = z or 0,
	}, parent)
	create("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency, LineJoinMode = Enum.LineJoinMode.Round }, f)
	return f
end

local function addEdge(parent, color, z, scale)
	scale = scale or 1
	sketchEdge(parent, color, 2 * scale, 0.25, 0.35, 2 * scale, z)
	sketchEdge(parent, color, 1.5 * scale, 0.55, -0.5, -1 * scale, z)
end

local function plainStroke(parent, color, transparency)
	return create("UIStroke", {
		Color = color or Theme.Ink, Thickness = 1.5, Transparency = transparency or 0.8,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

local HOVER_IN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER_OUT = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function hoverScale(parent, trigger, scale)
	trigger = trigger or parent
	scale = tonumber(scale) or 1.08
	local us = create("UIScale", { Scale = 1 }, parent)
	trigger.MouseEnter:Connect(function() TweenService:Create(us, HOVER_IN, { Scale = scale }):Play() end)
	trigger.MouseLeave:Connect(function() TweenService:Create(us, HOVER_OUT, { Scale = 1 }):Play() end)
	return us
end

local function hoverGlow(parent, trigger, color, baseTransparency)
	trigger = trigger or parent
	color = color or Theme.Accent
	local stroke = create("UIStroke", {
		Name = "HoverGlow", Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round, Color = color,
		Transparency = baseTransparency == nil and 1 or baseTransparency,
	}, parent)
	local c0, t0, tr0 = stroke.Color, stroke.Thickness, stroke.Transparency
	trigger.MouseEnter:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.16, Enum.EasingStyle.Sine), { Color = color, Thickness = t0 + 0.5, Transparency = 0.1 }):Play()
	end)
	trigger.MouseLeave:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.28, Enum.EasingStyle.Sine), { Color = c0, Thickness = t0, Transparency = tr0 }):Play()
	end)
	return stroke
end

local function pseudo(n) return (n * 9301 + 49297) % 233280 / 233280 * 2 - 1 end

local function makeRule(seed)
	local f = create("Frame", { Name = "Rule", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 6) })
	for i = 1, 6 do
		create("Frame", {
			Name = "Ink", BorderSizePixel = 0, BackgroundColor3 = Theme.Ink,
			BackgroundTransparency = 0.2 + 0.12 * math.abs(pseudo(seed * 31 + i)),
			AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0.1767, 0, 0, 2),
			Position = UDim2.new((i - 1) / 6, 0, 0.5, math.floor(pseudo(seed * 17 + i) * 1.6)),
			Rotation = pseudo(seed * 7 + i * 2) * 1.1,
		}, f)
	end
	return f
end

local function newRow(height)
	return create("Frame", { Name = "Row", BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false, Size = UDim2.new(1, 0, 0, height) })
end

local function newWell(size)
	local f = create("Frame", { Name = "Well", BackgroundColor3 = Theme.Well, BackgroundTransparency = 0.1, BorderSizePixel = 0, Size = UDim2.new(0, 0, 0, size) })
	addEdge(f, Theme.Ink, nil, 0.5)
	return f
end

local function newCheckBox(parent, size)
	local box = newWell(size)
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, 0, 0.5, 0)
	box.Size = UDim2.new(0, size, 0, size)
	box.Parent = parent
	local fill = create("Frame", {
		Name = "Fill", BorderSizePixel = 0, BackgroundColor3 = Theme.Off, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 1, -8),
	}, box)
	local function render(on)
		on = on and true or false
		TweenService:Create(fill, TweenInfo.new(0.16), { BackgroundColor3 = on and Theme.On or Theme.Off, BackgroundTransparency = on and 0 or 0.35 }):Play()
	end
	return box, render
end

--------------------------------------------------------------------------------------------------
-- Controls (shared by tabs, sub tabs, groupboxes and tabbox tabs)
--------------------------------------------------------------------------------------------------
local Container = {}
Container.__index = Container
local ObjectMethods = {}

-- Tab = one page in the sidebar. Group = a groupbox / tabbox tab. Both get every control from Container.
local Tab = setmetatable({}, { __index = Container })
Tab.__index = Tab
local Group = setmetatable({}, { __index = Container })
Group.__index = Group

function Container:_attach(obj)
	self._order += 1
	obj.LayoutOrder = self._order
	obj.Parent = self._content or self.Page
	return obj
end

local function requireKey(def, what)
	if def.key == nil then
		if def.label ~= nil then
			def.key = def.label
			warn("[UiLib] " .. what .. " without 'key' - using label '" .. tostring(def.label) .. "' as key")
		else
			error("[UiLib] " .. what .. " needs a 'key'", 3)
		end
	end
end

-- argument handling: every Add* accepts the old form  Add*{ key=, label=, ... }  and the Linoria/Feral form  Add*("Idx", { Text=, ... }) --
local autoKeyCounter = 0

local function fromInfo(idx, info)
	local d = {}
	for k, v in pairs(info) do d[k] = v end
	d.key = tostring(idx)
	if d.label == nil then d.label = d.Text or d.Title or d.Name or d.key end
	if d.default == nil then d.default = d.Default end
	if d.callback == nil then d.callback = d.Callback end
	if d.min == nil then d.min = d.Min end
	if d.max == nil then d.max = d.Max end
	if d.step == nil then
		if d.Rounding ~= nil then d.step = 10 ^ (-d.Rounding)
		elseif d.Increment ~= nil then d.step = d.Increment
		else d.step = 1 end
	end
	if d.suffix == nil then d.suffix = d.Suffix end
	if d.options == nil then d.options = d.Values end
	if d.multi == nil then d.multi = d.Multi end
	if d.numeric == nil then d.numeric = d.Numeric end
	if d.placeholder == nil then d.placeholder = d.Placeholder end
	if d.tooltip == nil then d.tooltip = d.Tooltip end
	if d.save == nil and d.Save ~= nil then d.save = d.Save end
	return d
end

-- returns def, usedLinoriaForm
local function normalize(a, b)
	if type(a) == "table" then
		local d = table.clone(a)
		if d.key == nil and d.Idx ~= nil then d.key = tostring(d.Idx) end
		if d.label == nil then d.label = d.Text or d.Title end
		if d.tooltip == nil then d.tooltip = d.Tooltip end
		return d, false
	end
	autoKeyCounter += 1
	return fromInfo(a ~= nil and a or ("__auto" .. autoKeyCounter), type(b) == "table" and b or {}), true
end

local function toStrings(list)
	local out = {}
	for _, o in ipairs(list or {}) do out[#out + 1] = tostring(o) end
	return out
end

local function finish(self, lin, ctrl)
	if lin and ctrl and ctrl.object then return ctrl.object end
	return self
end

-- a bar on the right of a row that holds colour swatches / key buttons ------------------------------------
local function ensureBar(ctrl)
	if ctrl.bar then return ctrl.bar end
	local bar = create("Frame", {
		Name = "Addons", BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -ctrl.barInset, 0, 2), Size = UDim2.new(0, 0, 0, 22), ZIndex = 2,
	}, ctrl.row)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center,
	}, bar)
	ctrl.bar = bar
	local function reserve()
		if ctrl.nameLabel then
			ctrl.nameLabel.Size = UDim2.new(1, -(ctrl.barInset + bar.AbsoluteSize.X + 6), ctrl.nameLabel.Size.Y.Scale, ctrl.nameLabel.Size.Y.Offset)
		end
	end
	bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(reserve)
	return bar
end

function Container:AddSection(text)
	local row = newRow(30)
	row.Name = "Section"
	local l = textLabel(string.upper(tostring(text)), 24, Enum.TextXAlignment.Left)
	l.TextColor3 = Theme.Muted
	l.Size = UDim2.new(1, 0, 0, 24)
	l.Parent = row
	local rule = makeRule(self._order + 2)
	rule.Position = UDim2.new(0, 0, 1, -6)
	rule.Parent = row
	self:_attach(row)
	return self
end

function Container:AddDivider()
	local row = newRow(6)
	row.Name = "Divider"
	makeRule(self._order + 11).Parent = row
	self:_attach(row)
	return self
end

function Container:AddBlank(height)
	self:_attach(newRow(tonumber(height) or 6))
	return self
end

-- Label: returns an object that can also host colour pickers / key pickers, and still chains like a tab ---------------
local LabelMethods = {}
local LabelMeta = {}
LabelMeta.__index = function(t, k)
	local m = LabelMethods[k]
	if m ~= nil then return m end
	local c = rawget(t, "_container")
	local v = c and c[k]
	if type(v) == "function" then
		return function(_, ...) return v(c, ...) end
	end
	return v
end

function LabelMethods.SetText(self, text) self.TextLabel.Text = tostring(text) end
function LabelMethods.SetVisible(self, state) self.Instance.Visible = state and true or false end
function LabelMethods.AddColorPicker(self, idx, info) return self._host.AddColorPicker(self._host, idx, info) end
function LabelMethods.AddKeyPicker(self, idx, info) return self._host.AddKeyPicker(self._host, idx, info) end

function Container:AddLabel(text, wrap)
	local row = newRow(0)
	row.Name = "Label"
	row.AutomaticSize = Enum.AutomaticSize.Y
	local l = textLabel(text, 25, Enum.TextXAlignment.Left)
	l.TextColor3 = Theme.Muted
	l.TextWrapped = wrap ~= false
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Parent = row
	self:_attach(row)

	local obj = setmetatable({ Type = "Label", Instance = row, TextLabel = l, _container = self }, LabelMeta)
	-- addons for labels use the same machinery as toggles
	local host = { _ctrl = { window = self._window, row = row, rowHeight = 22, barInset = 0, nameLabel = l, kind = "label", key = "__label", def = { label = text } } }
	obj._host = setmetatable(host, { __index = function(_, k) return ObjectMethods and ObjectMethods[k] end })
	return obj
end

-- Button ---------------------------------------------------------------------------------------------------
local function buttonDef(a, b)
	if type(a) == "string" then return { label = a, callback = b }, true end
	local d = table.clone(a or {})
	local lin = (d.label == nil and d.callback == nil)
	if d.label == nil then d.label = d.Text end
	if d.callback == nil then d.callback = d.Callback or d.Func end
	if d.tooltip == nil then d.tooltip = d.Tooltip end
	if d.doubleClick == nil then d.doubleClick = d.DoubleClick end
	return d, lin
end

function Container:AddButton(a, b)
	local def, lin = buttonDef(a, b)
	local window = self._window
	local row = newRow(32)
	row.Name = "Button"
	local holder = create("Frame", { Name = "Buttons", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, row)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, holder)

	local obj = { Type = "Button", Instance = row, Buttons = {} }

	local function relayout()
		local n = #obj.Buttons
		for _, b2 in ipairs(obj.Buttons) do
			b2.Size = UDim2.new(1 / n, -(6 * (n - 1)) / n, 1, 0)
		end
	end

	local function make(d)
		local btn = create("TextButton", {
			AutoButtonColor = false, Text = "", BackgroundColor3 = d.colour or d.color or Theme.Header,
			BackgroundTransparency = 0.1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), LayoutOrder = #obj.Buttons + 1,
		}, holder)
		addEdge(btn, Theme.Ink, nil, 0.5)
		hoverGlow(btn, btn, Theme.Flash)
		hoverScale(btn, btn, 1.03)
		local l = textLabel(d.label or "Button", 26, Enum.TextXAlignment.Center)
		l.Size = UDim2.fromScale(1, 1)
		l.Parent = btn
		local armed = false
		btn.MouseButton1Click:Connect(function()
			if d.doubleClick then
				if not armed then
					armed = true
					l.Text = "Click again to confirm"
					task.delay(1.5, function()
						if armed then armed = false l.Text = d.label or "Button" end
					end)
					return
				end
				armed = false
				l.Text = d.label or "Button"
			end
			l.TextColor3 = Theme.Flash
			TweenService:Create(l, TweenInfo.new(0.35), { TextColor3 = Theme.Label }):Play()
			if type(d.callback) == "function" then
				local ok, err = pcall(d.callback)
				if not ok then warn("[UiLib] button '" .. tostring(d.label) .. "' errored: " .. tostring(err)) end
			end
		end)
		if d.tooltip then window:_tip(btn, d.tooltip) end
		obj.Buttons[#obj.Buttons + 1] = btn
		relayout()
		return l
	end

	local firstLabel = make(def)
	function obj.SetText(_, text) firstLabel.Text = tostring(text) def.label = tostring(text) end
	function obj.AddButton(_, a2, b2)
		local d2 = buttonDef(a2, b2)
		local l2 = make(d2)
		local sub = { Type = "Button", Instance = obj.Buttons[#obj.Buttons] }
		function sub.SetText(_, text) l2.Text = tostring(text) d2.label = tostring(text) end
		sub.AddButton = obj.AddButton
		return sub
	end
	self:_attach(row)
	return lin and obj or self
end

-- Toggle -----------------------------------------------------------------------------------------------------
function Container:AddToggle(a, b)
	local def, lin = normalize(a, b)
	requireKey(def, "toggle")
	local window = self._window
	local row = newRow(26)
	row.Name = "Toggle_" .. tostring(def.key)
	local hit = create("TextButton", { Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 26) }, row)
	local l = textLabel(def.label or def.key, 13)
	l.Size = UDim2.new(1, -34, 1, 0)
	l.Parent = hit
	local box, render = newCheckBox(hit, 22)
	hoverScale(box, hit, 1.15)
	hoverGlow(box, hit, Theme.Accent)
	hit.MouseButton1Click:Connect(function() window:Set(def.key, not window:Get(def.key)) end)
	local ctrl = window:_register(def, "toggle", render, false)
	ctrl.row, ctrl.rowHeight, ctrl.barInset, ctrl.nameLabel = row, 26, 30, l
	if def.Risky or def.risky then l.TextColor3 = Theme.Danger end
	if def.tooltip then window:_tip(hit, def.tooltip) end
	self:_attach(row)
	return finish(self, lin, ctrl)
end

-- Slider ----------------------------------------------------------------------------------------------------
function Container:AddSlider(a, b)
	local def, lin = normalize(a, b)
	requireKey(def, "slider")
	local window = self._window
	local lo, hi = tonumber(def.min) or 0, tonumber(def.max) or 1
	if hi < lo then lo, hi = hi, lo end
	local step = tonumber(def.step) or 0
	local suffix = def.suffix and tostring(def.suffix) or ""
	local prefix = def.prefix or def.Prefix
	prefix = prefix and tostring(prefix) or ""

	local row = newRow(48)
	row.Name = "Slider_" .. tostring(def.key)
	local l = textLabel(def.label or def.key, 26)
	l.Size = UDim2.new(1, -90, 0, 22)
	l.Parent = row
	local readout = textLabel("", 13, Enum.TextXAlignment.Right)
	readout.TextColor3 = Theme.Accent
	readout.Size = UDim2.new(0, 90, 0, 22)
	readout.Position = UDim2.new(1, -90, 0, 0)
	readout.Parent = row

	local track = create("TextButton", {
		Name = "Track", Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Well, BackgroundTransparency = 0.15,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 0, 28),
	}, row)
	addEdge(track, Theme.Ink, nil, 0.5)
	hoverGlow(track, track, Theme.Accent)
	local fill = create("Frame", { Name = "Fill", BorderSizePixel = 0, BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.1, Size = UDim2.new(0, 0, 1, 0) }, track)

	local function render(v)
		v = clamp(tonumber(v) or lo, lo, hi)
		fill.Size = UDim2.new(hi > lo and (v - lo) / (hi - lo) or 0, 0, 1, 0)
		readout.Text = prefix .. formatNumber(v, step) .. suffix
	end
	local function fromX(x)
		local w = track.AbsoluteSize.X
		if w <= 0 then return lo end
		return clamp(snap(lo + clamp((x - track.AbsolutePosition.X) / w, 0, 1) * (hi - lo), lo, step), lo, hi)
	end
	track.InputBegan:Connect(function(input)
		if not isPointer(input) then return end
		window._activeSlider = function(x) window:Set(def.key, fromX(x)) end
		window._activeSlider(input.Position.X)
	end)

	local ctrl = window:_register(def, "slider", render, lo)
	ctrl.low, ctrl.high, ctrl.step = lo, hi, step
	ctrl.row, ctrl.nameLabel = row, l
	if def.tooltip then window:_tip(row, def.tooltip) end
	window:Set(def.key, window:Get(def.key), true) -- clamp the initial value
	self:_attach(row)
	return finish(self, lin, ctrl)
end

-- popup list used by dropdowns ---------------------------------------------------------------------------------
local function makePopup(window, row, baseHeight, px, pw)
	px, pw = px or 0.42, pw or 0.58
	local list = create("ScrollingFrame", {
		Name = "Options", Visible = false, Active = true, BackgroundColor3 = Theme.List, BackgroundTransparency = 0.04,
		BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Ink, ScrollBarImageTransparency = 0.5,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Size = UDim2.new(pw, 0, 0, 0),
		Position = UDim2.new(px, 0, 0, baseHeight), ZIndex = 3,
	}, row)
	plainStroke(list)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder }, list)

	-- search bar (shown above the options when the dropdown is searchable: Searchable = true, or 8+ options unless Searchable = false)
	local SEARCH_H = 26
	local searchWell = newWell(24)
	searchWell.Name = "Search"
	searchWell.Visible = false
	searchWell.ZIndex = 3
	searchWell.Size = UDim2.new(pw, 0, 0, 24)
	searchWell.Position = UDim2.new(px, 0, 0, baseHeight + 2)
	searchWell.Parent = row
	local searchBox = create("TextBox", {
		Name = "Field", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -14, 1, 0), Position = UDim2.new(0, 7, 0, 0), AutoLocalize = false,
		FontFace = Library.FontFace, TextSize = math.floor(25 * (Library.TextScale or 1) + 0.5), TextColor3 = Theme.Value, PlaceholderText = "Search...",
		PlaceholderColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ClipsDescendants = true, Text = "", ZIndex = 4,
	}, searchWell)

	local popup = { List = list, Open = false, Count = 0, Shown = 0, Arrow = nil, Search = searchBox, SearchEnabled = false }
	local function h() return math.min(popup.Shown, 8) * 24 end
	function popup.resize()
		local extra = popup.SearchEnabled and SEARCH_H or 0
		row.Size = UDim2.new(1, 0, 0, baseHeight + (popup.Open and h() + 4 + extra or 0))
		list.Position = UDim2.new(px, 0, 0, baseHeight + extra)
		list.Size = UDim2.new(pw, 0, 0, popup.Open and h() or 0)
		searchWell.Visible = popup.Open and popup.SearchEnabled
	end
	function popup.set(state)
		state = state and popup.Count > 0
		if popup.Open == state then return end
		popup.Open = state
		list.Visible = state
		if not state and searchBox.Text ~= "" then searchBox.Text = "" end
		if popup.Arrow then popup.Arrow.Text = state and "^" or "v" end
		popup.resize()
		if state then
			if window._openDropdown and window._openDropdown ~= popup.set then window._openDropdown(false) end
			window._openDropdown = popup.set
		elseif window._openDropdown == popup.set then
			window._openDropdown = nil
		end
	end
	return popup
end

local function newSelectedButton(row, text, stacked)
	local btn = create("TextButton", {
		Name = "Selected", Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Well, BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Size = stacked and UDim2.new(1, 0, 0, 28) or UDim2.new(0.58, 0, 0, 28),
		Position = stacked and UDim2.new(0, 0, 0, 22) or UDim2.new(0.42, 0, 0, 2),
	}, row)
	addEdge(btn, Theme.Ink, nil, 0.5)
	hoverGlow(btn, btn, Theme.Accent)
	local l = textLabel(text or "", 26)
	l.Size = UDim2.new(1, -22, 1, 0)
	l.Position = UDim2.new(0, 8, 0, 0)
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = btn
	local arrow = textLabel("v", 24, Enum.TextXAlignment.Center)
	arrow.TextColor3 = Theme.Muted
	arrow.Size = UDim2.new(0, 22, 1, 0)
	arrow.Position = UDim2.new(1, -24, 0, 0)
	arrow.Parent = btn
	return btn, l, arrow
end

local function hoverRow(btn)
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Theme.Ink
		TweenService:Create(btn, TweenInfo.new(0.14), { BackgroundTransparency = 0.85 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.22), { BackgroundTransparency = 1 }):Play()
	end)
end

local function playerNames()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do out[#out + 1] = p.Name end
	table.sort(out)
	return out
end

-- Dropdown: single value, or def.multi = true -> value is a table { [name] = true } --------------------------------
function Container:AddDropdown(a, b)
	local def, lin = normalize(a, b)
	requireKey(def, "dropdown")
	local window = self._window
	local stacked = self._stacked == true
	local special = def.SpecialType or def.specialType
	local options = special == "Player" and playerNames() or toStrings(def.options)
	local multi = def.multi == true
	local allowNull = def.AllowNull == true or def.allowNull == true

	local baseH = stacked and 54 or 32
	local row = newRow(baseH)
	row.Name = "Dropdown_" .. tostring(def.key)
	local l = textLabel(def.label or def.key, 13)
	l.Size = stacked and UDim2.new(1, 0, 0, 20) or UDim2.new(0.42, -6, 0, 32)
	l.Parent = row
	local selBtn, selLabel, arrow = newSelectedButton(row, "", stacked)
	local popup = makePopup(window, row, baseH, stacked and 0 or 0.42, stacked and 1 or 0.58)
	popup.Arrow = arrow
	popup.Count = #options
	popup.Shown = #options
	local buttons = {}
	local optionRows = {}
	local function applyFilter()
		local q = string.lower(popup.Search.Text)
		local shown = 0
		for _, name in ipairs(options) do
			local bt = optionRows[name]
			if bt then
				local ok = q == "" or string.find(string.lower(name), q, 1, true) ~= nil
				bt.Visible = ok
				if ok then shown += 1 end
			end
		end
		popup.Shown = shown
		popup.List.CanvasPosition = Vector2.new(0, 0)
		popup.resize()
	end
	popup.Search:GetPropertyChangedSignal("Text"):Connect(applyFilter)

	local function isSelected(name, v)
		if multi then return type(v) == "table" and v[name] == true end
		return name == tostring(v)
	end
	local function highlight(v)
		for name, lab in pairs(buttons) do lab.TextColor3 = isSelected(name, v) and Theme.Accent or Theme.Label end
	end
	local function currentValue() return window:Get(def.key) end

	local function rebuild()
		for _, c in ipairs(popup.List:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		buttons = {}
		optionRows = {}
		if popup.Search.Text ~= "" then popup.Search.Text = "" end
		popup.Count = #options
		popup.Shown = #options
		local searchable = def.Searchable
		if searchable == nil then searchable = def.searchable end
		popup.SearchEnabled = searchable == true or (searchable ~= false and #options >= 8)
		for i, name in ipairs(options) do
			local bt = create("TextButton", { Name = "Option_" .. name, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i }, popup.List)
			local t = textLabel(name, 25)
			t.Size = UDim2.new(1, -16, 1, 0)
			t.Position = UDim2.new(0, 8, 0, 0)
			t.TextTruncate = Enum.TextTruncate.AtEnd
			t.Parent = bt
			buttons[name] = t
			optionRows[name] = bt
			hoverRow(bt)
			bt.MouseButton1Click:Connect(function()
				if multi then
					local cur = currentValue()
					local nextValue = {}
					if type(cur) == "table" then
						for k, v in pairs(cur) do nextValue[k] = v end
					end
					nextValue[name] = (not nextValue[name]) or nil
					window:Set(def.key, nextValue)
				else
					popup.set(false)
					if allowNull and tostring(currentValue()) == name then
						window:Set(def.key, "")
					else
						window:Set(def.key, name)
					end
				end
			end)
		end
		if window._controls[def.key] then highlight(currentValue()) end
		popup.resize()
	end

	local function render(v)
		local text
		if multi then
			local picked = {}
			for _, name in ipairs(options) do
				if type(v) == "table" and v[name] == true then picked[#picked + 1] = name end
			end
			text = #picked > 0 and table.concat(picked, ", ") or nil
		else
			text = (v ~= nil and v ~= "") and tostring(v) or nil
		end
		selLabel.Text = text or "--"
		selLabel.TextColor3 = text and Theme.Label or Theme.Muted
		highlight(v)
	end
	selBtn.MouseButton1Click:Connect(function() popup.set(not popup.Open) end)
	rebuild()

	-- resolve the default (Linoria allows an index, a name, or for multi a list of either)
	local function resolveOne(d)
		if type(d) == "number" then return options[d] end
		if d ~= nil then return tostring(d) end
		return nil
	end
	if multi then
		local map = {}
		local d = def.default
		if type(d) == "table" then
			for k, v in pairs(d) do
				if type(k) == "number" then
					local nm = resolveOne(v)
					if nm then map[nm] = true end
				elseif v then
					map[tostring(k)] = true
				end
			end
		elseif d ~= nil then
			local nm = resolveOne(d)
			if nm then map[nm] = true end
		end
		def.default = map
	else
		local r = resolveOne(def.default)
		if r == nil and not lin and not allowNull then r = options[1] end
		def.default = r
	end

	local ctrl = window:_register(def, multi and "multidropdown" or "dropdown", render, multi and {} or (allowNull and "" or options[1]))
	ctrl.row, ctrl.nameLabel = row, l
	ctrl.setOptions = function(list)
		options = toStrings(list)
		rebuild()
		local cur = window:Get(def.key)
		if multi and type(cur) == "table" then
			local pruned = {}
			for k, v in pairs(cur) do
				if table.find(options, k) then pruned[k] = v end
			end
			window:Set(def.key, pruned, true)
			cur = pruned
		end
		render(cur)
	end
	ctrl.getOptions = function() return table.clone(options) end

	if special == "Player" then
		window:_track(Players.PlayerAdded:Connect(function() ctrl.setOptions(playerNames()) end))
		window:_track(Players.PlayerRemoving:Connect(function(p)
			task.defer(function() ctrl.setOptions(playerNames()) end)
		end))
	end
	if def.tooltip then window:_tip(row, def.tooltip) end
	self:_attach(row)
	return finish(self, lin, ctrl)
end

-- Input --------------------------------------------------------------------------------------------------------
function Container:AddInput(a, b)
	local def, lin = normalize(a, b)
	requireKey(def, "input")
	local window = self._window
	local stacked = self._stacked == true
	local row = newRow(stacked and 50 or 32)
	row.Name = "Input_" .. tostring(def.key)
	local l = textLabel(def.label or def.key, 26)
	l.Size = stacked and UDim2.new(1, 0, 0, 20) or UDim2.new(0.42, -8, 1, 0)
	l.Parent = row
	local well = newWell(24)
	well.Size = stacked and UDim2.new(1, 0, 0, 24) or UDim2.new(0.58, 0, 0, 24)
	well.Position = stacked and UDim2.new(0, 0, 0, 22) or UDim2.new(0.42, 0, 0, 2)
	well.Parent = row
	hoverGlow(well, well, Theme.Accent)
	local box = create("TextBox", {
		Name = "Field", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -14, 1, 0), Position = UDim2.new(0, 7, 0, 0), AutoLocalize = false,
		FontFace = Library.FontFace, TextSize = math.floor(25 * (Library.TextScale or 1) + 0.5), TextColor3 = Theme.Value, PlaceholderText = tostring(def.placeholder or ""),
		PlaceholderColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ClipsDescendants = true, Text = "",
	}, well)
	local maxLength = tonumber(def.MaxLength or def.maxLength)
	local liveUpdate = def.Finished == false or (lin and def.Finished ~= true) -- Linoria: the callback runs while typing unless Finished = true
	local function render(v)
		if box:IsFocused() then return end
		box.Text = v == nil and "" or tostring(v)
	end
	local function commit()
		local text = box.Text
		if maxLength and #text > maxLength then text = string.sub(text, 1, maxLength) end
		if def.numeric then
			local n = tonumber(text)
			if n == nil then render(window:Get(def.key)) return end
			window:Set(def.key, n)
		else
			window:Set(def.key, text)
		end
	end
	box.FocusLost:Connect(commit)
	if liveUpdate then box:GetPropertyChangedSignal("Text"):Connect(function() if box:IsFocused() then commit() end end) end
	local ctrl = window:_register(def, "input", render, def.numeric and 0 or "")
	ctrl.row, ctrl.nameLabel = row, l
	if def.tooltip then window:_tip(row, def.tooltip) end
	self:_attach(row)
	return finish(self, lin, ctrl)
end

-- Colour picker (RGB sliders). Used as its own row AND as an addon on toggles / labels ------------------------------------
local function colorPickerOn(window, row, rowHeight, swatch, def, lin)
	local channels = { "R", "G", "B" }
	local panelHeight = 86
	local panel = create("Frame", {
		Name = "Panel", Visible = false, Active = true, BackgroundColor3 = Theme.List, BackgroundTransparency = 0.04, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, rowHeight), ZIndex = 3,
	}, row)
	addEdge(panel, Theme.Ink, nil, 0.5)

	local parts = {}
	for i, ch in ipairs(channels) do
		local r = create("Frame", { Name = "Channel_" .. ch, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 22), Position = UDim2.new(0, 8, 0, 8 + (i - 1) * 26), ZIndex = 3 }, panel)
		local t = textLabel(ch, 14)
		t.Size = UDim2.new(0, 16, 1, 0)
		t.ZIndex = 3
		t.Parent = r
		local track = create("TextButton", {
			Name = "Track", Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Well, BackgroundTransparency = 0.15,
			BorderSizePixel = 0, Size = UDim2.new(1, -52, 1, 0), Position = UDim2.new(0, 20, 0, 0), ZIndex = 3,
		}, r)
		addEdge(track, Theme.Ink, nil, 0.5)
		local fill = create("Frame", { Name = "Fill", BorderSizePixel = 0, BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.1, Size = UDim2.new(0, 0, 1, 0), ZIndex = 4 }, track)
		local read = textLabel("", 13, Enum.TextXAlignment.Right)
		read.TextColor3 = Theme.Accent
		read.Size = UDim2.new(0, 28, 1, 0)
		read.Position = UDim2.new(1, -28, 0, 0)
		read.ZIndex = 3
		read.Parent = r
		parts[ch] = { track = track, fill = fill, read = read }
	end

	local function channelOf(c, ch) return ch == "R" and c.R or ch == "G" and c.G or c.B end
	local function withChannel(c, ch, v)
		return Color3.new(ch == "R" and v or c.R, ch == "G" and v or c.G, ch == "B" and v or c.B)
	end
	local function render(c)
		c = typeof(c) == "Color3" and c or Color3.new(1, 1, 1)
		swatch.BackgroundColor3 = c
		for ch, p in pairs(parts) do
			local v = channelOf(c, ch)
			p.fill.Size = UDim2.new(v, 0, 1, 0)
			p.read.Text = tostring(math.floor(v * 255 + 0.5))
		end
	end

	local open = false
	local function setOpen(state)
		if open == state then return end
		open = state
		panel.Visible = open
		row.Size = UDim2.new(1, 0, 0, rowHeight + (open and panelHeight + 4 or 0))
		panel.Size = UDim2.new(1, 0, 0, open and panelHeight or 0)
		if open then
			if window._openDropdown and window._openDropdown ~= setOpen then window._openDropdown(false) end
			window._openDropdown = setOpen
		elseif window._openDropdown == setOpen then
			window._openDropdown = nil
		end
	end
	swatch.MouseButton1Click:Connect(function() setOpen(not open) end)

	for ch, p in pairs(parts) do
		p.track.InputBegan:Connect(function(input)
			if not isPointer(input) then return end
			window._activeSlider = function(x)
				local cur = window:Get(def.key)
				if typeof(cur) ~= "Color3" then cur = Color3.new(1, 1, 1) end
				local w = p.track.AbsoluteSize.X
				if w <= 0 then return end
				window:Set(def.key, withChannel(cur, ch, clamp((x - p.track.AbsolutePosition.X) / w, 0, 1)))
			end
			window._activeSlider(input.Position.X)
		end)
	end

	local ctrl = window:_register(def, "colorpicker", render, Color3.fromRGB(255, 255, 220))
	ctrl.row = row
	return ctrl
end

function Container:AddColorPicker(a, b)
	local def, lin = normalize(a, b)
	requireKey(def, "colorpicker")
	local window = self._window
	local row = newRow(32)
	row.Name = "ColorPicker_" .. tostring(def.key)
	local l = textLabel(def.label or def.key, 26)
	l.Size = UDim2.new(1, -40, 1, 0)
	l.Parent = row
	local swatch = create("TextButton", {
		Name = "Swatch", Text = "", AutoButtonColor = false, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 22, 0, 22), BackgroundColor3 = Color3.new(1, 1, 1),
	}, row)
	addEdge(swatch, Theme.Ink, nil, 0.5)
	hoverScale(swatch, swatch, 1.15)
	hoverGlow(swatch, swatch, Theme.Accent)
	local ctrl = colorPickerOn(window, row, 32, swatch, def, lin)
	ctrl.nameLabel = l
	if def.tooltip then window:_tip(row, def.tooltip) end
	self:_attach(row)
	return finish(self, lin, ctrl)
end

-- Keybind (legacy: plain key -> onPress) -------------------------------------------------------------------------------
function Container:AddKeybind(def)
	requireKey(def, "keybind")
	local window = self._window
	local row = newRow(26)
	row.Name = "Keybind_" .. tostring(def.key)
	local l = textLabel(def.label or def.key, 26)
	l.Size = UDim2.new(1, -100, 1, 0)
	l.Parent = row
	local btn = create("TextButton", {
		Name = "Bind", Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Well, BackgroundTransparency = 0.15,
		BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 92, 0, 22),
	}, row)
	addEdge(btn, Theme.Ink, nil, 0.5)
	hoverGlow(btn, btn, Theme.Accent)
	local t = textLabel("None", 13, Enum.TextXAlignment.Center)
	t.Size = UDim2.fromScale(1, 1)
	t.Parent = btn

	local listening = false
	local function render(v)
		t.Text = listening and "..." or ((v and v ~= "") and tostring(v) or "None")
		t.TextColor3 = listening and Theme.Flash or Theme.Label
	end
	btn.MouseButton1Click:Connect(function()
		listening = true
		render(window:Get(def.key))
	end)
	window:_track(UserInputService.InputBegan:Connect(function(input, gp)
		if window._destroyed then return end
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				window:Set(def.key, input.KeyCode == Enum.KeyCode.Escape and "None" or input.KeyCode.Name)
				render(window:Get(def.key))
			end
			return
		end
		if gp then return end
		local v = window:Get(def.key)
		if v and v ~= "None" and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == v and type(def.onPress) == "function" then
			task.spawn(def.onPress)
		end
	end))
	window:_register(def, "keybind", render, def.default or "None")
	self:_attach(row)
	return self
end

--------------------------------------------------------------------------------------------------
-- Control objects (Toggles / Options entries)  +  addons (colour picker, key picker)
--------------------------------------------------------------------------------------------------

function ObjectMethods.SetValue(self, v) self._ctrl.window:Set(self._ctrl.key, v) end
ObjectMethods.Set = ObjectMethods.SetValue
function ObjectMethods.GetValue(self) return self._ctrl.window:Get(self._ctrl.key) end
function ObjectMethods.OnChanged(self, fn)
	table.insert(self._ctrl.listeners, fn)
	return self
end
function ObjectMethods.SetValues(self, list)
	if self._ctrl.setOptions then self._ctrl.setOptions(list) end
end
function ObjectMethods.GetValues(self)
	return self._ctrl.getOptions and self._ctrl.getOptions() or {}
end
function ObjectMethods.SetText(self, text)
	local ctrl = self._ctrl
	if ctrl.nameLabel then ctrl.nameLabel.Text = tostring(text) end
end
function ObjectMethods.SetVisible(self, state)
	if self._ctrl.row then self._ctrl.row.Visible = state and true or false end
end
function ObjectMethods.AddTooltip(self, text)
	local ctrl = self._ctrl
	if ctrl.row then ctrl.window:_tip(ctrl.row, text) end
	return self
end
-- key picker object ----------------------------------------------------------------------------------
function ObjectMethods.GetState(self)
	local kc = self._ctrl
	if kc.kind ~= "keypicker" then return false end
	local mode = kc.window:Get(kc.key)[2]
	if mode == "Always" then return true end
	return kc.state == true
end
function ObjectMethods.OnClick(self, fn)
	table.insert(self._ctrl.clickListeners, fn)
	return self
end

function ObjectMethods.AddColorPicker(self, idx, info)
	local ctrl = self._ctrl
	local window = ctrl.window
	info = info or {}
	if idx == nil then
		autoKeyCounter += 1
		idx = "__color" .. autoKeyCounter
	end
	local def = {
		key = tostring(idx), label = info.Title or info.Text or ctrl.def.label, default = info.Default or Color3.new(1, 1, 1),
		callback = info.Callback, save = info.save,
	}
	local bar = ensureBar(ctrl)
	local swatch = create("TextButton", {
		Name = "Swatch", Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = 2, ZIndex = 2,
		Size = UDim2.new(0, 22, 0, 22), BackgroundColor3 = def.default,
	}, bar)
	addEdge(swatch, Theme.Ink, 3, 0.5)
	hoverScale(swatch, swatch, 1.15)
	hoverGlow(swatch, swatch, Theme.Accent)
	local c2 = colorPickerOn(window, ctrl.row, ctrl.rowHeight, swatch, def, true)
	return c2.object
end

local KEY_MODES = { "Toggle", "Hold", "Always" }

function ObjectMethods.AddKeyPicker(self, idx, info)
	local ctrl = self._ctrl
	local window = ctrl.window
	info = info or {}
	if idx == nil then
		autoKeyCounter += 1
		idx = "__key" .. autoKeyCounter
	end
	local mode = info.Mode or "Toggle"
	if not table.find(KEY_MODES, mode) then mode = "Toggle" end
	local def = {
		key = tostring(idx), label = info.Text or ctrl.def.label or "Keybind",
		default = { info.Default or "None", mode }, callback = info.ChangedCallback, save = info.save,
	}
	local bar = ensureBar(ctrl)
	local btn = create("TextButton", {
		Name = "Key", Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Well, BackgroundTransparency = 0.15, BorderSizePixel = 0,
		LayoutOrder = 1, ZIndex = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 22),
	}, bar)
	addEdge(btn, Theme.Ink, 3, 0.5)
	hoverGlow(btn, btn, Theme.Accent)
	local t = textLabel("[None]", 13, Enum.TextXAlignment.Center)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.new(0, 0, 1, 0)
	t.ZIndex = 3
	create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, t)
	t.Parent = btn

	local kc
	local function display()
		local v = window:Get(def.key) or { "None", "Toggle" }
		if kc and kc.listening then
			t.Text = "[...]"
			t.TextColor3 = Theme.Flash
		else
			t.Text = "[" .. tostring(v[1]) .. (v[2] ~= "Toggle" and (" · " .. v[2]) or "") .. "]"
			t.TextColor3 = Theme.Label
		end
	end

	kc = window:_register(def, "keypicker", function() display() end, { "None", "Toggle" })
	kc.state = false
	kc.listening = false
	kc.clickCb = info.Callback
	kc.noUI = info.NoUI == true
	kc.syncKey = (info.SyncToggleState and ctrl.kind == "toggle") and ctrl.key or nil
	kc.clickListeners = {}
	kc.button = btn
	kc.name = def.label
	table.insert(window._keypickers, kc)
	window:_tip(btn, "Click: set key  |  Right click: mode (Toggle / Hold / Always)")

	btn.MouseButton1Click:Connect(function()
		kc.listening = true
		display()
	end)
	btn.MouseButton2Click:Connect(function()
		local v = window:Get(def.key)
		local idxMode = table.find(KEY_MODES, v[2]) or 1
		window:Set(def.key, { v[1], KEY_MODES[idxMode % #KEY_MODES + 1] })
	end)

	if kc.syncKey then
		local parent = window._controls[kc.syncKey]
		if parent then
			parent.onSet = function(value)
				kc.state = value == true
			end
			kc.state = window:Get(kc.syncKey) == true
		end
	end
	kc.refresh = display
	return kc.object
end

--------------------------------------------------------------------------------------------------
-- Groupboxes / tabboxes / sub tabs  (two-column layout, Linoria / Feral style)
--------------------------------------------------------------------------------------------------
local function groupFrame(title, seed)
	local frame = create("Frame", {
		Name = "Groupbox_" .. tostring(title), BackgroundColor3 = Theme.Well, BackgroundTransparency = 0.35, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	})
	addEdge(frame, Theme.Ink, 0, 0.5)
	local body = create("Frame", { Name = "Body", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 1 }, frame)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) }, body)
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, body)
	local head = create("Frame", { Name = "Head", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 }, body)
	local l = textLabel(string.upper(tostring(title)), 24, Enum.TextXAlignment.Left)
	l.TextColor3 = Theme.Header
	l.Size = UDim2.new(1, 0, 0, 26)
	l.Parent = head
	local rule = makeRule(seed or 3)
	rule.Position = UDim2.new(0, 0, 0, 28)
	rule.Parent = head
	local content = create("Frame", { Name = "Content", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, body)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, content)
	return frame, content, l, body
end

function Tab:_cols()
	if not self._colFrames then
		local host = create("Frame", { Name = "Columns", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, nil)
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, host)
		local function col(name, order)
			local f = create("Frame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, host)
			create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, f)
			return f
		end
		self._colFrames = { Left = col("Left", 1), Right = col("Right", 2), _n = { Left = 0, Right = 0 } }
		self:_attach(host)
	end
	return self._colFrames
end

local function newGroup(owner, content, frame, title)
	return setmetatable({
		_window = owner._window, _order = 0, _content = content, _stacked = true, Name = title, Instance = frame, Container = content,
	}, Group)
end

function Tab:AddGroupbox(title, side)
	local frame, content
	local parent
	if side == "Left" or side == "Right" then
		local cols = self:_cols()
		cols._n[side] += 1
		parent = cols[side]
		frame, content = groupFrame(title, cols._n[side] * 7 + (side == "Left" and 1 or 4))
		frame.LayoutOrder = cols._n[side]
		frame.Parent = parent
	else
		frame, content = groupFrame(title, self._order + 5)
		self:_attach(frame)
	end
	local g = newGroup(self, content, frame, title)
	if not (side == "Left" or side == "Right") then g._stacked = false end
	return g
end
-- Feral style: Tab:AddSection("Name", "Left"|"Right") makes a groupbox (without a side it is just a heading)
function Tab:AddSection(title, side)
	if side == "Left" or side == "Right" or side == "left" or side == "right" then
		return self:AddGroupbox(title, (string.lower(side) == "left") and "Left" or "Right")
	end
	return Container.AddSection(self, title)
end
function Tab:AddLeftGroupbox(title) return self:AddGroupbox(title, "Left") end
function Tab:AddRightGroupbox(title) return self:AddGroupbox(title, "Right") end

-- Tabbox: one box with several tabs inside (Linoria AddLeftTabbox / AddRightTabbox) ------------------------------------
function Tab:AddTabbox(side)
	local frame = create("Frame", {
		Name = "Tabbox", BackgroundColor3 = Theme.Well, BackgroundTransparency = 0.35, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	})
	addEdge(frame, Theme.Ink, 0, 0.5)
	local body = create("Frame", { Name = "Body", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 1 }, frame)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder }, body)
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, body)
	local bar = create("Frame", { Name = "Bar", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 }, body)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, bar)
	local rule = makeRule(9)
	rule.LayoutOrder = 2
	rule.Parent = body
	local holder = create("Frame", { Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 }, body)
	create("UIPadding", { PaddingTop = UDim.new(0, 6) }, holder)

	local tabbox = { Instance = frame, Tabs = {}, _buttons = {} }
	local owner = self

	local function select(name)
		for tabName, info in pairs(tabbox.Tabs) do
			local on = tabName == name
			info.Content.Visible = on
			info.Label.TextColor3 = on and Theme.Header or Theme.Muted
			info.Button.BackgroundTransparency = on and 0.86 or 1
		end
	end

	function tabbox.AddTab(_, name)
		name = tostring(name)
		local n = #tabbox._buttons + 1
		local btn = create("TextButton", { Name = "Tab_" .. name, Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Ink, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), LayoutOrder = n }, bar)
		local label = textLabel(string.upper(name), 22, Enum.TextXAlignment.Center)
		label.Size = UDim2.fromScale(1, 1)
		label.TextColor3 = Theme.Muted
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Parent = btn
		tabbox._buttons[n] = btn
		for _, b2 in ipairs(tabbox._buttons) do b2.Size = UDim2.new(1 / #tabbox._buttons, -2, 1, 0) end

		local content = create("Frame", { Name = "Content_" .. name, Visible = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, holder)
		create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, content)
		tabbox.Tabs[name] = { Content = content, Button = btn, Label = label }
		hoverGlow(btn, btn, Theme.Accent)
		btn.MouseButton1Click:Connect(function() select(name) end)
		if n == 1 then select(name) end
		local g = newGroup(owner, content, frame, name)
		return g
	end

	local cols = self:_cols()
	cols._n[side] += 1
	frame.LayoutOrder = cols._n[side]
	frame.Parent = cols[side]
	return tabbox
end
function Tab:AddLeftTabbox() return self:AddTabbox("Left") end
function Tab:AddRightTabbox() return self:AddTabbox("Right") end

-- Sub tabs: a row of buttons at the top of a tab, each with its own set of columns / controls -----------------------------------
function Tab:AddSubTab(name)
	name = tostring(name)
	self._subs = self._subs or {}
	if not self._subBar then
		local bar = create("Frame", { Name = "SubTabs", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30) })
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, bar)
		self:_attach(bar)
		self._subBar = bar
	end

	local btn = create("TextButton", {
		Name = "Sub_" .. name, Text = name, AutoButtonColor = false, BackgroundColor3 = Theme.Ink, BackgroundTransparency = 1, BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = #self._subs + 1, AutoLocalize = false,
		FontFace = Library.FontFace, TextSize = math.floor(24 * (Library.TextScale or 1) + 0.5), TextColor3 = Theme.Muted,
	}, self._subBar)
	create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, btn)
	create("UIStroke", { Color = Theme.Shadow, Thickness = 1.5, Transparency = 0.35, LineJoinMode = Enum.LineJoinMode.Round }, btn)
	hoverGlow(btn, btn, Theme.Accent)

	local holder = create("Frame", { Name = "SubTab_" .. name, Visible = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, holder)
	self:_attach(holder)

	local sub = setmetatable({ _window = self._window, _order = 0, _content = holder, Name = name, Button = btn, Page = holder }, Tab)
	table.insert(self._subs, sub)

	local parent = self
	local function select()
		for _, s in ipairs(parent._subs) do
			local on = s == sub
			s.Page.Visible = on
			s.Button.TextColor3 = on and Theme.Header or Theme.Muted
			s.Button.BackgroundTransparency = on and 0.86 or 1
		end
		parent._activeSub = sub
	end
	sub.Select = select
	btn.MouseButton1Click:Connect(select)
	if #self._subs == 1 then select() end
	return sub
end

--------------------------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------------------------
local Window = {}
Window.__index = Window

-- Toggles / Options entries: read .Value, call :SetValue / :OnChanged / :AddColorPicker / :AddKeyPicker ...
local ObjMeta = {}
ObjMeta.__index = function(t, k)
	local ctrl = rawget(t, "_ctrl")
	if k == "Value" then
		local v = ctrl.window._values[ctrl.key]
		if ctrl.kind == "keypicker" then return v and v[1] or "None" end
		return v
	elseif k == "Mode" and ctrl.kind == "keypicker" then
		local v = ctrl.window._values[ctrl.key]
		return v and v[2] or "Toggle"
	end
	return ObjectMethods[k]
end

function Window:_track(conn)
	table.insert(self._connections, conn)
	return conn
end

function Window:_makeDraggable(handle, target, onFinish)
	handle.InputBegan:Connect(function(input)
		if not isPointer(input) then return end
		local startMouse = input.Position
		local parent = target.Parent
		local origin = parent and parent.AbsolutePosition or Vector2.zero
		local startPos = target.AbsolutePosition - origin -- relative to the parent, so the GUI inset can't shift it
		local moved = false
		self._activeDrag = function(pos)
			local d = pos - startMouse
			if d.Magnitude > 3 then moved = true end
			target.AnchorPoint = Vector2.new(0, 0)
			target.Position = UDim2.fromOffset(math.floor(startPos.X + d.X), math.floor(startPos.Y + d.Y))
		end
		self._dragFinish = function()
			if onFinish then onFinish(moved) end
		end
	end)
end

function Window:_buildInput()
	self:_track(UserInputService.InputChanged:Connect(function(input)
		if self._destroyed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if self._tipFollow then self._tipFollow() end
		if self._activeSlider then self._activeSlider(input.Position.X) end
		if self._activeDrag then self._activeDrag(input.Position) end
		if self._activeResize then self._activeResize(input.Position) end
	end))
	self:_track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			for _, kc in ipairs(self._keypickers) do
				local v = self._values[kc.key]
				if v and v[2] == "Hold" and v[1] == input.KeyCode.Name then self:_setKeyState(kc, false) end
			end
			return
		end
		if not isPointer(input) then return end
		self._activeSlider = nil
		self._activeResize = nil
		if self._activeDrag then
			local finish = self._dragFinish
			self._activeDrag, self._dragFinish = nil, nil
			if finish then finish() end
		end
	end))
	self:_track(UserInputService.InputBegan:Connect(function(input, gp)
		if self._destroyed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		-- a key picker is waiting for its key
		for _, kc in ipairs(self._keypickers) do
			if kc.listening then
				kc.listening = false
				local v = self._values[kc.key] or { "None", "Toggle" }
				self:Set(kc.key, { input.KeyCode == Enum.KeyCode.Escape and "None" or input.KeyCode.Name, v[2] })
				kc.refresh()
				return
			end
		end
		if gp then return end
		local name = input.KeyCode.Name
		if self._opt.ToggleKeyCode and input.KeyCode == self._opt.ToggleKeyCode then
			self:Toggle()
		end
		local tk = Library.ToggleKeybind
		if tk and type(tk) == "table" and tk.Value == name and tk.Value ~= "None" and self == Library._last then
			self:Toggle()
		end
		for _, kc in ipairs(self._keypickers) do
			local v = self._values[kc.key]
			if v and v[1] == name and name ~= "None" then
				if v[2] == "Toggle" then self:_setKeyState(kc, not kc.state)
				elseif v[2] == "Hold" then self:_setKeyState(kc, true) end
			end
		end
	end))
end

function Window:_buildToggleButton()
	local size = self._opt.ToggleSize
	local btn = create("TextButton", {
		Name = "Launcher", Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Header, BackgroundTransparency = 1,
		BorderSizePixel = 0, Size = UDim2.fromOffset(size, size), Position = self._opt.TogglePosition, AnchorPoint = Vector2.new(0, 0.5),
	}, self.Gui)
	self.Launcher = btn
	addEdge(btn, Theme.Ink, 1)
	hoverGlow(btn, btn, Theme.Flash, 0.6)
	hoverScale(btn, btn, 1.1)
	self:SetToggleIcon(self._opt.ToggleIcon or self._opt.ToggleImage)
	self:_makeDraggable(btn, btn, function(moved)
		if not moved then self:Toggle() end
	end)
end

-- the little square that opens / closes the menu: a picture ("rbxassetid://123", or just the number) or, with nil, a letter / text
local function assetUrl(v)
	if type(v) == "number" then return "rbxassetid://" .. tostring(math.floor(v)) end
	if type(v) == "string" then
		v = string.gsub(v, "^%s+", "")
		v = string.gsub(v, "%s+$", "")
		if v == "" then return nil end
		if string.match(v, "^%d+$") then return "rbxassetid://" .. v end
		return v
	end
	return nil
end

function Window:SetToggleIcon(image)
	local btn = self.Launcher
	if not btn then return self end
	local url = assetUrl(image)
	self._opt.ToggleIcon = url
	for _, name in ipairs({ "Icon", "LauncherText" }) do
		local old = btn:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local size = self._opt.ToggleSize
	if url then
		local backing = self._opt.ToggleIconBackground ~= false
		btn.BackgroundColor3 = Color3.new(0, 0, 0)
		btn.BackgroundTransparency = backing and 0.35 or 1
		create("ImageLabel", {
			Name = "Icon", BackgroundTransparency = 1, Image = url, ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2,
		}, btn)
	else
		local text = self._opt.ToggleText
		if type(text) ~= "string" or text == "" then
			text = string.upper(string.sub(tostring(self._opt.Title), 1, 1))
		end
		btn.BackgroundColor3 = Theme.Header
		btn.BackgroundTransparency = 0.1
		local t = textLabel(text, math.floor(size * 0.52), Enum.TextXAlignment.Center)
		t.Name = "LauncherText"
		t.Size = UDim2.fromScale(1, 1)
		t.ZIndex = 2
		t.Parent = btn
	end
	return self
end

function Window:_layoutDivider()
	if not self.Divider then return end
	self.Divider.Size = UDim2.new(0, self._opt.Height - 58, 0, 6)
	self.Divider.Position = UDim2.new(0, self._opt.SidebarWidth, 0.5, 19)
end

function Window:_makeResizable(root)
	local grip = create("TextButton", { Name = "Grip", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(26, 18), ZIndex = 4 }, root)
	hoverScale(grip, grip, 1.2)
	local arrow = textLabel("v", 20, Enum.TextXAlignment.Center) -- same font as the rest; rotated to point down-right
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(0.5, 0, 0.5, 0)
	arrow.Size = UDim2.fromOffset(20, 20)
	arrow.Rotation = -45
	arrow.TextColor3 = Theme.Muted
	arrow.ZIndex = 4
	arrow.Parent = grip
	grip.MouseEnter:Connect(function() TweenService:Create(arrow, TweenInfo.new(0.16), { TextColor3 = Theme.Flash }):Play() end)
	grip.MouseLeave:Connect(function() TweenService:Create(arrow, TweenInfo.new(0.22), { TextColor3 = Theme.Muted }):Play() end)
	grip.InputBegan:Connect(function(input)
		if not isPointer(input) then return end
		local startMouse = input.Position
		local w, h = self._opt.Width, self._opt.Height
		self._activeResize = function(pos)
			local d = pos - startMouse
			self._opt.Width = clamp(math.floor(w + d.X), self._opt.MinWidth, self._opt.MaxWidth)
			self._opt.Height = clamp(math.floor(h + d.Y), self._opt.MinHeight, self._opt.MaxHeight)
			root.Size = UDim2.fromOffset(self._opt.Width, self._opt.Height)
			self:_layoutDivider()
		end
	end)
	self.ResizeGrip = grip
end

function Window:_buildWindow()
	local opt = self._opt
	local root = create("Frame", {
		Name = "Window", Visible = false, BackgroundColor3 = Theme.Background, BackgroundTransparency = Theme.BackgroundTransparency,
		BorderSizePixel = 0, Size = UDim2.fromOffset(opt.Width, opt.Height), Position = opt.Position, AnchorPoint = opt.AnchorPoint,
	}, self.Gui)
	self.Root = root
	self.RootScale = create("UIScale", { Scale = 1 }, root)
	addEdge(root, Theme.Ink, 0)

	-- header
	local header = create("TextButton", { Name = "Header", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.05, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 38) }, root)
	self.Header = header
	local grad = create("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.Header), ColorSequenceKeypoint.new(0.55, Theme.Header), ColorSequenceKeypoint.new(1, Theme.Flash) }),
		Rotation = -12, Offset = Vector2.new(-0.8, 0),
	}, header)
	self._headerRotate = TweenService:Create(grad, TweenInfo.new(9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 12 })
	self._headerSweep = TweenService:Create(grad, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(0.35, 0) })
	self._headerRotate:Play()
	self._headerSweep:Play()
	addEdge(header, Theme.Ink, 1)

	local title = textLabel(opt.Title, 26, Enum.TextXAlignment.Left)
	title.Name = "Title"
	title.Size = UDim2.new(1, -80, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.ZIndex = 2
	title.Parent = header
	self.Title = title

	local close = create("TextButton", { Name = "Close", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(40, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ZIndex = 2 }, header)
	local x = textLabel("x", 24, Enum.TextXAlignment.Center)
	x.Name = "X"
	x.Size = UDim2.fromScale(1, 1)
	x.ZIndex = 3
	x.Parent = close
	hoverGlow(close, close, Theme.Danger, 0.55)
	hoverScale(close, close, 1.2)
	close.MouseEnter:Connect(function() TweenService:Create(x, TweenInfo.new(0.16), { TextColor3 = Theme.Flash }):Play() end)
	close.MouseLeave:Connect(function() TweenService:Create(x, TweenInfo.new(0.22), { TextColor3 = Theme.Label }):Play() end)
	close.MouseButton1Click:Connect(function() self:Close() end)

	-- sidebar
	local sidebar = create("ScrollingFrame", {
		Name = "Tabs", Active = true, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Ink,
		ScrollBarImageTransparency = 0.6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(0, opt.SidebarWidth, 1, -38), Position = UDim2.new(0, 0, 0, 38),
	}, root)
	self.Sidebar = sidebar
	local tabList = create("Frame", { Name = "TabList", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, sidebar)
	self.TabList = tabList
	create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, tabList)
	create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6) }, sidebar)
	local marker = textLabel("I", 24, Enum.TextXAlignment.Center)
	marker.Name = "Marker"
	marker.TextColor3 = Theme.Accent
	marker.TextTransparency = 1
	marker.Size = UDim2.fromOffset(10, 28)
	marker.ZIndex = 2
	marker.Parent = sidebar
	self.Marker = marker

	-- divider
	local divider = makeRule(10)
	divider.Rotation = 90
	divider.AnchorPoint = Vector2.new(0.5, 0.5)
	divider.Parent = root
	self.Divider = divider
	self:_layoutDivider()

	self.Pages = create("Frame", { Name = "Pages", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -opt.SidebarWidth, 1, -38), Position = UDim2.new(0, opt.SidebarWidth, 0, 38) }, root)

	if opt.Draggable then self:_makeDraggable(header, root, nil) end
	if opt.Resizable then self:_makeResizable(root) end

	-- notifications
	local holder = create("Frame", { Name = "Notifications", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 260, 1, -32), ZIndex = 20 }, self.Gui)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6) }, holder)
	self._notifyHolder = holder
end

function Window:_build()
	local parent, protected = getGuiParent()
	local gui = create("ScreenGui", { Name = randomName(), ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = self._opt.DisplayOrder })
	if protected then protect(gui) end

	-- keep the UI in English: stop Roblox from auto-translating any text in it
	if self._opt.ForceEnglish ~= false then
		local function lock(o)
			if o:IsA("GuiBase2d") then
				pcall(function() o.AutoLocalize = false end)
			end
		end
		lock(gui)
		self._lockEnglish = lock
		self:_track(gui.DescendantAdded:Connect(lock))
	end

	gui.Parent = parent
	self.Gui = gui
	self:_buildToggleButton()
	self:_buildWindow()
	self:_buildInput()
	if self._opt.StartOpen then self:Open() end
end

-- tabs -------------------------------------------------------------------------------------------
function Window:AddTab(name)
	assert(not self._destroyed, "Window is destroyed")
	name = tostring(name)
	self._tabCount += 1
	local order = self._tabCount
	local tab = setmetatable({ _window = self, Name = name, _order = 0, SidebarOrder = order }, Tab)

	local btn = create("TextButton", { Name = "Tab_" .. name, Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Ink, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order }, self.TabList)
	tab.Button = btn
	local label = textLabel(name, Library.TabTextSize or 26)
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 14, 0, 0)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = btn
	tab.Label = label

	local page = create("ScrollingFrame", {
		Name = "Page_" .. name, Visible = false, Active = true, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Ink, ScrollBarImageTransparency = 0.5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 1),
	}, self.Pages)
	tab.Page = page
	create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, page)
	create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }, page)

	hoverGlow(btn, btn, Theme.Accent)
	btn.MouseEnter:Connect(function()
		if self._active ~= tab then TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.9 }):Play() end
	end)
	btn.MouseLeave:Connect(function()
		if self._active ~= tab then TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play() end
	end)
	btn.MouseButton1Click:Connect(function() self:SelectTab(name) end)

	self._tabs[#self._tabs + 1] = tab
	if not self._active then self:SelectTab(name) end
	return tab
end

function Window:GetTab(name)
	for _, t in ipairs(self._tabs) do
		if t.Name == name then return t end
	end
	return nil
end

function Window:SelectTab(name)
	local found
	for _, t in ipairs(self._tabs) do
		local vis = t.Name == name
		t.Page.Visible = vis
		t.Button.BackgroundTransparency = vis and 0.86 or 1
		t.Label.TextColor3 = vis and Theme.Value or Theme.Label
		if vis then
			self._active = t
			found = t
		end
	end
	if found then self:_moveMarker(found) end
	return self
end

function Window:_moveMarker(tab)
	local marker = self.Marker
	local first = self._markerTab == nil
	self._markerTab = tab
	if self._markerShimmer then
		self._markerShimmer:Cancel()
		self._markerShimmer = nil
	end
	local pos = UDim2.new(0, 0, 0, (tab.SidebarOrder - 1) * 34 + 1)
	marker.TextColor3 = Theme.Flash
	if first then
		marker.Position = pos
		TweenService:Create(marker, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	else
		TweenService:Create(marker, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos }):Play()
	end
	TweenService:Create(marker, TweenInfo.new(0.3), { TextColor3 = Theme.Accent }):Play()
	task.delay(0.35, function()
		if self._destroyed or self._markerTab ~= tab then return end
		local tw = TweenService:Create(marker, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextColor3 = Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.4) })
		self._markerShimmer = tw
		tw:Play()
	end)
end

-- values -----------------------------------------------------------------------------------------
function Window:_writeThrough(ctrl, value)
	if ctrl.path and self._opt.Target then
		setPath(self._opt.Target, ctrl.path, value)
	end
end

function Window:_register(def, kind, render, fallback)
	local key = tostring(def.key)
	if self._controls[key] then
		warn("[UiLib] duplicate control key '" .. key .. "' -- the second one won't be saved")
	end
	local path = def.path
	if path == nil then path = key end
	local ctrl = { def = def, kind = kind, key = key, path = path, render = render, window = self, listeners = {} }
	ctrl.object = setmetatable({ Type = kind, Idx = key, _ctrl = ctrl }, ObjMeta)
	if kind == "toggle" then self.Toggles[key] = ctrl.object else self.Options[key] = ctrl.object end
	self._controls[key] = ctrl
	local value = nil
	if path and self._opt.Target then value = getPath(self._opt.Target, path) end
	if value == nil then value = def.default end
	if value == nil then value = fallback end
	self._values[key] = value
	pcall(render, value)
	self:_writeThrough(ctrl, value)
	return ctrl
end

function Window:Set(key, value, silent)
	if self._destroyed then return self end
	key = tostring(key)
	local ctrl = self._controls[key]
	if not ctrl then
		warn("[UiLib] Set: no control named '" .. key .. "'")
		return self
	end
	if ctrl.kind == "slider" then
		local n = tonumber(value)
		if n == nil then return self end
		value = clamp(snap(n, ctrl.low, ctrl.step), ctrl.low, ctrl.high)
	elseif ctrl.kind == "toggle" then
		value = value and true or false
	elseif ctrl.kind == "colorpicker" then
		if typeof(value) ~= "Color3" then return self end
	elseif ctrl.kind == "keypicker" then
		local cur = self._values[key] or { "None", "Toggle" }
		local nk, nm
		if type(value) == "string" then
			nk, nm = value, cur[2]
		elseif type(value) == "table" then
			nk = value[1] or value.Key or value.key or cur[1]
			nm = value[2] or value.Mode or value.mode or cur[2]
		else
			return self
		end
		if not table.find(KEY_MODES, nm) then nm = "Toggle" end
		value = { tostring(nk), nm }
		if cur[2] ~= nm and ctrl.state then self:_setKeyState(ctrl, false) end
	elseif ctrl.kind == "multidropdown" then
		if type(value) ~= "table" then return self end
		local map = {}
		for k, v in pairs(value) do
			if type(k) == "number" then map[tostring(v)] = true elseif v then map[tostring(k)] = true end
		end
		value = map
	end
	local old = self._values[key]
	self._values[key] = value
	self:_writeThrough(ctrl, value)
	pcall(ctrl.render, value)
	if ctrl.onSet then pcall(ctrl.onSet, value) end
	if silent or old == value then return self end
	if type(ctrl.def.callback) == "function" then
		local ok, err = pcall(ctrl.def.callback, value)
		if not ok then warn("[UiLib] callback for '" .. key .. "' errored: " .. tostring(err)) end
	end
	for _, fn in ipairs(ctrl.listeners) do
		local ok, err = pcall(fn, value)
		if not ok then warn("[UiLib] OnChanged for '" .. key .. "' errored: " .. tostring(err)) end
	end
	for _, fn in ipairs(self._listeners) do
		pcall(fn, key, value, old)
	end
	return self
end

function Window:Get(key)
	return self._values[tostring(key)]
end

function Window:SetMany(tbl, silent)
	for k, v in pairs(tbl) do self:Set(k, v, silent) end
	return self
end

function Window:Values(onlySaved)
	local out = {}
	for k, v in pairs(self._values) do
		local ctrl = self._controls[k]
		if not (onlySaved and ctrl and ctrl.def.save == false) then out[k] = v end
	end
	return out
end

function Window:ApplyTo(tbl)
	for _, ctrl in pairs(self._controls) do
		if ctrl.path then setPath(tbl, ctrl.path, self._values[ctrl.key]) end
	end
	return tbl
end

function Window:OnChange(fn)
	assert(type(fn) == "function", "OnChange needs a function")
	table.insert(self._listeners, fn)
	return function()
		for i, f in ipairs(self._listeners) do
			if f == fn then table.remove(self._listeners, i) return end
		end
	end
end

function Window:RunCallbacks()
	for key, ctrl in pairs(self._controls) do
		if type(ctrl.def.callback) == "function" then
			task.spawn(function() pcall(ctrl.def.callback, self._values[key]) end)
		end
	end
end

function Window:SetOptions(key, list)
	local ctrl = self._controls[tostring(key)]
	if ctrl and ctrl.setOptions then ctrl.setOptions(list) end
	return self
end

function Window:GetOptions(key)
	local ctrl = self._controls[tostring(key)]
	return ctrl and ctrl.getOptions and ctrl.getOptions() or {}
end

-- key pickers / tooltips / watermark / keybind list ---------------------------------------------------
function Window:_setKeyState(kc, st)
	st = st and true or false
	if kc.state == st then return end
	kc.state = st
	if kc.syncKey then self:Set(kc.syncKey, st) end
	if type(kc.clickCb) == "function" then
		task.spawn(function()
			local ok, err = pcall(kc.clickCb, st)
			if not ok then warn("[UiLib] key picker callback errored: " .. tostring(err)) end
		end)
	end
	for _, fn in ipairs(kc.clickListeners) do task.spawn(pcall, fn, st) end
end

function Window:_tip(gui, text)
	if not gui or text == nil or text == "" then return end
	gui.MouseEnter:Connect(function()
		if self._destroyed or not self.Gui then return end
		if not self._tipFrame then
			local f = create("Frame", {
				Name = "Tooltip", Visible = false, BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.02, BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), ZIndex = 40,
			}, self.Gui)
			plainStroke(f, Theme.Ink, 0.4)
			create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, f)
			local l = textLabel("", 20, Enum.TextXAlignment.Left)
			l.AutomaticSize = Enum.AutomaticSize.XY
			l.Size = UDim2.new(0, 0, 0, 0)
			l.ZIndex = 41
			l.Parent = f
			self._tipFrame, self._tipLabel = f, l
		end
		self._tipLabel.Text = tostring(text)
		self._tipFollow = function()
			local m = UserInputService:GetMouseLocation()
			self._tipFrame.Position = UDim2.fromOffset(m.X + 14, m.Y + 6)
		end
		self._tipFollow()
		self._tipFrame.Visible = true
	end)
	gui.MouseLeave:Connect(function()
		if self._tipFrame then self._tipFrame.Visible = false end
		self._tipFollow = nil
	end)
end

-- open / close -----------------------------------------------------------------------------------
local TWEEN_OPEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_CLOSE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

function Window:Open()
	if self._destroyed then return self end
	self._open = true
	if self._popTween then self._popTween:Cancel() end
	self.Root.Visible = true
	self.Launcher.Visible = self._opt.AlwaysShowLauncher ~= false
	self.RootScale.Scale = 0.85
	self._popTween = TweenService:Create(self.RootScale, TWEEN_OPEN, { Scale = 1 })
	self._popTween:Play()
	return self
end

function Window:Close()
	if self._destroyed then return self end
	self._open = false
	self.Launcher.Visible = true
	if self._openDropdown then self._openDropdown(false) end
	if self._popTween then self._popTween:Cancel() end
	local tw = TweenService:Create(self.RootScale, TWEEN_CLOSE, { Scale = 0.85 })
	self._popTween = tw
	tw:Play()
	tw.Completed:Connect(function()
		if not self._destroyed and not self._open then self.Root.Visible = false end
	end)
	return self
end

function Window:Toggle()
	if self._open then return self:Close() end
	return self:Open()
end

function Window:IsOpen() return self._open end

function Window:SetToggleKey(keyCode) self._opt.ToggleKeyCode = keyCode return self end

function Window:SetTitle(text)
	if self.Title then self.Title.Text = tostring(text) end
	return self
end

function Window:SetVisible(state)
	state = state and true or false
	if self.Launcher then self.Launcher.Visible = state and (self._opt.AlwaysShowLauncher ~= false or not self._open) end
	if self.Root then self.Root.Visible = state and self._open end
	return self
end

local function measureText(text, size, width)
	local ok, res = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = Library.FontFace
		params.Size = size
		params.Width = width
		return TextService:GetTextBoundsAsync(params).Y
	end)
	if ok and type(res) == "number" and res > 0 then return math.ceil(res) end
	local lines = math.max(1, math.ceil(#text * size * 0.55 / width))
	return lines * (size + 2)
end

function Window:Notify(title, text, duration)
	if self._destroyed then return end
	duration = tonumber(duration) or 4
	title, text = tostring(title or ""), tostring(text or "")
	-- fixed, measured height (no AutomaticSize) so a toast can never grow past its text
	local innerWidth = 240
	local bodyH = measureText(text, 14, innerWidth)
	local toast = create("Frame", {
		BackgroundColor3 = Theme.Background, BackgroundTransparency = Theme.BackgroundTransparency, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8 + 18 + 2 + bodyH + 8), ClipsDescendants = true, ZIndex = 20,
	}, self._notifyHolder)
	plainStroke(toast, Theme.Ink, 0.35)
	local t = textLabel(title, 15)
	t.TextColor3 = Theme.Header
	t.Size = UDim2.new(1, -20, 0, 18)
	t.Position = UDim2.new(0, 10, 0, 8)
	t.ZIndex = 21
	t.Parent = toast
	local b = textLabel(text, 14)
	b.TextWrapped = true
	b.TextYAlignment = Enum.TextYAlignment.Top
	b.Size = UDim2.new(1, -20, 0, bodyH)
	b.Position = UDim2.new(0, 10, 0, 28)
	b.ZIndex = 21
	b.Parent = toast
	task.delay(duration, function()
		if toast.Parent then toast:Destroy() end
	end)
end

function Window:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	if Library._last == self then Library._last = nil end
	for _, c in ipairs(self._connections) do pcall(function() c:Disconnect() end) end
	self._connections, self._listeners = {}, {}
	for _, tw in ipairs({ "_markerShimmer", "_headerRotate", "_headerSweep", "_popTween" }) do
		if self[tw] then pcall(function() self[tw]:Cancel() end) self[tw] = nil end
	end
	if self.Gui then pcall(function() self.Gui:Destroy() end) end
	self.Gui, self.Root, self.Header, self.Sidebar, self.Pages, self.Launcher = nil, nil, nil, nil, nil, nil
	if self._registry and self._registry[self.Folder] == self then self._registry[self.Folder] = nil end
end


--------------------------------------------------------------------------------------------------
-- Stats panels: small pop-out windows with rows of  "label ........ value"  (Library:CreateStats)
--------------------------------------------------------------------------------------------------
local Stats = {}
Stats.__index = Stats

local function formatCount(value)
	if type(value) ~= "number" or value ~= math.floor(value) or math.abs(value) >= 9007199254740992 then return tostring(value) end
	local s = tostring(math.abs(value)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (value < 0 and "-" or "") .. s
end

local function formatClock(seconds)
	local total = math.max(0, math.floor(tonumber(seconds) or 0))
	local h, m, s = math.floor(total / 3600), math.floor(total % 3600 / 60), total % 60
	if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
	return string.format("%d:%02d", m, s)
end

Library.FormatCount = formatCount
Library.FormatClock = formatClock
Library._stats = {}

-- opts: Title, Id, Color (header colour), Width, Position, AnchorPoint, RowHeight, TitleSize, RowSize,
--       Draggable, Collapsible, StartCollapsed, Rows = { {key, label, color, default, format, clock}, ... }
function Library:CreateStats(opts)
	opts = opts or {}
	local self = setmetatable({}, Stats)
	self._opt = {
		Title = opts.Title or "Stats", Width = opts.Width or 270, RowHeight = opts.RowHeight or 30,
		TitleSize = opts.TitleSize or 26, RowSize = opts.RowSize or 21,
		Position = opts.Position or UDim2.new(1, -12, 0.5, 0), AnchorPoint = opts.AnchorPoint or Vector2.new(1, 0.5),
		Draggable = opts.Draggable ~= false, Collapsible = opts.Collapsible ~= false,
		Color = opts.Color or Color3.fromRGB(240, 190, 40), DisplayOrder = opts.DisplayOrder or 12,
	}
	self._rows, self._order, self._values, self._connections, self._destroyed = {}, 0, {}, {}, false

	-- running the script twice replaces the old panel with the same Id
	if opts.Id then
		genv.__CinderStats = genv.__CinderStats or {}
		local old = genv.__CinderStats[opts.Id]
		if old and old ~= self then pcall(function() old:Destroy() end) end
		genv.__CinderStats[opts.Id] = self
		self._id = opts.Id
	end

	local parent, protected = getGuiParent()
	local gui = create("ScreenGui", { Name = randomName(), ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = self._opt.DisplayOrder })
	if protected then protect(gui) end
	local function lock(o)
		if o:IsA("GuiBase2d") then pcall(function() o.AutoLocalize = false end) end
	end
	lock(gui)
	table.insert(self._connections, gui.DescendantAdded:Connect(lock))
	gui.Parent = parent
	self.Gui = gui

	local root = create("Frame", {
		Name = "Panel", BackgroundColor3 = Theme.Background, BackgroundTransparency = Theme.BackgroundTransparency, BorderSizePixel = 0,
		Size = UDim2.new(0, self._opt.Width, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = self._opt.Position, AnchorPoint = self._opt.AnchorPoint,
	}, gui)
	self.Root = root
	addEdge(root, Theme.Ink, 0)

	local content = create("Frame", { Name = "Content", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 1 }, root)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, content)
	create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, content)

	local header = create("TextButton", {
		Name = "Header", Text = "", AutoButtonColor = false, BackgroundColor3 = self._opt.Color, BackgroundTransparency = 0.05, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, self._opt.RowHeight + 8), LayoutOrder = 0,
	}, content)
	addEdge(header, Theme.Ink, 1)
	local title = textLabel(self._opt.Title, self._opt.TitleSize, Enum.TextXAlignment.Left)
	title.Name = "Title"
	title.TextColor3 = Color3.new(1, 1, 1)
	local tstroke = title:FindFirstChildOfClass("UIStroke")
	if tstroke then tstroke.Color = Color3.new(0, 0, 0); tstroke.Transparency = 0; tstroke.Thickness = 1.5 end
	title.Size = UDim2.new(1, -16, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.ZIndex = 2
	title.Parent = header
	self.Header, self.Title = header, title

	local body = create("Frame", { Name = "Body", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, content)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, body)
	self.Body = body

	-- drag by the header; a click without moving collapses / expands
	local dragging, moved, startMouse, startPos = false, false, nil, nil
	table.insert(self._connections, header.InputBegan:Connect(function(input)
		if not isPointer(input) then return end
		dragging, moved, startMouse = true, false, input.Position
		startPos = root.AbsolutePosition - (gui.AbsolutePosition)
	end))
	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		if not dragging or self._destroyed or not self._opt.Draggable then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local d = input.Position - startMouse
		if d.Magnitude > 3 then moved = true end
		if moved then
			root.AnchorPoint = Vector2.new(0, 0)
			root.Position = UDim2.fromOffset(math.floor(startPos.X + d.X), math.floor(startPos.Y + d.Y))
		end
	end))
	table.insert(self._connections, UserInputService.InputEnded:Connect(function(input)
		if not isPointer(input) or not dragging then return end
		dragging = false
		if not moved and self._opt.Collapsible then self:SetCollapsed(not self._collapsed) end
	end))

	table.insert(Library._stats, self)
	for _, def in ipairs(opts.Rows or {}) do self:AddStat(def) end
	if opts.StartCollapsed then self:SetCollapsed(true) end
	return self
end

function Window:CreateStats(opts) return Library:CreateStats(opts) end

-- def: { key, label, color, default, format = "number" | "clock" | "text" | function(value) -> string, clock = true (auto-counting timer) }
-- also accepts AddStat("key", "Label", { Color = ..., Default = ..., Format = ... })
function Stats:AddStat(def, label, extra)
	if type(def) == "string" then
		local info = type(extra) == "table" and extra or {}
		def = { key = def, label = label, color = info.Color or info.color, default = info.Default, format = info.Format, clock = info.Clock }
	end
	assert(type(def) == "table" and def.key ~= nil, "AddStat needs a key")
	local key = tostring(def.key)
	if self._destroyed or self._rows[key] then return self end
	self._order += 1
	local n = self._order
	if n > 1 then
		local rule = makeRule(n)
		rule.LayoutOrder = n * 10 - 1
		rule.Parent = self.Body
	end
	local row = create("Frame", { Name = "Row_" .. key, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, self._opt.RowHeight), LayoutOrder = n * 10 }, self.Body)
	local l = textLabel(def.label or key, self._opt.RowSize, Enum.TextXAlignment.Left)
	l.Size = UDim2.new(0.62, 0, 1, 0)
	l.Parent = row
	local color = def.color or Theme.Value
	local v = textLabel("0", self._opt.RowSize, Enum.TextXAlignment.Right)
	v.Size = UDim2.new(0.38, 0, 1, 0)
	v.Position = UDim2.new(0.62, 0, 0, 0)
	v.TextColor3 = color
	v.Parent = row
	local scale = create("UIScale", {}, v)
	self._rows[key] = { def = def, frame = row, label = l, value = v, scale = scale, color = color, format = def.format }
	local initial = def.default
	if initial == nil then initial = (def.format == "text") and "" or 0 end
	self._values[key] = initial
	self:_render(key, initial, false)
	if def.clock then
		local t0 = os.clock()
		self._rows[key].format = def.format or "clock"
		self:Poll(key, 1, function() return os.clock() - t0 end)
	end
	return self
end

function Stats:_render(key, value, animate)
	local r = self._rows[key]
	if not r then return end
	local f = r.format
	local text
	if type(f) == "function" then
		local ok, res = pcall(f, value)
		text = ok and tostring(res) or tostring(value)
	elseif f == "clock" then
		text = formatClock(value)
	elseif f == "text" then
		text = tostring(value)
	elseif type(value) == "number" then
		text = formatCount(value)
	else
		text = tostring(value)
	end
	r.value.Text = text
	if not animate then return end
	r.value.TextColor3 = Theme.Flash
	r.scale.Scale = 1.16
	TweenService:Create(r.value, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextColor3 = r.color }):Play()
	TweenService:Create(r.scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function Stats:Set(key, value, color)
	if self._destroyed then return self end
	key = tostring(key)
	local r = self._rows[key]
	if not r then
		warn("[UiLib] Stats:Set - no row named '" .. key .. "'")
		return self
	end
	if color then r.color = color end
	local old = self._values[key]
	self._values[key] = value
	self:_render(key, value, old ~= value)
	return self
end

function Stats:Increment(key, amount)
	return self:Set(key, (tonumber(self._values[tostring(key)]) or 0) + (tonumber(amount) or 1))
end

function Stats:Get(key) return self._values[tostring(key)] end

function Stats:SetMany(values)
	for k, v in pairs(values) do self:Set(k, v) end
	return self
end

function Stats:Reset(keys)
	if keys then
		for _, k in ipairs(keys) do self:Set(k, 0) end
	else
		for k in pairs(self._rows) do self:Set(k, 0) end
	end
	return self
end

function Stats:SetLabel(key, text)
	local r = self._rows[tostring(key)]
	if r then r.label.Text = tostring(text) end
	return self
end

function Stats:SetColor(key, color)
	local r = self._rows[tostring(key)]
	if r then
		r.color = color
		r.value.TextColor3 = color
	end
	return self
end

function Stats:SetTitle(text)
	if self.Title then self.Title.Text = tostring(text) end
	return self
end

function Stats:SetHeaderColor(color)
	if self.Header then self.Header.BackgroundColor3 = color end
	return self
end

function Stats:SetVisible(state)
	if self.Root then self.Root.Visible = state and true or false end
	return self
end

function Stats:Toggle()
	if self.Root then self.Root.Visible = not self.Root.Visible end
	return self
end

function Stats:SetCollapsed(state)
	self._collapsed = state and true or false
	if self.Body then self.Body.Visible = not self._collapsed end
	return self
end

function Stats:SetPosition(position, anchor)
	if self.Root then
		self.Root.AnchorPoint = anchor or self.Root.AnchorPoint
		self.Root.Position = position
	end
	return self
end

-- every `interval` seconds call producer() and show what it returns
function Stats:Poll(key, interval, producer)
	assert(type(producer) == "function", "Poll needs a function")
	local delay = math.max(0.1, tonumber(interval) or 1)
	task.spawn(function()
		while not self._destroyed do
			local ok, result = pcall(producer)
			if ok and result ~= nil then self:Set(key, result) end
			task.wait(delay)
		end
	end)
	return self
end

function Stats:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	for _, c in ipairs(self._connections) do pcall(function() c:Disconnect() end) end
	self._connections = {}
	if self.Gui then pcall(function() self.Gui:Destroy() end) end
	self.Gui, self.Root, self.Header, self.Body, self.Title = nil, nil, nil, nil, nil
	if self._id and genv.__CinderStats and genv.__CinderStats[self._id] == self then genv.__CinderStats[self._id] = nil end
end

--------------------------------------------------------------------------------------------------
-- Library:CreateWindow
--------------------------------------------------------------------------------------------------
function Library:CreateWindow(opts)
	opts = table.clone(opts or {})
	-- Linoria / Feral option names
	if typeof(opts.Size) == "UDim2" then
		if opts.Width == nil then opts.Width = opts.Size.X.Offset end
		if opts.Height == nil then opts.Height = opts.Size.Y.Offset end
	end
	opts.Size = nil
	if opts.AutoShow ~= nil and opts.StartOpen == nil then opts.StartOpen = opts.AutoShow end
	if opts.Title == nil and opts.Name ~= nil then opts.Title = opts.Name end
	if opts.Theme then
		for k, v in pairs(opts.Theme) do Theme[k] = v end
	end
	local self = setmetatable({}, Window)
	self._opt = {}
	for k, v in pairs(Library.Defaults) do self._opt[k] = v end
	for k, v in pairs(opts) do
		if v ~= nil and k ~= "Theme" then self._opt[k] = v end
	end
	self._tabs, self._tabCount, self._controls, self._values = {}, 0, {}, {}
	self.Toggles, self.Options, self._keypickers = {}, {}, {}
	self._listeners, self._connections = {}, {}
	self._open, self._destroyed = false, false
	self.Folder = tostring(self._opt.Folder):gsub("[^%w%-_ ]", "")
	if self.Folder == "" then self.Folder = "UiLib" end
	self.User = LocalPlayer and LocalPlayer.Name:gsub("[^%w%-_ ]", "") or "Player"

	genv.__UiLibWindows = genv.__UiLibWindows or {}
	local reg = genv.__UiLibWindows
	if reg[self.Folder] and reg[self.Folder] ~= self then pcall(function() reg[self.Folder]:Destroy() end) end
	reg[self.Folder] = self
	self._registry = reg

	Library.Unloaded = false
	Library._last = self
	Library.Toggles, Library.Options = self.Toggles, self.Options
	genv.Toggles, genv.Options = self.Toggles, self.Options

	self:_build()
	Library.Holder = self.Gui
	return self
end

-- Linoria / Feral style helpers on the library itself ------------------------------------------------------
genv.__UiLibLibrary = Library
Library._unloadCallbacks = {}
Library.Unloaded = false
Library.Toggles, Library.Options = {}, {}

function Library:OnUnload(fn)
	table.insert(Library._unloadCallbacks, fn)
end

function Library:Unload()
	if Library.Unloaded then return end
	Library.Unloaded = true
	for _, fn in ipairs(Library._unloadCallbacks) do pcall(fn) end
	Library._unloadCallbacks = {}
	for _, p in ipairs(table.clone(Library._stats)) do pcall(function() p:Destroy() end) end
	local reg = genv.__UiLibWindows
	if type(reg) == "table" then
		for _, w in pairs(table.clone(reg)) do pcall(function() w:Destroy() end) end
	end
end
Library.Exit = Library.Unload

function Library:Notify(a, b, c)
	local w = Library._last
	if not w or w._destroyed then return end
	if type(b) == "string" then
		w:Notify(a, b, c)
	else
		w:Notify(w._opt.Title, a, b)
	end
end


Library.FormatNumber = formatNumber
return Library

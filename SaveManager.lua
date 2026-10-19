--[[
    SaveManager for UiLib  

    local SaveManager = loadstring(game:HttpGet(".../SaveManager.lua"))()
    local SM = SaveManager.new(Window, { Folder = "MyHub" })
    SM:SetIgnore({ "Some.Key" })         -- keys that must never be saved
    SM:BuildConfigTab("Config")          -- or SM:BuildConfigTab(existingTab)
    SM:LoadAutoload()                    -- call at the END of your script

    Linoria / Feral style (no .new needed, uses the last window you created):
        SaveManager:SetLibrary(Library)
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({ "Key1", "Key2" })
        SaveManager:SetFolder("MyHub/Game")
        SaveManager:BuildConfigSection(tabOrSubTabOrGroupbox)
        SaveManager:LoadAutoloadConfig()

    Files:   <Folder>/<name>.json              configs
             <Folder>/autoload_<Username>.txt  per-account autoload (falls back to <Folder>/autoload.txt)
    No filesystem in the executor -> configs are kept in memory for the session.
]]

local cloneref = cloneref or function(i) return i end
local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local genv = (getgenv and getgenv()) or _G

local fs = {
	write = writefile, read = readfile, isFile = isfile, isFolder = isfolder,
	makeFolder = makefolder, list = listfiles, delete = delfile,
}
local hasFS = type(fs.write) == "function" and type(fs.read) == "function"
	and type(fs.isFile) == "function" and type(fs.list) == "function"

local function clean(name)
	return (string.gsub(string.gsub(string.gsub(tostring(name or ""), "[^%w%-_ ]", ""), "^%s+", ""), "%s+$", ""))
end

local function cleanPath(name)
	local parts = {}
	for part in string.gmatch(tostring(name or ""), "[^/\\]+") do
		part = clean(part)
		if part ~= "" then parts[#parts + 1] = part end
	end
	return table.concat(parts, "/")
end

local function ensureFolder(path)
	if type(fs.makeFolder) ~= "function" then return end
	local cur
	for part in string.gmatch(path, "[^/]+") do
		cur = cur and (cur .. "/" .. part) or part
		local ok, exists = pcall(fs.isFolder, cur)
		if not ok or not exists then pcall(fs.makeFolder, cur) end
	end
end

-- value (de)serialisation: JSON can't hold Color3 ------------------------------------------------
local function encode(v)
	if typeof(v) == "Color3" then return { __t = "Color3", r = v.R, g = v.G, b = v.B } end
	return v
end

local function decode(v)
	if type(v) == "table" and v.__t == "Color3" then return Color3.new(v.r, v.g, v.b) end
	return v
end

local SaveManager = {}
SaveManager.__index = SaveManager

function SaveManager.new(window, opts)
	opts = opts or {}
	local self = setmetatable({}, SaveManager)
	self.Window = window
	self.Folder = cleanPath(opts.Folder or window.Folder or "UiLib")
	if self.Folder == "" then self.Folder = "UiLib" end
	self.User = clean(Players.LocalPlayer and Players.LocalPlayer.Name or "Player")
	self.Ignore = {}
	self.Quiet = opts.Quiet == true
	if opts.Ignore then self:SetIgnore(opts.Ignore) end

	genv.__SaveManagerMemory = genv.__SaveManagerMemory or {}
	genv.__SaveManagerMemory[self.Folder] = genv.__SaveManagerMemory[self.Folder] or { configs = {}, autoload = {} }
	self._mem = genv.__SaveManagerMemory[self.Folder]
	return self
end

function SaveManager:SetIgnore(list)
	for _, k in ipairs(list) do self.Ignore[tostring(k)] = true end
	return self
end

function SaveManager:_say(title, text)
	if self.Quiet then return end
	print("[SaveManager] " .. title .. ": " .. text)
	pcall(function() self.Window:Notify(title, text, 3) end)
end

function SaveManager:_path(name) return self.Folder .. "/" .. clean(name) .. ".json" end
function SaveManager:_autoPath() return self.Folder .. "/autoload_" .. self.User .. ".txt" end
function SaveManager:_sharedAutoPath() return self.Folder .. "/autoload.txt" end

function SaveManager:List()
	local out, seen = {}, {}
	if hasFS then
		ensureFolder(self.Folder)
		local ok, files = pcall(fs.list, self.Folder)
		if ok and type(files) == "table" then
			for _, f in ipairs(files) do
				local n = string.match(f, "([^/\\]+)%.json$")
				if n and not seen[n] then
					seen[n] = true
					out[#out + 1] = n
				end
			end
		end
	else
		for k in pairs(self._mem.configs) do out[#out + 1] = k end
	end
	table.sort(out)
	return out
end

function SaveManager:Save(name)
	name = clean(name)
	if name == "" then return false, "a config needs a name" end
	local values = {}
	for k, v in pairs(self.Window:Values(true)) do
		if not self.Ignore[k] then values[k] = encode(v) end
	end
	local ok, json = pcall(function()
		return HttpService:JSONEncode({ __ui = "UiLib", __user = self.User, values = values })
	end)
	if not ok then return false, "could not encode: " .. tostring(json) end
	if hasFS then
		ensureFolder(self.Folder)
		local ok2, err = pcall(fs.write, self:_path(name), json)
		if not ok2 then return false, tostring(err) end
	else
		self._mem.configs[name] = json
	end
	return true, name
end

function SaveManager:Load(name)
	name = clean(name)
	if name == "" then return false, "a config needs a name" end
	local json
	if hasFS then
		local ok, exists = pcall(fs.isFile, self:_path(name))
		if not ok or not exists then return false, "no config named '" .. name .. "'" end
		local ok2, data = pcall(fs.read, self:_path(name))
		if not ok2 then return false, tostring(data) end
		json = data
	else
		json = self._mem.configs[name]
		if not json then return false, "no config named '" .. name .. "'" end
	end
	local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
	if not ok or type(data) ~= "table" or type(data.values) ~= "table" then
		return false, "'" .. name .. "' isn't a valid config"
	end
	self.Window.Loading = true
	local applied, skipped = 0, 0
	for k, v in pairs(data.values) do
		local ctrl = self.Window._controls[k]
		if ctrl and ctrl.def.save ~= false and not self.Ignore[k] then
			self.Window:Set(k, decode(v))
			applied += 1
		else
			skipped += 1
		end
	end
	self.Window.Loading = false
	if skipped > 0 then warn("[SaveManager] loaded '" .. name .. "' (" .. applied .. " applied, " .. skipped .. " unknown keys ignored)") end
	return true, name
end

function SaveManager:Delete(name)
	name = clean(name)
	if name == "" then return false, "a config needs a name" end
	if hasFS then
		if type(fs.delete) ~= "function" then return false, "this executor can't delete files" end
		local ok, err = pcall(fs.delete, self:_path(name))
		if not ok then return false, tostring(err) end
	else
		self._mem.configs[name] = nil
	end
	if self:GetAutoload() == name then self:ClearAutoload() end
	return true, name
end

function SaveManager:SetAutoload(name)
	name = clean(name)
	if name == "" then return false end
	if hasFS then
		ensureFolder(self.Folder)
		pcall(fs.write, self:_autoPath(), name)
	else
		self._mem.autoload[self.User] = name
	end
	return true, name
end

function SaveManager:ClearAutoload()
	if hasFS then
		ensureFolder(self.Folder)
		pcall(fs.write, self:_autoPath(), "")
	else
		self._mem.autoload[self.User] = false
	end
end

function SaveManager:GetAutoload()
	if hasFS then
		for _, p in ipairs({ self:_autoPath(), self:_sharedAutoPath() }) do
			local ok, exists = pcall(fs.isFile, p)
			if ok and exists then
				local ok2, data = pcall(fs.read, p)
				if ok2 then
					local n = clean(data)
					if n ~= "" then return n end
					if p == self:_autoPath() then return nil end -- explicitly cleared for this account
				end
			end
		end
		return nil
	end
	local v = self._mem.autoload[self.User]
	return v or nil
end

function SaveManager:LoadAutoload()
	local name = self:GetAutoload()
	if not name then return false, "No autoload configured." end
	local ok, res = self:Load(name)
	if ok then self:_say("Autoload", "loaded '" .. res .. "'") end
	return ok, res
end

-- ready-made UI ----------------------------------------------------------------------------------
-- cfg / auto / danger are containers (tab, sub tab or groupbox); headings = true puts section headings between them
function SaveManager:_populate(cfg, auto, danger, headings)
	local win = self.Window

	if headings then cfg:AddSection("Configs") end
	cfg:AddDropdown({ key = "__sm.selected", label = "Config", options = self:List(), save = false, path = false })
	cfg:AddInput({ key = "__sm.name", label = "Name", placeholder = "new config name", save = false, path = false })

	local function refresh()
		win:SetOptions("__sm.selected", self:List())
	end
	local function target()
		local typed = clean(win:Get("__sm.name"))
		if typed ~= "" then return typed end
		return clean(win:Get("__sm.selected"))
	end

	cfg:AddButton({ label = "Save", callback = function()
		local ok, res = self:Save(target())
		self:_say(ok and "Saved" or "Save failed", tostring(res))
		if ok then
			refresh()
			win:Set("__sm.selected", res, true)
			win:Set("__sm.name", "", true)
		end
	end })
	cfg:AddButton({ label = "Load", colour = Color3.fromRGB(90, 170, 110), callback = function()
		local ok, res = self:Load(clean(win:Get("__sm.selected")))
		self:_say(ok and "Loaded" or "Load failed", tostring(res))
	end })
	cfg:AddButton({ label = "Refresh list", colour = win.Theme and win.Theme.Neutral or Color3.fromRGB(60, 60, 78), callback = refresh })

	if headings then auto:AddSection("Autoload") end
	auto:AddLabel("Every account can use a different autoload config.")
	auto:AddButton({ label = "Set as autoload", colour = Color3.fromRGB(60, 60, 78), callback = function()
		local n = clean(win:Get("__sm.selected"))
		if n == "" then self:_say("Autoload", "pick a config first") return end
		self:SetAutoload(n)
		self:_say("Autoload", "'" .. n .. "' will load on start")
	end })
	auto:AddButton({ label = "Clear autoload", colour = Color3.fromRGB(60, 60, 78), callback = function()
		self:ClearAutoload()
		self:_say("Autoload", "cleared")
	end })

	if headings then danger:AddSection("Danger") end
	danger:AddButton({ label = "Delete selected", colour = Color3.fromRGB(235, 51, 90), callback = function()
		local n = clean(win:Get("__sm.selected"))
		if n == "" then self:_say("Delete", "pick a config first") return end
		local ok, res = self:Delete(n)
		self:_say(ok and "Deleted" or "Delete failed", tostring(res))
		if ok then
			refresh()
			win:Set("__sm.selected", self:List()[1] or "", true)
		end
	end })

	local autoName = self:GetAutoload()
	if autoName then win:Set("__sm.selected", autoName, true) end
end

function SaveManager:BuildConfigTab(tabOrName)
	local win = self.Window
	local tab = tabOrName
	if tab == nil or type(tab) == "string" then
		tab = win:AddTab(tab or "Config")
	end
	self._tab = tab
	self:_populate(tab, tab, tab, true)
	return tab
end

-- Linoria / Feral style ------------------------------------------------------------------------------
-- These can be called on the module itself (SaveManager:SetFolder(...)); the first call that needs a window
-- turns the module into an instance bound to Library's most recent window.
local function ensure(self)
	if rawget(self, "Window") then return self end
	local lib = rawget(self, "Library") or genv.__UiLibLibrary
	local win = lib and lib._last
	assert(win, "SaveManager: create a window first (and call SaveManager:SetLibrary(Library))")
	local inst = SaveManager.new(win, { Folder = rawget(self, "_folder") })
	for k, v in pairs(inst) do rawset(self, k, v) end
	local pending = rawget(self, "_pendingIgnore")
	if pending then self:SetIgnore(pending) end
	return self
end

function SaveManager:SetLibrary(lib)
	rawset(self, "Library", lib)
	return self
end

function SaveManager:IgnoreThemeSettings()
	-- there are no theme controls in the menu, nothing to ignore
	return self
end

function SaveManager:SetIgnoreIndexes(list)
	if rawget(self, "Window") then
		self:SetIgnore(list)
	else
		local pending = rawget(self, "_pendingIgnore") or {}
		for _, k in ipairs(list) do pending[#pending + 1] = k end
		rawset(self, "_pendingIgnore", pending)
	end
	return self
end

function SaveManager:SetFolder(folder)
	folder = cleanPath(folder)
	if folder == "" then folder = "UiLib" end
	if rawget(self, "Window") then
		self.Folder = folder
		genv.__SaveManagerMemory = genv.__SaveManagerMemory or {}
		genv.__SaveManagerMemory[folder] = genv.__SaveManagerMemory[folder] or { configs = {}, autoload = {} }
		self._mem = genv.__SaveManagerMemory[folder]
	else
		rawset(self, "_folder", folder)
	end
	return self
end

-- target: a tab / sub tab (gets two groupboxes) or a groupbox (everything goes inside it)
function SaveManager:BuildConfigSection(target)
	ensure(self)
	if type(target) ~= "table" then
		return self:BuildConfigTab(target)
	end
	if type(target.AddGroupbox) == "function" then
		local left = target:AddGroupbox("Configs", "Left")
		local right = target:AddGroupbox("Autoload", "Right")
		self._tab = target
		self:_populate(left, right, right, false)
		return target
	end
	self:_populate(target, target, target, true)
	return target
end

function SaveManager:LoadAutoloadConfig()
	ensure(self)
	return self:LoadAutoload()
end

return SaveManager

--[[
    SaveManager for the Feral UI Library (Linoria-compatible API)

    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    SaveManager:SetFolder("MyHub/MyGame")
    SaveManager:BuildConfigSection(Tab)
    SaveManager:LoadAutoloadConfig()
]]

local HttpService = game:GetService("HttpService")
local env = (getgenv and getgenv()) or _G

local SaveManager = {
    Folder  = "FeralHub",
    Ignore  = {},
    Library = nil,
}

SaveManager.Parser = {
    Toggle = {
        Save = function(idx, obj) return { type = "Toggle", idx = idx, value = obj.Value } end,
        Load = function(idx, data) local o = env.Toggles[idx]; if o then o:SetValue(data.value) end end,
    },
    Slider = {
        Save = function(idx, obj) return { type = "Slider", idx = idx, value = tostring(obj.Value) } end,
        Load = function(idx, data) local o = env.Options[idx]; if o then o:SetValue(data.value) end end,
    },
    Dropdown = {
        Save = function(idx, obj) return { type = "Dropdown", idx = idx, value = obj.Value, multi = obj.Multi } end,
        Load = function(idx, data) local o = env.Options[idx]; if o then o:SetValue(data.value) end end,
    },
    Input = {
        Save = function(idx, obj) return { type = "Input", idx = idx, text = obj.Value } end,
        Load = function(idx, data)
            local o = env.Options[idx]
            if o and type(data.text) == "string" then o:SetValue(data.text) end
        end,
    },
    KeyPicker = {
        Save = function(idx, obj) return { type = "KeyPicker", idx = idx, mode = obj.Mode, key = obj.Value } end,
        Load = function(idx, data) local o = env.Options[idx]; if o then o:SetValue({ data.key, data.mode }) end end,
    },
    ColorPicker = {
        Save = function(idx, obj) return { type = "ColorPicker", idx = idx, value = obj.Value:ToHex() } end,
        Load = function(idx, data)
            local o = env.Options[idx]
            if not o then return end
            local ok, c = pcall(Color3.fromHex, data.value)
            if ok then o:SetValueRGB(c) end
        end,
    },
}

local function SafeFolder(path)
    if not isfolder(path) then makefolder(path) end
end

function SaveManager:SetIgnoreIndexes(list)
    for _, key in ipairs(list) do self.Ignore[key] = true end
end

function SaveManager:IgnoreThemeSettings()
    self:SetIgnoreIndexes({ "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", "ThemeManager_ThemeList", "ThemeManager_CustomThemeList", "ThemeManager_CustomThemeName" })
end

function SaveManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
end

function SaveManager:SetLibrary(library)
    self.Library = library
end

function SaveManager:BuildFolderTree()
    local parts = string.split(self.Folder, "/")
    local path = ""
    for _, p in ipairs(parts) do
        path = path == "" and p or (path .. "/" .. p)
        SafeFolder(path)
    end
    SafeFolder(self.Folder .. "/settings")
end

function SaveManager:Save(name)
    if not name or name:gsub(" ", "") == "" then return false, "no config file is selected" end

    local data = { objects = {} }
    for idx, toggle in pairs(env.Toggles) do
        if not self.Ignore[idx] then table.insert(data.objects, self.Parser.Toggle.Save(idx, toggle)) end
    end
    for idx, option in pairs(env.Options) do
        local parser = self.Parser[option.Type]
        if parser and not self.Ignore[idx] then table.insert(data.objects, parser.Save(idx, option)) end
    end

    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not ok then return false, "failed to encode data" end

    local wrote, err = pcall(writefile, self.Folder .. "/settings/" .. name .. ".json", encoded)
    if not wrote then return false, "failed to write file: " .. tostring(err) end
    return true
end

function SaveManager:Load(name)
    if not name or name:gsub(" ", "") == "" then return false, "no config file is selected" end

    local file = self.Folder .. "/settings/" .. name .. ".json"
    if not isfile(file) then return false, "invalid file" end

    local ok, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(file))
    if not ok then return false, "decode error" end

    for _, obj in ipairs(decoded.objects) do
        local parser = self.Parser[obj.type]
        if parser and not self.Ignore[obj.idx] then
            task.spawn(parser.Load, obj.idx, obj)
        end
    end
    return true
end

function SaveManager:Delete(name)
    if not name or name:gsub(" ", "") == "" then return false, "no config file is selected" end
    local file = self.Folder .. "/settings/" .. name .. ".json"
    if not isfile(file) then return false, "invalid file" end
    local ok, err = pcall(delfile, file)
    if not ok then return false, "delete file error: " .. tostring(err) end
    return true
end

function SaveManager:RefreshConfigList()
    local ok, list = pcall(listfiles, self.Folder .. "/settings")
    if not ok then return {} end
    local out = {}
    for _, file in ipairs(list) do
        file = tostring(file):gsub("\\", "/")
        local name = file:match("([^/]+)%.json$")
        if name then table.insert(out, name) end
    end
    table.sort(out)
    return out
end

function SaveManager:GetAutoloadConfig()
    local path = self.Folder .. "/settings/autoload.txt"
    if isfile(path) then return readfile(path) end
    return "none"
end

function SaveManager:SaveAutoloadConfig(name)
    local ok, err = pcall(writefile, self.Folder .. "/settings/autoload.txt", name)
    if not ok then return false, "write file error: " .. tostring(err) end
    return true
end

function SaveManager:LoadAutoloadConfig()
    local path = self.Folder .. "/settings/autoload.txt"
    if not isfile(path) then return end
    local name = readfile(path)
    local ok, err = self:Load(name)
    if not ok then
        return self.Library:Notify("Failed to load autoload config: " .. tostring(err))
    end
    self.Library:Notify(string.format("Auto loaded config %q", name))
end

function SaveManager:BuildConfigSection(tab)
    assert(self.Library, "Must set SaveManager.Library")
    local Library = self.Library

    local section = tab:AddRightGroupbox("Configuration")

    section:AddInput("SaveManager_ConfigName", { Text = "Config name" })
    section:AddDropdown("SaveManager_ConfigList", { Text = "Config list", Values = self:RefreshConfigList(), AllowNull = true })
    section:AddDivider()

    section:AddButton("Create config", function()
        local name = env.Options.SaveManager_ConfigName.Value
        if name:gsub(" ", "") == "" then return Library:Notify("Invalid config name (empty)", 2) end
        local ok, err = self:Save(name)
        if not ok then return Library:Notify("Failed to save config: " .. err) end
        Library:Notify(string.format("Created config %q", name))
        env.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
        env.Options.SaveManager_ConfigList:SetValue(nil)
    end):AddButton("Load config", function()
        local name = env.Options.SaveManager_ConfigList.Value
        local ok, err = self:Load(name)
        if not ok then return Library:Notify("Failed to load config: " .. err) end
        Library:Notify(string.format("Loaded config %q", name))
    end)

    section:AddButton("Overwrite config", function()
        local name = env.Options.SaveManager_ConfigList.Value
        local ok, err = self:Save(name)
        if not ok then return Library:Notify("Failed to overwrite config: " .. err) end
        Library:Notify(string.format("Overwrote config %q", name))
    end):AddButton("Delete config", function()
        local name = env.Options.SaveManager_ConfigList.Value
        local ok, err = self:Delete(name)
        if not ok then return Library:Notify("Failed to delete config: " .. err) end
        Library:Notify(string.format("Deleted config %q", name))
        env.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
        env.Options.SaveManager_ConfigList:SetValue(nil)
    end)

    section:AddButton("Refresh list", function()
        env.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
        env.Options.SaveManager_ConfigList:SetValue(nil)
    end)

    local autoLabel = section:AddLabel("Current autoload config: " .. self:GetAutoloadConfig(), true)
    section:AddButton("Set as autoload", function()
        local name = env.Options.SaveManager_ConfigList.Value
        local ok, err = self:SaveAutoloadConfig(name)
        if not ok then return Library:Notify("Failed to set autoload config: " .. err) end
        autoLabel:SetText("Current autoload config: " .. name)
        Library:Notify(string.format("Set %q to auto load", name))
    end)

    self:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
end

SaveManager:BuildFolderTree()

return SaveManager

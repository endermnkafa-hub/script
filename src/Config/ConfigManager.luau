--!strict
local ConfigSchema = require("Config.ConfigSchema")
local HttpService = game:GetService("HttpService")
local Logger = require("Core.Logger")

local ConfigManager = {
    FileName = "4080_Hub_TSB_Config.json",
    Config = {},
    RegisteredUI = {},
}

-- Generate Default Config from Schema
for catName, catSchema in pairs(ConfigSchema) do
    ConfigManager.Config[catName] = {}
    for key, spec in pairs(catSchema) do
        ConfigManager.Config[catName][key] = spec.Default
    end
end

local function SerializeValue(val: any): any
    if typeof(val) == "Color3" then
        return { __type = "Color3", R = val.R, G = val.G, B = val.B }
    elseif typeof(val) == "EnumItem" then
        return { __type = "EnumItem", EnumType = tostring(val.EnumType), Name = val.Name }
    elseif type(val) == "table" then
        local t = {}
        for k, v in pairs(val) do t[tostring(k)] = SerializeValue(v) end
        return t
    else
        return val
    end
end

local function DeserializeValue(val: any): any
    if type(val) == "table" then
        if val.__type == "Color3" then
            return Color3.new(val.R or 0, val.G or 0, val.B or 0)
        elseif val.__type == "EnumItem" then
            local enumTypeStr = val.EnumType or ""
            local enumName = val.Name or ""
            if enumTypeStr:find("KeyCode") and Enum.KeyCode[enumName] then
                return Enum.KeyCode[enumName]
            elseif enumTypeStr:find("UserInputType") and Enum.UserInputType[enumName] then
                return Enum.UserInputType[enumName]
            end
            return val
        else
            local t = {}
            for k, v in pairs(val) do t[k] = DeserializeValue(v) end
            return t
        end
    else
        return val
    end
end

local function DeepMerge(target: any, source: any)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" and not v.__type then
            DeepMerge(target[k], v)
        else
            target[k] = v
        end
    end
end

function ConfigManager:Save(): (boolean, string?)
    if typeof(writefile) ~= "function" then
        return false, "Executor writefile API not supported"
    end
    local ok, err = pcall(function()
        local dataToSave = {}
        for cat, val in pairs(self.Config) do
            dataToSave[cat] = SerializeValue(val)
        end
        local json = HttpService:JSONEncode(dataToSave)
        writefile(self.FileName, json)
    end)
    if ok then Logger:Info("Config", "Saved config successfully.") end
    return ok, err
end

function ConfigManager:Load(): (boolean, string?)
    if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
        return false, "Executor readfile/isfile API not supported"
    end
    if not isfile(self.FileName) then
        return false, "Config file not found"
    end
    local ok, err = pcall(function()
        local raw = readfile(self.FileName)
        local rawData = HttpService:JSONDecode(raw)
        local decoded = DeserializeValue(rawData)
        DeepMerge(self.Config, decoded)
        self:RefreshUI()
    end)
    if ok then Logger:Info("Config", "Loaded config successfully.") end
    return ok, err
end

function ConfigManager:RefreshUI()
    for _, item in ipairs(self.RegisteredUI) do
        if item.Getter and item.Setter then
            pcall(function()
                local val = item.Getter()
                if val ~= nil then item.Setter(val) end
            end)
        end
    end
end

function ConfigManager:Reset()
    if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(self.FileName) then
        pcall(function() delfile(self.FileName) end)
    end
    self:RefreshUI()
end

return ConfigManager

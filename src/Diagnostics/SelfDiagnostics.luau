--!strict
local Logger = require("Core.Logger")
local ServiceContainer = require("Core.ServiceContainer")

local SelfDiagnostics = {}

function SelfDiagnostics:RunHealthCheck(): (boolean, { [string]: string })
    local report = {}
    local isHealthy = true

    local requiredServices = { "Players", "RunService", "UserInputService", "Workspace", "HttpService" }
    for _, sName in ipairs(requiredServices) do
        local ok, s = pcall(function() return game:GetService(sName) end)
        if ok and s then
            report["Service_" .. sName] = "OK"
        else
            report["Service_" .. sName] = "MISSING"
            isHealthy = false
        end
    end

    -- Check executor capabilities
    report["API_writefile"] = (typeof(writefile) == "function") and "AVAILABLE" or "UNSUPPORTED"
    report["API_hookmetamethod"] = (typeof(hookmetamethod) == "function") and "AVAILABLE" or "UNSUPPORTED"
    report["API_Drawing"] = (typeof(Drawing) == "table" and Drawing.new ~= nil) and "AVAILABLE" or "UNSUPPORTED"

    Logger:Info("SelfDiagnostics", string.format("Health Check Complete. Status: %s", isHealthy and "HEALTHY" or "DEGRADED"))
    return isHealthy, report
end

return SelfDiagnostics

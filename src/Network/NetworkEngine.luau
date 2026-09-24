--!strict
local EventBus = require("Core.EventBus")
local Logger = require("Core.Logger")
local RemoteResolver = require("Network.RemoteResolver")

local NetworkEngine = {
    OutgoingHooked = false,
    PacketCount = 0,
    LastPacketTick = 0,
    LastGoal = nil :: string?,
}

function NetworkEngine:Init()
    pcall(function()
        if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                local args = {...}

                if method == "FireServer" and self:IsA("RemoteEvent") then
                    local name = self.Name:lower()
                    if name:find("comm") or name:find("combat") or name:find("action") then
                        NetworkEngine.PacketCount += 1
                        NetworkEngine.LastPacketTick = os.clock()

                        if type(args[1]) == "table" and args[1].Goal then
                            NetworkEngine.LastGoal = tostring(args[1].Goal)
                            EventBus:Publish("Network.OutgoingGoal", args[1].Goal, args[1])
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
            self.OutgoingHooked = true
            Logger:Info("NetworkEngine", "Metamethod hook initialized successfully.")
        end
    end)
end

function NetworkEngine:SendAction(goalName: string, payload: any?): boolean
    local remote = RemoteResolver:Resolve("Communicate")
    if remote then
        local data = payload or {}
        data.Goal = goalName
        local ok = pcall(function() remote:FireServer(data) end)
        return ok
    end
    return false
end

return NetworkEngine

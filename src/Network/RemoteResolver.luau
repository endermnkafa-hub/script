--!strict
local Logger = require("Core.Logger")

local RemoteResolver = {
    _cache = {} :: { [string]: RemoteEvent | RemoteFunction },
}

function RemoteResolver:Resolve(namePattern: string): RemoteEvent?
    if self._cache[namePattern] and (self._cache[namePattern] :: Instance).Parent then
        return self._cache[namePattern] :: RemoteEvent
    end

    local char = game:GetService("Players").LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("RemoteEvent") and child.Name:lower():find(namePattern:lower()) then
                self._cache[namePattern] = child
                return child
            end
        end
    end

    local rep = game:GetService("ReplicatedStorage")
    for _, desc in ipairs(rep:GetDescendants()) do
        if desc:IsA("RemoteEvent") and desc.Name:lower():find(namePattern:lower()) then
            self._cache[namePattern] = desc
            return desc
        end
    end

    return nil
end

return RemoteResolver

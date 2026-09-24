--!strict
local ServiceContainer = {}
ServiceContainer.__index = ServiceContainer

function ServiceContainer.new()
    local self = setmetatable({
        _services = {},
        _factories = {},
        _resolving = {},
    }, ServiceContainer)
    return self
end

function ServiceContainer:Register(name: string, instanceOrFactory: any)
    assert(name and instanceOrFactory, "ServiceContainer:Register requires name and instance/factory")
    if type(instanceOrFactory) == "function" then
        self._factories[name] = instanceOrFactory
    else
        self._services[name] = instanceOrFactory
    end
    return instanceOrFactory
end

function ServiceContainer:Get(name: string): any
    if self._services[name] then
        return self._services[name]
    end

    if self._factories[name] then
        if self._resolving[name] then
            error(string.format("Circular dependency detected while resolving service '%s'!", name))
        end

        self._resolving[name] = true
        local factory = self._factories[name]
        local instance = factory(self)
        self._resolving[name] = nil

        self._services[name] = instance
        self._factories[name] = nil
        return instance
    end

    error(string.format("Service '%s' is not registered in ServiceContainer!", tostring(name)))
end

function ServiceContainer:Has(name: string): boolean
    return self._services[name] ~= nil or self._factories[name] ~= nil
end

function ServiceContainer:BuildGraph(): { string }
    local graph = {}
    for name, _ in pairs(self._services) do table.insert(graph, name) end
    for name, _ in pairs(self._factories) do table.insert(graph, name) end
    table.sort(graph)
    return graph
end

return ServiceContainer

--!strict
local ServiceContainer = {
    _services = {} :: { [string]: any },
}

function ServiceContainer:Register(name: string, serviceInstance: any)
    assert(name and serviceInstance, "ServiceContainer:Register requires name and instance")
    self._services[name] = serviceInstance
    return serviceInstance
end

function ServiceContainer:Get(name: string): any
    local service = self._services[name]
    if not service then
        error(string.format("Service '%s' is not registered in ServiceContainer!", tostring(name)))
    end
    return service
end

function ServiceContainer:Has(name: string): boolean
    return self._services[name] ~= nil
end

function ServiceContainer:BuildGraph(): { string }
    local graph = {}
    for name, _ in pairs(self._services) do
        table.insert(graph, name)
    end
    table.sort(graph)
    return graph
end

return ServiceContainer

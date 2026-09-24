--!strict
local ServiceContainer = {}
ServiceContainer.__index = ServiceContainer

export type ServiceEntry = {
    Name: string,
    Instance: any?,
    Factory: ((container: any) -> any)?,
    Dependencies: { string },
    Resolved: boolean,
}

function ServiceContainer.new()
    local self = setmetatable({
        _services = {},
        _factories = {},
        _dependencies = {}, -- Adjacency list for real DAG
        _resolving = {},
    }, ServiceContainer)
    return self
end

function ServiceContainer:Register(name: string, instanceOrFactory: any, dependencies: { string }?)
    assert(name and instanceOrFactory, "ServiceContainer:Register requires name and instance/factory")
    local deps = dependencies or {}
    self._dependencies[name] = deps

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
            error(string.format("[ServiceContainer] Circular dependency detected while resolving service '%s'!", name))
        end

        self._resolving[name] = true
        local factory = self._factories[name]
        local instance = factory(self)
        self._resolving[name] = nil

        self._services[name] = instance
        self._factories[name] = nil
        return instance
    end

    error(string.format("[ServiceContainer] Service '%s' is not registered!", tostring(name)))
end

function ServiceContainer:Has(name: string): boolean
    return self._services[name] ~= nil or self._factories[name] ~= nil
end

function ServiceContainer:BuildGraph(): { [string]: { string } }
    local graph = {}
    for name, deps in pairs(self._dependencies) do
        graph[name] = deps
    end
    return graph
end

function ServiceContainer:TopologicalSort(): ({ string }, boolean, string?)
    local visited = {}
    local recStack = {}
    local order = {}
    local hasCycle = false
    local cycleNode = nil

    local function dfs(node: string)
        if recStack[node] then
            hasCycle = true
            cycleNode = node
            return
        end
        if visited[node] then return end

        visited[node] = true
        recStack[node] = true

        local deps = self._dependencies[node] or {}
        for _, dep in ipairs(deps) do
            if self:Has(dep) then
                dfs(dep)
            end
        end

        recStack[node] = false
        table.insert(order, node)
    end

    for name, _ in pairs(self._dependencies) do
        if not visited[name] then
            dfs(name)
        end
    end

    return order, not hasCycle, cycleNode
end

function ServiceContainer:ResolveAllInOrder(): { string }
    local order, noCycles, cycleNode = self:TopologicalSort()
    if not noCycles then
        error(string.format("[ServiceContainer] Cannot initialize services due to circular dependency involving '%s'!", tostring(cycleNode)))
    end

    for _, sName in ipairs(order) do
        self:Get(sName)
    end
    return order
end

return ServiceContainer

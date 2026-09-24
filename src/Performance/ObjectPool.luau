--!strict
local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.new(factory: () -> any, resetFn: (any) -> (), initialSize: number?)
    local self = setmetatable({
        _factory = factory,
        _reset = resetFn,
        _pool = {},
    }, ObjectPool)

    for i = 1, (initialSize or 10) do
        table.insert(self._pool, factory())
    end
    return self
end

function ObjectPool:Acquire(): any
    if #self._pool > 0 then
        return table.remove(self._pool)
    else
        return self._factory()
    end
end

function ObjectPool:Release(obj: any)
    if self._reset then
        pcall(self._reset, obj)
    end
    table.insert(self._pool, obj)
end

return ObjectPool

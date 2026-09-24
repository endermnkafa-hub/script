--!strict
local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.new(factory: () -> any, resetFn: ((any) -> ())?, initialSize: number?)
    local self = setmetatable({
        _factory = factory,
        _reset = resetFn,
        _pool = {},
        Acquisitions = 0,
        Releases = 0,
    }, ObjectPool)

    for i = 1, (initialSize or 8) do
        table.insert(self._pool, factory())
    end
    return self
end

function ObjectPool:Acquire(): any
    self.Acquisitions += 1
    if #self._pool > 0 then
        return table.remove(self._pool)
    else
        return self._factory()
    end
end

function ObjectPool:Release(obj: any)
    self.Releases += 1
    if self._reset then
        pcall(self._reset, obj)
    end
    table.insert(self._pool, obj)
end

function ObjectPool:GetSize(): number
    return #self._pool
end

return ObjectPool

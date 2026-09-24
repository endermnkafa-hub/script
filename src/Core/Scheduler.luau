--!strict
local Scheduler = {
    _intervals = {
        Fast = 0,           -- Frame-rate bound (0s)
        Normal = 0.05,      -- 20 Hz
        Slow = 0.5,         -- 2 Hz
        Background = 2.0,   -- 0.5 Hz
    },
    _tasks = {} :: { [string]: { Category: string, Callback: (dt: number) -> (), LastRun: number, Enabled: boolean } },
}

function Scheduler:Register(name: string, category: string, callback: (dt: number) -> (), enabled: boolean?)
    self._tasks[name] = {
        Category = category or "Normal",
        Callback = callback,
        LastRun = 0,
        Enabled = enabled ~= false,
    }
end

function Scheduler:SetEnabled(name: string, enabled: boolean)
    if self._tasks[name] then
        self._tasks[name].Enabled = enabled
    end
end

function Scheduler:Step(dt: number)
    local now = os.clock()
    for name, taskItem in pairs(self._tasks) do
        if taskItem.Enabled then
            local interval = self._intervals[taskItem.Category] or 0.05
            if (now - taskItem.LastRun) >= interval then
                local taskDt = taskItem.LastRun == 0 and dt or (now - taskItem.LastRun)
                taskItem.LastRun = now
                pcall(taskItem.Callback, taskDt)
            end
        end
    end
end

return Scheduler

--!strict
local Signal = require("Core.Signal")

export type StateDefinition = {
    Priority: number?,
    OnEnter: ((self: any, prevState: string, ctx: any) -> ())?,
    OnUpdate: ((self: any, dt: number, ctx: any) -> ())?,
    OnExit: ((self: any, nextState: string, ctx: any) -> ())?,
    CanEnter: ((self: any, ctx: any) -> boolean)?,
    CanExit: ((self: any, ctx: any) -> boolean)?,
}

export type TransitionRule = {
    From: string | { string },
    To: string,
    Priority: number?,
    Condition: ((ctx: any) -> boolean)?,
}

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(initialState: string?, logger: any?)
    local self = setmetatable({
        CurrentState = initialState or "IDLE",
        PreviousState = "NONE",
        StateStartTime = os.clock(),
        TransitionsCount = 0,
        History = {},
        StateChanged = Signal.new(),
        _logger = logger,
        _states = {},
        _transitions = {},
        _priorities = {
            EMERGENCY_STOP = 100,
            SKY_ESCAPE     = 90,
            SKY_DODGE      = 80,
            VOID_KILL      = 70,
            MASS_BRING     = 60,
            BEHIND_TP      = 50,
            COMBAT         = 30,
            IDLE           = 0,
        },
    }, StateMachine)
    return self
end

function StateMachine:RegisterState(name: string, def: StateDefinition)
    self._states[name] = def
    if def.Priority then
        self._priorities[name] = def.Priority
    end
end

function StateMachine:RegisterTransition(fromState: string | { string }, toState: string, condition: ((ctx: any) -> boolean)?)
    local fromList = type(fromState) == "table" and fromState or { fromState }
    for _, f in ipairs(fromList) do
        local key = f .. "->" .. toState
        self._transitions[key] = {
            From = f,
            To = toState,
            Condition = condition,
        }
    end
end

function StateMachine:CanTransitionTo(targetState: string, ctx: any): boolean
    if self.CurrentState == targetState then return false end

    -- Emergency stop can always interrupt everything
    if targetState == "EMERGENCY_STOP" then return true end
    if self.CurrentState == "EMERGENCY_STOP" and targetState ~= "IDLE" then return false end

    local currentDef = self._states[self.CurrentState]
    if currentDef and currentDef.CanExit and not currentDef:CanExit(ctx) then
        return false
    end

    local currentPri = self._priorities[self.CurrentState] or 0
    local targetPri = self._priorities[targetState] or 0

    -- Strict Priority Enforcement: Higher priority states naturally block lower priority overrides
    if targetPri < currentPri and currentPri >= 70 then
        return false
    end

    -- Explicit Transition Rule Check (if defined)
    local transKey = self.CurrentState .. "->" .. targetState
    local transRule = self._transitions[transKey]
    if transRule and transRule.Condition then
        if not transRule.Condition(ctx) then
            return false
        end
    end

    local targetDef = self._states[targetState]
    if targetDef and targetDef.CanEnter and not targetDef:CanEnter(ctx) then
        return false
    end

    return true
end

function StateMachine:TransitionTo(newState: string, ctx: any, force: boolean?): boolean
    if not force and not self:CanTransitionTo(newState, ctx) then
        return false
    end

    local oldState = self.CurrentState
    local oldDef = self._states[oldState]
    if oldDef and oldDef.OnExit then
        if self._logger then
            self._logger:SafeCall("FSM.OnExit", oldDef.OnExit, oldDef, newState, ctx)
        else
            pcall(oldDef.OnExit, oldDef, newState, ctx)
        end
    end

    table.insert(self.History, 1, oldState)
    if #self.History > 20 then table.remove(self.History) end

    self.PreviousState = oldState
    self.CurrentState = newState
    self.StateStartTime = os.clock()
    self.TransitionsCount += 1

    local newDef = self._states[newState]
    if newDef and newDef.OnEnter then
        if self._logger then
            self._logger:SafeCall("FSM.OnEnter", newDef.OnEnter, newDef, oldState, ctx)
        else
            pcall(newDef.OnEnter, newDef, oldState, ctx)
        end
    end

    self.StateChanged:Fire(newState, oldState)
    return true
end

function StateMachine:Rollback(ctx: any): boolean
    if #self.History > 0 then
        local prev = table.remove(self.History, 1)
        return self:TransitionTo(prev, ctx, true)
    end
    return false
end

function StateMachine:Update(dt: number, ctx: any)
    local def = self._states[self.CurrentState]
    if def and def.OnUpdate then
        if self._logger then
            self._logger:SafeCall("FSM.OnUpdate", def.OnUpdate, def, dt, ctx)
        else
            pcall(def.OnUpdate, def, dt, ctx)
        end
    end
end

return StateMachine

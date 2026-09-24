--!strict
local Signal = require("Core.Signal")
local Logger = require("Core.Logger")

export type StateDefinition = {
    OnEnter: ((self: any, prevState: string, ctx: any) -> ())?,
    OnUpdate: ((self: any, dt: number, ctx: any) -> ())?,
    OnExit: ((self: any, nextState: string, ctx: any) -> ())?,
    CanEnter: ((self: any, ctx: any) -> boolean)?,
    CanExit: ((self: any, ctx: any) -> boolean)?,
    Priority: number?,
}

local StateMachine = {
    CurrentState = "IDLE",
    PreviousState = "NONE",
    StateStartTime = os.clock(),
    TransitionsCount = 0,
    History = {} :: { string },
    StateChanged = Signal.new(),
    _states = {} :: { [string]: StateDefinition },
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
}

function StateMachine:RegisterState(name: string, def: StateDefinition)
    self._states[name] = def
    if def.Priority then
        self._priorities[name] = def.Priority
    end
end

function StateMachine:CanTransitionTo(targetState: string, ctx: any): boolean
    if self.CurrentState == targetState then return false end

    local currentDef = self._states[self.CurrentState]
    if currentDef and currentDef.CanExit and not currentDef:CanExit(ctx) then
        return false
    end

    local currentPri = self._priorities[self.CurrentState] or 0
    local targetPri = self._priorities[targetState] or 0

    if targetState == "EMERGENCY_STOP" then return true end
    if self.CurrentState == "EMERGENCY_STOP" and targetState ~= "IDLE" then
        return false
    end

    -- Strict Priority Enforcement: lower priority cannot preempt higher priority unless force transition!
    if targetPri < currentPri and currentPri >= 70 then
        return false
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
        Logger:SafeCall("FSM.OnExit", oldDef.OnExit, oldDef, newState, ctx)
    end

    table.insert(self.History, 1, oldState)
    if #self.History > 20 then table.remove(self.History) end

    self.PreviousState = oldState
    self.CurrentState = newState
    self.StateStartTime = os.clock()
    self.TransitionsCount += 1

    local newDef = self._states[newState]
    if newDef and newDef.OnEnter then
        Logger:SafeCall("FSM.OnEnter", newDef.OnEnter, newDef, oldState, ctx)
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
        Logger:SafeCall("FSM.OnUpdate", def.OnUpdate, def, dt, ctx)
    end
end

return StateMachine

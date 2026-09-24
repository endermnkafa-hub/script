--!strict
local EventBus = require("Core.EventBus")
local Cache = require("Performance.Cache")

export type EnemyData = {
    Cooldowns: { [string]: number },
    IsRagdoll: boolean,
    RagdollStart: number,
    WakeupTime: number,
    IsBlocking: boolean,
    LastSkill: string,
    LastSkillTick: number,
}

local EnemyState = {
    _states = {} :: { [Player]: EnemyData },
    Profiles = {
        Saitama = { NormalPunch = 12, Consecutive = 15, Shove = 14, Uppercut = 16 },
        Garou = { FlowingWater = 14, LethalWhirlwind = 15, HuntersGrasp = 18, PreysPeril = 16 },
        Sonic = { FlashStrike = 12, WhirlwindKick = 14, Scatter = 16, Shuriken = 15 },
        Suiryu = { VanishingKick = 14, HeadFirst = 15, SweepingKick = 16, FistBarrage = 18 },
        Universal = { Skill1 = 14, Skill2 = 15, Skill3 = 16, Skill4 = 16 },
    }
}

function EnemyState:Get(player: Player): EnemyData
    local data = self._states[player]
    if not data then
        data = {
            Cooldowns = {},
            IsRagdoll = false,
            RagdollStart = 0,
            WakeupTime = 0,
            IsBlocking = false,
            LastSkill = "None",
            LastSkillTick = 0,
        }
        self._states[player] = data
    end
    return data
end

function EnemyState:Update(player: Player)
    local entry = Cache:GetPlayerEntry(player)
    if not entry or not entry.IsAlive then return end

    local data = self:Get(player)
    local hum = entry.Humanoid
    local hState = hum:GetState()
    local isRag = (hState == Enum.HumanoidStateType.Physics or hState == Enum.HumanoidStateType.Ragdoll)

    if isRag and not data.IsRagdoll then
        data.IsRagdoll = true
        data.RagdollStart = os.clock()
        data.WakeupTime = data.RagdollStart + 2.25
        EventBus:Publish("Combat.EnemyRagdolled", player, data.WakeupTime)
    elseif not isRag and data.IsRagdoll then
        data.IsRagdoll = false
        EventBus:Publish("Combat.EnemyWakeup", player)
    end

    local isBlock = false
    local anim = entry.Animator
    if anim then
        for _, t in ipairs(anim:GetPlayingAnimationTracks()) do
            local n = (t.Name or ""):lower()
            if n:find("block") or n:find("guard") then
                isBlock = true
                break
            end
        end
    end
    data.IsBlocking = isBlock
end

return EnemyState

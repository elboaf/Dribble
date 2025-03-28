-- Dribble - Druid Assistant for Turtle WoW (1.12)
Dribble = {}

-- Spell names (EXACTLY AS YOU HAD THEM)
local MOTW_SPELL = "Mark of the Wild"
local THORNS_SPELL = "Thorns"
local MOONFIRE_SPELL = "Moonfire"
local HEALING_TOUCH_SPELL = "Healing Touch"

-- Buff/debuff texture patterns (EXACTLY AS YOU HAD THEM)
local MOTW_TEXTURE = "Regeneration"
local THORNS_TEXTURE = "Thorns"
local MOONFIRE_TEXTURE = "StarFall"

-- 1. KEEPING YOUR WORKING BUFF FUNCTIONS EXACTLY AS IS
local function HasBuff(unit, texturePattern)
    for i=1,16 do
        local buffTexture = UnitBuff(unit, i)
        if buffTexture and strfind(buffTexture, texturePattern) then
            return true
        end
    end
    return false
end

local function BuffUnit(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) then
        return false
    end

    if not HasBuff(unit, MOTW_TEXTURE) then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: "..UnitName(unit).." needs MOTW")
        CastSpellByName(MOTW_SPELL)
        SpellTargetUnit(unit)
        return true
    end

    if not HasBuff(unit, THORNS_TEXTURE) then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: "..UnitName(unit).." needs Thorns")
        CastSpellByName(THORNS_SPELL)
        SpellTargetUnit(unit)
        return true
    end

    return false
end

-- 2. NEW HEALING FUNCTION THAT WON'T INTERFERE
local function CheckAndHeal()
    -- Find who needs healing most
    local healTarget, healPercent = nil, 70
    
    -- Check player
    if not UnitIsDeadOrGhost("player") then
        local hp = (UnitHealth("player")/UnitHealthMax("player"))*100
        if hp < healPercent then
            healTarget = "player"
            healPercent = hp
        end
    end
    
    -- Check party
    for i=1,4 do
        local unit = "party"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            local hp = (UnitHealth(unit)/UnitHealthMax(unit))*100
            if hp < healPercent then
                healTarget = unit
                healPercent = hp
            end
        end
    end
    
    -- Heal if found someone below 70%
    if healTarget then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Healing "..(healTarget=="player" and "self" or UnitName(healTarget)).." ("..math.floor(healPercent).."%)")
        CastSpellByName(HEALING_TOUCH_SPELL)
        SpellTargetUnit(healTarget)
        return true
    end
    return false
end

-- 3. MAIN FUNCTION (ONLY CHANGED HEALING PART)
local function DoDribbleActions()
    -- YOUR WORKING BUFF CODE - COMPLETELY UNCHANGED
    if BuffUnit("player") then return end
    for i=1,4 do
        if BuffUnit("party"..i) then return end
    end
    
    -- Moonfire (unchanged)
    if UnitMana("player")/UnitManaMax("player") > 0.3 then
        for i=1,4 do
            local member = "party"..i
            if UnitExists(member) then
                local target = member.."target"
                if UnitExists(target) and UnitCanAttack("player", target) and not UnitIsDeadOrGhost(target) then
                    local hasMF = false
                    for j=1,16 do
                        if UnitDebuff(target,j) and strfind(UnitDebuff(target,j), MOONFIRE_TEXTURE) then
                            hasMF = true
                            break
                        end
                    end
                    if not hasMF then
                        AssistUnit(member)
                        CastSpellByName(MOONFIRE_SPELL)
                        return
                    end
                end
            end
        end
    end
    
    -- NEW HEALING CALL (REPLACED OLD VERSION)
    if CheckAndHeal() then return end
    
    -- Follow (unchanged)
    if UnitExists("party1") then
        FollowUnit("party1")
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: All actions complete")
end

SLASH_DRIBBLE1 = "/dribble"
SlashCmdList["DRIBBLE"] = DoDribbleActions
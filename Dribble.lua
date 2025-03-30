-- Dribble - Druid Assistant for Turtle WoW (1.12)
Dribble = {}

-- Spell names
local MOTW_SPELL = "Mark of the Wild"
local THORNS_SPELL = "Thorns"
local MOONFIRE_SPELL = "Moonfire"
local HEALING_TOUCH_SPELL = "Healing Touch"
local FAERIE_FIRE_SPELL = "Faerie Fire"

-- Texture patterns
local MOTW_TEXTURE = "Regeneration"
local THORNS_TEXTURE = "Thorns"
local MOONFIRE_TEXTURE = "StarFall"
local FAERIE_FIRE_TEXTURE = "Spell_Nature_FaerieFire"

-- Constants
local HEAL_THRESHOLD = 80    -- Heal below 70% HP
local MIN_MANA_DAMAGE = 50   -- Don't DPS below 50% mana (Moonfire only)

-- Settings
local followEnabled = true   -- Follow mode enabled by default
local damageAssistEnabled = true -- Damage assist enabled by default
local followTarget = "party1" -- Default follow target

local function IsInRange(unit)
    return CheckInteractDistance(unit, 4) -- 30 yard range
end

-- BUFFING (unchanged working version)
local function HasBuff(unit, texturePattern)
    if not IsInRange(unit) then return true end
    for i=1,16 do
        local buffTexture = UnitBuff(unit, i)
        if buffTexture and strfind(buffTexture, texturePattern) then
            return true
        end
    end
    return false
end

local function HasDebuff(unit, texturePattern)
    if not IsInRange(unit) then return true end
    for i=1,16 do
        local debuffTexture = UnitDebuff(unit, i)
        if debuffTexture and strfind(debuffTexture, texturePattern) then
            return true
        end
    end
    return false
end

local function BuffUnit(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not IsInRange(unit) then
        return false
    end

    if not HasBuff(unit, MOTW_TEXTURE) then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Buffing "..UnitName(unit))
        CastSpellByName(MOTW_SPELL)
        SpellTargetUnit(unit)
        return true
    end

    if not HasBuff(unit, THORNS_TEXTURE) then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Buffing "..UnitName(unit))
        CastSpellByName(THORNS_SPELL)
        SpellTargetUnit(unit)
        return true
    end

    return false
end

-- HEALING (always available, no mana restriction)
local function CheckAndHeal()
    local healTarget, lowestHP = nil, HEAL_THRESHOLD

    -- Check player
    if not UnitIsDeadOrGhost("player") and IsInRange("player") then
        local hp = UnitHealth("player")/UnitHealthMax("player")*100
        if hp < lowestHP then
            healTarget = "player"
            lowestHP = hp
        end
    end

    -- Check party
    for i=1,4 do
        local unit = "party"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsInRange(unit) then
            local hp = UnitHealth(unit)/UnitHealthMax(unit)*100
            if hp < lowestHP then
                healTarget = unit
                lowestHP = hp
            end
        end
    end

    if healTarget then
        DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: Healing %s (%d%%)", 
            healTarget=="player" and "self" or UnitName(healTarget), 
            math.floor(lowestHP)))
        CastSpellByName(HEALING_TOUCH_SPELL)
        SpellTargetUnit(healTarget)
        return true
    end
    return false
end

-- DAMAGE ASSIST (only if above 50% mana)
local function CastDamageSpells()
    if not damageAssistEnabled then return false end
    if UnitMana("player")/UnitManaMax("player")*100 < MIN_MANA_DAMAGE then
        return false
    end

    for i=1,4 do
        local member = "party"..i
        if UnitExists(member) then
            local target = member.."target"
            if UnitExists(target) and UnitCanAttack("player", target) and 
               not UnitIsDeadOrGhost(target) and IsInRange(target) then
                -- First check for Faerie Fire
                if not HasDebuff(target, FAERIE_FIRE_TEXTURE) then
                    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Faerie Fire on "..UnitName(target))
                    AssistUnit(member)
                    CastSpellByName(FAERIE_FIRE_SPELL)
                    return true
                end
                -- Then check for Moonfire
                if not HasDebuff(target, MOONFIRE_TEXTURE) then
                    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Moonfire on "..UnitName(target))
                    AssistUnit(member)
                    CastSpellByName(MOONFIRE_SPELL)
                    return true
                end
            end
        end
    end
    return false
end

-- MAIN FUNCTION (updated priority)
local function DoDribbleActions()
    -- 1. Follow first if enabled
    if followEnabled and UnitExists(followTarget) then
        FollowUnit(followTarget)
    end

    -- 2. Healing (always priority)
    if CheckAndHeal() then return end

    -- 3. Buffing
    if BuffUnit("player") then return end
    for i=1,4 do
        if BuffUnit("party"..i) then return end
    end

    -- 4. Damage only if mana permits and damage assist is enabled
    if CastDamageSpells() then return end

    DEFAULT_CHAT_FRAME:AddMessage("Dribble: All actions complete")
end

-- Toggle follow mode
local function ToggleFollowMode()
    followEnabled = not followEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Follow mode "..(followEnabled and "enabled" or "disabled"))
    if not followEnabled then
        FollowUnit("player") -- Stop following if we're toggling off
    end
end

-- Get party unit from target (new function)
local function GetPartyUnitFromTarget()
    if not UnitExists("target") then
        return nil
    end
    
    local targetName = UnitName("target")
    for i=1,4 do
        local unit = "party"..i
        if UnitExists(unit) and UnitName(unit) == targetName then
            return unit
        end
    end
    return nil
end

-- Set follow target (updated function)
local function SetFollowTarget(msg)
    local targetNum
    if msg == "" then
        -- No argument provided, try to detect from target
        local partyUnit = GetPartyUnitFromTarget()
        if partyUnit then
            followTarget = partyUnit
            DEFAULT_CHAT_FRAME:AddMessage("Dribble: Now following "..followTarget.." ("..UnitName(followTarget)..")")
            if followEnabled then
                FollowUnit(followTarget)
            end
            return
        else
            DEFAULT_CHAT_FRAME:AddMessage("Dribble: Not targeting a party member or target not found in party")
            return
        end
    else
        targetNum = tonumber(msg)
    end
    
    if targetNum and targetNum >= 1 and targetNum <= 4 then
        followTarget = "party"..targetNum
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Now following "..followTarget..(UnitExists(followTarget) and " ("..UnitName(followTarget)..")" or ""))
        if followEnabled then
            FollowUnit(followTarget)
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Invalid follow target. Usage: /dribblefollowtarget [1-4] or target a party member and use /dribblefollowtarget")
    end
end

-- Toggle damage assist mode
local function ToggleDamageAssistMode()
    damageAssistEnabled = not damageAssistEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Damage assist mode "..(damageAssistEnabled and "enabled" or "disabled"))
end

-- Slash commands
SLASH_DRIBBLE1 = "/dribble"
SlashCmdList["DRIBBLE"] = DoDribbleActions

SLASH_DRIBBLEFOLLOW1 = "/dribblefollow"
SlashCmdList["DRIBBLEFOLLOW"] = ToggleFollowMode

SLASH_DRIBBLEFOLLOWTARGET1 = "/dribblefollowtarget"
SlashCmdList["DRIBBLEFOLLOWTARGET"] = SetFollowTarget

SLASH_DRIBBLEDPS1 = "/dribbledps"
SlashCmdList["DRIBBLEDPS"] = ToggleDamageAssistMode
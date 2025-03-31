-- Dribble - Druid Assistant for Turtle WoW (1.12)
Dribble = {}

-- Spell names
local MOTW_SPELL = "Mark of the Wild"
local THORNS_SPELL = "Thorns"
local MOONFIRE_SPELL = "Moonfire"
local HEALING_TOUCH_SPELL = "Healing Touch"
local FAERIE_FIRE_SPELL = "Faerie Fire"
local HIBERNATE_SPELL = "Hibernate"
local REJUVENATION_SPELL = "Rejuvenation(Rank 2)"
local REGROWTH_SPELL = "Regrowth"

-- Texture patterns
local MOTW_TEXTURE = "Regeneration"
local THORNS_TEXTURE = "Thorns"
local MOONFIRE_TEXTURE = "StarFall"
local FAERIE_FIRE_TEXTURE = "Spell_Nature_FaerieFire"
local GOUGE_TEXTURE = "Ability_Gouge"
local HIBERNATE_TEXTURE = "Spell_Nature_Sleep"
local REJUVENATION_TEXTURE = "Spell_Nature_Rejuvenation"
local REGROWTH_TEXTURE = "Spell_Nature_ResistNature"

-- Healing Configuration
local HEALING_TOUCH_RANKS = {
    { name = "Healing Touch(Rank 1)", amount = 90, mana = 30 },
    { name = "Healing Touch(Rank 2)", amount = 220, mana = 55 },
    { name = "Healing Touch(Rank 3)", amount = 375, mana = 100 }
}

local REGROWTH_RANKS = {
    { name = "Regrowth(Rank 1)", amount = 200, mana = 60 },
    { name = "Regrowth(Rank 2)", amount = 400, mana = 105 }
}

local HEAL_THRESHOLD_PERCENT = 80    -- HT/Regrowth threshold
local REJUV_THRESHOLD_PERCENT = 85   -- Rejuv threshold
local MIN_HEAL_AMOUNT = 30           -- Minimum HP missing for direct heals
local MIN_MANA_DAMAGE = 50           -- Don't DPS below 50% mana

-- Settings
local followEnabled = true
local damageAssistEnabled = true
local followTarget = "party1"
local buffPets = true

local function IsInRange(unit)
    return CheckInteractDistance(unit, 4) -- 30 yard range
end

-- BUFFING (updated to include pets)
local function HasBuff(unit, texturePattern)
    if not UnitExists(unit) or not IsInRange(unit) then return true end
    for i=1,16 do
        local buffTexture = UnitBuff(unit, i)
        if buffTexture and strfind(buffTexture, texturePattern) then
            return true
        end
    end
    return false
end

local function HasDebuff(unit, texturePattern)
    if not UnitExists(unit) or not IsInRange(unit) then return true end
    for i=1,16 do
        local debuffTexture = UnitDebuff(unit, i)
        if debuffTexture and strfind(debuffTexture, texturePattern) then
            return true
        end
    end
    return false
end

local function IsTargetGouged()
    if not UnitExists("target") or not UnitCanAttack("player", "target") then
        return false
    end
    
    local creatureType = UnitCreatureType("target")
    if creatureType ~= "Beast" and creatureType ~= "Dragonkin" then
        return false
    end
    
    return HasDebuff("target", GOUGE_TEXTURE)
end

local function IsTargetHibernated()
    if not UnitExists("target") or not UnitCanAttack("player", "target") then
        return false
    end
    
    local creatureType = UnitCreatureType("target")
    if creatureType ~= "Beast" and creatureType ~= "Dragonkin" then
        return false
    end
    
    return HasDebuff("target", HIBERNATE_TEXTURE)
end

local function HandleGougedTarget()
    if not IsTargetGouged() then
        return false
    end
    
    if IsTargetHibernated() then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Target is already hibernated")
        return false
    end
    
    local targetName = UnitName("target")
    
    ClearTarget()
    TargetLastTarget()
    
    if not UnitExists("target") or UnitName("target") ~= targetName then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Failed to re-acquire target")
        return false
    end
    
    if UnitMana("player") < 10 then
        return false
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Casting Hibernate on gouged target")
    CastSpellByName(HIBERNATE_SPELL)
    return true
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

local function BuffPartyPets()
    if not buffPets then return false end
    
    for i=1,4 do
        local petUnit = "partypet"..i
        if UnitExists(petUnit) and not UnitIsDeadOrGhost(petUnit) then
            if BuffUnit(petUnit) then
                return true
            end
        end
    end
    return false
end

local function GetAppropriateHealRank(missingHealth, unit)
    -- First try to find suitable Regrowth
    for i = table.getn(REGROWTH_RANKS), 1, -1 do
        local rank = REGROWTH_RANKS[i]
        if missingHealth >= rank.amount and UnitMana("player") >= rank.mana and not HasBuff(unit, REGROWTH_TEXTURE) then
            return rank.name
        end
    end
    
    -- Fall back to Healing Touch if no suitable Regrowth or already has Regrowth
    local bestRank = HEALING_TOUCH_RANKS[1]
    for i = 1, table.getn(HEALING_TOUCH_RANKS) do
        local rank = HEALING_TOUCH_RANKS[i]
        if missingHealth >= rank.amount and UnitMana("player") >= rank.mana then
            bestRank = rank
        end
    end
    
    return bestRank.name
end

local function CheckRejuvenation()
    local didHeal = false
    
    -- Check player first
    if not UnitIsDeadOrGhost("player") and IsInRange("player") then
        local hpPercent = (UnitHealth("player") / UnitHealthMax("player")) * 100
        if hpPercent < REJUV_THRESHOLD_PERCENT and not HasBuff("player", REJUVENATION_TEXTURE) then
            DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: Rejuvenation on self (%d%%)", math.floor(hpPercent)))
            CastSpellByName(REJUVENATION_SPELL)
            SpellTargetUnit("player")
            didHeal = true
        end
    end

    -- Check party members
    for i=1,4 do
        local unit = "party"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsInRange(unit) then
            local hpPercent = (UnitHealth(unit) / UnitHealthMax(unit)) * 100
            if hpPercent < REJUV_THRESHOLD_PERCENT and not HasBuff(unit, REJUVENATION_TEXTURE) then
                DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: Rejuvenation on %s (%d%%)", UnitName(unit), math.floor(hpPercent)))
                CastSpellByName(REJUVENATION_SPELL)
                SpellTargetUnit(unit)
                didHeal = true
            end
        end
    end
    
    return didHeal
end

local function CheckAndHeal()
    local healTarget = nil
    local mostMissingHealth = 0
    local lowestHPPercent = 100

    -- Check player
    if not UnitIsDeadOrGhost("player") and IsInRange("player") then
        local currentHP = UnitHealth("player")
        local maxHP = UnitHealthMax("player")
        local missing = maxHP - currentHP
        local hpPercent = (currentHP / maxHP) * 100
        
        if hpPercent < lowestHPPercent then
            lowestHPPercent = hpPercent
            mostMissingHealth = missing
            healTarget = "player"
        end
    end

    -- Check party
    for i=1,4 do
        local unit = "party"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsInRange(unit) then
            local currentHP = UnitHealth(unit)
            local maxHP = UnitHealthMax(unit)
            local missing = maxHP - currentHP
            local hpPercent = (currentHP / maxHP) * 100
            
            if hpPercent < lowestHPPercent then
                lowestHPPercent = hpPercent
                mostMissingHealth = missing
                healTarget = unit
            end
        end
    end

    if healTarget and lowestHPPercent < HEAL_THRESHOLD_PERCENT and mostMissingHealth >= MIN_HEAL_AMOUNT then
        local spellName = GetAppropriateHealRank(mostMissingHealth, healTarget)
        DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: Healing %s (%d%% HP, missing %d) with %s", 
            healTarget=="player" and "self" or UnitName(healTarget), 
            math.floor(lowestHPPercent),
            mostMissingHealth,
            spellName))
        CastSpellByName(spellName)
        SpellTargetUnit(healTarget)
        return true
    end
    return false
end

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
               
                if IsTargetHibernated() then
                    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Target is hibernated - skipping damage")
                    return false
                end
                
                if not HasDebuff(target, FAERIE_FIRE_TEXTURE) then
                    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Faerie Fire on "..UnitName(target))
                    AssistUnit(member)
                    CastSpellByName(FAERIE_FIRE_SPELL)
                    return true
                end
                if not HasDebuff(target, MOONFIRE_TEXTURE) and not IsTargetHibernated() then
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

local function DoDribbleActions()
    -- 1. Follow first if enabled
    if followEnabled and UnitExists(followTarget) then
        FollowUnit(followTarget)
    end

    -- 2. Rejuvenation checks
    if CheckRejuvenation() then return end

    -- 3. Emergency Healing (Regrowth or Healing Touch)
    if CheckAndHeal() then return end

    -- 4. Handle gouged targets
    if UnitExists("target") and IsTargetGouged() then
        if HandleGougedTarget() then return end
    end

    -- 5. Buffing (players first, then pets)
    if BuffUnit("player") then return end
    for i=1,4 do
        if BuffUnit("party"..i) then return end
    end
    if BuffPartyPets() then return end

    -- 6. Damage only if mana permits
    if CastDamageSpells() then return end

    DEFAULT_CHAT_FRAME:AddMessage("Dribble: All actions complete")
end

local function ToggleFollowMode()
    followEnabled = not followEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Follow mode "..(followEnabled and "enabled" or "disabled"))
    if not followEnabled then
        FollowUnit("player")
    end
end

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

local function SetFollowTarget(msg)
    local targetNum
    if msg == "" then
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

local function ToggleDamageAssistMode()
    damageAssistEnabled = not damageAssistEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Damage assist mode "..(damageAssistEnabled and "enabled" or "disabled"))
end

local function TogglePetBuffingMode()
    buffPets = not buffPets
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Pet buffing "..(buffPets and "enabled" or "disabled"))
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

SLASH_DRIBBLEPETBUFFS1 = "/dribblepetbuffs"
SlashCmdList["DRIBBLEPETBUFFS"] = TogglePetBuffingMode
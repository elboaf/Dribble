-- Dribble - Druid Assistant for Turtle WoW (1.12)
Dribble = {}

-- Spell names
local MOTW_SPELL = "Mark of the Wild"
local THORNS_SPELL = "Thorns"
local MOONFIRE_SPELL = "Moonfire"
local HEALING_TOUCH_SPELL = "Healing Touch"
local FAERIE_FIRE_SPELL = "Faerie Fire"
local HIBERNATE_SPELL = "Hibernate"
local REJUVENATION_SPELL = "Rejuvenation"
local REGROWTH_SPELL = "Regrowth"
local IS_SPELL = "Insect Swarm"
local CAT_FORM_SPELL = "Cat Form"
local PROWL_SPELL = "Prowl"
local WRATH_SPELL = "Wrath"
local SWIFTMEND_SPELL = "Swiftmend"

-- Add these with the other spell names
local CLAW_SPELL = "Claw"
local FEROCIOUS_BITE_SPELL = "Ferocious Bite"

-- Add these with the other texture patterns

-- Texture patterns
local MOTW_TEXTURE = "Regeneration"
local THORNS_TEXTURE = "Thorns"
local MOONFIRE_TEXTURE = "StarFall"
local FAERIE_FIRE_TEXTURE = "Spell_Nature_FaerieFire"
local GOUGE_TEXTURE = "Ability_Gouge"
local HIBERNATE_TEXTURE = "Spell_Nature_Sleep"
local REJUVENATION_TEXTURE = "Spell_Nature_Rejuvenation"
local REGROWTH_TEXTURE = "Spell_Nature_ResistNature"
local IS_TEXTURE = "Spell_Nature_InsectSwarm"
local CAT_FORM_TEXTURE = "Ability_Druid_CatForm"
local PROWL_TEXTURE = "Ability_Ambush"
local STEALTH_TEXTURE = "Ability_Stealth"
local WRATH_TEXTURE = "Spell_Nature_Earthquake"

local expectedHoTHealing = {} -- Tracks expected HoT healing per unit
local catModeEnabled = false

-- Healing Configuration
local HEALING_TOUCH_RANKS = {
    { name = "Healing Touch(Rank 1)", amount = 55, mana = 25 },
    { name = "Healing Touch(Rank 2)", amount = 119, mana = 55 },
    { name = "Healing Touch(Rank 3)", amount = 253, mana = 110 },
    { name = "Healing Touch(Rank 4)", amount = 456, mana = 185 }
}

local REGROWTH_RANKS = {
    { 
        name = "Regrowth(Rank 1)", 
        directAmount = 107,      -- Direct heal amount
        hotAmount = 98,        -- Total HoT amount (15 per tick for 7 ticks)
        mana = 96, 
        hotDuration = 21 
    },
    { 
        name = "Regrowth(Rank 2)", 
        directAmount = 201,     -- Direct heal amount
        hotAmount = 175,        -- Total HoT amount (30 per tick for 7 ticks)
        mana = 164, 
        hotDuration = 21 
    },
    { 
        name = "Regrowth(Rank 3)", 
        directAmount = 274,     -- Direct heal amount
        hotAmount = 259,        -- Total HoT amount (45 per tick for 7 ticks)
        mana = 224, 
        hotDuration = 21 
    }
}

-- Add Rejuvenation ranks configuration
local REJUVENATION_RANKS = {
    { name = "Rejuvenation(Rank 1)", amount = 32, mana = 25, duration = 12 },
    { name = "Rejuvenation(Rank 2)", amount = 56, mana = 50, duration = 12 },
    { name = "Rejuvenation(Rank 3)", amount = 116, mana = 100, duration = 12 },
    { name = "Rejuvenation(Rank 4)", amount = 180, mana = 170, duration = 12 }
}

-- Healing Thresholds
local HEALING_TOUCH_THRESHOLD_PERCENT = 80    -- HT threshold
local REGROWTH_THRESHOLD_PERCENT = 70         -- Regrowth threshold
local REJUV_THRESHOLD_PERCENT = 60            -- Rejuv threshold
local SWIFTMEND_THRESHOLD_PERCENT = 80        -- Swiftmend threshold

local REJUV_MANA_THRESHOLD = 90 -- Don't cast Rejuv below 70% mana

local MIN_HEAL_AMOUNT = 30           -- Minimum HP missing for direct heals
local MIN_MANA_DAMAGE = 50           -- Don't DPS below 50% mana
local SWIFTMEND_COOLDOWN = 15        -- Swiftmend cooldown in seconds

-- Settings
local followEnabled = true
local damageAssistEnabled = true
local followTarget = "party1"
local buffPets = true
local rejuvEnabled = true
local regrowthEnabled = true
local healingTouchEnabled = true
local moonfireEnabled = true
local faerieFireEnabled = true
local insectSwarmEnabled = true
local wrathEnabled = true
local swiftmendEnabled = true

-- Swiftmend tracking
local swiftmendLastUsed = 0
local hotTimers = {} -- Tracks HoT expiration times per unit

local function IsInCombat()
    return UnitAffectingCombat("player")
end

local function IsInRange(unit)
    return CheckInteractDistance(unit, 4) -- 30 yard range
end

local function IsInForm(texturePattern)
    for i=1,16 do
        local buffTexture = UnitBuff("player", i)
        if buffTexture and strfind(buffTexture, texturePattern) then
            return true
        end
    end
    return false
end

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
    if not UnitExists("target") then
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



local function HandleStealthFollowing()
    if not followEnabled or UnitAffectingCombat("player") or not IsInRange(followTarget) then 
        return false 
    end
    
    if followEnabled and UnitExists(followTarget) then
        FollowUnit(followTarget)
    end
    
    if IsInForm(PROWL_TEXTURE) then
        if not (UnitExists(followTarget) and HasBuff(followTarget, STEALTH_TEXTURE)) then
            DEFAULT_CHAT_FRAME:AddMessage("Dribble: Party member left stealth - leaving prowl")
            CastSpellByName(PROWL_SPELL)
            return false
        end
        return true
    end
    
    if UnitExists(followTarget) and HasBuff(followTarget, STEALTH_TEXTURE) then
        if not IsInForm(CAT_FORM_TEXTURE) then
            DEFAULT_CHAT_FRAME:AddMessage("Dribble: Following stealthed target - entering Cat Form")
            CastSpellByName(CAT_FORM_SPELL)
            return true
        end
        
        if not IsInForm(PROWL_TEXTURE) then
            DEFAULT_CHAT_FRAME:AddMessage("Dribble: Following stealthed target - entering Prowl")
            CastSpellByName(PROWL_SPELL)
            return true
        end
    end
    
    return false
end

local function BuffUnit(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not IsInRange(unit) then
        return false
    end

    -- Never leave stealth if party member is still stealthed
    if IsInForm(PROWL_TEXTURE) and UnitExists(followTarget) and HasBuff(followTarget, STEALTH_TEXTURE) then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Maintaining stealth with party member")
        return false
    end

    -- Leave cat form temporarily to buff if needed
    local wasInCatForm = IsInForm(CAT_FORM_TEXTURE)
    if wasInCatForm and (not HasBuff(unit, MOTW_TEXTURE) or not HasBuff(unit, THORNS_TEXTURE)) then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Leaving cat form to buff")
        CastSpellByName(CAT_FORM_SPELL) -- Leave form
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

    -- Return to cat form if we left it for buffing
    if wasInCatForm and not IsInForm(CAT_FORM_TEXTURE) and catModeEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Returning to cat form after buffing")
        CastSpellByName(CAT_FORM_SPELL)
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

-- Add a function to periodically update expected HoT healing (call this in your main loop)
local function UpdateExpectedHoTHealing()
    local currentTime = GetTime()
    expectedHoTHealing = {} -- Reset and recalculate each update
    
    for unit, timers in pairs(hotTimers) do
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            -- Process Rejuvenation
            if timers.rejuv and currentTime < timers.rejuv.expire then
                local remainingDuration = timers.rejuv.expire - currentTime
                local totalDuration = timers.rejuv.rank.duration
                expectedHoTHealing[unit] = (expectedHoTHealing[unit] or 0) + 
                    (timers.rejuv.amount * (remainingDuration / totalDuration))
            end
            
            -- Process Regrowth
            if timers.regrowth and currentTime < timers.regrowth.expire then
                local remainingDuration = timers.regrowth.expire - currentTime
                local totalDuration = timers.regrowth.rank.hotDuration
                expectedHoTHealing[unit] = (expectedHoTHealing[unit] or 0) + 
                    (timers.regrowth.amount * (remainingDuration / totalDuration))
            end
        else
            -- Clear data for invalid units
            hotTimers[unit] = nil
        end
    end
end

-- Add a function to calculate effective missing health
local function GetEffectiveMissingHealth(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) then return 0 end
    
    local currentHP = UnitHealth(unit)
    local maxHP = UnitHealthMax(unit)
    local missing = maxHP - currentHP
    
    -- Get precise expected healing from UpdateExpectedHoTHealing
    UpdateExpectedHoTHealing() -- Ensure calculations are current
    
    return math.max(0, missing - (expectedHoTHealing[unit] or 0))
end


local function RecordHotCast(unit, spellName)
    if not hotTimers[unit] then 
        hotTimers[unit] = {} 
        expectedHoTHealing[unit] = 0
    end
    
    if string.find(spellName, "Rejuvenation") then
        -- Find and store the exact rank information
        for _, rank in ipairs(REJUVENATION_RANKS) do
            if rank.name == spellName then
                hotTimers[unit].rejuv = {
                    expire = GetTime() + rank.duration,
                    rank = rank,
                    amount = rank.amount
                }
                expectedHoTHealing[unit] = (expectedHoTHealing[unit] or 0) + rank.amount
                break
            end
        end
        
    elseif string.find(spellName, "Regrowth") then
        -- Find and store the exact rank information
        for _, rank in ipairs(REGROWTH_RANKS) do
            if rank.name == spellName then
                hotTimers[unit].regrowth = {
                    expire = GetTime() + rank.hotDuration,
                    rank = rank,
                    amount = rank.hotAmount
                }
                expectedHoTHealing[unit] = (expectedHoTHealing[unit] or 0) + rank.hotAmount
                break
            end
        end
    end
end

local function GetAppropriateHealRank(missingHealth, unit)
    -- Check Regrowth first if enabled
    if regrowthEnabled then
        for i = table.getn(REGROWTH_RANKS), 1, -1 do
            local rank = REGROWTH_RANKS[i]
            local totalHealing = rank.directAmount + rank.hotAmount
            -- Use REGROWTH_THRESHOLD_PERCENT for Regrowth specifically
            if missingHealth >= totalHealing and UnitMana("player") >= rank.mana and 
               not HasBuff(unit, REGROWTH_TEXTURE) and 
               ((UnitHealth(unit) / UnitHealthMax(unit)) * 100) < REGROWTH_THRESHOLD_PERCENT then
                return rank.name
            end
        end
    end
    
    -- Then check Healing Touch if enabled
    if healingTouchEnabled then
        local bestRank = HEALING_TOUCH_RANKS[1]
        for i = 1, table.getn(HEALING_TOUCH_RANKS) do
            local rank = HEALING_TOUCH_RANKS[i]
            -- Use HEALING_TOUCH_THRESHOLD_PERCENT for HT specifically
            if missingHealth >= rank.amount and UnitMana("player") >= rank.mana and 
               ((UnitHealth(unit) / UnitHealthMax(unit)) * 100) < HEALING_TOUCH_THRESHOLD_PERCENT then
                bestRank = rank
            end
        end
        -- Only return HT if we found a suitable rank and the health is below HT threshold
        if ((UnitHealth(unit) / UnitHealthMax(unit)) * 100) < HEALING_TOUCH_THRESHOLD_PERCENT then
            return bestRank.name
        end
    end
    
    return nil
end

local function GetAppropriateRejuvRank(missingHealth, unit)
    for i = table.getn(REJUVENATION_RANKS), 1, -1 do
        local rank = REJUVENATION_RANKS[i]
        if missingHealth >= rank.amount and UnitMana("player") >= rank.mana and not HasBuff(unit, REJUVENATION_TEXTURE) then
            return rank.name
        end
    end
    return REJUVENATION_RANKS[1].name -- Default to rank 1 if nothing else matches
end

local function CheckUnitSwiftmend(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not IsInRange(unit) then
        return false
    end
    
    local currentTime = GetTime()
    local hpPercent = (UnitHealth(unit) / UnitHealthMax(unit)) * 100
    
    -- Don't Swiftmend if above threshold (unless emergency)
    if hpPercent > SWIFTMEND_THRESHOLD_PERCENT and hpPercent >= 40 then
        return false
    end
    
    if hotTimers[unit] then
        local rejuvActive = HasBuff(unit, REJUVENATION_TEXTURE)
        local regrowthActive = HasBuff(unit, REGROWTH_TEXTURE)
        local consumedHoT = false
        
        -- Calculate time left on HoTs
        local rejuvTimeLeft = rejuvActive and (hotTimers[unit].rejuv.expire - currentTime) or 0
        local regrowthTimeLeft = regrowthActive and (hotTimers[unit].regrowth.expire - currentTime) or 0
        
        -- Prefer to consume Regrowth if it's about to expire
        if regrowthActive and regrowthTimeLeft < 7 then
            DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: Swiftmend on %s (Regrowth expiring in %.1fs)", 
                unit=="player" and "self" or UnitName(unit), regrowthTimeLeft))
            CastSpellByName(SWIFTMEND_SPELL)
            SpellTargetUnit(unit)
            swiftmendLastUsed = GetTime()
            consumedHoT = true
        -- Otherwise consume Rejuv if it's about to expire
        elseif not consumedHoT and rejuvActive and rejuvTimeLeft < 4 then
            DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: Swiftmend on %s (Rejuvenation expiring in %.1fs)", 
                unit=="player" and "self" or UnitName(unit), rejuvTimeLeft))
            CastSpellByName(SWIFTMEND_SPELL)
            SpellTargetUnit(unit)
            swiftmendLastUsed = GetTime()
            consumedHoT = true
        -- Emergency case - very low health and HoT has been active for at least 25% of its duration
        elseif not consumedHoT and hpPercent < 40 and (rejuvActive or regrowthActive) then
            local minTimePassed = false
            if rejuvActive and rejuvTimeLeft < (hotTimers[unit].rejuv.rank.duration * 0.75) then
                minTimePassed = true
            end
            if regrowthActive and regrowthTimeLeft < (hotTimers[unit].regrowth.rank.hotDuration * 0.75) then
                minTimePassed = true
            end
            
            if minTimePassed then
                DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: Emergency Swiftmend on %s (%d%% HP)", 
                    unit=="player" and "self" or UnitName(unit), math.floor(hpPercent)))
                CastSpellByName(SWIFTMEND_SPELL)
                SpellTargetUnit(unit)
                swiftmendLastUsed = GetTime()
                consumedHoT = true
            end
        end
        
        if consumedHoT then
            -- Update expected healing
            if expectedHoTHealing[unit] then
                if regrowthActive and hotTimers[unit].regrowth then
                    expectedHoTHealing[unit] = expectedHoTHealing[unit] - hotTimers[unit].regrowth.amount
                elseif rejuvActive and hotTimers[unit].rejuv then
                    expectedHoTHealing[unit] = expectedHoTHealing[unit] - hotTimers[unit].rejuv.amount
                end
                expectedHoTHealing[unit] = math.max(0, expectedHoTHealing[unit])
            end
            
            -- Clear the consumed HoT
            if hotTimers[unit] then
                if regrowthActive then hotTimers[unit].regrowth = nil end
                if rejuvActive then hotTimers[unit].rejuv = nil end
                
                -- Clean up if no more HoTs
                if not hotTimers[unit].regrowth and not hotTimers[unit].rejuv then
                    hotTimers[unit] = nil
                end
            end
            
            return true
        end
    end
    
    return false
end

local function CheckSwiftmend()
    if not swiftmendEnabled or (GetTime() - swiftmendLastUsed) < SWIFTMEND_COOLDOWN then
        return false
    end
    
    if UnitMana("player") < 67 then -- Swiftmend costs 67 mana
        return false
    end
    
    -- Check player first
    if CheckUnitSwiftmend("player") then return true end
    
    -- Check party members
    for i=1,4 do
        local unit = "party"..i
        if CheckUnitSwiftmend(unit) then return true end
    end
    
    return false
end

local function CheckRejuvenation()
    if IsInForm(PROWL_TEXTURE) then
        return false
    end
    
    if not rejuvEnabled then
        return false
    end

    -- Add mana threshold check (70%)
    if UnitMana("player")/UnitManaMax("player")*100 < 70 then
        return false
    end

    local didHeal = false
    
    if not UnitIsDeadOrGhost("player") and IsInRange("player") then
        local currentHP = UnitHealth("player")
        local maxHP = UnitHealthMax("player")
        local missing = maxHP - currentHP
        local hpPercent = (currentHP / maxHP) * 100
        
        if hpPercent < REJUV_THRESHOLD_PERCENT and not HasBuff("player", REJUVENATION_TEXTURE) then
            local spellName = GetAppropriateRejuvRank(missing, "player")
            DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: %s on self (%d%%, missing %d)", 
                spellName, math.floor(hpPercent), missing))
            CastSpellByName(spellName)
            SpellTargetUnit("player")
            RecordHotCast("player", spellName)
            didHeal = true
        end
    end

    for i=1,4 do
        local unit = "party"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsInRange(unit) then
            local currentHP = UnitHealth(unit)
            local maxHP = UnitHealthMax(unit)
            local missing = maxHP - currentHP
            local hpPercent = (currentHP / maxHP) * 100
            
            if hpPercent < REJUV_THRESHOLD_PERCENT and not HasBuff(unit, REJUVENATION_TEXTURE) then
                local spellName = GetAppropriateRejuvRank(missing, unit)
                DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: %s on %s (%d%%, missing %d)", 
                    spellName, UnitName(unit), math.floor(hpPercent), missing))
                CastSpellByName(spellName)
                SpellTargetUnit(unit)
                RecordHotCast(unit, spellName)
                didHeal = true
            end
        end
    end
    
    return didHeal
end

local function CheckAndHeal()
    if IsInForm(PROWL_TEXTURE) then
        return false
    end

    local healTarget = nil
    local mostMissingHealth = 0
    local lowestHPPercent = 100
    local effectiveMissing = 0

    -- Check player first
    if not UnitIsDeadOrGhost("player") and IsInRange("player") then
        local currentHP = UnitHealth("player")
        local maxHP = UnitHealthMax("player")
        local missing = maxHP - currentHP
        effectiveMissing = GetEffectiveMissingHealth("player")
        local hpPercent = (currentHP / maxHP) * 100
        
        if hpPercent < lowestHPPercent then
            lowestHPPercent = hpPercent
            mostMissingHealth = effectiveMissing -- Use effective missing health
            healTarget = "player"
        end
    end

    -- Check party members
    for i=1,4 do
        local unit = "party"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsInRange(unit) then
            local currentHP = UnitHealth(unit)
            local maxHP = UnitHealthMax(unit)
            local missing = maxHP - currentHP
            effectiveMissing = GetEffectiveMissingHealth(unit)
            local hpPercent = (currentHP / maxHP) * 100
            
            if hpPercent < lowestHPPercent then
                lowestHPPercent = hpPercent
                mostMissingHealth = effectiveMissing -- Use effective missing health
                healTarget = unit
            end
        end
    end

    -- Check if we found a target that needs healing
    local initialThreshold = math.max(HEALING_TOUCH_THRESHOLD_PERCENT, REGROWTH_THRESHOLD_PERCENT)
    if healTarget and lowestHPPercent < initialThreshold and mostMissingHealth >= MIN_HEAL_AMOUNT then
        local spellName = GetAppropriateHealRank(mostMissingHealth, healTarget)
        
        if not spellName then
            return false
        end
        
        -- Special message showing effective missing health
        if string.find(spellName, "Regrowth") then
            local regrowthInfo = nil
            for _, rank in ipairs(REGROWTH_RANKS) do
                if rank.name == spellName then
                    regrowthInfo = rank
                    break
                end
            end
            
            if regrowthInfo then
                DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: Healing %s (%d%% HP, missing %d [%d after HoTs]) with %s (%d direct + %d over %d sec)", 
                    healTarget=="player" and "self" or UnitName(healTarget), 
                    math.floor(lowestHPPercent),
                    UnitHealthMax(healTarget) - UnitHealth(healTarget),
                    mostMissingHealth,
                    spellName,
                    regrowthInfo.directAmount,
                    regrowthInfo.hotAmount,
                    regrowthInfo.hotDuration))
            else
                DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: Healing %s (%d%% HP, missing %d [%d after HoTs]) with %s", 
                    healTarget=="player" and "self" or UnitName(healTarget), 
                    math.floor(lowestHPPercent),
                    UnitHealthMax(healTarget) - UnitHealth(healTarget),
                    mostMissingHealth,
                    spellName))
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage(format("Dribble: Healing %s (%d%% HP, missing %d [%d after HoTs]) with %s", 
                healTarget=="player" and "self" or UnitName(healTarget), 
                math.floor(lowestHPPercent),
                UnitHealthMax(healTarget) - UnitHealth(healTarget),
                mostMissingHealth,
                spellName))
        end
        
        CastSpellByName(spellName)
        SpellTargetUnit(healTarget)
        
        -- Record if we cast a HoT
        if string.find(spellName, "Regrowth") or string.find(spellName, "Rejuvenation") then
            RecordHotCast(healTarget, spellName)
        end
        
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
            if UnitExists(target) and UnitCanAttack("player", target) and not UnitIsDeadOrGhost(target) then
                TargetUnit(target)

                if IsInRange(target) then
                    if IsTargetHibernated() then
                        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Target is hibernated - skipping damage")
                        return false
                    end
                    
                    if faerieFireEnabled and not HasDebuff(target, FAERIE_FIRE_TEXTURE) then
                        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Faerie Fire on "..UnitName(target))
                        AssistUnit(member)
                        CastSpellByName(FAERIE_FIRE_SPELL)
                        return true
                    end
                    if insectSwarmEnabled and not HasDebuff(target, IS_TEXTURE) and not IsTargetHibernated() then
                        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Insect Swarm on "..UnitName(target))
                        AssistUnit(member)
                        CastSpellByName(IS_SPELL)
                        return true
                    end
                    if moonfireEnabled and not HasDebuff(target, MOONFIRE_TEXTURE) and not IsTargetHibernated() then
                        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Moonfire on "..UnitName(target))
                        AssistUnit(member)
                        CastSpellByName(MOONFIRE_SPELL)
                        return true
                    end
                    if wrathEnabled and not IsTargetHibernated() then
                        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Casting Wrath on "..UnitName(target))
                        AssistUnit(member)
                        CastSpellByName(WRATH_SPELL)
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function ShouldLeaveCatFormForHealing()
    -- Never leave stealth if party member is still stealthed
    if IsInForm(PROWL_TEXTURE) and UnitExists(followTarget) and HasBuff(followTarget, STEALTH_TEXTURE) then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Maintaining stealth - skipping heal")
        return false
    end
    
    -- In cat mode, only heal if in combat AND someone is critically low
    if catModeEnabled and UnitAffectingCombat("player") then
        -- Check player first
        if not UnitIsDeadOrGhost("player") and (UnitHealth("player") / UnitHealthMax("player")) * 100 <= 40 then
            local missingHealth = UnitHealthMax("player") - UnitHealth("player")
            if GetAppropriateHealRank(missingHealth, "player") then
                DEFAULT_CHAT_FRAME:AddMessage("Dribble: Critical heal needed (Player at "..math.floor((UnitHealth("player") / UnitHealthMax("player")) * 100).."%)")
                return true
            end
        end
        
        -- Check party members
        for i=1,4 do
            local unit = "party"..i
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and 
               (UnitHealth(unit) / UnitHealthMax(unit)) * 100 <= 40 then
                local missingHealth = UnitHealthMax(unit) - UnitHealth(unit)
                if GetAppropriateHealRank(missingHealth, unit) then
                    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Critical heal needed ("..UnitName(unit).." at "..math.floor((UnitHealth(unit) / UnitHealthMax(unit)) * 100).."%)")
                    return true
                end
            end
        end
        return false
    end
    
    -- Normal healing behavior when not in cat mode or not in combat
    return true
end

local function HandleCatFormDPS()
    -- First try to get a target from party members
    local foundTarget = false
    for i=1,4 do
        local member = "party"..i
        if UnitExists(member) then
            local target = member.."target"
            if UnitExists(target) and UnitCanAttack("player", target) and not UnitIsDeadOrGhost(target) then
                if not UnitExists("target") or UnitName("target") ~= UnitName(target) then
                    TargetUnit(target)
                    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Assisting "..UnitName(member).." on "..UnitName(target))
                    foundTarget = true
                    break
                else
                    foundTarget = true
                    break
                end
            end
        end
    end

    if not foundTarget then
        return false
    end
    
    if not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDeadOrGhost("target") then
        return false
    end
    
    if not IsInForm(CAT_FORM_TEXTURE) then
        return false
    end
    
    local comboPoints = GetComboPoints()
    
    if not IsCurrentAction(60) then
    AttackTarget()
    end
    -- Use Ferocious Bite at 5 combo points
    if comboPoints >= 2 then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Using Ferocious Bite (5 combo points)")
        CastSpellByName(FEROCIOUS_BITE_SPELL)
        return true
    end
    
    -- Default to Claw to build combo points
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Using Claw to build combo points")
    CastSpellByName(CLAW_SPELL)
    return true
end

local function DoDribbleActions()
    UpdateExpectedHoTHealing() -- Update expected HoT healing first
    
    -- Handle follow (works in all modes)
    if followEnabled and UnitExists(followTarget) and not IsInForm(PROWL_TEXTURE) then
        FollowUnit(followTarget)
    end

    -- Handle stealth following (highest priority)
    if HandleStealthFollowing() then 
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Maintaining stealth with party")
        return 
    end

    -- Buff checks (player, party, and pets)
    if not IsInForm(PROWL_TEXTURE) then
        -- Buff player first
        if BuffUnit("player") then return end
        
        -- Buff party members
        for i=1,4 do
            local unit = "party"..i
            if BuffUnit(unit) then return end
        end
        
        -- Buff pets if enabled
        if buffPets then
            for i=1,4 do
                local petUnit = "partypet"..i
                if UnitExists(petUnit) and not UnitIsDeadOrGhost(petUnit) and BuffUnit(petUnit) then
                    return
                end
            end
        end
    end

    -- Make catmode and dpsmode mutually exclusive
    if catModeEnabled then
        damageAssistEnabled = false
        
        -- Cat Mode logic
        if not UnitAffectingCombat("player") then
            -- Out of combat - allow normal healing but default to cat form
            if CheckSwiftmend() then return end
            if CheckRejuvenation() then return end
            if CheckAndHeal() then return end
            
            -- Default to cat form when nothing else to do
            if not IsInForm(CAT_FORM_TEXTURE) then
                DEFAULT_CHAT_FRAME:AddMessage("Dribble: Entering cat form (idle in cat mode)")
                CastSpellByName(CAT_FORM_SPELL)
                return
            end
            
            -- Try to assist party members even when not in combat
            if HandleCatFormDPS() then
                return
            end
        else
            -- In combat - check for critical heals first
            if ShouldLeaveCatFormForHealing() then
                if IsInForm(CAT_FORM_TEXTURE) then
                    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Leaving cat form for critical healing")
                    CastSpellByName(CAT_FORM_SPELL) -- Leave form
                    return
                else
                    -- NEW: Actually perform the healing when not in cat form
                    if CheckSwiftmend() then return end
                    if CheckRejuvenation() then return end
                    if CheckAndHeal() then return end
                    
                    -- After healing, return to cat form if no more heals needed
                    if not ShouldLeaveCatFormForHealing() then
                        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Critical heals complete - returning to cat form")
                        CastSpellByName(CAT_FORM_SPELL)
                        return
                    end
                end
            else
                -- Stay in cat form and DPS
                if not IsInForm(CAT_FORM_TEXTURE) then
                    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Entering cat form (combat in cat mode)")
                    CastSpellByName(CAT_FORM_SPELL)
                    return
                end
                
                if HandleCatFormDPS() then
                    return
                end
            end
        end
    else
        -- Normal mode logic
        if CheckSwiftmend() then return end
        if CheckRejuvenation() then return end
        if CheckAndHeal() then return end
    end

    -- Handle other actions
    if UnitExists("target") and IsTargetGouged() then
        if HandleGougedTarget() then return end
    end

    if not catModeEnabled and CastDamageSpells() then 
        return 
    end

    -- Final fallback - ensure in cat form if in cat mode with nothing else to do
    if catModeEnabled and not IsInForm(CAT_FORM_TEXTURE) then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Entering cat form (fallback in cat mode)")
        CastSpellByName(CAT_FORM_SPELL)
        return
    end

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
    if damageAssistEnabled then
        catModeEnabled = false
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: DPS mode enabled (Cat mode disabled)")
    else
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: DPS mode disabled")
    end
end

local function TogglePetBuffingMode()
    buffPets = not buffPets
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Pet buffing "..(buffPets and "enabled" or "disabled"))
end

local function ToggleRejuvenation()
    rejuvEnabled = not rejuvEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Rejuvenation "..(rejuvEnabled and "enabled" or "disabled"))
end

local function ToggleRegrowth()
    regrowthEnabled = not regrowthEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Regrowth "..(regrowthEnabled and "enabled" or "disabled"))
end

local function ToggleHealingTouch()
    healingTouchEnabled = not healingTouchEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Healing Touch "..(healingTouchEnabled and "enabled" or "disabled"))
end

local function ToggleMoonfire()
    moonfireEnabled = not moonfireEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Moonfire "..(moonfireEnabled and "enabled" or "disabled"))
end

local function ToggleFaerieFire()
    faerieFireEnabled = not faerieFireEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Faerie Fire "..(faerieFireEnabled and "enabled" or "disabled"))
end

local function ToggleInsectSwarm()
    insectSwarmEnabled = not insectSwarmEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Insect Swarm "..(insectSwarmEnabled and "enabled" or "disabled"))
end

local function ToggleWrath()
    wrathEnabled = not wrathEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Wrath "..(wrathEnabled and "enabled" or "disabled"))
end

local function ToggleSwiftmend()
    swiftmendEnabled = not swiftmendEnabled
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Swiftmend "..(swiftmendEnabled and "enabled" or "disabled"))
end

local function ToggleCatMode()
    catModeEnabled = not catModeEnabled
    if catModeEnabled then
        damageAssistEnabled = false
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Cat mode enabled (DPS mode disabled)")
    else
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Cat mode disabled")
    end
    
    if not catModeEnabled and IsInForm(CAT_FORM_TEXTURE) then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Leaving cat form")
        CastSpellByName(CAT_FORM_SPELL) -- This will cancel form
    end
end

-- Add with the other slash commands

-- Slash commands
SLASH_DRIBBLE1 = "/dribble"
SLASH_DRIBBLEFOLLOW1 = "/dribblefollow"
SLASH_DRIBBLEFOLLOWTARGET1 = "/dribblefollowtarget"
SLASH_DRIBBLEDPS1 = "/dribbledps"
SLASH_DRIBBLEPETBUFFS1 = "/dribblepetbuffs"
SLASH_DRIBBLEREJUV1 = "/dribblerejuv"
SLASH_DRIBBLEREGROWTH1 = "/dribbleregrowth"
SLASH_DRIBBLEHT1 = "/dribbleht"
SLASH_DRIBBLEMOONFIRE1 = "/dribblemoonfire"
SLASH_DRIBBLEFAERIEFIRE1 = "/dribblefaeriefire"
SLASH_DRIBBLEINSECTSWARM1 = "/dribbleinsectswarm"
SLASH_DRIBBLEWRATH1 = "/dribblewrath"
SLASH_DRIBBLESWIFTMEND1 = "/dribbleswiftmend"
SLASH_DRIBBLECATMODE1 = "/dribblecatmode"

SlashCmdList["DRIBBLE"] = function()
    DoDribbleActions()
end

SlashCmdList["DRIBBLEFOLLOW"] = ToggleFollowMode
SlashCmdList["DRIBBLEFOLLOWTARGET"] = SetFollowTarget
SlashCmdList["DRIBBLEDPS"] = ToggleDamageAssistMode
SlashCmdList["DRIBBLEPETBUFFS"] = TogglePetBuffingMode
SlashCmdList["DRIBBLEREJUV"] = ToggleRejuvenation
SlashCmdList["DRIBBLEREGROWTH"] = ToggleRegrowth
SlashCmdList["DRIBBLEHT"] = ToggleHealingTouch
SlashCmdList["DRIBBLEMOONFIRE"] = ToggleMoonfire
SlashCmdList["DRIBBLEFAERIEFIRE"] = ToggleFaerieFire
SlashCmdList["DRIBBLEINSECTSWARM"] = ToggleInsectSwarm
SlashCmdList["DRIBBLEWRATH"] = ToggleWrath
SlashCmdList["DRIBBLESWIFTMEND"] = ToggleSwiftmend
SlashCmdList["DRIBBLECATMODE"] = ToggleCatMode
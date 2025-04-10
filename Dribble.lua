-- Dribble - Druid Assistant for Turtle WoW (1.12)
Dribble = {}

-- Spell names
local DASH_SPELL = "Dash"
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
local ABOLISH_POISON_SPELL = "Abolish Poison"
local REMOVE_CURSE_SPELL = "Remove Curse"
local NATURES_SWIFTNESS_SPELL = "Nature's Swiftness"

-- Add these with the other spell names
local CLAW_SPELL = "Claw"
local FEROCIOUS_BITE_SPELL = "Ferocious Bite"

-- Add these with the other texture patterns

-- Texture patterns
local DASH_TEXTURE = "Ability_Druid_Dash"
local SPRINT_TEXTURE = "Ability_Rogue_Sprint"
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
local POISON_TEXTURE = "Poison" -- This is a partial match for poison debuff textures
local CURSE_TEXTURE = "Curse" -- This is a partial match for curse debuff textures

local expectedHoTHealing = {} -- Tracks expected HoT healing per unit
local catModeEnabled = false
local tempDPSMode = false
local debugMode = false -- Added debug mode flag

-- Healing Configuration
local HEALING_TOUCH_RANKS = {
    { name = "Healing Touch(Rank 1)", amount = 55, mana = 25 },
    { name = "Healing Touch(Rank 2)", amount = 119, mana = 55 },
    { name = "Healing Touch(Rank 3)", amount = 253, mana = 110 },
    { name = "Healing Touch(Rank 4)", amount = 459, mana = 185 },
    { name = "Healing Touch(Rank 5)", amount = 712, mana = 264 },
    { name = "Healing Touch(Rank 6)", amount = 894, mana = 314 }
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
    },
        { 
        name = "Regrowth(Rank 4)", 
        directAmount = 360,     -- Direct heal amount
        hotAmount = 343,        -- Total HoT amount (45 per tick for 7 ticks)
        mana = 274, 
        hotDuration = 21 
    }
}

-- Add Rejuvenation ranks configuration
local REJUVENATION_RANKS = {
    { name = "Rejuvenation(Rank 1)", amount = 32, mana = 25, duration = 12 },
    { name = "Rejuvenation(Rank 2)", amount = 56, mana = 40, duration = 12 },
    { name = "Rejuvenation(Rank 3)", amount = 116, mana = 75, duration = 12 },
    { name = "Rejuvenation(Rank 4)", amount = 180, mana = 105, duration = 12 },
    { name = "Rejuvenation(Rank 5)", amount = 244, mana = 135, duration = 12 }
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

-- Debug message function
local function DebugMessage(msg)
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: "..msg)
    end
end

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

local function IsUnitHostile(unit)
    return UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDeadOrGhost(unit)
end

local function IsTargetGouged()
    if not UnitExists("target") then
        return false
    end

    for i = 1, 16 do
        local debuffTexture = UnitDebuff("target", i)
        if debuffTexture and strfind(debuffTexture, GOUGE_TEXTURE) then
            -- Use GameTooltip to get the debuff name
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE") -- Prevent tooltip from appearing on screen
            GameTooltip:SetUnitDebuff("target", i)
            local tooltipText = GameTooltipTextLeft1:GetText() -- First line of the tooltip (debuff name)
            GameTooltip:Hide()

            if tooltipText == "Gouge" then
                DebugMessage("Target is gouged")
                return true
            elseif tooltipText == "Rend" then
                DebugMessage("Target is rended")
                return false -- It's Rend, not Gouge
            end
        end
    end

    return false
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
    -- Just check current target if it exists
    if not UnitExists("target") or UnitIsDeadOrGhost("target") then
        return false
    end

    -- Must be beast/dragonkin
    local creatureType = UnitCreatureType("target")
    if creatureType ~= "Beast" and creatureType ~= "Dragonkin" then
        return false
    end

    -- Check for gouge
    if not IsTargetGouged() then
        return false
    end

    -- Don't double-hibernate
    if IsTargetHibernated() then
        return false
    end

    -- Check mana
    if UnitMana("player") < 10 then
        return false
    end

    -- If we get here, cast hibernate
    DebugMessage("Hibernating "..UnitName("target"))
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
            DebugMessage("Follow target left stealth - leaving prowl")
            CastSpellByName(PROWL_SPELL)
            return false
        end
        return true
    end
    
    if UnitExists(followTarget) and HasBuff(followTarget, STEALTH_TEXTURE) then
        if not IsInForm(CAT_FORM_TEXTURE) then
            DebugMessage("Following stealthed target - entering Cat Form")
            CastSpellByName(CAT_FORM_SPELL)
            return true
        end
        
        if not IsInForm(PROWL_TEXTURE) then
            DebugMessage("Following stealthed target - entering Prowl")
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
        DebugMessage("Maintaining stealth with party member")
        return false
    end

    -- Leave cat form temporarily to buff if needed
    local wasInCatForm = IsInForm(CAT_FORM_TEXTURE)
    if wasInCatForm and (not HasBuff(unit, MOTW_TEXTURE) or not HasBuff(unit, THORNS_TEXTURE)) then
        DebugMessage("Leaving cat form to buff")
        CastSpellByName(CAT_FORM_SPELL) -- Leave form
    end

    if not HasBuff(unit, MOTW_TEXTURE) then
        DebugMessage("Buffing "..UnitName(unit))
        CastSpellByName(MOTW_SPELL)
        SpellTargetUnit(unit)
        return true
    end

    if not HasBuff(unit, THORNS_TEXTURE) then
        DebugMessage("Buffing "..UnitName(unit))
        CastSpellByName(THORNS_SPELL)
        SpellTargetUnit(unit)
        return true
    end

    -- Return to cat form if we left it for buffing
    if wasInCatForm and not IsInForm(CAT_FORM_TEXTURE) and catModeEnabled then
        DebugMessage("Returning to cat form after buffing")
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
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not IsInRange(unit) and not IsUnitHostile("player") then
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
            DebugMessage(format("Swiftmend on %s (Regrowth expiring in %.1fs)", 
                unit=="player" and "self" or UnitName(unit), regrowthTimeLeft))
            CastSpellByName(SWIFTMEND_SPELL)
            SpellTargetUnit(unit)
            swiftmendLastUsed = GetTime()
            consumedHoT = true
        -- Otherwise consume Rejuv if it's about to expire
        elseif not consumedHoT and rejuvActive and rejuvTimeLeft < 4 then
            DebugMessage(format("Swiftmend on %s (Rejuvenation expiring in %.1fs)", 
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
                DebugMessage(format("Emergency Swiftmend on %s (%d%% HP)", 
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
    
    if not UnitIsDeadOrGhost("player") and IsInRange("player") and not IsUnitHostile("player") then
        local currentHP = UnitHealth("player")
        local maxHP = UnitHealthMax("player")
        local missing = maxHP - currentHP
        local hpPercent = (currentHP / maxHP) * 100
        
        if hpPercent < REJUV_THRESHOLD_PERCENT and not HasBuff("player", REJUVENATION_TEXTURE) then
            local spellName = GetAppropriateRejuvRank(missing, "player")
            DebugMessage(format("%s on self (%d%%, missing %d)", 
                spellName, math.floor(hpPercent), missing))
            CastSpellByName(spellName)
            SpellTargetUnit("player")
            RecordHotCast("player", spellName)
            didHeal = true
        end
    end

    for i=1,4 do
        local unit = "party"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsInRange(unit) and not IsUnitHostile("player") then
            local currentHP = UnitHealth(unit)
            local maxHP = UnitHealthMax(unit)
            local missing = maxHP - currentHP
            local hpPercent = (currentHP / maxHP) * 100
            
            if hpPercent < REJUV_THRESHOLD_PERCENT and not HasBuff(unit, REJUVENATION_TEXTURE) then
                local spellName = GetAppropriateRejuvRank(missing, unit)
                DebugMessage(format("%s on %s (%d%%, missing %d)", 
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

local function HasPoisonDebuff(unit)
    if not UnitExists(unit) then 
        return false 
    end
    
    for i = 1, 64 do  -- Max debuff slots per Turtle WoW
        local texture, _, dispelType = UnitDebuff(unit, i)
        if not texture then break end  -- No more debuffs
        
        -- Check both dispel type and texture as fallback
        if dispelType == "Poison" or (texture and strfind(string.lower(texture), "poison")) then
            return true
        end
    end
    
    return false
end

local function HasCurseDebuff(unit)
    if not UnitExists(unit) then 
        return false 
    end
    
    for i = 1, 64 do
        local texture, _, dispelType = UnitDebuff(unit, i)
        if not texture then break end
        
        -- Check both dispel type and texture as fallback
        if dispelType == "Curse" or (texture and strfind(string.lower(texture), "curse")) then
            return true
        end
    end
    
    return false
end

local function CheckAbolishPoison()
    -- Check player first
    if not UnitIsDeadOrGhost("player") and HasPoisonDebuff("player") and not HasBuff("player", ABOLISH_POISON_SPELL) then
        DebugMessage("Casting Abolish Poison on self")
        CastSpellByName(ABOLISH_POISON_SPELL)
        SpellTargetUnit("player")
        return true
    end

    -- Check party members
    for i=1,4 do
        local unit = "party"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and HasPoisonDebuff(unit) and not HasBuff(unit, ABOLISH_POISON_SPELL) then
            DebugMessage("Casting Abolish Poison on "..UnitName(unit))
            CastSpellByName(ABOLISH_POISON_SPELL)
            SpellTargetUnit(unit)
            return true
        end
    end

    return false
end

local function CheckRemoveCurse()
    -- Check player first
    if not UnitIsDeadOrGhost("player") and HasCurseDebuff("player") then
        DebugMessage("Removing curse from self")
        CastSpellByName(REMOVE_CURSE_SPELL)
        SpellTargetUnit("player")
        return true
    end

    -- Check party members
    for i=1,4 do
        local unit = "party"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and HasCurseDebuff(unit) then
            DebugMessage("Removing curse from "..UnitName(unit))
            CastSpellByName(REMOVE_CURSE_SPELL)
            SpellTargetUnit(unit)
            return true
        end
    end

    return false
end

local function CheckEmergencyHeal()
    -- Find Nature's Swiftness in spellbook
    local nsIndex = nil
    for i = 1, 180 do  -- Scan all spellbook slots
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if spellName and spellName == NATURES_SWIFTNESS_SPELL then
            nsIndex = i
            break
        end
    end
    
    -- Check if Nature's Swiftness is ready (not on cooldown)
    if not nsIndex then
        return false  -- Spell not found in spellbook
    end
    
    local start, duration = GetSpellCooldown(nsIndex, BOOKTYPE_SPELL)
    if start > 0 or duration > 0 then
        return false  -- Spell is on cooldown
    end
    
    -- Only cast if we don't already have the buff
    if HasBuff("player", NATURES_SWIFTNESS_SPELL) then
        return false
    end

    -- Check player first
    if not UnitIsDeadOrGhost("player") and (UnitHealth("player") / UnitHealthMax("player")) * 100 <= 40 then
        DebugMessage(format("EMERGENCY - Casting Nature's Swiftness (Player at %d%%)", 
            math.floor((UnitHealth("player") / UnitHealthMax("player")) * 100)))
        CastSpellByName(NATURES_SWIFTNESS_SPELL)
        return true
    end

    -- Check party members
    for i = 1, 4 do
        local unit = "party"..i
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsInRange(unit) and 
           (UnitHealth(unit) / UnitHealthMax(unit)) * 100 <= 40 then
            DebugMessage(format("EMERGENCY - Casting Nature's Swiftness (%s at %d%%)", 
                UnitName(unit), math.floor((UnitHealth(unit) / UnitHealthMax(unit)) * 100)))
            CastSpellByName(NATURES_SWIFTNESS_SPELL)
            return true
        end
    end

    return false
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
    if not UnitIsDeadOrGhost("player") and IsInRange("player") and not IsUnitHostile("player") then
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
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsInRange(unit) and not IsUnitHostile("player") then
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
                DebugMessage(format("Healing %s (%d%% HP, missing %d [%d after HoTs]) with %s (%d direct + %d over %d sec)", 
                    healTarget=="player" and "self" or UnitName(healTarget), 
                    math.floor(lowestHPPercent),
                    UnitHealthMax(healTarget) - UnitHealth(healTarget),
                    mostMissingHealth,
                    spellName,
                    regrowthInfo.directAmount,
                    regrowthInfo.hotAmount,
                    regrowthInfo.hotDuration))
            else
                DebugMessage(format("Healing %s (%d%% HP, missing %d [%d after HoTs]) with %s", 
                    healTarget=="player" and "self" or UnitName(healTarget), 
                    math.floor(lowestHPPercent),
                    UnitHealthMax(healTarget) - UnitHealth(healTarget),
                    mostMissingHealth,
                    spellName))
            end
        else
            DebugMessage(format("Healing %s (%d%% HP, missing %d [%d after HoTs]) with %s", 
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
    -- Improved target acquisition logic (works for all modes)
    local foundValidTarget = false
    for i=1,4 do
        local member = "party"..i
        if UnitExists(member) then
            local target = member.."target"
            if UnitExists(target) and UnitCanAttack("player", target) and not UnitIsDeadOrGhost(target) then
                -- Always update target to match party member's current target
                if not UnitExists("target") or not UnitIsUnit("target", target) then
                    TargetUnit(target)
                    DebugMessage("Assisting "..UnitName(member).." on "..UnitName(target))
                end
                foundValidTarget = true
                break
            end
        end
    end

    if not foundValidTarget then
        if UnitExists("target") and (UnitIsDeadOrGhost("target") or not UnitCanAttack("player", "target")) then
            ClearTarget()
        end
        return false
    end

    -- Additional check in case target became invalid
    if not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDeadOrGhost("target") then
        ClearTarget()
        return false
    end

    -- Skip damage if target is Gouged or Hibernated
    if IsTargetGouged() then
        DebugMessage("Target is gouged - skipping damage")
        return false
    end

    if IsTargetHibernated() then
        DebugMessage("Target is hibernated - skipping damage")
        return false
    end

    -- Always allow Faerie Fire regardless of DPS mode setting
    if faerieFireEnabled and not HasDebuff("target", FAERIE_FIRE_TEXTURE) then
        DebugMessage("Faerie Fire on "..UnitName("target"))
        CastSpellByName(FAERIE_FIRE_SPELL)
        return true
    end

    -- Only proceed with damage spells if DPS mode is enabled
    if not damageAssistEnabled then
        return false
    end

    if UnitMana("player")/UnitManaMax("player")*100 < MIN_MANA_DAMAGE then
        return false
    end

    -- Standard DPS rotation
    if insectSwarmEnabled and not HasDebuff("target", IS_TEXTURE) then
        DebugMessage("Insect Swarm on "..UnitName("target"))
        CastSpellByName(IS_SPELL)
        return true
    end

    if moonfireEnabled and not HasDebuff("target", MOONFIRE_TEXTURE) then
        DebugMessage("Moonfire on "..UnitName("target"))
        CastSpellByName(MOONFIRE_SPELL)
        return true
    end

    if wrathEnabled then
        DebugMessage("Casting Wrath on "..UnitName("target"))
        CastSpellByName(WRATH_SPELL)
        return true
    end

    return false
end

local function ShouldLeaveCatFormForHealing()
    -- Never leave stealth if party member is still stealthed
    if IsInForm(PROWL_TEXTURE) and UnitExists(followTarget) and HasBuff(followTarget, STEALTH_TEXTURE) then
        DebugMessage("Maintaining stealth - skipping heal")
        return false
    end
    
    -- Only leave cat form for critical heals in combat
    if catModeEnabled and UnitAffectingCombat("player") then
        -- Check player first (30% threshold)
        if not UnitIsDeadOrGhost("player") and not IsUnitHostile("player") and 
           (UnitHealth("player") / UnitHealthMax("player")) * 100 <= 30 then
            return true
        end
        
        -- Check party members (25% threshold)
        for i=1,4 do
            local unit = "party"..i
            if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and not IsUnitHostile(unit) and 
               (UnitHealth(unit) / UnitHealthMax(unit)) * 100 <= 25 then
                return true
            end
        end
        return false
    end
    
    -- Normal healing behavior when not in cat mode or not in combat
    return true
end

local function HandleCatFormDPS()
    -- Target acquisition (same as before)
    for i=1,4 do
        local member = "party"..i
        if UnitExists(member) then
            local target = member.."target"
            if UnitExists(target) and UnitCanAttack("player", target) and not UnitIsDeadOrGhost(target) then
                if not UnitExists("target") or not UnitIsUnit("target", target) then
                    TargetUnit(target)
                    DebugMessage("Assisting "..UnitName(member).." on "..UnitName(target))
                end
                break
            end
        end
    end

    -- Must be in cat form to continue
    if not IsInForm(CAT_FORM_TEXTURE) then
        return false
    end

    -- Clear invalid targets (including fleeing mobs)
    if UnitExists("target") and (not UnitCanAttack("player", "target") or UnitIsDeadOrGhost("target")) then
        ClearTarget()
        return false
    end

    -- Start attacking if not already
    if not IsCurrentAction(60) then
        AttackTarget()
    end

    -- ONLY use cat form abilities
    local comboPoints = GetComboPoints()
    
    if comboPoints >= 2 then
        DebugMessage("Using Ferocious Bite (2 combo points)")
        CastSpellByName(FEROCIOUS_BITE_SPELL)
        return true
    end
    
    DebugMessage("Using Claw to build combo points")
    CastSpellByName(CLAW_SPELL)
    return true
end

local function HandleSprintFollowing()
    if not followEnabled or UnitAffectingCombat("player") or not UnitExists(followTarget) or not IsInRange(followTarget) then 
        return false 
    end
    
    -- Check if our follow target is sprinting
    if not HasBuff(followTarget, SPRINT_TEXTURE) then
        return false
    end
    
    -- If we're already dashing, just maintain cat form
    if IsInForm(DASH_TEXTURE) then
        if not IsInForm(CAT_FORM_TEXTURE) then
            DebugMessage("Follow target sprinting - entering Cat Form to maintain Dash")
            CastSpellByName(CAT_FORM_SPELL)
        end
        return true
    end
    
    -- Enter cat form if not already
    if not IsInForm(CAT_FORM_TEXTURE) then
        DebugMessage("Follow target sprinting - entering Cat Form")
        CastSpellByName(CAT_FORM_SPELL)
        return true
    end
    
    -- Cast dash if in cat form and not already dashing
    if IsInForm(CAT_FORM_TEXTURE) and not IsInForm(DASH_TEXTURE) then
        DebugMessage("Follow target sprinting - using Dash to keep up")
        CastSpellByName(DASH_SPELL)
        return true
    end
    
    return false
end

local function DoDribbleActions()
    -- Handle special cases
    if UnitExists("target") and IsTargetGouged() then
        if HandleGougedTarget() then return end
    end

    if CheckEmergencyHeal() then return end
    
    -- Check for poison debuffs
    if CheckAbolishPoison() then return end

    if CheckRemoveCurse() then return end
    
    UpdateExpectedHoTHealing() -- Update expected HoT healing first
    
    -- Check if we should exit temporary DPS mode (only when combat ends)
    if tempDPSMode and not UnitAffectingCombat("player") then
        tempDPSMode = false
        DebugMessage("Combat ended - returning to Cat Mode")
    end
    
    -- Handle follow (works in all modes)
    if followEnabled and UnitExists(followTarget) and not IsInForm(PROWL_TEXTURE) then
        FollowUnit(followTarget)
    end

    -- Handle stealth following (highest priority)
    if HandleStealthFollowing() then 
        DebugMessage("Maintaining stealth with party")
        return 
    end
    
    -- Handle sprint following (second highest priority)
    if HandleSprintFollowing() then
        DebugMessage("Maintaining dash with sprinting party member")
        return
    end


    -- In temporary DPS mode (after leaving cat form to heal)
    if tempDPSMode then
        -- First handle emergency healing
        if CheckSwiftmend() then return end
        
        -- Check if anyone needs healing (below 60%)
        local needsHeal = false
        if not UnitIsDeadOrGhost("player") and not IsUnitHostile("player") and 
           (UnitHealth("player") / UnitHealthMax("player")) * 100 < 60 then
            needsHeal = true
        end
        
        if not needsHeal then
            for i=1,4 do
                local unit = "party"..i
                if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and not IsUnitHostile(unit) and 
                   (UnitHealth(unit) / UnitHealthMax(unit)) * 100 < 60 then
                    needsHeal = true
                    break
                end
            end
        end
        
        -- Perform healing if needed
        if needsHeal then
            if CheckRejuvenation() then return end
            if CheckAndHeal() then return end
        else
            -- No healing needed - do DPS but never on fleeing mobs
            if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
                local oldDPSState = damageAssistEnabled
                damageAssistEnabled = true
                if CastDamageSpells() then
                    damageAssistEnabled = oldDPSState
                    return
                end
                damageAssistEnabled = oldDPSState
            end
        end
        
        -- Don't return to cat form until combat ends
        return
    end

    -- Original cat mode logic
    if catModeEnabled then
        damageAssistEnabled = false
        
        if not UnitAffectingCombat("player") then
            -- Out of combat behavior
            if CheckSwiftmend() then return end
            if CheckRejuvenation() then return end
            if CheckAndHeal() then return end
            
            -- Default to cat form when idle
            if not IsInForm(CAT_FORM_TEXTURE) then
                DebugMessage("Entering cat form (idle)")
                CastSpellByName(CAT_FORM_SPELL)
                return
            end
            
            -- Assist party members
            if HandleCatFormDPS() then
                return
            end
        else
            -- In combat - check for critical heals
            if ShouldLeaveCatFormForHealing() then
                if IsInForm(CAT_FORM_TEXTURE) then
                    DebugMessage("Leaving cat form for critical healing - entering Temp DPS Mode")
                    CastSpellByName(CAT_FORM_SPELL) -- Leave form
                    tempDPSMode = true -- Enter temporary DPS mode
                    return
                else
                    -- We're already out of cat form (in temp DPS mode)
                    if CheckSwiftmend() then return end
                    if CheckRejuvenation() then return end
                    if CheckAndHeal() then return end
                    
                    -- No more healing needed - stay in temp DPS mode until combat ends
                end
            else
                -- Stay in cat form and DPS
                if not IsInForm(CAT_FORM_TEXTURE) and not tempDPSMode then
                    DebugMessage("Entering cat form (combat)")
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
        if CastDamageSpells() then return end
    end

    -- Final fallback - only return to cat form if not in tempDPSMode
    if catModeEnabled and not IsInForm(CAT_FORM_TEXTURE) and not tempDPSMode then
        DebugMessage("Entering cat form (fallback)")
        CastSpellByName(CAT_FORM_SPELL)
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
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Full DPS mode enabled (Cat mode disabled - all offensive spells active)")
    else
        DEFAULT_CHAT_FRAME:AddMessage("Dribble: Damage spells disabled (still casting Faerie Fire and assisting party)")
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
    tempDPSMode = false -- Reset temporary DPS mode when toggling
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

local function ToggleDebugMode()
    debugMode = not debugMode
    DEFAULT_CHAT_FRAME:AddMessage("Dribble: Debug mode "..(debugMode and "enabled" or "disabled"))
end

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
SLASH_DRIBBLEDEBUG1 = "/dribbledebug"

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
SlashCmdList["DRIBBLEDEBUG"] = ToggleDebugMode
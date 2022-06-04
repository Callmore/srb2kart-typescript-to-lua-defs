-- Advance tricks
-- by Callmore

-- Tricks intended to help increase the amount of choices a player has
-- in mid-air. Inspired by how MK8 has different trick animations depending on
-- what direction you are holding at the time.

-- Holding up will cause tricks to launch you upward but at the cost of your
-- horizonal momentum
-- Holding down will cause tricks to send you downwards, building speed. This
-- speed is released when you hit the floor, and converted into a large burst
-- forwards.
-- Not holding a direction will cause the trick to launch you forwards, at the
-- cost of your vertical momentum. This will cancel both upwards and downwards
-- momentum.

-- Holding either left or right will redirect your horizonal momentum in that
-- direction, potenionally recovering from a bad bump or launch, or helping you
-- take turns tighter.

-- 1.1
rawset(_G, "ADVANCETRICKS", 1*FRACUNIT + 1)

freeslot("S_ADVANCETRICKS_INDICATOR")
states[S_ADVANCETRICKS_INDICATOR] = {SPR_FWRK, A|FF_FULLBRIGHT|FF_ANIMATE, -1, nil, 3, 2, S_ADVANCETRICKS_INDICATOR}

-- Console variables

-- Toggle to disable advance tricks
-- I mean sure I guess...
local cv_tricksEnabled = CV_RegisterVar{
    name = "advt_enabled",
    defaultvalue = "Yes",
    flags = CV_NETVAR,
    PossibleValue = CV_YesNo
}

-- Infinite tricks toggles being able to trick endlessly in mid-air.
-- Someone suguested this in VC and I was like "okay".
local cv_infiniteTricks = CV_RegisterVar{
    name = "advt_rushtricks",
    defaultvalue = "Off",
    flags = CV_NETVAR,
    PossibleValue = CV_OnOff
}

-- Up trick power toggles between normal up tricks and *CrAzY* up tricks.
-- Crazy tricks don't remove speed when used and boost you up more than usual.
local cv_upTrickPower = CV_RegisterVar{
    name = "advt_uptrickpower",
    defaultvalue = "Normal",
    flags = CV_NETVAR,
    PossibleValue = {Normal = 0, Crazy = 1}
}

local cv_trickMomentumGuide = CV_RegisterVar{
    name = "advt_trickmomentumguide",
    defaultvalue = "Off",
    flags = 0,
    PossibleValue = CV_OnOff
}

-- Invert modes
local INVM_NONE = 0 -- 00
local INVM_HORIZONAL = 1 -- 01
local INVM_VERTICAL = 2 -- 10
local INVM_BOTH = 3 -- 11

-- Initalise advance tricks for a player.
local function initPlayer(p)
    p.advTricks = {
        airTics = 0,
        hasTricked = false,
        lastbrakeStatus = false,

        -- Spinning timers for spinning
        -- The cap can be set by the code for different spin lengths
        spinTime = 0,
        spinTimeMax = 0,
        spinAmount = 360,
        spinContinus = 0,

        lastHeldDirection = -1,
        downTrickActive = false,
        downTrickLastVelocity = 0,

        upTrickActive = false,

        -- tutorial related dumbvars
        -- (Guess they might be useful for some extra hooks for other mods?)
        didTrick = false,
        didUpTrick = false,
        didDownTrick = false,
        didRedirection = false,
    }
end

-- Check if a player is allowed to trick, returns true if they can,
-- returns false otherwise
local function canPlayerTrick(p)
    return (cv_tricksEnabled.value == 1
        and p.kartstuff[k_squishedtimer] <= 0
        and p.kartstuff[k_spinouttimer] <= 0
        and p.kartstuff[k_respawn] <= 0
        and p.deadtimer <= 0
        and p.playerstate == PST_LIVE
        and not P_IsObjectOnGround(p.mo) and p.advTricks.airTics >= 5
        and not p.advTricks.hasTricked)
end

local NEUTRAL_TRICK_MULTIPLYER = FRACUNIT*20

-- Calculate momentum for tricks
local function calculateUpTrickMomentum(p, angle)
    -- Calculate how much to divide the speed by
    -- this is only used for the meme option help
    local div_factor = FRACUNIT/2
    if cv_upTrickPower.value then
        div_factor = FRACUNIT
    end

    local new_speed = FixedMul(R_PointToDist2(0, 0, p.mo.momx, p.mo.momy), div_factor) -- -50% speed

    local x = FixedMul(cos(angle), new_speed)
    local y = FixedMul(sin(angle), new_speed)

    -- slight vertical boost
    local z = p.mo.scale*12 * P_MobjFlip(p.mo)

    if cv_upTrickPower.value then
        -- "slight" vertical boost
        z = p.mo.scale*24 * P_MobjFlip(p.mo)
    end
    return x, y, z
end

local function calculateDownTrickMomentum(p, angle)
    local gain = FixedMul(R_PointToDist2(0, 0, p.mo.momx, p.mo.momy), FRACUNIT/3) -- 33.3% is taken

    -- reduce player speed to 20% of its current
    local x = FixedMul(cos(angle), gain)
    local y = FixedMul(sin(angle), gain)

    -- add the amount of speed lost to the vertical velocity
    local z = (-p.mo.scale*16 - gain) * P_MobjFlip(p.mo)

    return x, y, z
end

local function calculateNeutralTrickMomentum(p, angle)
    local length = R_PointToDist2(0, 0, p.mo.momx, p.mo.momy)

    local normX, normY = cos(angle), sin(angle)
    if length == 0 then
        normX, normY = 0, 0
    end

    -- add the normalised velocity to the player's velocity multiplied by a bonus
    local x = FixedMul(cos(angle), length) + FixedMul(FixedMul(normX, NEUTRAL_TRICK_MULTIPLYER), p.mo.scale)
    local y = FixedMul(sin(angle), length) + FixedMul(FixedMul(normY, NEUTRAL_TRICK_MULTIPLYER), p.mo.scale)

    -- kill the player's vertical velocity
    local z = FixedMul(NEUTRAL_TRICK_MULTIPLYER, p.mo.scale/8) * P_MobjFlip(p.mo)

    return x, y, z
end

-- Get trick angle
local function getTrickAngleAndShift(p)
    -- get normalised horizonal velocity
    local angle = R_PointToAngle2(0, 0, p.mo.momx, p.mo.momy)

    -- Angle tweaking for recovery or speed
    local turn = p.cmd.driftturn

    -- Adjust for if you like MK wii and want your tricks reversed
    if (p.advt_invertMode or INVM_NONE) & INVM_HORIZONAL then
        turn = -$
    end

    local shift = 0
    if turn >= 400 then
        angle = $ + ANG15
        shift = 1
    elseif turn <= -400 then
        angle = $ - ANG15
        shift = -1
    end

    return angle, shift
end

-- Get buttons and invert settings
local function getTrickButtons(p)
    local btns = p.cmd.buttons
    local upbtn = BT_FORWARD
    local downbtn = BT_BACKWARD
    if (p.advt_invertMode or INVM_NONE) & INVM_VERTICAL then
        upbtn = BT_BACKWARD
        downbtn = BT_FORWARD
    end
    return btns, upbtn, downbtn
end

-- Preform a trick for a player. This does not do any check and just tricks.
local function doTrick(p)
    local angle, shift = getTrickAngleAndShift(p)

    if shift ~= 0 then
        p.advTricks.didRedirection = true
    end


    -- Delete pogo state so its hard to gain more speed
    p.kartstuff[k_pogospring] = 0

    -- Do not start a spin if doing a up or down trick
    local is_down_or_up_trick = false

    local btns, upbtn, downbtn = getTrickButtons(p)

    if btns & upbtn and shift == 0 then
        -- UP TRICK

        is_down_or_up_trick = true

        p.advTricks.upTrickActive = true
        p.advTricks.downTrickActive = false

        p.advTricks.didUpTrick = true

        p.mo.momx, p.mo.momy, p.mo.momz = calculateUpTrickMomentum(p, angle)
    elseif btns & downbtn and shift == 0 then
        -- DOWN TRICK

        is_down_or_up_trick = true

        -- Same sorta thing for forward tricks, take 33.3% of the speed,
        -- convert that to verical velocity, but when you hit the floor give
        -- the speed back and some more
        p.advTricks.downTrickActive = true
        p.advTricks.upTrickActive = false

        p.advTricks.didDownTrick = true

        p.mo.momx, p.mo.momy, p.mo.momz = calculateDownTrickMomentum(p, angle)
    else
        -- NEUTRAL TRICK

        p.advTricks.upTrickActive = false
        p.advTricks.downTrickActive = false

        p.mo.momx, p.mo.momy, p.mo.momz = calculateNeutralTrickMomentum(p, angle)
    end

    -- SOUND
    S_StartSound(p.mo, sfx_cdfm52)

    -- Fireworks
    for i = 1, 3 do
        local fw = P_SpawnMobj(p.mo.x, p.mo.y, p.mo.z, MT_KARMAFIREWORK)
        K_MatchGenericExtraFlags(fw, p.mo)

        fw.momx = p.mo.momx + (FixedMul(P_RandomFixed() - (FRACUNIT/2), mapobjectscale * 4))
        fw.momy = p.mo.momy + (FixedMul(P_RandomFixed() - (FRACUNIT/2), mapobjectscale * 4))
        fw.momz = p.mo.momz + (FixedMul(P_RandomFixed() - (FRACUNIT/2), mapobjectscale * 4) * P_MobjFlip(fw))
        fw.color = p.mo.color
    end

    -- start a speeen
    if not is_down_or_up_trick then
        p.advTricks.spinTime = 1
        p.advTricks.spinTimeMax = 2*TICRATE / 3
        p.advTricks.spinAmount = 360 * p.advTricks.lastHeldDirection
        if shift ~= 0 then
            p.advTricks.spinAmount = 720 * shift
        end
    else
        p.advTricks.spinContinus = 0
    end

    p.advTricks.didTrick = true
end

local function doDownTrick(p)
    local speed = R_PointToDist2(0, 0, p.mo.momx, p.mo.momy)
    local dir = p.mo.angle

    local fall_velocity = max(FixedMul(abs(p.advTricks.downTrickLastVelocity) - 16*p.mo.scale, 3*FRACUNIT), 0)

    p.mo.momx = FixedMul(cos(dir), speed + fall_velocity)
    p.mo.momy = FixedMul(sin(dir), speed + fall_velocity)

    -- play spindash sound
    S_StartSound(p.mo, sfx_s262)
end

-- Easing function for use while spinning the player
-- taken from https://easings.net/#easeOutCubic
local function easeInCubic(x)
    return FixedMul(FixedMul(x, x), x)
end

local function easeOutCubic(x)
    local inv = FRACUNIT - x
    return FRACUNIT - FixedMul(FixedMul(inv, inv), inv)
end

-- Thanks yoshimo
local function R_PointToDist3(x, y, z, tx, ty, tz)
    return R_PointToDist2(0, z, R_PointToDist2(x, y, tx, ty), tz)
end

-- I use pmo here to refer to the player's mobj. Since p is usually used to
-- refer to a variable holding a player, pmo is holding a player's mobj.
local function pThink(pmo)
    -- Sanity checks cause kart is ??? sometimes
    if not (pmo and pmo.valid and pmo.player and pmo.player.valid) then return end

    -- shortcut that would usualy be in a player iterator
    local p = pmo.player

    -- first, if they do not have variables initialised then do that
    if not p.advTricks then
        initPlayer(p)
    end

    -- Now we know that is initialised, go store it for quick accsess
    local at = p.advTricks

    -- Get control input, detect if brake was pushed down and set a variable
    local didPushBrake = (p.cmd.buttons & (p.advt_trickButton or BT_BRAKE)) and not at.lastBrakeStatus
    at.lastBrakeStatus = p.cmd.buttons & (p.advt_trickButton or BT_BRAKE)

    -- Check if the player is allowed to trick, only allow if they have not
    -- tricked this jump, have been in the air for at least 5 tics, and are not
    -- in a no control state.

    if not P_IsObjectOnGround(pmo) then
        at.airTics = $+1
    else
        at.airTics = 0
        at.hasTricked = false
        at.spinTime = 0
        at.spinTimeMax = 0

        if at.downTrickActive then
            doDownTrick(p)
            at.downTrickActive = false
        end

        if at.upTrickActive then
            at.upTrickActive = false
        end
    end

    if at.downTrickActive then
        at.downTrickLastVelocity = pmo.momz
    else
        at.downTrickLastVelocity = 0
    end

    if at.upTrickActive
    and (not G_BattleGametype()
    or not ((p.kartstuff[k_bumper] > 0
    and p.kartstuff[k_comebacktimer] <= 0)
    or p.kartstuff[k_comebackmode] == 1)) then
        for pi in players.iterate do
            if p ~= pi and pi and pi.valid and pi.mo and pi.mo.valid
            and pi.kartstuff[k_squishedtimer] <= 0
            and pi.kartstuff[k_spinouttimer] <= 0
            and pi.kartstuff[k_respawn] <= 0
            and (not G_BattleGametype()
            or (pi.kartstuff[k_bumper] > 0
            and pi.kartstuff[k_comebacktimer] <= 0))
            and not pi.advTricks.upTrickActive then
                local dist = R_PointToDist3(p.mo.x, p.mo.y, p.mo.z, pi.mo.x, pi.mo.y, pi.mo.z)
                if dist < (p.mo.scale * 512) then
                    pi.mo.momx = $ + FixedMul(p.mo.x - pi.mo.x, p.mo.scale/256)
                    pi.mo.momy = $ + FixedMul(p.mo.y - pi.mo.y, p.mo.scale/256)
                    pi.mo.momz = $ + FixedMul(p.mo.z - pi.mo.z, p.mo.scale/256)
                end
            end
        end
    end

    at.didTrick = false
    at.didUpTrick = false
    at.didDownTrick = false
    at.didRedirection = false
    
    if canPlayerTrick(p) and didPushBrake then
        doTrick(p)
        if not cv_infiniteTricks.value then
            at.hasTricked = true
        end
    end

    -- Grab the last held direction
    if p.cmd.driftturn > 0 then
        at.lastHeldDirection = 1
    elseif p.cmd.driftturn < 0 then
        at.lastHeldDirection = -1
    end

    -- Do funny spin animation
    if at.spinTime > 0 then
        local spin_amount = easeOutCubic(FixedDiv(at.spinTime, at.spinTimeMax))
        local spin_angle = FixedAngle(spin_amount * at.spinAmount)
        p.frameangle = $ + spin_angle
        at.spinTime = $ + 1
        if at.spinTime >= at.spinTimeMax then
            at.spinTime = 0
            at.spinTimeMax = 0
            at.spinAmount = 360
        end

        -- Do some extra flashing to help convay the trick's power
        if (at.spinTime % 4) >= 2 then
            pmo.colorized = true
        end
        if at.spinTime & 3 and at.spinTime <= (at.spinTimeMax / 2) then
            local g = P_SpawnGhostMobj(pmo)
            g.colorized = true
            g.tics = 4
        end
    elseif at.downTrickActive or at.upTrickActive then
        if at.downTrickActive then
            p.advTricks.spinContinus = $ + (FixedAngle(p.advTricks.downTrickLastVelocity) * 2)
        else
            -- Up trick must be active here
            p.advTricks.spinContinus = $ + ANG60
        end
        p.frameangle = $ + p.advTricks.spinContinus

        if leveltime & 3 then
            local g = P_SpawnGhostMobj(pmo)
            g.colorized = true
            g.tics = 4
        end

        if leveltime % 5 == 0 then
            p.mo.colorized = true
        end
    end
end
addHook("MobjThinker", pThink, MT_PLAYER)
-- I am using a MobjThinker instead of a ThinkFrame because I should only need
-- to effect players, not the global gamestate.

-- Initialisation function
local function pInit()
    if leveltime ~= 1 then return end
    for p in players.iterate do
        initPlayer(p)
    end
end
addHook("ThinkFrame", pInit)
-- This is here to force reitialise any player who was spectated.

-- Reset player functions
local function moReset(mo)
    if not (mo and mo.valid and mo.player and mo.player.valid) then return end
    initPlayer(mo.player)
end
addHook("MobjDeath", moReset, MT_PLAYER)

local function pReset(p)
    if not (p and p.valid) then return end
    initPlayer(p)
end
addHook("PlayerSpawn", pReset)
-- Reset a player when they die to avoid spilling stuff over multiple lives

-- Funny mid-air up trick shenanigans
-- Code taken from hpmod because detecting bumps is ouch
local function midAirBump(mo, other)
    if mo and mo.valid and mo.player and mo.player.valid
    and other and other.valid and other.type == MT_PLAYER and other.player and other.player.valid
    and ((mo.z >= other.z and mo.z < other.z + other.height)
    or (other.z >= mo.z and other.z < mo.z + mo.height)) then
        local att, vic = nil, nil
        if mo.player.advTricks.upTrickActive and not other.player.advTricks.upTrickActive then
            att = mo
            vic = other.player
        elseif other.player.advTricks.upTrickActive and not mo.player.advTricks.upTrickActive then
            att = other
            vic = mo.player
        end

        if att ~= nil and vic ~= nil then
            if att.player.kartstuff[k_squishedtimer] > 0
            or att.player.kartstuff[k_spinouttimer] > 0
            or att.player.kartstuff[k_respawn] > 0
            or att.player.deadtimer > 0
            or (G_BattleGametype()
            and ((att.player.kartstuff[k_bumper] > 0
            and att.player.kartstuff[k_comebacktimer] <= 0)
            or att.player.kartstuff[k_comebackmode] == 1)) then
                return
            end
            
            K_SpinPlayer(vic, att, 1, att, false)
        end
    end
end
addHook("MobjCollide", midAirBump, MT_PLAYER)

-- ngl i wonder if anyone will just type mk and map it to brake
local stringToButton = {
    i = BT_ATTACK,
    item = BT_ATTACK,

    d = BT_DRIFT,
    drift = BT_DRIFT,
    mk = BT_DRIFT,

    b = BT_BRAKE,
    brake = BT_BRAKE,

    c = BT_CUSTOM1,
    c1 = BT_CUSTOM1,
    custom1 = BT_CUSTOM1,
    ["custom 1"] = BT_CUSTOM1,
    
    c2 = BT_CUSTOM1,
    custom2 = BT_CUSTOM1,
    ["custom 2"] = BT_CUSTOM2,
    
    c3 = BT_CUSTOM3,
    custom3 = BT_CUSTOM3,
    ["custom 3"] = BT_CUSTOM3,
}

local buttonToString = {
    [BT_ATTACK] = "Item",
    [BT_DRIFT] = "Drift",
    [BT_BRAKE] = "Brake",
    [BT_ACCELERATE] = "Accelerate",
    [BT_CUSTOM1] = "Custom 1",
    [BT_CUSTOM2] = "Custom 2",
    [BT_CUSTOM3] = "Custom 3",
}

-- Console commands
local function printMapButtonHelpText(p)
    CONS_Printf(p, "Current trick button is \130" .. buttonToString[(p.advt_trickButton or BT_BRAKE)] .. "\128.")
    CONS_Printf(p, "Valid keys are: \130Brake\128, \130Drift\128, \130Item\128, \130Custom 1\128, \130Custom 2\128, \130Custom 3\128.")
end

local function cmd_mapTrickButton(p, new_button)
    if new_button == nil then
        printMapButtonHelpText(p)
        return
    end

    new_button = $:lower()

    if stringToButton[new_button] == nil then
        CONS_Printf(p, 'Invalid button name "\130' .. new_button .. '\128".')
        printMapButtonHelpText(p)
        return
    end

    local new_trick_button = stringToButton[new_button]

    CONS_Printf(p, "Trick button set to \130" .. buttonToString[new_trick_button] .. "\128.")
    p.advt_trickButton = new_trick_button
end
COM_AddCommand("advt_trickbutton", cmd_mapTrickButton)



local stringToInvert = {
    o = INVM_NONE,
    off = INVM_NONE,

    h = INVM_HORIZONAL,
    horizonal = INVM_HORIZONAL,

    v = INVM_VERTICAL,
    vertical = INVM_VERTICAL,

    b = INVM_BOTH,
    both = INVM_BOTH,
}

local invertToString = {
    [INVM_NONE] = "No",
    [INVM_HORIZONAL] = "Horizonal",
    [INVM_VERTICAL] = "Vertical",
    [INVM_BOTH] = "Both",
}

local function printInvertControlHelpText(p)
    CONS_Printf(p, "Current inverted axis is \130" .. invertToString[p.advt_invertMode or INVM_NONE] .. "\128.")
    CONS_Printf(p, "Valid values are: \130Off\128, \130Horizonal\128, \130Vertical\128, \130Both\128.")
end

local function cmd_invertControls(p, new_invert)
    if new_invert == nil then
        printInvertControlHelpText(p)
        return
    end

    new_invert = $:lower()

    if stringToInvert[new_invert] == nil then
        CONS_Printf(p, 'Invalid value "\130' .. new_invert .. '\128".')
        printInvertControlHelpText(p)
        return
    end

    local axis_mod = stringToInvert[new_invert]

    local str_add = "."
    if axis_mod == INVM_BOTH or axis_mod == INVM_NONE then
        str_add = "es."
    end
    CONS_Printf(p, "Inverting \130" .. invertToString[axis_mod] .. "\128 axis" .. str_add)
    p.advt_invertMode = axis_mod
end
COM_AddCommand("advt_invertmode", cmd_invertControls)

-- minenice asked for this
local function cmd_mkmode(p)
    cmd_invertControls(p, "both")
end
COM_AddCommand("advt_mkwiimode", cmd_mkmode)

-- TUTORIALCODE!!!1!!!111!!!1111!!!11!11!!11!!!1!1!!!1!!!!1!1!1!!!1!1!!1
local TUTORIAL_SAVE_FILE_NAME = "advtrickstutorial.sav2"
local TRICKS_TO_ADVANCE_TUTORIAL = 5

local tutorialState = 0
local tutTricksWaited = 0

local tutHasUpTricked = false
local tutHasDownTricked = false

local tutInstructionGreen = false
local tutInstructionFadeTime = 0
local tutInstructionFadeTimeMax = TICRATE / 2
local tutInstructionFadeInOut = false -- false for fade-in, true for fade-out

local tutAlreadyDone = false

-- Try to load the tutorial file
local f = io.open(TUTORIAL_SAVE_FILE_NAME, "r")
if f ~= nil then
    local completed = f:read("*number")
    if completed >= ADVANCETRICKS then
        tutAlreadyDone = true
        print("Detected already completed tutorial, skipping steps past 1.")
        print("Use \130advt_resettutoral\128 or delete \130" .. TUTORIAL_SAVE_FILE_NAME .. "\128 to reset the tutorial.")
    end
    f:close()
end

local function fadeOutTasks()
    tutInstructionFadeTime = tutInstructionFadeTimeMax
    tutInstructionFadeInOut = true
    tutInstructionGreen = true
end

local function fadeInTasks()
    tutInstructionFadeTime = tutInstructionFadeTimeMax
    tutInstructionFadeInOut = false
    tutInstructionGreen = false
end

-- Save the tutorial, say if it fails
local function saveTutorialDone()
    f = assert(io.open(TUTORIAL_SAVE_FILE_NAME, "w"))
    f:write(ADVANCETRICKS)
    f:close()
    print("Saved tutorial completed to \130" .. TUTORIAL_SAVE_FILE_NAME .. "\128.")
end

local function tutorialThinker()
    if tutorialState == nil and tutInstructionFadeTime == 0 then return end

    if not (consoleplayer and consoleplayer.valid
    and consoleplayer.mo and consoleplayer.mo.valid and consoleplayer.advTricks) then return end

    if tutInstructionFadeTime > 0 then
        tutInstructionFadeTime = $-1
    end

    local p = consoleplayer
    local at = p.advTricks

    if tutorialState == 0 then
        -- Pre first trick

        if canPlayerTrick(p) then
            tutorialState = 1 -- ADVANCE
            fadeInTasks()
        end

    elseif tutorialState == 1 then
        -- First trick

        if at.didTrick then
            tutorialState = 2 -- ADVANCE
            tutTricksWaited = TRICKS_TO_ADVANCE_TUTORIAL
            fadeOutTasks()
        end

    elseif tutorialState == 2 then
        -- Waiting for 5 tricks

        if tutAlreadyDone then
            if tutInstructionFadeTime == 0 then
                tutorialState = nil
            end
        elseif at.didTrick then
            tutTricksWaited = $-1
            if tutTricksWaited <= 0 then
                tutorialState = 3 -- ADVANCE
                fadeInTasks()
            end
        end

    elseif tutorialState == 3 then
        -- Advanced tricks
        if at.didUpTrick then
            tutHasUpTricked = true
        elseif at.didDownTrick then
            tutHasDownTricked = true
        end

        if tutHasUpTricked and tutHasDownTricked then
            tutorialState = 4 -- ADVANCE
            tutTricksWaited = TRICKS_TO_ADVANCE_TUTORIAL
            fadeOutTasks()
        end

    elseif tutorialState == 4 then
        -- Waiting for 5 more tricks

        if at.didTrick then
            tutTricksWaited = $-1
            if tutTricksWaited <= 0 then
                tutorialState = 5 -- ADVANCE
                fadeInTasks()
            end
        end

    elseif tutorialState == 5 then
        -- Redirection

        if at.didRedirection then
            tutorialState = nil
            fadeOutTasks()

            saveTutorialDone()
        end

    end
end
addHook("ThinkFrame", tutorialThinker)

local HUD_FADE_TABLE = {  -- oh boy massive tables for translating transparency
    {V_90TRANS, V_90TRANS, V_90TRANS, V_90TRANS, V_90TRANS, V_90TRANS, V_90TRANS, V_90TRANS, V_90TRANS, V_90TRANS},
    {V_80TRANS, V_80TRANS, V_80TRANS, V_80TRANS, V_80TRANS, V_90TRANS, V_90TRANS, V_90TRANS, V_90TRANS, V_90TRANS},
    {V_70TRANS, V_70TRANS, V_70TRANS, V_70TRANS, V_80TRANS, V_80TRANS, V_80TRANS, V_90TRANS, V_90TRANS, V_90TRANS},
    {V_60TRANS, V_60TRANS, V_60TRANS, V_70TRANS, V_70TRANS, V_80TRANS, V_80TRANS, V_80TRANS, V_90TRANS, V_90TRANS},
    {V_50TRANS, V_50TRANS, V_60TRANS, V_60TRANS, V_70TRANS, V_70TRANS, V_80TRANS, V_80TRANS, V_90TRANS, V_90TRANS},
    {V_40TRANS, V_40TRANS, V_50TRANS, V_50TRANS, V_60TRANS, V_70TRANS, V_70TRANS, V_80TRANS, V_80TRANS, V_90TRANS},
    {V_30TRANS, V_30TRANS, V_40TRANS, V_50TRANS, V_50TRANS, V_60TRANS, V_70TRANS, V_70TRANS, V_80TRANS, V_90TRANS},
    {V_20TRANS, V_20TRANS, V_30TRANS, V_40TRANS, V_50TRANS, V_60TRANS, V_60TRANS, V_70TRANS, V_80TRANS, V_90TRANS},
    {V_10TRANS, V_10TRANS, V_20TRANS, V_30TRANS, V_40TRANS, V_50TRANS, V_60TRANS, V_70TRANS, V_80TRANS, V_90TRANS},
    {0, V_10TRANS, V_20TRANS, V_30TRANS, V_40TRANS, V_50TRANS, V_60TRANS, V_70TRANS, V_80TRANS, V_90TRANS}
}

local BASE_VIDEO_FLAGS = V_SNAPTORIGHT|V_6WIDTHSPACE|V_ALLOWLOWERCASE

local function tutorialHud(v, p)
    if tutorialState == nil and tutInstructionFadeTime == 0 then return end
    if p ~= consoleplayer then return end
    if p.spectator then return end
    if cv_tricksEnabled.value == 0 then return end -- :(

    -- Im pulling in some extra code for fading

    local cv_translucentHud = CV_FindVar("translucenthud")
    local t = tutInstructionFadeTime
    if not tutInstructionFadeInOut then
        t = tutInstructionFadeTimeMax - tutInstructionFadeTime
    end
    local fade_flag = HUD_FADE_TABLE[cv_translucentHud.value][11 - min(10, max(0, t))]
    if fade_flag == nil then return end

    local add_x = FixedInt(easeOutCubic(FixedDiv(t, tutInstructionFadeTimeMax)) * 10)
    if not tutInstructionFadeInOut then
        add_x = 10 - $ + 10
    end

    local turn_green = 0
    if tutInstructionGreen then
        turn_green = V_GREENMAP
    end

    if tutorialState == 1 or tutorialState == 2 then
        local trick_btn = buttonToString[(p.advt_trickButton or BT_BRAKE)]
        v.drawString(300 + add_x, 130, "Push \130" .. trick_btn .. "\128 to \130trick\128!", BASE_VIDEO_FLAGS|fade_flag|turn_green, "thin-right")
    elseif tutorialState == 3 or tutorialState == 4 then
        local turn_green_up = 0
        local turn_green_down = 0
        if tutHasUpTricked then
            turn_green_up = V_GREENMAP
        end
        if tutHasDownTricked then
            turn_green_down = V_GREENMAP
        end

        local up_str = "up"
        local down_str = "down"
        if (p.advt_invertMode or INVM_NONE) & INVM_HORIZONAL then
            up_str = "down"
            down_str = "up"
        end

        v.drawString(300 + add_x, 130, "Hold \130" .. up_str .. "\128 while tricking to \130attack\128!", BASE_VIDEO_FLAGS|fade_flag|turn_green_up, "thin-right")
        v.drawString(300 + add_x, 140, "Hold \130" .. down_str .. "\128 while tricking to \130slam\128!", BASE_VIDEO_FLAGS|fade_flag|turn_green_down, "thin-right")
    elseif tutorialState == 5 or tutorialState == nil then
        v.drawString(300 + add_x, 130, "Hold \130left\128 or \130right\128 while tricking", BASE_VIDEO_FLAGS|fade_flag|turn_green, "thin-right")
        v.drawString(300 + add_x, 140, "to \130redirect your momentum\128!", BASE_VIDEO_FLAGS|fade_flag|turn_green, "thin-right")
    end
end
hud.add(tutorialHud, "game")

-- Delete tutorial progress and reset tutorial locally
-- Fails to open file silently
local function com_resetTutorial(p)
    if not p == consoleplayer then return end
    local f = io.open(TUTORIAL_SAVE_FILE_NAME, "w")
    if f then
        f:write(0)
        f:close()
    end
    tutorialState = 0
    tutHasUpTricked = false
    tutHasDownTricked = false
    tutAlreadyDone = false
    print("Tutorial reset.")
end
COM_AddCommand("advt_resettutorial", com_resetTutorial)

local function getStartPosition(p)
    local angle, shift = getTrickAngleAndShift(p)
    local btns, upbtn, downbtn = getTrickButtons(p)

    local mx, my, mz = 0, 0, 0
    if btns & upbtn then
        mx, my, mz = calculateUpTrickMomentum(p, angle)
    elseif btns & downbtn then
        mx, my, mz = calculateDownTrickMomentum(p, angle)
    else
        mx, my, mz = calculateNeutralTrickMomentum(p, angle)
    end

    return {
        x = p.mo.x,
        y = p.mo.y,
        z = p.mo.z,
        momx = mx,
        momy = my,
        momz = mz,
    }
end

local function predictNextPosition(pos, g)
    return {
        x = pos.x + pos.momx,
        y = pos.y + pos.momy,
        z = pos.z + pos.momz,
        momx = pos.momx,
        momy = pos.momy,
        momz = pos.momz - g,
    }
end

local PREDICTION_TICS = TICRATE/3

local momentumGuides = {[0]={}, {}, {}, {}}

local function spawnMomentumGuide(dpi)
    local t = P_SpawnMobj(0, 0, 0, MT_THOK)
    t.tics = 2
    t.state = S_ADVANCETRICKS_INDICATOR
    t.eflags = $|(MFE_DRAWONLYFORP1 << dpi)
    return t
end

-- Local only momentum guide
local function moveMomentumGuides()
    if not cv_trickMomentumGuide.value then return end

    for dpi = 0, 3 do -- 3 is max splitscreen players
        local is_player = dpi <= splitscreen

        if is_player and displayplayers[dpi] and displayplayers[dpi].valid and displayplayers[dpi].mo and displayplayers[dpi].mo.valid then
            local mg = momentumGuides[dpi]
            local p = displayplayers[dpi]
            if canPlayerTrick(p) then
                local grav = gravity * P_MobjFlip(p.mo)

                local player_initial_location = getStartPosition(p)

                local current_location = predictNextPosition(player_initial_location, grav)
                for i = 1, PREDICTION_TICS do
                    if not (mg[i] and mg[i].valid) then
                        mg[i] = spawnMomentumGuide(dpi)
                    end

                    mg[i].flags2 = $&~MF2_DONTDRAW
                    P_TeleportMove(mg[i], current_location.x, current_location.y, current_location.z)

                    current_location = predictNextPosition(current_location, grav)
                    mg[i].tics = 2
                    mg[i].color = p.mo.color

                    local max_scale = p.mo.scale
                    local percent_scale = FRACUNIT - FixedDiv(i, PREDICTION_TICS)
                    mg[i].scale = FixedMul(max_scale, percent_scale)
                end
            else
                for i = 1, PREDICTION_TICS do
                    if not (mg[i] and mg[i].valid) then
                        mg[i] = spawnMomentumGuide(dpi)
                    end
                    mg[i].flags2 = $|MF2_DONTDRAW
                    mg[i].tics = 2
                end
            end
        end
    end
end
addHook("ThinkFrame", moveMomentumGuides)

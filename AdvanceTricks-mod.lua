--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
rawset(_G, "ADVANCETRICKS", 1 * FRACUNIT + 1)
freeslot("S_ADVANCETRICKS_INDICATOR")
local cv_tricksEnabled = CV_RegisterVar({name = "advt_enabled", defaultvalue = "Yes", PossibleValue = CV_YesNo, flags = CV_NETVAR})
local cv_infiniteTricks = CV_RegisterVar({name = "advt_rushtricks", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = CV_NETVAR})
local cv_upTrickPower = CV_RegisterVar({name = "advt_uptrickpower", defaultvalue = "Normal", PossibleValue = {Normal = 0, Crazy = 1}, flags = CV_NETVAR})
local cv_trickMomentumGuide = CV_RegisterVar({name = "advt_trickmomentumguide", defaultvalue = "Off", PossibleValue = CV_OnOff, flags = 0})
---
-- @compileMembersOnly
local INVM_NONE = 0
---
-- @compileMembersOnly
local INVM_HORIZONAL = 1
---
-- @compileMembersOnly
local INVM_VERTICAL = 2
---
-- @compileMembersOnly
local INVM_BOTH = 3
local function initPlayer(p)
    p.advTricks = {
        airTics = 0,
        hasTricked = false,
        lastBrakeStatus = 0,
        spinTime = 0,
        spinTimeMax = 0,
        spinAmount = 360,
        spinContinus = 0,
        lastHeldDirection = -1,
        downTrickActive = false,
        downTrickLastVelocity = 0,
        upTrickActive = false,
        didTrick = false,
        didUpTrick = false,
        didDownTrick = false,
        didRedirection = false
    }
end
local function canPlayerTrick(p)
    if p.advTricks ~= nil then
        return cv_tricksEnabled.value == 1 and p.kartstuff[k_squishedtimer] <= 0 and p.kartstuff[k_spinouttimer] <= 0 and p.kartstuff[k_respawn] <= 0 and p.deadtimer <= 0 and p.playerstate == PST_LIVE and not P_IsObjectOnGround(p.mo) and p.advTricks.airTics >= 5 and not p.advTricks.hasTricked
    end
    return false
end
local NEUTRAL_TRICK_MULTIPLYER = 20 * FRACUNIT
local function calculateUpTrickMomentum(p, angle)
    local div_factor = FRACUNIT / 2
    if cv_upTrickPower.value == 1 then
        div_factor = FRACUNIT
    end
    local new_speed = FixedMul(
        R_PointToDist2(0, 0, p.mo.momx, p.mo.momy),
        div_factor
    )
    local x = FixedMul(
        cos(angle),
        new_speed
    )
    local y = FixedMul(
        sin(angle),
        new_speed
    )
    local z = p.mo.scale * 12 * P_MobjFlip(p.mo)
    if cv_upTrickPower.value == 1 then
        z = p.mo.scale * 24 * P_MobjFlip(p.mo)
    end
    return {x, y, z}
end
local function calculateDownTrickMomentum(p, angle)
    if p.mo ~= nil then
        local gain = FixedMul(
            R_PointToDist2(0, 0, p.mo.momx, p.mo.momy),
            FRACUNIT / 3
        )
        local x = FixedMul(
            cos(angle),
            gain
        )
        local y = FixedMul(
            sin(angle),
            gain
        )
        local z = (-p.mo.scale * 16 - gain) * P_MobjFlip(p.mo)
        return {x, y, z}
    end
    return {0, 0, 0}
end
local function calculateNeutralTrickMomentum(p, angle)
    if p.mo ~= nil then
        local length = R_PointToDist2(0, 0, p.mo.momx, p.mo.momy)
        local normX, normY = cos(angle), sin(angle)
        if length == 0 then
            normX, normY = 0, 0
        end
        local x = FixedMul(
            cos(angle),
            length
        ) + FixedMul(
            FixedMul(normX, NEUTRAL_TRICK_MULTIPLYER),
            p.mo.scale
        )
        local y = FixedMul(
            sin(angle),
            length
        ) + FixedMul(
            FixedMul(normY, NEUTRAL_TRICK_MULTIPLYER),
            p.mo.scale
        )
        local z = FixedMul(NEUTRAL_TRICK_MULTIPLYER, p.mo.scale / 8) * P_MobjFlip(p.mo)
        return {x, y, z}
    end
    return {0, 0, 0}
end
local function getTrickAngleAndShift(p)
    if p.mo ~= nil then
        local angle = R_PointToAngle2(0, 0, p.mo.momx, p.mo.momy)
        local turn = p.cmd.driftturn
        if (p.advt_invertMode or INVM_NONE) & INVM_HORIZONAL then
            turn = -turn
        end
        local shift = 0
        if turn >= 400 then
            angle = angle + ANG15
            shift = 1
        elseif turn <= -400 then
            angle = angle - ANG15
            shift = -1
        end
        return {angle, shift}
    end
    return {0, 0}
end
local function getTrickButtons(p)
    local btns = p.cmd.buttons
    local upbtn = BT_FORWARD
    local downbtn = BT_BACKWARD
    if (p.advt_invertMode or INVM_NONE) & INVM_VERTICAL then
        upbtn = BT_BACKWARD
        downbtn = BT_FORWARD
    end
    return {btns, upbtn, downbtn}
end
local function inBattleModeAndAlive(p)
    return p.kartstuff[k_bumper] > 0 and p.kartstuff[k_comebacktimer] <= 0 or p.kartstuff[k_comebackmode] == 1
end
local function doTrick(p)
    if p.advTricks == nil or p.mo == nil then
        return
    end
    local angle, shift = table.unpack(getTrickAngleAndShift(p))
    if shift ~= 0 then
        p.advTricks.didRedirection = true
    end
    p.kartstuff[k_pogospring] = 0
    local is_down_or_up_trick = false
    local btns, upbtn, downbtn = table.unpack(getTrickButtons(p))
    if btns & upbtn and shift == 0 then
        is_down_or_up_trick = true
        p.advTricks.upTrickActive = true
        p.advTricks.downTrickActive = false
        p.advTricks.didUpTrick = true
        local ____temp_0 = calculateUpTrickMomentum(p, angle)
        p.mo.momx = ____temp_0[1]
        p.mo.momy = ____temp_0[2]
        p.mo.momz = ____temp_0[3]
    elseif btns & downbtn and shift == 0 then
        is_down_or_up_trick = true
        p.advTricks.downTrickActive = true
        p.advTricks.upTrickActive = false
        p.advTricks.didDownTrick = true
        local ____temp_1 = calculateDownTrickMomentum(p, angle)
        p.mo.momx = ____temp_1[1]
        p.mo.momy = ____temp_1[2]
        p.mo.momz = ____temp_1[3]
    else
        p.advTricks.upTrickActive = false
        p.advTricks.downTrickActive = false
        local ____temp_2 = calculateNeutralTrickMomentum(p, angle)
        p.mo.momx = ____temp_2[1]
        p.mo.momy = ____temp_2[2]
        p.mo.momz = ____temp_2[3]
    end
    S_StartSound(p.mo, sfx_cdfm52)
    for i = 1, 3 do
        local fw = P_SpawnMobj(p.mo.x, p.mo.y, p.mo.z, MT_KARMAFIREWORK)
        K_MatchGenericExtraFlags(fw, p.mo)
        fw.momx = p.mo.momx + FixedMul(
            P_RandomFixed() - FRACUNIT / 2,
            mapobjectscale * 4
        )
        fw.momy = p.mo.momy + FixedMul(
            P_RandomFixed() - FRACUNIT / 2,
            mapobjectscale * 4
        )
        fw.momz = p.mo.momz + FixedMul(
            P_RandomFixed() - FRACUNIT / 2,
            mapobjectscale * 4
        ) * P_MobjFlip(fw)
        fw.color = p.mo.color
    end
    if not is_down_or_up_trick then
        p.advTricks.spinTime = 1
        p.advTricks.spinTimeMax = 2 * TICRATE / 3
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
    if p.mo == nil or p.advTricks == nil then
        return
    end
    local speed = R_PointToDist2(0, 0, p.mo.momx, p.mo.momy)
    local dir = p.mo.angle
    local fall_velicity = max(
        FixedMul(
            abs(p.advTricks.downTrickLastVelocity) - 16 * p.mo.scale,
            3 * FRACUNIT
        ),
        0
    )
    p.mo.momx = FixedMul(
        cos(dir),
        speed + fall_velicity
    )
    p.mo.momy = FixedMul(
        sin(dir),
        speed + fall_velicity
    )
    S_StartSound(p.mo, sfx_s262)
end
local function easeInCubic(x)
    return FixedMul(
        FixedMul(x, x),
        x
    )
end
local function easeOutCubic(x)
    local inv = FRACUNIT - x
    return FRACUNIT - FixedMul(
        FixedMul(inv, inv),
        inv
    )
end
local function R_PointToDist3(x, y, z, tx, ty, tz)
    return R_PointToDist2(
        0,
        z,
        R_PointToDist2(x, y, tx, ty),
        tz
    )
end
addHook(
    "MobjThinker",
    function(pmo)
        if not pmo.valid or pmo.player == nil or not pmo.player.valid then
            return
        end
        local p = pmo.player
        if p.mo == nil then
            error("Mobj on player is somehow null despite getting here.", 0)
        end
        if p.advTricks == nil then
            initPlayer(p)
        end
        local at = p.advTricks
        local didPushBrake = p.cmd.buttons & (p.advt_trickButton or BT_BRAKE) and not at.lastBrakeStatus
        at.lastBrakeStatus = p.cmd.buttons & (p.advt_trickButton or BT_BRAKE)
        if not P_IsObjectOnGround(pmo) then
            at.airTics = at.airTics + 1
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
        if at.upTrickActive and not inBattleModeAndAlive(p) then
            for pi in players.iterate do
                if p ~= pi and pi ~= nil and pi.valid and pi.mo ~= nil and pi.mo.valid and pi.kartstuff[k_squishedtimer] <= 0 and pi.kartstuff[k_spinouttimer] <= 0 and pi.kartstuff[k_respawn] <= 0 and inBattleModeAndAlive(p) and pi.advTricks ~= nil and not pi.advTricks.upTrickActive then
                    local dist = R_PointToDist3(
                        p.mo.x,
                        p.mo.y,
                        p.mo.z,
                        pi.mo.x,
                        pi.mo.y,
                        pi.mo.z
                    )
                    if dist < p.mo.scale * 512 then
                        local ____pi_mo_3, ____momx_4 = pi.mo, "momx"
                        ____pi_mo_3[____momx_4] = ____pi_mo_3[____momx_4] + FixedMul(p.mo.x - pi.mo.x, p.mo.scale / 256)
                        local ____pi_mo_5, ____momy_6 = pi.mo, "momy"
                        ____pi_mo_5[____momy_6] = ____pi_mo_5[____momy_6] + FixedMul(p.mo.y - pi.mo.y, p.mo.scale / 256)
                        local ____pi_mo_7, ____momz_8 = pi.mo, "momz"
                        ____pi_mo_7[____momz_8] = ____pi_mo_7[____momz_8] + FixedMul(p.mo.z - pi.mo.z, p.mo.scale / 256)
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
            if cv_infiniteTricks.value == 0 then
                at.hasTricked = true
            end
        end
        if p.cmd.driftturn > 0 then
            at.lastHeldDirection = 1
        elseif p.cmd.driftturn < 0 then
            at.lastHeldDirection = -1
        end
        if at.spinTime > 0 then
            local spin_amount = easeOutCubic(FixedDiv(at.spinTime, at.spinTimeMax))
            local spin_angle = FixedAngle(spin_amount * at.spinAmount)
            p.frameangle = p.frameangle + spin_angle
            at.spinTime = at.spinTime + 1
            if at.spinTime >= at.spinTimeMax then
                at.spinTime = 0
                at.spinTimeMax = 0
                at.spinAmount = 360
            end
            if at.spinTime % 4 >= 2 then
                pmo.colorized = true
            end
            if at.spinTime & 3 and at.spinTime <= at.spinTimeMax / 2 then
                local g = P_SpawnGhostMobj(pmo)
                g.colorized = true
                g.tics = 4
            end
        elseif at.downTrickActive or at.upTrickActive then
            if at.downTrickActive then
                at.spinContinus = at.spinContinus + FixedAngle(at.downTrickLastVelocity) * 2
            else
                at.spinContinus = at.spinContinus + ANG60
            end
            p.frameangle = p.frameangle + at.spinContinus
            if leveltime & 3 then
                local g = P_SpawnGhostMobj(pmo)
                g.colorized = true
                g.tics = 4
            end
            if leveltime % 5 == 0 then
                pmo.colorized = true
            end
        end
    end,
    MT_PLAYER
)
addHook(
    "ThinkFrame",
    function()
        if leveltime ~= 1 then
            return
        end
        for p in players.iterate do
            initPlayer(p)
        end
    end
)
addHook(
    "MobjDeath",
    function(mo)
        if not (mo ~= nil and mo.valid and mo.player ~= nil and mo.player.valid) then
            return
        end
        initPlayer(mo.player)
    end,
    MT_PLAYER
)
addHook(
    "PlayerSpawn",
    function(p)
        if not (p and p.valid) then
            return
        end
        initPlayer(p)
    end
)
addHook(
    "MobjCollide",
    function(mo, other)
        local ____mo_valid_9 = mo
        if ____mo_valid_9 ~= nil then
            ____mo_valid_9 = ____mo_valid_9.valid
        end
        local ____mo_valid_9_13 = ____mo_valid_9
        if ____mo_valid_9_13 then
            local ____mo_player_valid_11 = mo.player
            if ____mo_player_valid_11 ~= nil then
                ____mo_player_valid_11 = ____mo_player_valid_11.valid
            end
            ____mo_valid_9_13 = ____mo_player_valid_11
        end
        local ____mo_valid_9_13_16 = ____mo_valid_9_13
        if ____mo_valid_9_13_16 then
            local ____other_valid_14 = other
            if ____other_valid_14 ~= nil then
                ____other_valid_14 = ____other_valid_14.valid
            end
            ____mo_valid_9_13_16 = ____other_valid_14
        end
        local ____temp_19 = ____mo_valid_9_13_16 and other.type == MT_PLAYER
        if ____temp_19 then
            local ____other_player_valid_17 = other.player
            if ____other_player_valid_17 ~= nil then
                ____other_player_valid_17 = ____other_player_valid_17.valid
            end
            ____temp_19 = ____other_player_valid_17
        end
        if ____temp_19 and (mo.z >= other.z and mo.z < other.z + other.height or other.z >= mo.z and other.z < mo.z + mo.height) then
            local att = nil
            local vic = nil
            local ____mo_player_advTricks_upTrickActive_20 = mo.player.advTricks
            if ____mo_player_advTricks_upTrickActive_20 ~= nil then
                ____mo_player_advTricks_upTrickActive_20 = ____mo_player_advTricks_upTrickActive_20.upTrickActive
            end
            local ____mo_player_advTricks_upTrickActive_20_24 = ____mo_player_advTricks_upTrickActive_20
            if ____mo_player_advTricks_upTrickActive_20_24 then
                local ____other_player_advTricks_upTrickActive_22 = other.player.advTricks
                if ____other_player_advTricks_upTrickActive_22 ~= nil then
                    ____other_player_advTricks_upTrickActive_22 = ____other_player_advTricks_upTrickActive_22.upTrickActive
                end
                ____mo_player_advTricks_upTrickActive_20_24 = not ____other_player_advTricks_upTrickActive_22
            end
            if ____mo_player_advTricks_upTrickActive_20_24 then
                att = mo
                vic = other.player
            else
                local ____other_player_advTricks_upTrickActive_25 = other.player.advTricks
                if ____other_player_advTricks_upTrickActive_25 ~= nil then
                    ____other_player_advTricks_upTrickActive_25 = ____other_player_advTricks_upTrickActive_25.upTrickActive
                end
                local ____other_player_advTricks_upTrickActive_25_29 = ____other_player_advTricks_upTrickActive_25
                if ____other_player_advTricks_upTrickActive_25_29 then
                    local ____mo_player_advTricks_upTrickActive_27 = mo.player.advTricks
                    if ____mo_player_advTricks_upTrickActive_27 ~= nil then
                        ____mo_player_advTricks_upTrickActive_27 = ____mo_player_advTricks_upTrickActive_27.upTrickActive
                    end
                    ____other_player_advTricks_upTrickActive_25_29 = not ____mo_player_advTricks_upTrickActive_27
                end
                if ____other_player_advTricks_upTrickActive_25_29 then
                    att = other
                    vic = mo.player
                end
            end
            if att ~= nil and vic ~= nil then
                if att.player.kartstuff[k_squishedtimer] > 0 or att.player.kartstuff[k_spinouttimer] > 0 or att.player.kartstuff[k_spinouttimer] > 0 or att.player.kartstuff[k_respawn] > 0 or inBattleModeAndAlive(att.player) then
                    return
                end
                K_SpinPlayer(
                    vic,
                    att,
                    1,
                    att,
                    false
                )
            end
        end
    end,
    MT_PLAYER
)
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
    ["custom 3"] = BT_CUSTOM3
}
local buttonToString = {
    [BT_ATTACK] = "Item",
    [BT_DRIFT] = "Drift",
    [BT_BRAKE] = "Brake",
    [BT_ACCELERATE] = "Accelerate",
    [BT_CUSTOM1] = "Custom 1",
    [BT_CUSTOM2] = "Custom 2",
    [BT_CUSTOM3] = "Custom 3"
}
local function printMapButtonHelpText(p)
    CONS_Printf(
        p,
        ("Current trick button is " .. tostring(buttonToString[p.advt_trickButton or BT_BRAKE])) .. "."
    )
    CONS_Printf(p, "Valid keys are: Brake, Drift, Item, Custom 1, Custom 2, Custom 3.")
end
COM_AddCommand(
    "advt_trickbutton",
    function(p, new_button)
        if new_button == nil then
            printMapButtonHelpText(p)
            return
        end
        new_button = string.lower(new_button)
        if stringToButton[new_button] == nil then
            CONS_Printf(p, ("Invalid button name \"" .. new_button) .. ".")
            return
        end
        local new_trick_button = stringToButton[new_button]
        CONS_Printf(
            p,
            ("Trick button set to " .. tostring(buttonToString[new_trick_button])) .. "."
        )
        p.advt_trickButton = new_trick_button
    end
)
local stringToInvert = {
    o = INVM_NONE,
    off = INVM_NONE,
    h = INVM_HORIZONAL,
    horizonal = INVM_HORIZONAL,
    v = INVM_VERTICAL,
    vertical = INVM_VERTICAL,
    b = INVM_BOTH,
    both = INVM_BOTH
}
local invertToString = {[INVM_NONE] = "No", [INVM_HORIZONAL] = "Horizontal", [INVM_VERTICAL] = "Vertical", [INVM_BOTH] = "Both"}
local function printInvertControlHelpText(p)
    CONS_Printf(p, ("Current inverted axis is " .. invertToString[p.advt_invertMode or INVM_NONE]) .. "")
    CONS_Printf(p, "Valid values are: Off, Horizontal, Vertical, Both.")
end
local function setInvertMode(p, invert)
    local str_add = "."
    if invert == INVM_BOTH or invert == INVM_NONE then
        str_add = "es."
    end
    CONS_Printf(p, (("Inverting " .. invertToString[invert]) .. " axis") .. str_add)
    p.advt_invertMode = invert
end
COM_AddCommand(
    "advt_invertmode",
    function(p, new_invert)
        if new_invert == nil then
            printInvertControlHelpText(p)
            return
        end
        new_invert = string.lower(new_invert)
        local axis_mod = stringToInvert[new_invert]
        if axis_mod == nil then
            CONS_Printf(p, ("Invalid value \"" .. new_invert) .. "\".")
            printInvertControlHelpText(p)
            return
        end
        setInvertMode(p, axis_mod)
    end
)
COM_AddCommand(
    "advt_mkwiimode",
    function(p)
        setInvertMode(p, INVM_BOTH)
    end
)
local TUTORIAL_SAVE_FILE_NAME = "advtrickstutorial.sav2"
local TRICKS_TO_ADVANCE_TUTORIAL = 5
local tutorialState = 0
local tutTricksWaited = 0
local tutHasUpTricked = false
local tutHasDownTricked = false
local tutInstructionGreen = false
local tutInstructionFadeTime = 0
local tutInstructionFadeTimeMax = TICRATE / 2
local tutInstructionFadeInOut = false
local tutAlreadyDone = false
local f = io.open(TUTORIAL_SAVE_FILE_NAME, "r")
if f ~= nil then
    local completed = f:read("*n")
    if completed >= ADVANCETRICKS then
        tutAlreadyDone = true
        print("Detected already completed tutorial, skipping steps past 1.")
        print(("Use advt_resettutorial or delete " .. TUTORIAL_SAVE_FILE_NAME) .. "")
    end
    f:close()
end
local function fadeOutTasks()
    tutInstructionFadeTime = tutInstructionFadeTimeMax
    tutInstructionFadeInOut = false
    tutInstructionGreen = false
end
local function fadeInTasks()
    tutInstructionFadeTime = tutInstructionFadeTimeMax
    tutInstructionFadeInOut = false
    tutInstructionGreen = false
end
local function saveTutorialDone()
    local f = assert({io.open(TUTORIAL_SAVE_FILE_NAME, "w")})
    f:write(ADVANCETRICKS)
    f:close()
    print(("Saved tutorial completed to " .. TUTORIAL_SAVE_FILE_NAME) .. ".")
end
addHook(
    "ThinkFrame",
    function()
        if tutorialState == nil and tutInstructionFadeTime == 0 then
            return
        end
        local ____consoleplayer_valid_30 = consoleplayer
        if ____consoleplayer_valid_30 ~= nil then
            ____consoleplayer_valid_30 = ____consoleplayer_valid_30.valid
        end
        local ____temp_34 = not ____consoleplayer_valid_30
        if not ____temp_34 then
            local ____consoleplayer_mo_valid_32 = consoleplayer.mo
            if ____consoleplayer_mo_valid_32 ~= nil then
                ____consoleplayer_mo_valid_32 = ____consoleplayer_mo_valid_32.valid
            end
            ____temp_34 = not ____consoleplayer_mo_valid_32
        end
        if ____temp_34 or consoleplayer.advTricks == nil then
            return
        end
        if tutInstructionFadeTime > 0 then
            tutInstructionFadeTime = tutInstructionFadeTime - 1
        end
        local p = consoleplayer
        local at = p.advTricks
        repeat
            local ____switch98 = tutorialState
            local ____cond98 = ____switch98 == 0
            if ____cond98 then
                if canPlayerTrick(p) then
                    tutorialState = 1
                    fadeInTasks()
                end
                break
            end
            ____cond98 = ____cond98 or ____switch98 == 1
            if ____cond98 then
                if at.didTrick then
                    tutorialState = 2
                    tutTricksWaited = TRICKS_TO_ADVANCE_TUTORIAL
                    fadeOutTasks()
                end
                break
            end
            ____cond98 = ____cond98 or ____switch98 == 2
            if ____cond98 then
                if tutAlreadyDone then
                    if tutInstructionFadeTime == 0 then
                        tutorialState = nil
                    elseif at.didTrick then
                        tutTricksWaited = tutTricksWaited - 1
                        if tutTricksWaited <= 0 then
                            tutorialState = 3
                            fadeInTasks()
                        end
                    end
                end
                break
            end
            ____cond98 = ____cond98 or ____switch98 == 3
            if ____cond98 then
                if at.didUpTrick then
                    tutHasUpTricked = true
                elseif at.didDownTrick then
                    tutHasDownTricked = true
                end
                if tutHasUpTricked and tutHasDownTricked then
                    tutorialState = 4
                    tutTricksWaited = TRICKS_TO_ADVANCE_TUTORIAL
                    fadeOutTasks()
                end
                break
            end
            ____cond98 = ____cond98 or ____switch98 == 4
            if ____cond98 then
                if at.didTrick then
                    tutTricksWaited = tutTricksWaited - 1
                    if tutTricksWaited <= 0 then
                        tutorialState = 5
                        fadeInTasks()
                    end
                end
                break
            end
            ____cond98 = ____cond98 or ____switch98 == 5
            if ____cond98 then
                if at.didRedirection then
                    tutorialState = nil
                    fadeOutTasks()
                    saveTutorialDone()
                end
                break
            end
        until true
    end
)
local HUD_FADE_TABLE = {
    {
        V_90TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS
    },
    {
        V_80TRANS,
        V_80TRANS,
        V_80TRANS,
        V_80TRANS,
        V_80TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS
    },
    {
        V_70TRANS,
        V_70TRANS,
        V_70TRANS,
        V_70TRANS,
        V_80TRANS,
        V_80TRANS,
        V_80TRANS,
        V_90TRANS,
        V_90TRANS,
        V_90TRANS
    },
    {
        V_60TRANS,
        V_60TRANS,
        V_60TRANS,
        V_70TRANS,
        V_70TRANS,
        V_80TRANS,
        V_80TRANS,
        V_80TRANS,
        V_90TRANS,
        V_90TRANS
    },
    {
        V_50TRANS,
        V_50TRANS,
        V_60TRANS,
        V_60TRANS,
        V_70TRANS,
        V_70TRANS,
        V_80TRANS,
        V_80TRANS,
        V_90TRANS,
        V_90TRANS
    },
    {
        V_40TRANS,
        V_40TRANS,
        V_50TRANS,
        V_50TRANS,
        V_60TRANS,
        V_70TRANS,
        V_70TRANS,
        V_80TRANS,
        V_80TRANS,
        V_90TRANS
    },
    {
        V_30TRANS,
        V_30TRANS,
        V_40TRANS,
        V_50TRANS,
        V_50TRANS,
        V_60TRANS,
        V_70TRANS,
        V_70TRANS,
        V_80TRANS,
        V_90TRANS
    },
    {
        V_20TRANS,
        V_20TRANS,
        V_30TRANS,
        V_40TRANS,
        V_50TRANS,
        V_60TRANS,
        V_60TRANS,
        V_70TRANS,
        V_80TRANS,
        V_90TRANS
    },
    {
        V_10TRANS,
        V_10TRANS,
        V_20TRANS,
        V_30TRANS,
        V_40TRANS,
        V_50TRANS,
        V_60TRANS,
        V_70TRANS,
        V_80TRANS,
        V_90TRANS
    },
    {
        0,
        V_10TRANS,
        V_20TRANS,
        V_30TRANS,
        V_40TRANS,
        V_50TRANS,
        V_60TRANS,
        V_70TRANS,
        V_80TRANS,
        V_90TRANS
    }
}
local BASE_VIDEO_FLAGS = V_SNAPTORIGHT | V_6WIDTHSPACE | V_ALLOWLOWERCASE
hud.add(
    function(v, p)
        if tutorialState == nil and tutInstructionFadeTime == 0 then
            return
        end
        if p ~= consoleplayer then
            return
        end
        if p.spectator then
            return
        end
        if cv_tricksEnabled.value == 0 then
            return
        end
        local cv_translucentHud = CV_FindVar("translucenthud")
        local t = tutInstructionFadeTime
        if not tutInstructionFadeInOut then
            t = tutInstructionFadeTimeMax - tutInstructionFadeTime
        end
        local fade_flag = HUD_FADE_TABLE[cv_translucentHud.value + 1][10 - min(
            10,
            max(0, t)
        ) + 1]
        if fade_flag == nil then
            return
        end
        local add_x = FixedInt(easeOutCubic(FixedDiv(t, tutInstructionFadeTimeMax)) * 10)
        if not tutInstructionFadeInOut then
            add_x = 10 - add_x + 10
        end
        local turn_green = 0
        if tutInstructionGreen then
            turn_green = V_GREENMAP
        end
        repeat
            local ____switch120 = tutorialState
            local trick_btn, turn_green_up, turn_green_down, up_str, down_str
            local ____cond120 = ____switch120 == 1 or ____switch120 == 2
            if ____cond120 then
                trick_btn = buttonToString[p.advt_trickButton or BT_BRAKE]
                v.drawString(
                    300 + add_x,
                    130,
                    ("Push " .. tostring(trick_btn)) .. " to trick!",
                    BASE_VIDEO_FLAGS | fade_flag | turn_green,
                    "thin-right"
                )
                break
            end
            ____cond120 = ____cond120 or (____switch120 == 3 or ____switch120 == 4)
            if ____cond120 then
                turn_green_up = 0
                turn_green_down = 0
                if tutHasUpTricked then
                    turn_green_up = V_GREENMAP
                end
                if tutHasDownTricked then
                    turn_green_down = V_GREENMAP
                end
                up_str = "up"
                down_str = "down"
                if (p.advt_invertMode or INVM_NONE) & INVM_HORIZONAL then
                    up_str = "down"
                    down_str = "up"
                end
                v.drawString(
                    300 + add_x,
                    130,
                    ("Hold " .. up_str) .. " while tricking to attack!",
                    BASE_VIDEO_FLAGS | fade_flag | turn_green_up,
                    "thin-right"
                )
                v.drawString(
                    300 + add_x,
                    140,
                    "to redirect your momentum!",
                    BASE_VIDEO_FLAGS | fade_flag | turn_green,
                    "thin-right"
                )
                break
            end
            ____cond120 = ____cond120 or (____switch120 == 5 or ____switch120 == nil)
            if ____cond120 then
                v.drawString(
                    300 + add_x,
                    130,
                    "Hold left or right while tricking",
                    BASE_VIDEO_FLAGS | fade_flag | turn_green,
                    "thin-right"
                )
                v.drawString(
                    300 + add_x,
                    140,
                    "to redirect your momentum!",
                    BASE_VIDEO_FLAGS | fade_flag | turn_green,
                    "thin-right"
                )
                break
            end
        until true
    end,
    "game"
)
COM_AddCommand(
    "advt_resettutorial",
    function(p)
        if not (p == consoleplayer) then
            return
        end
        local f = io.open(TUTORIAL_SAVE_FILE_NAME, "w")
        if f ~= nil then
            f:write(0)
            f:close()
        end
        tutorialState = 0
        tutHasUpTricked = false
        tutHasDownTricked = false
        print("Tutorial reset.")
    end
)
local function getStartPosition(p)
    local angle, _ = table.unpack(getTrickAngleAndShift(p))
    local btns, upbtn, downbtn = table.unpack(getTrickButtons(p))
    local mx = 0
    local my = 0
    local mz = 0
    if btns & upbtn then
        mx, my, mz = table.unpack(calculateUpTrickMomentum(p, angle))
    elseif btns & downbtn then
        mx, my, mz = table.unpack(calculateDownTrickMomentum(p, angle))
    else
        mx, my, mz = table.unpack(calculateNeutralTrickMomentum(p, angle))
    end
    return {
        x = p.mo.x,
        y = p.mo.y,
        z = p.mo.z,
        momx = mx,
        momy = my,
        momz = mz
    }
end
local function predictNextPosition(pos, grav)
    return {
        x = pos.x + pos.momx,
        y = pos.y + pos.momy,
        z = pos.z + pos.momz,
        momx = pos.momx,
        momy = pos.momy,
        momz = pos.momz - grav
    }
end
local PREDICTION_TICS = TICRATE / 3
local momentumGuides = {{}, {}, {}, {}}
local function spawnMomentumGuide(dpi)
    local t = P_SpawnMobj(0, 0, 0, MT_THOK)
    t.tics = 2
    t.state = S_ADVANCETRICKS_INDICATOR
    t.eflags = t.eflags | MFE_DRAWONLYFORP1 << dpi
    return t
end
addHook(
    "ThinkFrame",
    function()
        if not cv_trickMomentumGuide.value then
            return
        end
        for dpi = 0, 3 do
            local is_player = dpi <= splitscreen
            local ____is_player_39 = is_player
            if ____is_player_39 then
                local ____displayplayers_dpi_mo_37 = displayplayers[dpi]
                if ____displayplayers_dpi_mo_37 ~= nil then
                    ____displayplayers_dpi_mo_37 = ____displayplayers_dpi_mo_37.mo
                end
                local ____displayplayers_dpi_mo_valid_35 = ____displayplayers_dpi_mo_37
                if ____displayplayers_dpi_mo_valid_35 ~= nil then
                    ____displayplayers_dpi_mo_valid_35 = ____displayplayers_dpi_mo_valid_35.valid
                end
                ____is_player_39 = ____displayplayers_dpi_mo_valid_35
            end
            if ____is_player_39 then
                local mg = momentumGuides[dpi + 1]
                local p = displayplayers[dpi]
                if canPlayerTrick(p) then
                    local grav = gravity * P_MobjFlip(p.mo)
                    local player_inital_location = getStartPosition(p)
                    local current_location = predictNextPosition(player_inital_location, grav)
                    for i = 1, PREDICTION_TICS do
                        local ____mg_i_valid_40 = mg[i + 1]
                        if ____mg_i_valid_40 ~= nil then
                            ____mg_i_valid_40 = ____mg_i_valid_40.valid
                        end
                        if not ____mg_i_valid_40 then
                            mg[i + 1] = spawnMomentumGuide(dpi)
                        end
                        local guide = mg[i + 1]
                        guide.flags2 = guide.flags2 & ~MF2_DONTDRAW
                        P_TeleportMove(guide, current_location.x, current_location.y, current_location.z)
                        current_location = predictNextPosition(current_location, grav)
                        guide.tics = 2
                        guide.color = p.mo.color
                        local max_scale = p.mo.scale
                        local percent_scale = FRACUNIT - FixedDiv(i, PREDICTION_TICS)
                        guide.scale = FixedMul(max_scale, percent_scale)
                    end
                else
                    for i = 1, PREDICTION_TICS do
                        local ____mg_i_valid_42 = mg[i + 1]
                        if ____mg_i_valid_42 ~= nil then
                            ____mg_i_valid_42 = ____mg_i_valid_42.valid
                        end
                        if not ____mg_i_valid_42 then
                            mg[i + 1] = spawnMomentumGuide(dpi)
                        end
                        local ____mg_index_44, ____flags2_45 = mg[i + 1], "flags2"
                        ____mg_index_44[____flags2_45] = ____mg_index_44[____flags2_45] | MF2_DONTDRAW
                        mg[i + 1].tics = 2
                    end
                end
            end
        end
    end
)

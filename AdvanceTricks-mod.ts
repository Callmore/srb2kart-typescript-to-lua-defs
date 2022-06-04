// Advance tricks
// by Callmore

// Tricks intended to help increase the amount of choices a player has
// in mid-air. Inspired by how MK8 has different trick animations depending on
// what direction you are holding at the time.

// Holding up will cause tricks to launch you upward but at the cost of your
// horizonal momentum
// Holding down will cause tricks to send you downwards, building speed. This
// speed is released when you hit the floor, and converted into a large burst
// forwards.
// Not holding a direction will cause the trick to launch you forwards, at the
// cost of your vertical momentum. This will cancel both upwards and downwards
// momentum.

// Holding either left or right will redirect your horizonal momentum in that
// direction, potenionally recovering from a bad bump or launch, or helping you
// take turns tighter.

/** @noSelfInFile */

interface AdvanceTricksInfo {
    lastBrakeStatus: ButtonEnum;
    airTics: number;
    hasTricked: boolean;
    spinTime: number;
    spinTimeMax: number;
    spinAmount: number;
    spinContinus: number;
    lastHeldDirection: number;
    downTrickActive: boolean;
    downTrickLastVelocity: number;
    upTrickActive: boolean;
    didTrick: boolean;
    didUpTrick: boolean;
    didDownTrick: boolean;
    didRedirection: boolean;
}

interface player_t {
    advTricks?: AdvanceTricksInfo;
    advt_invertMode: InvertMode;
    advt_trickButton: ButtonEnum;
}

// 1.1
rawset(_G, "ADVANCETRICKS", 1 * FRACUNIT + 1);

freeslot("S_ADVANCETRICKS_INDICATOR");

// Console variables

// Toggle to disable advance tricks
// I mean sure I guess...
const cv_tricksEnabled = CV_RegisterVar({
    name: "advt_enabled",
    defaultvalue: "Yes",
    PossibleValue: CV_YesNo,
    flags: CV_NETVAR,
});

// Infinite tricks toggles being able to trick endlessly in mid-air.
// Someone suguested this in VC and I was like "okay".
const cv_infiniteTricks = CV_RegisterVar({
    name: "advt_rushtricks",
    defaultvalue: "Off",
    PossibleValue: CV_OnOff,
    flags: CV_NETVAR,
});

// Up trick power toggles between normal up tricks and *CrAzY* up tricks.
// Crazy tricks don't remove speed when used and boost you up more than usual.
const cv_upTrickPower = CV_RegisterVar({
    name: "advt_uptrickpower",
    defaultvalue: "Normal",
    PossibleValue: { Normal: 0, Crazy: 1 },
    flags: CV_NETVAR,
});

const cv_trickMomentumGuide = CV_RegisterVar({
    name: "advt_trickmomentumguide",
    defaultvalue: "Off",
    PossibleValue: CV_OnOff,
    flags: 0,
});

// Invert modes
/** @compileMembersOnly */
enum InvertMode {
    INVM_NONE,
    INVM_HORIZONAL,
    INVM_VERTICAL,
    INVM_BOTH,
}
//const INVM_NONE = 0; // 00
//const INVM_HORIZONAL = 1; // 01
//const INVM_VERTICAL = 2; // 10
//const INVM_BOTH = 3; // 11

// Initalise advance tricks for a player.
function initPlayer(p: player_t): void {
    p.advTricks = {
        airTics: 0,
        hasTricked: false,
        lastBrakeStatus: 0,

        // Spinning timers for spinning
        // The cap can be set by the code for different spin lengths
        spinTime: 0,
        spinTimeMax: 0,
        spinAmount: 360,
        spinContinus: 0,

        lastHeldDirection: -1,
        downTrickActive: false,
        downTrickLastVelocity: 0,

        upTrickActive: false,

        // tutorial related dumbvars
        // (Guess they might be useful for some extra hooks for other mods?)
        didTrick: false,
        didUpTrick: false,
        didDownTrick: false,
        didRedirection: false,
    };
}

// Check if a player is allowed to trick, returns true if they can,
// returns false otherwise
function canPlayerTrick(p: player_t): boolean {
    if (p.advTricks != null) {
        return (
            cv_tricksEnabled.value == 1 &&
            p.kartstuff[Kartstuff.k_squishedtimer] <= 0 &&
            p.kartstuff[Kartstuff.k_spinouttimer] <= 0 &&
            p.kartstuff[Kartstuff.k_respawn] <= 0 &&
            p.deadtimer <= 0 &&
            p.playerstate == PlayerState.PST_LIVE &&
            !P_IsObjectOnGround(p.mo!) &&
            p.advTricks.airTics >= 5 &&
            !p.advTricks.hasTricked
        );
    }
    return false;
}

const NEUTRAL_TRICK_MULTIPLYER: fixed_t = 20 * FRACUNIT;

// Calculate momentum for tricks
function calculateUpTrickMomentum(
    p: player_t,
    angle: angle_t
): [fixed_t, fixed_t, fixed_t] {
    // Calculate how much to divide the speed by
    // this is only used for the meme option help
    let div_factor: fixed_t = FRACUNIT / 2;
    if (cv_upTrickPower.value == 1) {
        div_factor = FRACUNIT;
    }

    const new_speed = FixedMul(
        R_PointToDist2(0, 0, p.mo!.momx, p.mo!.momy),
        div_factor
    ); // -50% speed

    const x = FixedMul(cos(angle), new_speed);
    const y = FixedMul(sin(angle), new_speed);

    let z: fixed_t = p.mo!.scale * 12 * P_MobjFlip(p.mo!);

    if (cv_upTrickPower.value == 1) {
        // "slight" vertical boost
        z = p.mo!.scale * 24 * P_MobjFlip(p.mo!);
    }

    return [x, y, z];
}

function calculateDownTrickMomentum(
    p: player_t,
    angle: angle_t
): [fixed_t, fixed_t, fixed_t] {
    if (p.mo != null) {
        const gain = FixedMul(
            R_PointToDist2(0, 0, p.mo.momx, p.mo.momy),
            FRACUNIT / 3
        ); // 33.3% is taken

        // reduce player speed to 20% of its current
        const x = FixedMul(cos(angle), gain);
        const y = FixedMul(sin(angle), gain);

        // add the amount of speed lost to the vertical velocity
        const z = (-p.mo.scale * 16 - gain) * P_MobjFlip(p.mo);

        return [x, y, z];
    }
    return [0, 0, 0];
}

function calculateNeutralTrickMomentum(
    p: player_t,
    angle: angle_t
): [fixed_t, fixed_t, fixed_t] {
    if (p.mo != null) {
        const length = R_PointToDist2(0, 0, p.mo.momx, p.mo.momy);

        let [normX, normY] = [cos(angle), sin(angle)];
        if (length == 0) {
            [normX, normY] = [0, 0];
        }

        const x =
            FixedMul(cos(angle), length) +
            FixedMul(FixedMul(normX, NEUTRAL_TRICK_MULTIPLYER), p.mo.scale);
        const y =
            FixedMul(sin(angle), length) +
            FixedMul(FixedMul(normY, NEUTRAL_TRICK_MULTIPLYER), p.mo.scale);
        const z =
            FixedMul(NEUTRAL_TRICK_MULTIPLYER, p.mo.scale / 8) *
            P_MobjFlip(p.mo);

        return [x, y, z];
    }
    return [0, 0, 0];
}

// Get trick angle
function getTrickAngleAndShift(p: player_t): [angle_t, number] {
    if (p.mo != null) {
        // get normalised horizonal velocity
        let angle = R_PointToAngle2(0, 0, p.mo.momx, p.mo.momy);

        // Angle tweaking for recovery or speed
        let turn = p.cmd.driftturn;

        // Adjust for if you like MK wii and want your tricks reversed
        if (
            (p.advt_invertMode || InvertMode.INVM_NONE) &
            InvertMode.INVM_HORIZONAL
        ) {
            turn = -turn;
        }

        let shift = 0;
        if (turn >= 400) {
            angle += ANG15;
            shift = 1;
        } else if (turn <= -400) {
            angle -= ANG15;
            shift = -1;
        }

        return [angle, shift];
    }
    return [0, 0];
}

// Get buttons and invert settings
function getTrickButtons(p: player_t): [ButtonEnum, ButtonEnum, ButtonEnum] {
    const btns = p.cmd.buttons;
    let upbtn = ButtonEnum.BT_FORWARD;
    let downbtn = ButtonEnum.BT_BACKWARD;
    if (
        (p.advt_invertMode || InvertMode.INVM_NONE) & InvertMode.INVM_VERTICAL
    ) {
        upbtn = ButtonEnum.BT_BACKWARD;
        downbtn = ButtonEnum.BT_FORWARD;
    }
    return [btns, upbtn, downbtn];
}

function inBattleModeAndAlive(p: player_t): boolean {
    return (
        (p.kartstuff[Kartstuff.k_bumper] > 0 &&
            p.kartstuff[Kartstuff.k_comebacktimer] <= 0) ||
        p.kartstuff[Kartstuff.k_comebackmode] == 1
    );
}

// Preform a trick for a player. This does not do any check and just tricks.
function doTrick(p: player_t): void {
    if (p.advTricks == null || p.mo == null) {
        return;
    }

    const [angle, shift] = getTrickAngleAndShift(p);

    if (shift != 0) {
        p.advTricks.didRedirection = true;
    }

    // delete pogo state so its hard to gain more speed
    p.kartstuff[Kartstuff.k_pogospring] = 0;

    // Do not start a spin if doing a up or down trick
    let is_down_or_up_trick = false;

    const [btns, upbtn, downbtn] = getTrickButtons(p);

    if (btns & upbtn && shift == 0) {
        // UP TRICK
        is_down_or_up_trick = true;

        p.advTricks.upTrickActive = true;
        p.advTricks.downTrickActive = false;

        p.advTricks.didUpTrick = true;

        [p.mo.momx, p.mo.momy, p.mo.momz] = calculateUpTrickMomentum(p, angle);
    } else if (btns & downbtn && shift == 0) {
        // DOWN TRICK

        is_down_or_up_trick = true;

        // Same sorta thing for forward tricks, take 33.3% of the speed,
        // convert that to verical velocity, but when you hit the floor give
        // the speed back and some more
        p.advTricks.downTrickActive = true;
        p.advTricks.upTrickActive = false;

        p.advTricks.didDownTrick = true;

        [p.mo.momx, p.mo.momy, p.mo.momz] = calculateDownTrickMomentum(
            p,
            angle
        );
    } else {
        // NEUTRAL TRICK

        p.advTricks.upTrickActive = false;
        p.advTricks.downTrickActive = false;

        [p.mo.momx, p.mo.momy, p.mo.momz] = calculateNeutralTrickMomentum(
            p,
            angle
        );
    }

    // SOUND
    S_StartSound(p.mo, sfx_cdfm52);

    // Fireworks
    for (const i of $range(1, 3)) {
        const fw = P_SpawnMobj(p.mo.x, p.mo.y, p.mo.z, MT_KARMAFIREWORK);
        K_MatchGenericExtraFlags(fw, p.mo);

        fw.momx =
            p.mo.momx +
            FixedMul(P_RandomFixed() - FRACUNIT / 2, mapobjectscale * 4);
        fw.momy =
            p.mo.momy +
            FixedMul(P_RandomFixed() - FRACUNIT / 2, mapobjectscale * 4);
        fw.momz =
            p.mo.momz +
            FixedMul(P_RandomFixed() - FRACUNIT / 2, mapobjectscale * 4) *
                P_MobjFlip(fw);
        fw.color = p.mo.color;
    }

    // start a speeen
    if (!is_down_or_up_trick) {
        p.advTricks.spinTime = 1;
        p.advTricks.spinTimeMax = (2 * TICRATE) / 3;
        p.advTricks.spinAmount = 360 * p.advTricks.lastHeldDirection;
        if (shift != 0) {
            p.advTricks.spinAmount = 720 * shift;
        }
    } else {
        p.advTricks.spinContinus = 0;
    }

    p.advTricks.didTrick = true;
}

function doDownTrick(p: player_t): void {
    if (p.mo == null || p.advTricks == null) {
        return;
    }
    const speed = R_PointToDist2(0, 0, p.mo.momx, p.mo.momy);
    const dir = p.mo.angle;

    const fall_velicity = max(
        FixedMul(
            abs(p.advTricks.downTrickLastVelocity) - 16 * p.mo.scale,
            3 * FRACUNIT
        ),
        0
    );

    p.mo.momx = FixedMul(cos(dir), speed + fall_velicity);
    p.mo.momy = FixedMul(sin(dir), speed + fall_velicity);

    // play spindash sound
    S_StartSound(p.mo, sfx_s262);
}

// Easing function for use while spinning the player
// taken from https://easings.net/#easeOutCubic
function easeInCubic(x: fixed_t): fixed_t {
    return FixedMul(FixedMul(x, x), x);
}

function easeOutCubic(x: fixed_t): fixed_t {
    const inv = FRACUNIT - x;
    return FRACUNIT - FixedMul(FixedMul(inv, inv), inv);
}

// Thanks yoshimo
function R_PointToDist3(
    x: fixed_t,
    y: fixed_t,
    z: fixed_t,
    tx: fixed_t,
    ty: fixed_t,
    tz: fixed_t
): fixed_t {
    return R_PointToDist2(0, z, R_PointToDist2(x, y, tx, ty), tz);
}

// I use pmo here to refer to the player's mobj. Since p is usually used to
// refer to a variable holding a player, pmo is holding a player's mobj.
addHook(
    "MobjThinker",
    (pmo: mobj_t) => {
        // Sanity checks cause kart is ??? sometimes
        if (!pmo.valid || pmo.player == null || !pmo.player.valid) {
            return;
        }

        // shortcut that would usualy be in a player iterator
        const p = pmo.player;

        if (p.mo == null) {
            throw "Mobj on player is somehow null despite getting here.";
        }

        // first, if they do not have variables initialised then do that
        if (p.advTricks == null) {
            initPlayer(p);
        }

        // Now we know that is initialised, go store it for quick accsess
        const at = p.advTricks!;

        // Get control input, detect if brake was pushed down and set a variable
        const didPushBrake =
            p.cmd.buttons & (p.advt_trickButton || ButtonEnum.BT_BRAKE) &&
            !at.lastBrakeStatus;
        at.lastBrakeStatus =
            p.cmd.buttons & (p.advt_trickButton || ButtonEnum.BT_BRAKE);

        // Check if the player is allowed to trick, only allow if they have not
        // tricked this jump, have been in the air for at least 5 tics, and are not
        // in a no control state.

        if (!P_IsObjectOnGround(pmo)) {
            at.airTics += 1;
        } else {
            at.airTics = 0;
            at.hasTricked = false;
            at.spinTime = 0;
            at.spinTimeMax = 0;

            if (at.downTrickActive) {
                doDownTrick(p);
                at.downTrickActive = false;
            }

            if (at.upTrickActive) {
                at.upTrickActive = false;
            }
        }

        if (at.downTrickActive) {
            at.downTrickLastVelocity = pmo.momz;
        } else {
            at.downTrickLastVelocity = 0;
        }

        if (at.upTrickActive && !inBattleModeAndAlive(p)) {
            for (const pi of players.iterate) {
                if (
                    p != pi &&
                    pi != null &&
                    pi.valid &&
                    pi.mo != null &&
                    pi.mo.valid &&
                    pi.kartstuff[Kartstuff.k_squishedtimer] <= 0 &&
                    pi.kartstuff[Kartstuff.k_spinouttimer] <= 0 &&
                    pi.kartstuff[Kartstuff.k_respawn] <= 0 &&
                    inBattleModeAndAlive(p) &&
                    pi.advTricks != null &&
                    !pi.advTricks.upTrickActive
                ) {
                    const dist = R_PointToDist3(
                        p.mo.x,
                        p.mo.y,
                        p.mo.z,
                        pi.mo.x,
                        pi.mo.y,
                        pi.mo.z
                    );
                    if (dist < p.mo.scale * 512) {
                        pi.mo.momx += FixedMul(
                            p.mo.x - pi.mo.x,
                            p.mo.scale / 256
                        );
                        pi.mo.momy += FixedMul(
                            p.mo.y - pi.mo.y,
                            p.mo.scale / 256
                        );
                        pi.mo.momz += FixedMul(
                            p.mo.z - pi.mo.z,
                            p.mo.scale / 256
                        );
                    }
                }
            }
        }

        at.didTrick = false;
        at.didUpTrick = false;
        at.didDownTrick = false;
        at.didRedirection = false;

        if (canPlayerTrick(p) && didPushBrake) {
            doTrick(p);
            if (cv_infiniteTricks.value == 0) {
                at.hasTricked = true;
            }
        }

        // Grab the last held direction
        if (p.cmd.driftturn > 0) {
            at.lastHeldDirection = 1;
        } else if (p.cmd.driftturn < 0) {
            at.lastHeldDirection = -1;
        }

        // Do funny spin animation
        if (at.spinTime > 0) {
            const spin_amount = easeOutCubic(
                FixedDiv(at.spinTime, at.spinTimeMax)
            );
            const spin_angle = FixedAngle(spin_amount * at.spinAmount);
            p.frameangle += spin_angle;
            at.spinTime += 1;
            if (at.spinTime >= at.spinTimeMax) {
                at.spinTime = 0;
                at.spinTimeMax = 0;
                at.spinAmount = 360;
            }

            // Do some extra flashing to help convay the trick's power
            if (at.spinTime % 4 >= 2) {
                pmo.colorized = true;
            }
            if (at.spinTime & 3 && at.spinTime <= at.spinTimeMax / 2) {
                const g = P_SpawnGhostMobj(pmo);
                g.colorized = true;
                g.tics = 4;
            }
        } else if (at.downTrickActive || at.upTrickActive) {
            if (at.downTrickActive) {
                at.spinContinus += FixedAngle(at.downTrickLastVelocity) * 2;
            } else {
                // Up trick must be active here
                at.spinContinus += ANG60;
            }
            p.frameangle += at.spinContinus;

            if (leveltime & 3) {
                const g = P_SpawnGhostMobj(pmo);
                g.colorized = true;
                g.tics = 4;
            }

            if (leveltime % 5 == 0) {
                pmo.colorized = true;
            }
        }
    },
    MT_PLAYER
);
// I am using a MobjThinker instead of a ThinkFrame because I should only need
// to effect players, not the global gamestate.

// Initialisation function
addHook("ThinkFrame", () => {
    if (leveltime != 1) {
        return;
    }
    for (const p of players.iterate) {
        initPlayer(p);
    }
});
// This is here to force reitialise any player who has spectated.

// Reset player functions
addHook(
    "MobjDeath",
    (mo: mobj_t) => {
        if (!(mo != null && mo.valid && mo.player != null && mo.player.valid)) {
            return;
        }
        initPlayer(mo.player);
    },
    MT_PLAYER
);

// Reset a player when they die to avoid spilling stuff over multiple lives
addHook("PlayerSpawn", (p: player_t) => {
    if (!(p && p.valid)) {
        return;
    }
    initPlayer(p);
});

// Funny mid-air up trick shenanigans
// Code taken from hpmod because detecting bumps is ouch
addHook(
    "MobjCollide",
    (
        mo: mobj_t | undefined,
        other: mobj_t | undefined
    ): boolean | undefined => {
        if (
            mo?.valid &&
            mo.player?.valid &&
            other?.valid &&
            other.type == MT_PLAYER &&
            other.player?.valid &&
            ((mo.z >= other.z && mo.z < other.z + other.height) ||
                (other.z >= mo.z && other.z < mo.z + mo.height))
        ) {
            let att: mobj_t | null = null;
            let vic: player_t | null = null;
            if (
                mo.player.advTricks?.upTrickActive &&
                !other.player.advTricks?.upTrickActive
            ) {
                att = mo;
                vic = other.player;
            } else if (
                other.player.advTricks?.upTrickActive &&
                !mo.player.advTricks?.upTrickActive
            ) {
                att = other;
                vic = mo.player;
            }

            if (att != null && vic != null) {
                if (
                    att.player!.kartstuff[Kartstuff.k_squishedtimer] > 0 ||
                    att.player!.kartstuff[Kartstuff.k_spinouttimer] > 0 ||
                    att.player!.kartstuff[Kartstuff.k_spinouttimer] > 0 ||
                    att.player!.kartstuff[Kartstuff.k_respawn] > 0 ||
                    inBattleModeAndAlive(att.player!)
                ) {
                    return;
                }

                K_SpinPlayer(vic, att, 1, att, false);
            }
        }
    },
    MT_PLAYER
);

// ngl i wonder if anyone will just type mk and map it to brake
const stringToButton: Record<string, ButtonEnum> = {
    i: ButtonEnum.BT_ATTACK,
    item: ButtonEnum.BT_ATTACK,

    d: ButtonEnum.BT_DRIFT,
    drift: ButtonEnum.BT_DRIFT,
    mk: ButtonEnum.BT_DRIFT,

    b: ButtonEnum.BT_BRAKE,
    brake: ButtonEnum.BT_BRAKE,

    c: ButtonEnum.BT_CUSTOM1,
    c1: ButtonEnum.BT_CUSTOM1,
    custom1: ButtonEnum.BT_CUSTOM1,
    "custom 1": ButtonEnum.BT_CUSTOM1,

    c2: ButtonEnum.BT_CUSTOM1,
    custom2: ButtonEnum.BT_CUSTOM1,
    "custom 2": ButtonEnum.BT_CUSTOM2,

    c3: ButtonEnum.BT_CUSTOM3,
    custom3: ButtonEnum.BT_CUSTOM3,
    "custom 3": ButtonEnum.BT_CUSTOM3,
};

const buttonToString: Record<ButtonEnum, string | undefined> = {
    [ButtonEnum.BT_ATTACK]: "Item",
    [ButtonEnum.BT_DRIFT]: "Drift",
    [ButtonEnum.BT_BRAKE]: "Brake",
    [ButtonEnum.BT_ACCELERATE]: "Accelerate",
    [ButtonEnum.BT_CUSTOM1]: "Custom 1",
    [ButtonEnum.BT_CUSTOM2]: "Custom 2",
    [ButtonEnum.BT_CUSTOM3]: "Custom 3",
};

// Console commands
function printMapButtonHelpText(p: player_t) {
    CONS_Printf(
        p,
        `Current trick button is \x80${
            buttonToString[p.advt_trickButton || ButtonEnum.BT_BRAKE]
        }\x80.`
    );
    CONS_Printf(
        p,
        `Valid keys are: \x82Brake\x80, \x82Drift\x80, \x82Item\x80, \x82Custom 1\x80, \x82Custom 2\x80, \x82Custom 3\x80.`
    );
}

COM_AddCommand("advt_trickbutton", (p: player_t, new_button: string) => {
    if (new_button == null) {
        printMapButtonHelpText(p);
        return;
    }

    new_button = new_button.toLowerCase();

    if (stringToButton[new_button] == null) {
        CONS_Printf(p, `Invalid button name "\x82${new_button}\x80.`);
        return;
    }

    const new_trick_button = stringToButton[new_button];

    CONS_Printf(
        p,
        `Trick button set to \x82${buttonToString[new_trick_button]}\x80.`
    );
    p.advt_trickButton = new_trick_button;
});

const stringToInvert: Record<string, InvertMode | undefined> = {
    o: InvertMode.INVM_NONE,
    off: InvertMode.INVM_NONE,
    h: InvertMode.INVM_HORIZONAL,
    horizonal: InvertMode.INVM_HORIZONAL,
    v: InvertMode.INVM_VERTICAL,
    vertical: InvertMode.INVM_VERTICAL,
    b: InvertMode.INVM_BOTH,
    both: InvertMode.INVM_BOTH,
};

const invertToString: Record<InvertMode, string> = {
    [InvertMode.INVM_NONE]: "No",
    [InvertMode.INVM_HORIZONAL]: "Horizontal",
    [InvertMode.INVM_VERTICAL]: "Vertical",
    [InvertMode.INVM_BOTH]: "Both",
};

function printInvertControlHelpText(p: player_t) {
    CONS_Printf(
        p,
        `Current inverted axis is \x82${
            invertToString[p.advt_invertMode ?? InvertMode.INVM_NONE]
        }\x80`
    );
    CONS_Printf(
        p,
        "Valid values are: \x82Off\x80, \x82Horizontal\x80, \x82Vertical\x80, \x82Both\x80."
    );
}

function setInvertMode(p: player_t, invert: InvertMode) {
    let str_add = ".";
    if (invert == InvertMode.INVM_BOTH || invert == InvertMode.INVM_NONE) {
        str_add = "es.";
    }
    CONS_Printf(
        p,
        `Inverting \x82${invertToString[invert]}\x80 axis${str_add}`
    );
    p.advt_invertMode = invert;
}

COM_AddCommand(
    "advt_invertmode",
    (p: player_t, new_invert: string | undefined) => {
        if (new_invert == null) {
            printInvertControlHelpText(p);
            return;
        }

        new_invert = new_invert.toLowerCase();

        const axis_mod = stringToInvert[new_invert];
        if (axis_mod == null) {
            CONS_Printf(p, `Invalid value "\x82${new_invert}\x80".`);
            printInvertControlHelpText(p);
            return;
        }
        setInvertMode(p, axis_mod);
    }
);

// minenice asked for this
COM_AddCommand("advt_mkwiimode", (p: player_t) => {
    setInvertMode(p, InvertMode.INVM_BOTH);
});

// TUTORIALCODE!!!1!!!111!!!1111!!!11!11!!11!!!1!1!!!1!!!!1!1!1!!!1!1!!1
const TUTORIAL_SAVE_FILE_NAME = "advtrickstutorial.sav2";
const TRICKS_TO_ADVANCE_TUTORIAL = 5;

let tutorialState: number | null = 0;
let tutTricksWaited = 0;

let tutHasUpTricked = false;
let tutHasDownTricked = false;

let tutInstructionGreen = false;
let tutInstructionFadeTime = 0;
const tutInstructionFadeTimeMax = TICRATE / 2;
let tutInstructionFadeInOut = false; // false for fade-in, true for fade-out

let tutAlreadyDone = false;

// Try to load the tutorial file
const [f] = io.open(TUTORIAL_SAVE_FILE_NAME, "r");
if (f != null) {
    const completed = f.read("*n") as number;
    if (completed >= ADVANCETRICKS) {
        tutAlreadyDone = true;
        print("Detected already completed tutorial, skipping steps past 1.");
        print(
            `Use \x82advt_resettutorial\x80 or delete \x82${TUTORIAL_SAVE_FILE_NAME}\x80`
        );
    }
    f.close();
}

function fadeOutTasks() {
    tutInstructionFadeTime = tutInstructionFadeTimeMax;
    tutInstructionFadeInOut = false;
    tutInstructionGreen = false;
}

function fadeInTasks() {
    tutInstructionFadeTime = tutInstructionFadeTimeMax;
    tutInstructionFadeInOut = false;
    tutInstructionGreen = false;
}

// Save the tutorial, say if it fails.
function saveTutorialDone() {
    const [f] = assert(io.open(TUTORIAL_SAVE_FILE_NAME, "w"));
    f!.write(ADVANCETRICKS);
    f!.close();
    print(`Saved tutorial completed to \x82${TUTORIAL_SAVE_FILE_NAME}\x80.`);
}

addHook("ThinkFrame", () => {
    if (tutorialState == null && tutInstructionFadeTime == 0) {
        return;
    }

    if (
        !consoleplayer?.valid ||
        !consoleplayer.mo?.valid ||
        consoleplayer.advTricks == null
    ) {
        return;
    }

    if (tutInstructionFadeTime > 0) {
        tutInstructionFadeTime--;
    }

    const p = consoleplayer;
    const at = p.advTricks!;

    switch (tutorialState) {
        case 0: // Pre first trick
            if (canPlayerTrick(p)) {
                tutorialState = 1; // ADVANCE
                fadeInTasks();
            }
            break;

        case 1: // First trick
            if (at.didTrick) {
                tutorialState = 2; // ADVANCE
                tutTricksWaited = TRICKS_TO_ADVANCE_TUTORIAL;
                fadeOutTasks();
            }
            break;

        case 2: // Waiting for 5 tricks
            if (tutAlreadyDone) {
                if (tutInstructionFadeTime == 0) {
                    tutorialState = null;
                } else if (at.didTrick) {
                    tutTricksWaited--;
                    if (tutTricksWaited <= 0) {
                        tutorialState = 3;
                        fadeInTasks();
                    }
                }
            }
            break;

        case 3: // Advanced tricks
            if (at.didUpTrick) {
                tutHasUpTricked = true;
            } else if (at.didDownTrick) {
                tutHasDownTricked = true;
            }

            if (tutHasUpTricked && tutHasDownTricked) {
                tutorialState = 4; // ADVANCE
                tutTricksWaited = TRICKS_TO_ADVANCE_TUTORIAL;
                fadeOutTasks();
            }
            break;

        case 4: // Waiting for 5 more tricks
            if (at.didTrick) {
                tutTricksWaited--;
                if (tutTricksWaited <= 0) {
                    tutorialState = 5;
                    fadeInTasks();
                }
            }
            break;

        case 5: // Redirection
            if (at.didRedirection) {
                tutorialState = null;
                fadeOutTasks();
                saveTutorialDone();
            }
            break;
    }
});

const HUD_FADE_TABLE: number[][] = [
    [
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
    ],
    [
        VideoFlags.V_80TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
    ],
    [
        VideoFlags.V_70TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
    ],
    [
        VideoFlags.V_60TRANS,
        VideoFlags.V_60TRANS,
        VideoFlags.V_60TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
    ],
    [
        VideoFlags.V_50TRANS,
        VideoFlags.V_50TRANS,
        VideoFlags.V_60TRANS,
        VideoFlags.V_60TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_90TRANS,
        VideoFlags.V_90TRANS,
    ],
    [
        VideoFlags.V_40TRANS,
        VideoFlags.V_40TRANS,
        VideoFlags.V_50TRANS,
        VideoFlags.V_50TRANS,
        VideoFlags.V_60TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_90TRANS,
    ],
    [
        VideoFlags.V_30TRANS,
        VideoFlags.V_30TRANS,
        VideoFlags.V_40TRANS,
        VideoFlags.V_50TRANS,
        VideoFlags.V_50TRANS,
        VideoFlags.V_60TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_90TRANS,
    ],
    [
        VideoFlags.V_20TRANS,
        VideoFlags.V_20TRANS,
        VideoFlags.V_30TRANS,
        VideoFlags.V_40TRANS,
        VideoFlags.V_50TRANS,
        VideoFlags.V_60TRANS,
        VideoFlags.V_60TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_90TRANS,
    ],
    [
        VideoFlags.V_10TRANS,
        VideoFlags.V_10TRANS,
        VideoFlags.V_20TRANS,
        VideoFlags.V_30TRANS,
        VideoFlags.V_40TRANS,
        VideoFlags.V_50TRANS,
        VideoFlags.V_60TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_90TRANS,
    ],
    [
        0,
        VideoFlags.V_10TRANS,
        VideoFlags.V_20TRANS,
        VideoFlags.V_30TRANS,
        VideoFlags.V_40TRANS,
        VideoFlags.V_50TRANS,
        VideoFlags.V_60TRANS,
        VideoFlags.V_70TRANS,
        VideoFlags.V_80TRANS,
        VideoFlags.V_90TRANS,
    ],
];

const BASE_VIDEO_FLAGS =
    VideoFlags.V_SNAPTORIGHT |
    VideoFlags.V_6WIDTHSPACE |
    VideoFlags.V_ALLOWLOWERCASE;

hud.add((v: HudDrawer, p: player_t) => {
    if (tutorialState == null && tutInstructionFadeTime == 0) {
        return;
    }
    if (p != consoleplayer) {
        return;
    }
    if (p.spectator) {
        return;
    }
    if (cv_tricksEnabled.value == 0) {
        return; // :(
    }

    // Im pulling in some extra code for fading

    const cv_translucentHud = CV_FindVar("translucenthud");
    let t = tutInstructionFadeTime;
    if (!tutInstructionFadeInOut) {
        t = tutInstructionFadeTimeMax - tutInstructionFadeTime;
    }
    const fade_flag =
        HUD_FADE_TABLE[cv_translucentHud.value][10 - min(10, max(0, t))];
    if (fade_flag == null) {
        return;
    }

    let add_x = FixedInt(
        easeOutCubic(FixedDiv(t, tutInstructionFadeTimeMax)) * 10
    );
    if (!tutInstructionFadeInOut) {
        add_x = 10 - add_x + 10;
    }

    let turn_green = 0;
    if (tutInstructionGreen) {
        turn_green = VideoFlags.V_GREENMAP;
    }

    switch (tutorialState) {
        case 1:
        case 2:
            let trick_btn =
                buttonToString[p.advt_trickButton ?? ButtonEnum.BT_BRAKE];
            v.drawString(
                300 + add_x,
                130,
                `Push \x81${trick_btn}\x80 to \x81trick\x80!`,
                BASE_VIDEO_FLAGS | fade_flag | turn_green,
                "thin-right"
            );
            break;

        case 3:
        case 4:
            let turn_green_up = 0;
            let turn_green_down = 0;
            if (tutHasUpTricked) {
                turn_green_up = VideoFlags.V_GREENMAP;
            }
            if (tutHasDownTricked) {
                turn_green_down = VideoFlags.V_GREENMAP;
            }

            let up_str = "up";
            let down_str = "down";
            if (
                (p.advt_invertMode ?? InvertMode.INVM_NONE) &
                InvertMode.INVM_HORIZONAL
            ) {
                up_str = "down";
                down_str = "up";
            }

            v.drawString(
                300 + add_x,
                130,
                `Hold \x82${up_str}\x80 while tricking to \x82attack\x80!`,
                BASE_VIDEO_FLAGS | fade_flag | turn_green_up,
                "thin-right"
            );
            v.drawString(
                300 + add_x,
                140,
                "to \x82redirect your momentum\x80!",
                BASE_VIDEO_FLAGS | fade_flag | turn_green,
                "thin-right"
            );
            break;

        case 5:
        case null:
            v.drawString(
                300 + add_x,
                130,
                "Hold \x82left\x80 or \x82right\x80 while tricking",
                BASE_VIDEO_FLAGS | fade_flag | turn_green,
                "thin-right"
            );
            v.drawString(
                300 + add_x,
                140,
                "to \x82redirect your momentum\x80!",
                BASE_VIDEO_FLAGS | fade_flag | turn_green,
                "thin-right"
            );
            break;
    }
}, "game");

// Delete tutorial progress and reset tutorial locally
// Fails to open file silently
COM_AddCommand("advt_resettutorial", (p: player_t) => {
    if (!(p == consoleplayer)) {
        return;
    }

    const [f] = io.open(TUTORIAL_SAVE_FILE_NAME, "w");
    if (f != null) {
        f.write(0);
        f.close();
    }
    tutorialState = 0;
    tutHasUpTricked = false;
    tutHasDownTricked = false;
    print("Tutorial reset.");
});

interface Movement {
    x: fixed_t;
    y: fixed_t;
    z: fixed_t;
    momx: fixed_t;
    momy: fixed_t;
    momz: fixed_t;
}

function getStartPosition(p: player_t): Movement {
    const [angle, _] = getTrickAngleAndShift(p);
    const [btns, upbtn, downbtn] = getTrickButtons(p);

    let mx = 0,
        my = 0,
        mz = 0;
    if (btns & upbtn) {
        [mx, my, mz] = calculateUpTrickMomentum(p, angle);
    } else if (btns & downbtn) {
        [mx, my, mz] = calculateDownTrickMomentum(p, angle);
    } else {
        [mx, my, mz] = calculateNeutralTrickMomentum(p, angle);
    }

    return {
        x: p.mo!.x,
        y: p.mo!.y,
        z: p.mo!.z,
        momx: mx,
        momy: my,
        momz: mz,
    };
}

function predictNextPosition(pos: Movement, grav: number): Movement {
    return {
        x: pos.x + pos.momx,
        y: pos.y + pos.momy,
        z: pos.z + pos.momz,
        momx: pos.momx,
        momy: pos.momy,
        momz: pos.momz - grav,
    };
}

const PREDICTION_TICS = TICRATE / 3;
const momentumGuides: (null | mobj_t)[][] = [[], [], [], []];

function spawnMomentumGuide(dpi: number) {
    const t = P_SpawnMobj(0, 0, 0, MT_THOK);
    t.tics = 2;
    t.state = S_ADVANCETRICKS_INDICATOR;
    t.eflags |= ExtraObjectFlags.MFE_DRAWONLYFORP1 << dpi;
    return t;
}

// Local only momentum guide
addHook("ThinkFrame", () => {
    if (!cv_trickMomentumGuide.value) return;
    for (const dpi of $range(0, 3)) {
        const is_player = dpi <= splitscreen;

        if (is_player && displayplayers[dpi]?.mo?.valid) {
            const mg = momentumGuides[dpi];
            const p = displayplayers[dpi]!;
            if (canPlayerTrick(p)) {
                const grav = gravity * P_MobjFlip(p.mo!);
                const player_inital_location = getStartPosition(p);
                let current_location = predictNextPosition(
                    player_inital_location,
                    grav
                );
                for (const i of $range(1, PREDICTION_TICS)) {
                    if (!mg[i]?.valid) {
                        mg[i] = spawnMomentumGuide(dpi);
                    }

                    const guide = mg[i]!;

                    guide.flags2 &= ~ObjectFlags2.MF2_DONTDRAW;
                    P_TeleportMove(
                        guide,
                        current_location.x,
                        current_location.y,
                        current_location.z
                    );

                    current_location = predictNextPosition(
                        current_location,
                        grav
                    );
                    guide.tics = 2;
                    guide.color = p.mo!.color;

                    let max_scale = p.mo!.scale;
                    let percent_scale = FRACUNIT - FixedDiv(i, PREDICTION_TICS);
                    guide.scale = FixedMul(max_scale, percent_scale);
                }
            } else {
                for (const i of $range(1, PREDICTION_TICS)) {
                    if (!mg[i]?.valid) {
                        mg[i] = spawnMomentumGuide(dpi);
                    }
                    mg[i]!.flags2 |= ObjectFlags2.MF2_DONTDRAW;
                    mg[i]!.tics = 2;
                }
            }
        }
    }
});

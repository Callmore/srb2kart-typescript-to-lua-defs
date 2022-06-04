declare interface mobj_t {
    tics: number;
    eflags: ExtraObjectFlags;
    state: number;
    valid: boolean;
    angle: angle_t;
    x: fixed_t;
    y: fixed_t;
    z: fixed_t;
    momx: fixed_t;
    momy: fixed_t;
    momz: fixed_t;
    height: fixed_t;
    player: player_t | null;
    scale: fixed_t;
    color: number;
    colorized: boolean;
    type: MobjNumber;
    flags2: ObjectFlags2;
}

declare function P_TeleportMove(
    mobj: mobj_t,
    x: fixed_t,
    y: fixed_t,
    z: fixed_t
): void;

declare function P_SpawnGhostMobj(mo: mobj_t): mobj_t;

declare function P_IsObjectOnGround(mo: mobj_t): boolean;
declare function P_SpawnMobj(
    x: fixed_t,
    y: fixed_t,
    z: fixed_t,
    mobj: MobjNumber
): mobj_t;
declare function P_MobjFlip(mo: mobj_t): -1 | 1;

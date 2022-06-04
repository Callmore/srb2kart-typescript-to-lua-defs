declare interface player_t {
    valid: boolean;
    spectator: boolean;
    mo: mobj_t | null;
    kartstuff: KartstuffArray;
    deadtimer: tic_t;
    playerstate: PlayerState;
    cmd: ticcmd_t;
    frameangle: angle_t;
}
declare interface ticcmd_t {
    buttons: ButtonEnum;
    driftturn: angle_t;
}

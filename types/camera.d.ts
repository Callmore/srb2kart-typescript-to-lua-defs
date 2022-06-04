// The entirety of camera_t is readonly.

// https://git.do.srb2.org/KartKrew/Kart-Public/-/blob/master/src/p_local.h#L77
declare interface camera_t {
    readonly chase: boolean;
    readonly aiming: angle_t;

    // Things used by FS cameras.
    readonly viewheight: fixed_t;
    readonly startangle: angle_t;

    // Camera demobjerization
    // Info for drawing: position.
    readonly x: fixed_t;
    readonly y: fixed_t;
    readonly z: fixed_t;

    //More drawing info: to determine current sprite.
    readonly angle: angle_t; // orientation

    readonly subsector: subsector_s;

    // The closest interval over all contacted Sectors (or Things).
    readonly floorz: fixed_t;
    readonly ceilingz: fixed_t;

    // For movement checking.
    readonly radius: fixed_t;
    readonly height: fixed_t;

    readonly relativex: fixed_t;

    // Momentums, used to update position.
    readonly momx: fixed_t;
    readonly momy: fixed_t;
    readonly momz: fixed_t;
    // SRB2Kart: camera pans while drifting
    readonly pan: fixed_t;
}

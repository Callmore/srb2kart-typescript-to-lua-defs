declare type KartstuffArray = Record<
    Kartstuff,
    number | fixed_t | angle_t | tic_t
>;

declare function K_MatchGenericExtraFlags(target: mobj_t, source: mobj_t): void;

/**
 * Spins a `player` out. `source` is where the spin-out comes from, and `inflictor` is the player who caused it.
 * Setting type to zero (spinout) will make `sfx_slip` play and make the player move if they were moving less than a fourth of their speed, which is banana-stepping behaviour. Setting it higher than zero does not cause these effects to happen (internally referred to as a wipeout instead). In Battle, setting `trapitem` to `true` will make this spinout not award extra points or reduce the `player`'s or the `source`'s wanted status. Does nothing in Race otherwise.
 * @param player
 * @param source
 * @param type
 * @param inflictor
 * @param trapitem
 */
declare function K_SpinPlayer(
    player: player_t,
    source: mobj_t,
    type: number,
    inflictor: mobj_t,
    trapitem: boolean
): void;

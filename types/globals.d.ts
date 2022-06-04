declare const gravity: fixed_t;
declare const splitscreen: number;
declare const players: Record<number, player_t | undefined> & {
    iterate: LuaIterable<player_t>;

    /**
     * Returns the maximum amount of players that this server will allow.
     */
    max: LuaLengthMethod<number>;
};
declare const displayplayers: Record<number, player_t | undefined>;
declare const consoleplayer: player_t | undefined;

declare const mapobjectscale: fixed_t;
declare const leveltime: tic_t;

/*
type StateString<S extends string> = Uppercase<`S_${S}`>;
type MobjSlotString<S extends string> = Uppercase<`MT_${S}`>;

type FreeslotString<S extends string> = StateString<S> | MobjSlotString<S>;

declare function freeslot<S extends string>(
    ...identifiers: FreeslotString<S>[]
): number;

TODO: Figure out a type assertion that allows for correctly formatted freeslot strings.
*/
declare function freeslot(...identifiers: string[]): number;

//declare function addHook(hookName: string, fn: Function, extra: string | number): void
declare function addHook(
    hookName: "MobjThinker",
    fn: (mo: mobj_t) => void,
    target: number
): void;
declare function addHook(hookName: "ThinkFrame", fn: () => void): void;
declare function addHook(
    hookName: "MobjDeath",
    fn: (mo: mobj_t) => boolean | null | void,
    target: number
): void;
declare function addHook(
    hookName: "PlayerSpawn",
    fn: (p: player_t) => boolean | null | void
): void;
declare function addHook(
    hookName: "MobjCollide",
    fn: (mo: mobj_t, other: mobj_t) => boolean | undefined,
    target: number
): void;

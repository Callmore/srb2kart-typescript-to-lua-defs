declare namespace hud {
    function add(
        fn: (drawer: HudDrawer, player: player_t, c: camera_t) => void,
        hook: "game"
    ): void;
}

/** @noSelf */
declare interface HudDrawer {
    drawString: (
        x: number,
        y: number,
        text: string,
        flags: number,
        font: string
    ) => void;
}

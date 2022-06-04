declare const CV_NETVAR: number;

type CVFlag = number;

type CVarPosibleValueRange = {
    MIN: number;
    MAX: number;
    [key: string]: number;
};

type CVarPosibleValueOptions = {
    [key: string | number]: string | number;
};

declare const CV_YesNo: {
    Yes: 1;
    No: 0;
};

declare const CV_OnOff: {
    On: 1;
    Off: 0;
};

interface CVarSettings<
    T extends CVarPosibleValueRange | CVarPosibleValueOptions,
    K extends keyof T
> {
    name: string;
    PossibleValue: T;
    defaultvalue: T[K] | keyof T;
    flags: CVFlag;
}

interface consolevariable_t {
    value: number;
}

declare function CV_FindVar(variable: string): consolevariable_t;

declare function CONS_Printf(player: player_t, message: string): void;

declare function COM_AddCommand(
    commandName: string,
    fn: (player: player_t, ...args: string[]) => void
): void;

declare function CV_RegisterVar<
    T extends CVarPosibleValueRange | CVarPosibleValueOptions,
    K extends keyof T
>(settings: CVarSettings<T, K>): consolevariable_t;

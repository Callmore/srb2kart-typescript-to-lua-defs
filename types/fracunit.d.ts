declare enum fixed_t {}
//declare type fixed_t = number & { __fixed_t: void };

declare const FRACUNIT: fixed_t;

declare function FixedMul(a: fixed_t, b: fixed_t): fixed_t;
declare function FixedDiv(a: fixed_t, b: fixed_t): fixed_t;
declare function FixedAngle(a: angle_t): fixed_t;

declare function FixedInt(value: fixed_t): number;

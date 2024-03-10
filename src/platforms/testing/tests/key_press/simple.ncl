let { imports, step, codes, report, .. } = import "base.ncl" in
let { lit, key-press, kc, mod, .. } = imports.lib in

let md = codes.mod in
let c = codes.kc in

let km = [
    lit (key-press kc.A),
    lit (key-press kc.B),
] in

{
    key_map = km,
    tests = [
        {
            name = "single tap",
            steps = step.tap-ms 0 100,
            expected = [
                report 0 [c.A],
                report 0 [],
            ],
        },
        {
            name = "two consecutive taps",
            steps = step.tap 0
                @ step.tap 1,
            expected = [
                report 0 [c.A],
                report 0 [],
                report 0 [c.B],
                report 0 [],
            ],
        },
        {
            name = "two partially overlapping taps",
            steps = step.press 0
                @ step.press 1
                @ step.release 0
                @ step.release 1,
            expected = [
                report 0 [c.A],
                report 0 [c.A, c.B],
                report 0 [c.B],
                report 0 [],
            ],
        },
        {
            name = "two fully overlapping taps",
            steps = step.press 0
                @ step.tap 1
                @ step.release 0,
            expected = [
                report 0 [c.A],
                report 0 [c.A, c.B],
                report 0 [c.A],
                report 0 [],
            ],
        },
    ],
}

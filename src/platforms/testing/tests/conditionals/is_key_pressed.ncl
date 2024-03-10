let { imports, step, event, codes, report, toKeyMap, .. } = import "base.ncl" in
let { lit, switch, case, key-press, kc, is-key-pressed, not, or, and, .. } = imports.lib in

let md = codes.mod in
let c = codes.kc in

let naive_xor = fun a b => or [and [a, not b], and [not a, b]] in

let { km, key } = toKeyMap [
    ["dummy0",       lit (key-press kc.KA16)],
    ["dummy1",       lit (key-press kc.KA19)],
    [
        "k0",
        switch [
            # Extensive naive check of logical operators.
            # I repeat, naive. Do not try this exactly at home. This can be greatly simplified.
            case (naive_xor (is-key-pressed 0) (is-key-pressed 1))
                (switch [
                    case (is-key-pressed 0) (lit (key-press kc.L)),
                ] (key-press kc.O)),
            case (and [is-key-pressed 0, is-key-pressed 1])
                (lit (key-press kc.D)),
        ] (key-press kc.S)
    ],
] in

{
    key_map = km,
    tests = [
        {
            name = "check all keys",
            steps = std.array.range 0 (std.array.length km)
                |> std.array.flat_map (fun i => step.tap i),
            expected = [
                report 0 [c.S],
                report 0 [],
            ],
        },
        {
            name = "check if dummy0 pressed",
            steps = step.press key.dummy0
                @ step.tap key.k0,
            expected = [
                report 0 [c.L],
                report 0 [],
            ],
        },
        {
            name = "check if dummy1 pressed",
            steps = step.press key.dummy1
                @ step.tap key.k0,
            expected = [
                report 0 [c.O],
                report 0 [],
            ],
        },
        {
            name = "check if dummy0 and dummy1 are both pressed",
            steps = step.press key.dummy0
                @ step.press key.dummy1
                @ step.tap key.k0,
            expected = [
                report 0 [c.D],
                report 0 [],
            ],
        },
        {
            name = "mix and match",
            steps = step.press key.dummy0
                @ step.press key.k0
                @ step.press key.dummy1
                @ step.release key.k0
                @ step.tap key.k0
                @ step.release key.dummy0
                @ step.tap key.k0,
            expected = [
                report 0 [c.L],
                report 0 [],
                report 0 [c.D],
                report 0 [],
                report 0 [c.O],
                report 0 [],
            ],
        },
    ],
}

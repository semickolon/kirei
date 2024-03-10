let { imports, step, event, codes, report, toKeyMap, .. } = import "base.ncl" in
let { lit, switch, case, key-press, kc, is-key-code-pressed, and, .. } = imports.lib in

let md = codes.mod in
let c = codes.kc in

let L1 = kc.KA0 in
let L2 = kc.F13 in

let if_layer_1 = is-key-code-pressed L1 in
let if_layer_2 = is-key-code-pressed L2 in
let if_layer_tri = and [if_layer_1, if_layer_2] in

let { km, key } = toKeyMap [
    ["mo1",       lit (key-press L1)],
    ["mo2",       lit (key-press L2)],
    [
        "k0",
        switch [
            case if_layer_tri (lit (key-press kc.N)),
            case if_layer_2   (lit (key-press kc.U)),
            case if_layer_1   (lit (key-press kc.T)),
        ] (key-press kc.Z)
    ],
    [
        "k1",
        switch [
            case if_layer_tri (lit (key-press kc.B)),
            case if_layer_2   (lit (key-press kc.R)),
            case if_layer_1   (lit (key-press kc.V)),
        ] (key-press kc.H)
    ]
] in

{
    key_map = km,
    tests = [
        {
            name = "check all keys",
            steps = std.array.range 0 (std.array.length km)
                |> std.array.flat_map (fun i => step.tap i),
            expected = [
                report 0 [c.F13],
                report 0 [],
                report 0 [c.Z],
                report 0 [],
                report 0 [c.H],
                report 0 [],
            ],
        },
        {
            name = "check layer 1",
            steps = step.press key.mo1
                @ step.tap key.k0
                @ step.tap key.k1,
            expected = [
                report 0 [c.T],
                report 0 [],
                report 0 [c.V],
                report 0 [],
            ],
        },
        {
            name = "check layer 2",
            steps = step.press key.mo2
                @ step.tap key.k0
                @ step.tap key.k1,
            expected = [
                report 0 [c.F13],
                report 0 [c.F13, c.U],
                report 0 [c.F13],
                report 0 [c.F13, c.R],
                report 0 [c.F13],
            ],
        },
        {
            name = "check tri-layer",
            steps = step.press key.mo1
                @ step.press key.mo2
                @ step.tap key.k0
                @ step.tap key.k1,
            expected = [
                report 0 [c.F13],
                report 0 [c.F13, c.N],
                report 0 [c.F13],
                report 0 [c.F13, c.B],
                report 0 [c.F13],
            ],
        },
        {
            name = "mix and match",
            steps = step.press key.mo1
                @ step.press key.k0
                @ step.press key.mo2
                @ step.tap key.k1
                @ step.release key.mo1
                @ step.release key.k0
                @ step.release key.mo2,
            expected = [
                report 0 [c.T],
                report 0 [c.T, c.F13],
                report 0 [c.T, c.F13, c.B],
                report 0 [c.T, c.F13],
                report 0 [c.F13],
                report 0 [],
            ],
        },
    ],
}

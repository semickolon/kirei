let { imports, step, event, codes, report, toKeyMap, .. } = import "base.ncl" in
let { lit, switch, case, key-press, kc, is-key-code-pressed, or, mod, mod-weak, mod-weak-anti, .. } = imports.lib in

let md = codes.mod in
let c = codes.kc in

let { km, key } = toKeyMap [
    ["lsft",        lit (key-press (mod 'shift 'left))],
    ["weak_rgui",   lit (key-press (mod-weak 'gui 'right))],
    [
        "gresc",
        switch [
            case (or [is-key-code-pressed kc.LSFT, is-key-code-pressed kc.RSFT, is-key-code-pressed kc.LGUI, is-key-code-pressed kc.RGUI])
                (lit (key-press (kc.GRV & mod-weak-anti 'shift 'both & mod-weak-anti 'gui 'both)))
        ] (key-press kc.ESC)
    ],
    [
        "australia",
        switch [
            case (or [is-key-code-pressed kc.LSFT, is-key-code-pressed kc.RSFT])
                (lit (key-press (kc.N4 & mod-weak-anti 'shift 'both)))
        ] (key-press (kc.N4 & mod-weak 'shift 'left))
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
                report (md.lsft) [],
                report 0 [],
                report (md.rgui) [],
                report 0 [],
                report 0 [c.ESC],
                report 0 [],
                report (md.lsft) [c.N4],
                report 0 [],
            ],
        },
        {
            name = "grave if lsft held",
            steps = step.press key.lsft
                @ step.tap key.gresc
                @ step.tap key.gresc,
            expected = [
                report (md.lsft) [],
                report 0 [c.GRV],
                report (md.lsft) [],
                report 0 [c.GRV],
                report (md.lsft) [],
            ],
        },
        {
            name = "grave once if weak rgui held",
            steps = step.press key.weak_rgui
                @ step.tap key.gresc
                @ step.tap key.gresc,
            expected = [
                report (md.rgui) [],
                report 0 [c.GRV],
                report 0 [],
                report 0 [c.ESC],
                report 0 [],
            ],
        },
        {
            name = "australia flips 4 and $",
            steps = step.tap key.australia
                @ step.press key.lsft
                @ step.tap key.australia
                @ step.release key.lsft,
            expected = [
                report (md.lsft) [c.N4],
                report 0 [],
                report (md.lsft) [],
                report 0 [c.N4],
                report (md.lsft) [],
                report 0 [],
            ],
        },
    ],
}

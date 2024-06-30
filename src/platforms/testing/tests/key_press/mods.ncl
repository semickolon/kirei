let { imports, step, codes, report, .. } = import "base.ncl" in
let { lit, key-press, kc, mod, .. } = imports.lib in

let md = codes.mod in
let c = codes.kc in

let km = [
    lit (key-press (kc.A & mod 'ctrl 'left)),
    lit (key-press (mod 'shift 'both)),
    lit (key-press (kc.B & mod 'alt 'left)),
    lit (key-press (mod 'gui 'left & mod 'alt 'right)),
] in

{
    key_map = km,
    tests = [
        {
            name = "check all keys",
            steps = std.array.range 0 (std.array.length km)
                |> std.array.flat_map (fun i => step.tap i),
            expected = [
                report (md.lctl) [c.A],
                report 0 [],
                report (md.lsft + md.rsft) [],
                report 0 [],
                report (md.lalt) [c.B],
                report 0 [],
                report (md.lgui + md.ralt) [],
                report 0 [],
            ]
        },
        {
            name = "press and release all keys out of order",
            steps = step.press 0
                @ step.press 2
                @ step.press 3
                @ step.press 1
                @ step.release 2
                @ step.release 1
                @ step.release 0
                @ step.release 3,
            expected = [
                report (md.lctl) [c.A],
                report (md.lctl + md.lalt) [c.A, c.B],
                report (md.lctl + md.lalt + md.lgui + md.ralt) [c.A, c.B],
                report (md.lctl + md.lalt + md.lgui + md.ralt + md.lsft + md.rsft) [c.A, c.B],
                report (md.lctl + md.lgui + md.ralt + md.lsft + md.rsft) [c.A],
                report (md.lctl + md.lgui + md.ralt) [c.A],
                report (md.lgui + md.ralt) [],
                report 0 [],
            ]
        }
    ],
}

let { imports, step, event, codes, report, .. } = import "_base.ncl" in
let { lit, key-press, kc, mod, mod-weak, .. } = imports.lib in

let md = codes.mod in
let c = codes.kc in

let key = {
    weak_lsft = 0,
    weak_rctl = 1,
    a = 2,
    weak_lsft_b = 3,
    ralt_c = 4,
    weak_rgui_a = 5,
} in

let km = [
    lit (key-press (mod-weak 'shift 'left)),
    lit (key-press (mod-weak 'ctrl 'right)),
    lit (key-press kc.A),
    lit (key-press (kc.B & mod-weak 'shift 'left)),
    lit (key-press (kc.C & mod 'alt 'right)),
    lit (key-press (kc.A & mod 'gui 'right)),
] in

{
    key_map = km,
    tests = [
        {
            name = "check all keys",
            steps = step.tap key.weak_lsft
                @ step.tap key.weak_rctl
                @ step.tap key.a
                @ step.tap key.weak_lsft_b,
            expected = [
                report (md.lsft) [],
                report 0 [],
                report (md.rctl) [],
                report 0 [],
                report 0 [c.A],
                report 0 [],
                report (md.lsft) [c.B],
                report 0 [],
            ],
        },
        {
            name = "bound weak mods unregister on next code",
            steps = step.press key.weak_lsft_b
                @ step.press key.ralt_c
                @ step.release key.weak_lsft_b
                @ step.release key.ralt_c,
            expected = [
                report (md.lsft) [c.B],
                report (md.ralt) [c.B, c.C],
                report (md.ralt) [c.C],
                report 0 [],
            ],
        },
        {
            name = "unbound weak mods do stack",
            steps = step.press key.weak_rctl
                @ step.press key.weak_lsft,
            expected = [
                report (md.rctl) [],
                report (md.rctl + md.lsft) [],
            ],
        },
        {
            name = "bound weak mods do not stack",
            steps = step.press key.weak_lsft_b
                @ step.press key.weak_rgui_a,
            expected = [
                report (md.lsft) [c.B],
                report (md.rgui) [c.B, c.A],
            ],
        },
        {
            name = "unbound weak mods become bound on next code",
            steps = step.press key.weak_lsft
                @ step.press key.weak_rctl
                @ step.press key.ralt_c
                @ step.press key.a
                @ step.release key.a,
            expected = [
                report (md.lsft) [],
                report (md.lsft + md.rctl) [],
                report (md.lsft + md.rctl + md.ralt) [c.C],
                report (md.ralt) [c.C, c.A],
                report (md.ralt) [c.C],
            ],
        },
        {
            name = "released unbound weak mods no longer bind (they're really gone)",
            steps = step.press key.weak_lsft
                @ step.press key.weak_rctl
                @ step.release key.weak_lsft
                @ step.press key.a,
            expected = [
                report (md.lsft) [],
                report (md.lsft + md.rctl) [],
                report (md.rctl) [],
                report (md.rctl) [c.A],
            ],
        },
        {
            name = "unbound weak mods that become bound to a code are unregistered on release of said code",
            steps = step.press key.weak_lsft
                @ step.press key.weak_rctl
                @ step.tap key.a,
            expected = [
                report (md.lsft) [],
                report (md.lsft + md.rctl) [],
                report (md.lsft + md.rctl) [c.A],
                report 0 [],
            ],
        },
    ],
}

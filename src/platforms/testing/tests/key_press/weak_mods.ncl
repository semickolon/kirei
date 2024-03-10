let { imports, step, event, codes, report, toKeyMap, .. } = import "base.ncl" in
let { lit, key-press, kc, mod, mod-weak, .. } = imports.lib in

let md = codes.mod in
let c = codes.kc in

let { km, key } = toKeyMap [
    ["weak_lsft",       lit (key-press (mod-weak 'shift 'left))],
    ["weak_rctl",       lit (key-press (mod-weak 'ctrl 'right))],
    ["a",               lit (key-press kc.A)],
    ["b",               lit (key-press kc.B)],
    ["weak_lsft_b",     lit (key-press (kc.B & mod-weak 'shift 'left))],
    ["ralt_c",          lit (key-press (kc.C & mod 'alt 'right))],
    ["weak_rgui_a",     lit (key-press (kc.A & mod 'gui 'right))],
    ["ka0",             lit (key-press kc.KA0)],
    ["weak_lalt_ka1",   lit (key-press (kc.KA1 & mod-weak 'alt 'left))],
    ["rsft",            lit (key-press (mod 'shift 'right))],
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
                report (md.rctl) [],
                report 0 [],
                report 0 [c.A],
                report 0 [],
                report 0 [c.B],
                report 0 [],
                report (md.lsft) [c.B],
                report 0 [],
                report (md.ralt) [c.C],
                report 0 [],
                report (md.rgui) [c.A],
                report 0 [],
                report (md.lalt) [],
                report 0 [],
                report (md.rsft) [],
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
            name = "bound weak mods do not unregister on next key group without code",
            steps = step.press key.weak_lsft_b
                @ step.press key.rsft
                @ step.tap key.a,
            expected = [
                report (md.lsft) [c.B],
                report (md.lsft + md.rsft) [c.B],
                report (md.rsft) [c.B, c.A],
                report (md.rsft) [c.B],
            ],
        },
        {
            name = "unbound weak mods do not bind to already pressed keys",
            steps = step.press key.a
                @ step.press key.weak_rctl
                @ step.press key.weak_lsft_b
                @ step.press key.ralt_c,
            expected = [
                report 0 [c.A],
                report (md.rctl) [c.A],
                report (md.rctl + md.lsft) [c.A, c.B],
                report (md.ralt) [c.A, c.B, c.C],
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
        {
            name = "unbound weak mods cannot be bound to non-hid keyboard codes",
            steps = step.press key.weak_lsft
                @ step.tap key.ka0
                @ step.tap key.a,
            expected = [
                report (md.lsft) [],
                report (md.lsft) [c.A],
                report 0 [],
            ],
        },
        {
            name = "bound weak mods cannot be unregistered by non-hid keyboard codes",
            steps = step.press key.weak_lsft_b
                @ step.tap key.ka0
                @ step.press key.weak_lalt_ka1
                @ step.tap key.ka0,
            expected = [
                report (md.lsft) [c.B],
                report (md.lsft + md.lalt) [c.B],
            ],
        },
        {
            name = "bound weak mods do not unregister on press of same binding",
            steps = step.press key.weak_lsft_b
                @ step.press key.b
                @ step.tap key.a
                @ step.release key.weak_lsft_b
                @ step.release key.b,
            expected = [
                report (md.lsft) [c.B],
                report 0 [c.B, c.A],
                report 0 [c.B],
                report 0 [],
            ],
        },
        {
            name = "weak mods 'bound' to non-hid keyboard codes are not really bound",
            steps = step.press key.weak_lalt_ka1
                @ step.tap key.a,
            expected = [
                report (md.lalt) [],
                report (md.lalt) [c.A],
                report 0 [],
            ],
        },
        {
            name = "weak mods 'bound' to non-hid keyboard codes do stack",
            steps = step.press key.weak_lalt_ka1
                @ step.press key.weak_lsft
                @ step.tap key.ralt_c,
            expected = [
                report (md.lalt) [],
                report (md.lalt + md.lsft) [],
                report (md.lalt + md.lsft + md.ralt) [c.C],
                report 0 [],
            ],
        },
        {
            name = "released weak mods 'bound' to non-hid keyboard codes no longer bind",
            steps = step.tap key.weak_lalt_ka1
                @ step.tap key.a,
            expected = [
                report (md.lalt) [],
                report 0 [],
                report 0 [c.A],
                report 0 [],
            ],
        },
    ],
}

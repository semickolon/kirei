let { imports, step, codes, report, toKeyMap, .. } = import "base.ncl" in
let { lit, key-press, key-toggle, kc, mod, mod-anti, mod-weak-anti, .. } = imports.lib in

let md = codes.mod in
let c = codes.kc in

let { km, key } = toKeyMap [
    ["tog_d",                   lit (key-toggle kc.D)],
    ["d",                       lit (key-press kc.D)],
    ["z",                       lit (key-press kc.Z)],
    ["tog_lctl_d",              lit (key-toggle (kc.D & mod 'ctrl 'left))],
    ["lctl_d",                  lit (key-press (kc.D & mod 'ctrl 'left))],
    ["tog_anti_lctl_d",         lit (key-toggle (kc.D & mod-anti 'ctrl 'left))],
    ["lctl",                    lit (key-press (mod 'ctrl 'left))],
    ["anti_lctl",               lit (key-press (mod-anti 'ctrl 'left))],
    ["tog_weak_anti_lctl",      lit (key-toggle (mod-weak-anti 'ctrl 'left))],
] in

{
    key_map = km,
    tests = [
        {
            name = "key toggle works",
            steps = step.tap key.tog_d
                @ step.tap key.z
                @ step.tap key.tog_d
                @ step.tap key.z,
            expected = [
                report 0 [c.D],
                report 0 [c.D, c.Z],
                report 0 [c.D],
                report 0 [],
                report 0 [c.Z],
                report 0 [],
            ],
        },
        {
            name = "key toggle activates on incomplete match",
            steps = step.press key.d
                @ step.tap key.tog_lctl_d # D already pressed here
                @ step.release key.d
                @ step.tap key.tog_lctl_d # Ctrl already pressed here
                @ step.tap key.tog_lctl_d,
            expected = [
                report 0 [c.D],
                report (md.lctl) [c.D],
                report (md.lctl) [],
                report (md.lctl) [c.D],
                report 0 [],
            ],
        },
        {
            name = "key toggle deactivates on complete match",
            steps = step.press key.lctl_d
                @ step.tap key.tog_lctl_d, # Ctrl-D already pressed here
            expected = [
                report (md.lctl) [c.D],
                report 0 [],
            ],
        },
        {
            name = "key toggle activates on incomplete match, with anti",
            steps = step.press key.lctl_d
                @ step.tap key.tog_anti_lctl_d
                @ step.tap key.tog_anti_lctl_d
                @ step.release key.lctl_d
                @ step.press key.d
                @ step.tap key.tog_anti_lctl_d
                @ step.press key.lctl,
            expected = [
                report (md.lctl) [c.D],
                report 0 [c.D],
                report (md.lctl) [],
                report 0 [],
                report 0 [c.D],
            ],
        },
        {
            name = "key toggle deactivates on complete match, with anti",
            steps = step.press key.anti_lctl
                @ step.press key.d
                @ step.press key.lctl
                @ step.tap key.tog_anti_lctl_d,
            expected = [
                report 0 [c.D],
                report (md.lctl) [],
            ],
        },
        {
            name = "key toggle with weak anti mods works",
            steps = step.tap key.tog_weak_anti_lctl
                @ step.tap key.lctl_d
                @ step.tap key.lctl_d
                @ step.tap key.tog_weak_anti_lctl
                @ step.tap key.lctl_d
                @ step.tap key.tog_weak_anti_lctl
                @ step.tap key.tog_weak_anti_lctl
                @ step.tap key.lctl_d,
            expected = [
                report 0 [c.D],
                report 0 [],
                report (md.lctl) [c.D],
                report 0 [],
                report 0 [c.D],
                report 0 [],
                report (md.lctl) [c.D],
                report 0 [],
            ],
        },
    ]
}

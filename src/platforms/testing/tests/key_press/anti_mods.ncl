let { imports, step, codes, report, toKeyMap, .. } = import "base.ncl" in
let { lit, key-press, kc, mod, mod-anti, mod-weak-anti, .. } = imports.lib in

let md = codes.mod in
let c = codes.kc in

let { km, key } = toKeyMap [
    ["lsft_a",          lit (key-press (kc.A & mod 'shift 'left))],
    ["rsft",            lit (key-press (mod 'shift 'right))],
    ["anti_lsft",       lit (key-press (mod-anti 'shift 'left))],
    ["anti_lsft_b",     lit (key-press (kc.B & mod-anti 'shift 'left))],
    ["wk_anti_lsft",    lit (key-press (mod-weak-anti 'shift 'left))],
    ["wk_anti_sft_x",   lit (key-press (kc.X & mod-weak-anti 'shift 'both))],
    ["anti_ctl",        lit (key-press (mod-anti 'ctrl 'both))],
    ["ctl_sft",         lit (key-press (mod 'ctrl 'both & mod 'shift 'both))],
] in

{
    key_map = km,
    tests = [
        {
            name = "check all keys",
            steps = std.array.range 0 (std.array.length km)
                |> std.array.flat_map (fun i => step.tap i),
            expected = [
                report (md.lsft) [c.A],
                report 0 [],
                report (md.rsft) [],
                report 0 [],
                report 0 [c.B],
                report 0 [],
                report 0 [c.X],
                report 0 [],
                report (md.lctl + md.rctl + md.lsft + md.rsft) [],
                report 0 [],
            ],
        },
        {
            name = "anti-mods work",
            steps = step.press key.lsft_a
                @ step.tap key.anti_lsft
                @ step.tap key.anti_lsft_b
                @ step.release key.lsft_a,
            expected = [
                report (md.lsft) [c.A],
                report 0 [c.A],
                report (md.lsft) [c.A],
                report 0 [c.A, c.B],
                report (md.lsft) [c.A],
                report 0 [],
            ],
        },
        {
            name = "anti-mods do stack",
            steps = step.press key.anti_lsft
                @ step.press key.anti_ctl
                @ step.press key.ctl_sft
                @ step.release key.anti_lsft
                @ step.release key.anti_ctl
                @ step.release key.ctl_sft,
            expected = [
                report (md.rsft) [],
                report (md.rsft + md.lsft) [],
                report (md.rsft + md.lsft + md.lctl + md.rctl) [],
                report 0 [],
            ],
        },
        {
            name = "normal and weak anti-mods work",
            steps = step.press key.lsft_a
                @ step.press key.wk_anti_sft_x
                @ step.press key.ctl_sft
                @ step.tap key.anti_lsft_b,
            expected = [
                report (md.lsft) [c.A],
                report 0 [c.A, c.X],
                report (md.lctl + md.rctl) [c.A, c.X],
                report (md.rsft + md.lctl + md.rctl) [c.A, c.X, c.B],
                report (md.lsft + md.rsft + md.lctl + md.rctl) [c.A, c.X],
            ],
        },
        {
            name = "unbound weak anti-mods work",
            steps = step.press key.wk_anti_lsft
                @ step.tap key.lsft_a
                @ step.tap key.lsft_a,
            expected = [
                report 0 [c.A],
                report 0 [],
                report (md.lsft) [c.A],
                report 0 [],
            ],
        },
    ],
}

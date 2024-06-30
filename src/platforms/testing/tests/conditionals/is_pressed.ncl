let { imports, step, codes, report, toKeyMap, .. } = import "base.ncl" in
let { lit, switch, case, key-press, kc, is-pressed, mod, .. } = imports.lib in

let md = codes.mod in
let c = codes.kc in

let { km, key } = toKeyMap [
    ["lctl",        lit (key-press (mod 'ctrl 'left))],
    ["rctl",        lit (key-press (mod 'ctrl 'right))],
    ["lsft",        lit (key-press (mod 'shift 'left))],
    ["rsft",        lit (key-press (mod 'shift 'right))],
    ["lalt",        lit (key-press (mod 'alt 'left))],
    ["ralt",        lit (key-press (mod 'alt 'right))],
    ["lgui",        lit (key-press (mod 'gui 'left))],
    ["rgui",        lit (key-press (mod 'gui 'right))],
    ["w",           lit (key-press kc.W)],
    ["x",           lit (key-press kc.X)],
    ["y",           lit (key-press kc.Y)],
    ["z",           lit (key-press kc.Z)],
    [
        "main",
        switch [
            case (is-pressed "Ctrl-Shift-Alt-Gui" "!")
                (lit (key-press kc.N7)),
            case (is-pressed "Ctrl^" kc.W)
                (lit (key-press kc.N6)),
            case (is-pressed "Alt? Shift RGui" "?")
                (lit (key-press kc.N5)),
            case (is-pressed "LShift" [kc.X, kc.Y])
                (lit (key-press kc.N4)),
            case (is-pressed "RShift" kc.Y)
                (lit (key-press kc.N3)),
            case (is-pressed "LGui" [])
                (lit (key-press kc.N2)),
            case (is-pressed "RAlt" "!")
                (lit (key-press kc.N1)),
            case (is-pressed "LCtrl" "?")
                (lit (key-press kc.N0)),
        ] (key-press kc.S)
    ],
] in

{
    key_map = km,
    tests = [
        {
            name = "fallback works",
            steps = step.tap key.main,
            expected = [
                report 0 [c.S],
                report 0 [],
            ],
        },
        {
            name = "0 works - optional code",
            steps = step.press key.lctl
                @ step.tap key.main

                @ step.press key.x
                @ step.tap key.main

                @ step.press key.lalt
                @ step.tap key.main

                @ step.release key.lctl
                @ step.release key.x
                @ step.tap key.main,
            expected = [
                report (md.lctl) [],
                report (md.lctl) [c.N0],
                report (md.lctl) [],

                report (md.lctl) [c.X],
                report (md.lctl) [c.X, c.N0],
                report (md.lctl) [c.X],
                
                report (md.lctl + md.lalt) [c.X],
                report (md.lctl + md.lalt) [c.X, c.S],
                report (md.lctl + md.lalt) [c.X],
                
                report (md.lalt) [c.X],
                report (md.lalt) [],
                report (md.lalt) [c.S],
                report (md.lalt) [],
            ],
        },
        {
            name = "1 works - required code",
            steps = step.press key.ralt
                @ step.tap key.main

                @ step.press key.w
                @ step.tap key.main

                @ step.press key.lsft
                @ step.tap key.main,
            expected = [
                report (md.ralt) [],
                report (md.ralt) [c.S],
                report (md.ralt) [],

                report (md.ralt) [c.W],
                report (md.ralt) [c.W, c.N1],
                report (md.ralt) [c.W],

                report (md.ralt + md.lsft) [c.W],
                report (md.ralt + md.lsft) [c.W, c.S],
                report (md.ralt + md.lsft) [c.W],
            ],
        },
        {
            name = "2 works - unwanted code",
            steps = step.press key.lgui
                @ step.tap key.main

                @ step.press key.y
                @ step.tap key.main,
            expected = [
                report (md.lgui) [],
                report (md.lgui) [c.N2],
                report (md.lgui) [],

                report (md.lgui) [c.Y],
                report (md.lgui) [c.Y, c.S],
                report (md.lgui) [c.Y],
            ],
        },
        {
            name = "3 works - exact code",
            steps = step.press key.rsft
                @ step.tap key.main

                @ step.press key.y
                @ step.tap key.main

                @ step.press key.z
                @ step.tap key.main

                @ step.release key.y
                @ step.tap key.main,
            expected = [
                report (md.rsft) [],
                report (md.rsft) [c.S],
                report (md.rsft) [],

                report (md.rsft) [c.Y],
                report (md.rsft) [c.Y, c.N3],
                report (md.rsft) [c.Y],

                report (md.rsft) [c.Y, c.Z],
                report (md.rsft) [c.Y, c.Z, c.S],
                report (md.rsft) [c.Y, c.Z],

                report (md.rsft) [c.Z],
                report (md.rsft) [c.Z, c.S],
                report (md.rsft) [c.Z],
            ],
        },
        {
            name = "4 works - range",
            steps = step.press key.lsft
                @ step.press key.w
                @ step.tap key.main

                @ step.press key.x
                @ step.tap key.main

                @ step.press key.y
                @ step.tap key.main

                @ step.release key.y
                @ step.tap key.main,
            expected = [
                report (md.lsft) [],
                report (md.lsft) [c.W],
                report (md.lsft) [c.W, c.S],
                report (md.lsft) [c.W],

                report (md.lsft) [c.W, c.X],
                report (md.lsft) [c.W, c.X, c.N4],
                report (md.lsft) [c.W, c.X],

                report (md.lsft) [c.W, c.X, c.Y],
                report (md.lsft) [c.W, c.X, c.Y, c.N4],
                report (md.lsft) [c.W, c.X, c.Y],

                report (md.lsft) [c.W, c.X],
                report (md.lsft) [c.W, c.X, c.S],
                report (md.lsft) [c.W, c.X],
            ],
        },
        {
            name = "3 and 4 work",
            steps = step.press key.lsft
                @ step.press key.y
                @ step.tap key.main

                @ step.release key.y
                @ step.press key.rsft
                @ step.press key.y
                @ step.tap key.main

                @ step.release key.y
                @ step.release key.lsft
                @ step.press key.y
                @ step.tap key.main,
            expected = [
                report (md.lsft) [],
                report (md.lsft) [c.Y],
                report (md.lsft) [c.Y, c.N4],
                report (md.lsft) [c.Y],

                report (md.lsft) [],
                report (md.lsft + md.rsft) [],
                report (md.lsft + md.rsft) [c.Y],
                report (md.lsft + md.rsft) [c.Y, c.S],
                report (md.lsft + md.rsft) [c.Y],

                report (md.lsft + md.rsft) [],
                report (md.rsft) [],
                report (md.rsft) [c.Y],
                report (md.rsft) [c.Y, c.N3],
                report (md.rsft) [c.Y],
            ],
        },
        {
            name = "5 works - multiple mods", # Alt? Shift RGui
            steps = step.press key.lsft
                @ step.tap key.main

                @ step.press key.rgui
                @ step.tap key.main

                @ step.release key.lsft
                @ step.press key.rsft
                @ step.tap key.main

                @ step.press key.lalt
                @ step.press key.ralt
                @ step.tap key.main

                @ step.release key.ralt
                @ step.tap key.main

                @ step.release key.lalt
                @ step.tap key.main

                @ step.press key.lsft
                @ step.tap key.main

                @ step.release key.rsft
                @ step.release key.lsft
                @ step.tap key.main,
            expected = [
                report (md.lsft) [],
                report (md.lsft) [c.S],
                report (md.lsft) [],

                report (md.lsft + md.rgui) [],
                report (md.lsft + md.rgui) [c.N5],
                report (md.lsft + md.rgui) [],

                report (md.rgui) [],
                report (md.rgui + md.rsft) [],
                report (md.rgui + md.rsft) [c.N5],
                report (md.rgui + md.rsft) [],

                report (md.rgui + md.rsft + md.lalt) [],
                report (md.rgui + md.rsft + md.lalt + md.ralt) [],
                report (md.rgui + md.rsft + md.lalt + md.ralt) [c.N5],
                report (md.rgui + md.rsft + md.lalt + md.ralt) [],

                report (md.rgui + md.rsft + md.lalt) [],
                report (md.rgui + md.rsft + md.lalt) [c.N5],
                report (md.rgui + md.rsft + md.lalt) [],

                report (md.rgui + md.rsft) [],
                report (md.rgui + md.rsft) [c.N5],
                report (md.rgui + md.rsft) [],

                report (md.rgui + md.rsft + md.lsft) [],
                report (md.rgui + md.rsft + md.lsft) [c.N5],
                report (md.rgui + md.rsft + md.lsft) [],

                report (md.rgui + md.lsft) [],
                report (md.rgui) [],
                report (md.rgui) [c.S],
                report (md.rgui) [],
            ],
        },
        {
            name = "6 works - xor mod", # Ctrl^ W
            steps = step.press key.lctl
                @ step.press key.rctl
                @ step.press key.w
                @ step.tap key.main

                @ step.release key.lctl
                @ step.repress key.w
                @ step.tap key.main

                @ step.release key.rctl
                @ step.repress key.w
                @ step.tap key.main

                @ step.press key.lctl
                @ step.repress key.w
                @ step.tap key.main,
            expected = [
                report (md.lctl) [],
                report (md.lctl + md.rctl) [],
                report (md.lctl + md.rctl) [c.W],
                report (md.lctl + md.rctl) [c.W, c.S],
                report (md.lctl + md.rctl) [c.W],

                report (md.rctl) [c.W],
                report (md.rctl) [],
                report (md.rctl) [c.W],
                report (md.rctl) [c.W, c.N6],
                report (md.rctl) [c.W],

                report 0 [c.W],
                report 0 [],
                report 0 [c.W],
                report 0 [c.W, c.S],
                report 0 [c.W],

                report (md.lctl) [c.W],
                report (md.lctl) [],
                report (md.lctl) [c.W],
                report (md.lctl) [c.W, c.N6],
                report (md.lctl) [c.W],
            ]
        },
        {
            name = "7 works - all mods", # Ctrl-Shift-Alt-Gui !
            steps = step.press key.lctl
                @ step.press key.rsft
                @ step.press key.lalt
                @ step.press key.z
                @ step.tap key.main

                @ step.press key.rgui
                @ step.repress key.z
                @ step.tap key.main,
            expected = [
                report (md.lctl) [],
                report (md.lctl + md.rsft) [],
                report (md.lctl + md.rsft + md.lalt) [],
                report (md.lctl + md.rsft + md.lalt) [c.Z],
                report (md.lctl + md.rsft + md.lalt) [c.Z, c.S],
                report (md.lctl + md.rsft + md.lalt) [c.Z],

                report (md.lctl + md.rsft + md.lalt + md.rgui) [c.Z],
                report (md.lctl + md.rsft + md.lalt + md.rgui) [],
                report (md.lctl + md.rsft + md.lalt + md.rgui) [c.Z],
                report (md.lctl + md.rsft + md.lalt + md.rgui) [c.Z, c.N7],
                report (md.lctl + md.rsft + md.lalt + md.rgui) [c.Z],
            ]
        }
    ],
}

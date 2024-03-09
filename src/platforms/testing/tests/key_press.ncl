let { imports, step, .. } = import "_base.ncl" in
let { parseKeyMap, KeyMap, .. } = imports.keymap in
let { lit, key-press, kc, .. } = imports.lib in

let km = [
    (lit (key-press kc.A)),
    (lit (key-press kc.B)),
] in

{
    key_map = km,
    steps = [
        step.press 0,
        step.release 0,

        step.press 1,
        step.release 1,

        step.press 1,
        step.release 1,

        step.press 0,
        step.release 0,
    ],
    expected = "abba",
}

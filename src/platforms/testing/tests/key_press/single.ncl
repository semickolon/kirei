let { imports, step, event, .. } = import "_base.ncl" in
let { parseKeyMap, KeyMap, .. } = imports.keymap in
let { lit, key-press, kc, mod, .. } = imports.lib in

let km = [
    (lit (key-press kc.A)),
] in

{
    key_map = km,
    steps = [
        step.press 0,
        step.wait 100,
        step.release 0,
    ],
    expected = [
        event.pressed 4,
        event.released 4,
    ],
}

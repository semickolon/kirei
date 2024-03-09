let { imports, step, event, .. } = import "_base.ncl" in
let { parseKeyMap, KeyMap, .. } = imports.keymap in
let { lit, key-press, kc, mod, .. } = imports.lib in

let km = [
    (lit (key-press kc.A)),
    (lit (key-press (kc.B & mod 'ctrl 'left))),
] in

{
    key_map = km,
    steps = [
        step.press 0,
        step.wait 100,
        step.release 0,
        step.wait 500,

        step.press 1,
        step.wait 100,
        step.release 1,
        step.wait 500,

        step.press 0,
        step.press 1,
        step.release 1,
        step.release 0,
    ],
    expected = [
        event.pressed 4,
        event.released 4,

        event.pressed 224,
        event.pressed 5,
        event.released 224,
        event.released 5,

        event.pressed 4,
        event.pressed 224,
        event.pressed 5,
        event.released 224,
        event.released 5,
        event.released 4,
    ],
}

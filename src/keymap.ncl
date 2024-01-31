let { parseKeymap, .. } = import "kirei/ncl/keymap.ncl" in
let { key_press, hold_tap, tap_dance, kc, .. } = import "kirei/ncl/utils.ncl" in

parseKeymap [
    tap_dance 250 [
        key_press kc.A,
        key_press kc.B,
        key_press kc.C,
        key_press kc.D,
    ],
    hold_tap (key_press kc.C) (key_press kc.D) {},
    key_press kc.A,
    key_press kc.B,
    key_press kc.C,
    key_press kc.D,
    key_press kc.A,
    key_press kc.B,
    key_press kc.C,
    key_press kc.D,
    key_press kc.A,
    key_press kc.B,
    key_press kc.C,
    key_press kc.D,
]

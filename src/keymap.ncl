let { parseKeymap, .. } = import "kirei/ncl/keymap.ncl" in
let { key_press, hold_tap, tap_dance, kc, .. } = import "kirei/ncl/utils.ncl" in

# parseKeymap (
# (
#     "QWERTYUIOPASDFGHJKL;ZXCVBNM,./"
#     |> std.string.characters
#     |> std.array.map (fun c => key_press kc."%{c}")
# ) @ [
#     key_press kc.BSPC,
#     key_press kc.BSPC,
#     key_press kc.SPC,
#     key_press kc.SPC,
# ]
# )

let kp = key_press in
let rs = fun kc => kp ([229] @ kc) in

parseKeymap [
    # kp kc.F16, kp kc.F15, kp kc.F14, kp kc.F13,
    # kp kc.F20, kp kc.F19, kp kc.F18, kp kc.F17,
    # kp kc.F24, kp kc.F23, kp kc.F22, kp kc.F21,
    # rs kc.F16, rs kc.F15, rs kc.F14, rs kc.F13,

    kp kc.A, kp kc.B, kp kc.C, kp kc.D,
    kp kc.E, kp kc.F, kp kc.G, kp kc.H,
    kp kc.I, kp kc.J, kp kc.K, kp kc.L,
    kp kc.M, kp kc.N, kp kc.O, kp kc.P,
]
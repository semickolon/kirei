let { parseKeymap, .. } = import "kirei/ncl/keymap.ncl" in
let { key_press, hold_tap, tap_dance, kc, .. } = import "kirei/ncl/utils.ncl" in

parseKeymap (
(
    "QWERTYUIOPASDFGHJKLAZXCVBNMAAA"
    |> std.string.characters
    |> std.array.map (fun c => key_press kc."%{c}")
) @ [
    key_press kc.BSPC,
    key_press kc.BSPC,
    key_press kc.SPC,
    key_press kc.SPC,
]
)
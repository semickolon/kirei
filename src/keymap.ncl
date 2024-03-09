let { parseKeyMap, .. } = import "kirei/ncl/keymap.ncl" in
let { switch, case, not, is-key-pressed, lit, key-press, kc, mod-weak-anti, .. } = import "kirei/ncl/lib.ncl" in

parseKeyMap [
    # switch [
    #     case (not (is-key-pressed 2))
    #         (lit (key-press (kc.B & mod-weak-anti 'alt 'both))),
    #     case (is-key-pressed 3)
    #         (lit (key-press (kc.A & mod-weak-anti 'alt 'both))),
    # ] (key-press (kc.A & mod-weak-anti 'alt 'both)),
    # switch [
    #     case (not (is-key-pressed 2))
    #         (lit (key-press (kc.B & mod-weak-anti 'alt 'both))),
    #     case (is-key-pressed 3)
    #         (lit (key-press (kc.A & mod-weak-anti 'alt 'both))),
    # ] (key-press (kc.B & mod-weak-anti 'alt 'both)),
    (lit (key-press kc.A)),
    (lit (key-press kc.B)),
]

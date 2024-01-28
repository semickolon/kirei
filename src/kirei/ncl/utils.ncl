{
    key_press = fun kcs => { tag = 'key_press, data.key_codes.value = kcs },

    hold_tap = fun hold tap props' => { tag = 'hold_tap, data = {
        hold_behavior.value = hold,
        tap_behavior.value = tap,
        props.value = props',
    } },

    tap_dance = fun tapping_term_ms' bindings' => { tag = 'tap_dance, data = {
        bindings.value = bindings',
        tapping_term_ms = tapping_term_ms',
    } },

    kc = {
        A = [4],
        B = [5],
        C = [6],
        D = [7],
        LCTL = [224],
        LSFT = [225],
        LCTL_A = LCTL @ A,
    },
}

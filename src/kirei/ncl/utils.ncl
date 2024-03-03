let enumerate = fun arr => std.array.fold_left (fun acc e => acc @ [{
    index = std.array.length acc,
    value = e
}] ) [] arr in

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

    kc = (import "codes.ncl")
        |> enumerate
        |> std.array.flat_map (fun { index, value } => std.array.map (fun str => { field = str, value = [index] }) value)
        |> std.record.from_array,
}

let Uint = fun bits => std.contract.from_predicate (fun value =>
    std.is_number value
    && std.number.is_integer value
    && value >= 0
    && value < (std.number.pow 2 bits)
) in

let LazyIndexed = fun T => { value | T } in
let LazySlice = fun T => { value | Array T } in

let rec transform = fun e =>
    if std.is_record e then
        if std.record.has_field "_tagged_union" e then
            { "%{std.to_string e.tag}" = transform e.data }
        else
            std.record.map_values transform e
    else if std.is_array e then
        std.array.map transform e
    else
        e
in

let rec toZon = fun e =>
    if std.is_record e then
        let inner = 
            std.record.to_array e
            |> std.array.map (fun {field, value} => ".%{field} = %{toZon value}")
            |> std.array.intersperse ", "
            |> std.array.fold_left (++) ""
        in
        ".{ %{inner} }"
    else if std.is_array e then
        let inner =
            std.array.map toZon e
            |> std.array.intersperse ", "
            |> std.array.fold_left (++) ""
        in
        ".{ %{inner} }"
    else if std.is_enum e then
        ".%{std.to_string e}"
    else
        std.to_string e
in

let TaggedUnion = fun tag_enum match_fn => {
    _tagged_union | Bool | default = true,
    tag | tag_enum,
    data | match_fn tag,
} in

let rec types = {
    Root = {
        header | types.Header | default = {},
        behaviors | LazySlice Behavior,
    },
    Header = {
        magic | Uint 16 | default = 64105,
        version | Uint 16 | default = 1,
    },
    Keycode = Uint 16,
    Behavior = TaggedUnion
        [| 'key_press, 'hold_tap, 'tap_dance |]
        (match {
            'key_press => {
                key_codes | LazySlice Keycode,
            },
            'hold_tap => {  
                hold_behavior | LazyIndexed Behavior,
                tap_behavior | LazyIndexed Behavior,
                props | LazyIndexed HoldTapProps,
            },
            'tap_dance => { 
                bindings | LazySlice Behavior,
                tapping_term_ms | Uint 14 | default = 200,
            }
        }),
    HoldTapProps = {
        timeout_ms | Uint 14 | default = 200,
        timeout_decision | [| 'hold, 'tap |] | default = 'hold,
        eager_decision | [| 'none, 'hold, 'tap |] | default = 'none,
        key_interrupts | Array HoldTapKeyInterrupt | default = [],
        quick_tap_ms | Uint 14 | default = 0,
        quick_tap_interrupt_ms | Uint 14 | default = 0,
        global_quick_tap_ms | Uint 14 | default = 0,
        global_quick_tap_ignore_consecutive | Bool | default = false,
    },
    HoldTapKeyInterrupt = [| 'none, 'hold_on_press, 'hold_on_release, 'tap_on_press, 'tap_on_release |],
}
in

{
    Keymap = types.Root,
    parseKeymap = fun km => "pub const K = %{toZon (transform ({ behaviors.value = km } | Keymap))};",
}

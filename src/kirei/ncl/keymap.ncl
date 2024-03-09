let { Uint, TaggedUnion, FixedArray, Ptr, Void, zonify, .. } = import "zig.ncl" in

let KeyCode = Uint 12 in
let KeyIndex = Uint 8 in

let ModifierNecessity = [| 'unwanted, 'required, '"optional" |] in

let KeyPattern = {
    mods | FixedArray 8 ModifierNecessity | default = { array = std.array.replicate 8 'unwanted },
    key_code = TaggedUnion
        [| 'none, 'exact, 'range |]
        (match {
            'none => {},
            'exact => KeyCode,
            'range => { from | KeyCode, to | KeyCode },
        }),
} in

let rec lang = {
    Expression = fun T => TaggedUnion
        [| 'literal, 'swt |]
        (match {
            'literal => T,
            'swt => Switch T,
        }),

    Switch = fun T => {
        branches | Array (Branch T),
        fallback | T,
    },

    Branch = fun T => {
        condition | Condition,
        value | Expression T,
    },

    Condition = TaggedUnion
        [| 'literal, 'query, 'logical_not, 'logical_and, 'logical_or |]
        (match {
            'literal => Bool,
            'query => Query,
            'logical_not => Ptr Condition,
            'logical_and => Array Condition, # TODO: At least 2 elements please
            'logical_or => Array Condition,
        }),
    
    Query = TaggedUnion
        [| 'is_pressed, 'is_key_pressed |]
        (match {
            'is_pressed => KeyPattern,
            'is_key_pressed => KeyIndex,
        }),
} in

let rec keymap = {
    KeyGroup =
        let Props = {
            retention | [| 'normal, 'weak |] | default = 'normal,
            anti | Bool | default = false,
        } in

        let Modifier = {
            side | [| 'none, 'left, 'right, 'both |] | default = 'none,
            props | Props | default = {}, 
        } in

        {
            mods | {
                ctrl | Modifier | default = {},
                shift | Modifier | default = {},
                alt | Modifier | default = {},
                gui | Modifier | default = {},
            } | default = {},
            key_code | KeyCode | default = 0,
        },

    KeyPressBehavior = {
        key_group | KeyGroup,
        # hooks
    },

    KeyToggleBehavior = {
        key_group | KeyGroup,
        # hooks
    },

    HoldTapBehavior = {
        hold_key_def | Ptr KeyDef,
        tap_key_def | Ptr KeyDef,
        timeout_ms | Uint 16,
    },

    KeyDef = TaggedUnion
        [| 'none, 'key_press, 'key_toggle, 'hold_tap |]
        (match {
            'none => Void,
            'key_press => KeyPressBehavior,
            'key_toggle => KeyToggleBehavior,
            'hold_tap => HoldTapBehavior,
        }),
    
    KeyMap = Array (lang.Expression KeyDef),
} in

{
    KeyMap = keymap.KeyMap,
    parseKeyMap = fun km => "pub const key_map = %{zonify (km | keymap.KeyMap)};",
}
